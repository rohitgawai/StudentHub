import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-push-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Permanently deletes a user account and every trace of it on the server:
// device tokens, form submissions, role requests, authored posts, push log
// entries, reports (as author OR reporter) and finally the profile row itself
// (which cascades profile_credentials via the ON DELETE CASCADE FK).
//
// Authorization requires BOTH the shared push secret AND proof that the
// caller holds the admin role (admin_user_id is verified against
// `profiles.roles`, same trust model as delete-post). Without the role check,
// anyone with the leaked secret could delete arbitrary accounts.
Deno.serve(async (req) => {
  // Browser CORS preflight must succeed BEFORE the secret check, otherwise the
  // panel (Flutter web) silently fails every admin action with a 401.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  let payload: { user_id?: string; admin_user_id?: string }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400, headers: corsHeaders })
  }
  const user_id = (payload.user_id ?? '').trim()
  if (!user_id) {
    return new Response('Missing user_id', { status: 400, headers: corsHeaders })
  }

  const adminUserId = (payload.admin_user_id ?? '').trim()
  if (!adminUserId) {
    return new Response('Missing admin_user_id', {
      status: 400,
      headers: corsHeaders,
    })
  }
  const { data: admins, error: adminError } = await supabase
    .from('profiles')
    .select('roles')
    .eq('user_id', adminUserId)
    .limit(1)
  if (adminError) {
    console.error('delete-user admin lookup failed', adminError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  const isAdmin = (admins ?? []).some((p) =>
    Array.isArray(p.roles) && p.roles.includes('admin'))
  if (!isAdmin) {
    return new Response('Not an admin', { status: 403, headers: corsHeaders })
  }

  // Target must exist — refuse to delete nothing.
  const { data: existing, error: lookupError } = await supabase
    .from('profiles')
    .select('user_id')
    .eq('user_id', user_id)
    .limit(1)
  if (lookupError) {
    console.error('delete-user lookup failed', lookupError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  if (!existing || existing.length === 0) {
    return new Response(JSON.stringify({ error: 'account_not_found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
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
      return new Response('Internal error', { status: 500, headers: corsHeaders })
    }
  }

  // reported_posts: as author of the reported content OR as the reporter.
  const { error: reportError } = await supabase
    .from('reported_posts')
    .delete()
    .or(`author_id.eq.${user_id},reporter_id.eq.${user_id}`)
  if (reportError) {
    console.error('delete-user reported_posts failed', reportError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }

  // The profile last: profile_credentials cascades with it.
  const { error: profileError } = await supabase
    .from('profiles')
    .delete()
    .eq('user_id', user_id)
  if (profileError) {
    console.error('delete-user profiles failed', profileError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ deleted: user_id }), {
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
})