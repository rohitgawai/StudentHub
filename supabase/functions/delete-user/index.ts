import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

// Permanently deletes a user account and every trace of it on the server:
// device tokens, form submissions, role requests, authored posts, push log
// entries, reports (as author OR reporter) and finally the profile row itself
// (which cascades profile_credentials via the ON DELETE CASCADE FK).
//
// Authorization is the shared push secret (same trust model as send-push and
// account-credentials): only the admin panel — which has its own hardcoded
// login UI — can call it. Returns 404 when the target account does not exist.
// The app side force-logs-out the deleted user via its profiles realtime
// subscription + periodic sync when the row disappears.
Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: { user_id?: string }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400 })
  }
  const user_id = (payload.user_id ?? '').trim()
  if (!user_id) {
    return new Response('Missing user_id', { status: 400 })
  }

  // Target must exist — refuse to delete nothing.
  const { data: existing, error: lookupError } = await supabase
    .from('profiles')
    .select('user_id')
    .eq('user_id', user_id)
    .limit(1)
  if (lookupError) {
    console.error('delete-user lookup failed', lookupError.message)
    return new Response('Internal error', { status: 500 })
  }
  if (!existing || existing.length === 0) {
    return new Response(JSON.stringify({ error: 'account_not_found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Simple user_id columns first.
  const simpleDeletes: [string, string][] = [
    ['device_tokens', 'user_id'],
    ['form_submissions', 'user_id'],
    ['role_requests', 'user_id'],
    ['posts', 'author_id'],
    ['push_log', 'author_id'],
  ]
  for (const [table, column] of simpleDeletes) {
    const { error } = await supabase.from(table).delete().eq(column, user_id)
    if (error) {
      console.error(`delete-user ${table} failed`, error.message)
      return new Response('Internal error', { status: 500 })
    }
  }

  // reported_posts: as author of the reported content OR as the reporter.
  const { error: reportError } = await supabase
    .from('reported_posts')
    .delete()
    .or(`author_id.eq.${user_id},reporter_id.eq.${user_id}`)
  if (reportError) {
    console.error('delete-user reported_posts failed', reportError.message)
    return new Response('Internal error', { status: 500 })
  }

  // The profile last: profile_credentials cascades with it.
  const { error: profileError } = await supabase
    .from('profiles')
    .delete()
    .eq('user_id', user_id)
  if (profileError) {
    console.error('delete-user profiles failed', profileError.message)
    return new Response('Internal error', { status: 500 })
  }

  return new Response(JSON.stringify({ deleted: user_id }), {
    headers: { 'Content-Type': 'application/json' },
  })
})