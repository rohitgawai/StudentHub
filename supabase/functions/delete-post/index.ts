import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

// Deletes a post ONLY when the caller proves they are its author — or when the
// caller proves they hold the admin role (moderation). The app has no auth
// accounts, so identity is the user id from the `profiles` table: `delete
// where id = ? AND author_id = ?` for authors; for admins the caller's user id
// is looked up in `profiles` and their roles must include 'admin'.
Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: { post_id?: string; author_id?: string; admin_user_id?: string }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400 })
  }
  const { post_id, author_id, admin_user_id } = payload
  if (!post_id) {
    return new Response('Missing post_id', { status: 400 })
  }

  // Moderation path: verify the caller really is an admin before allowing a
  // delete of a post they did not author.
  if (admin_user_id) {
    const { data: admins, error: adminError } = await supabase
      .from('profiles')
      .select('roles')
      .eq('user_id', admin_user_id)
      .limit(1)
    if (adminError) {
      console.error('delete-post admin lookup failed', adminError.message)
      return new Response('Internal error', { status: 500 })
    }
    const isAdmin = (admins ?? []).some((p) =>
      Array.isArray(p.roles) && p.roles.includes('admin'))
    if (!isAdmin) {
      return new Response('Not an admin', { status: 403 })
    }
    const { error: moderationError } = await supabase
      .from('posts')
      .delete()
      .eq('id', post_id)
    if (moderationError) {
      console.error('delete-post (admin) failed', moderationError.message)
      return new Response('Internal error', { status: 500 })
    }
    return new Response(JSON.stringify({ deleted: post_id, as: 'admin' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (!author_id) {
    return new Response('Missing author_id', { status: 400 })
  }

  const { data: rows, error: selectError } = await supabase
    .from('posts')
    .select('id')
    .eq('id', post_id)
    .eq('author_id', author_id)
    .limit(1)
  if (selectError) {
    console.error('delete-post check failed', selectError.message)
    return new Response('Internal error', { status: 500 })
  }
  if (!rows || rows.length === 0) {
    return new Response('Not found or not the author', { status: 404 })
  }

  const { error: deleteError } = await supabase
    .from('posts')
    .delete()
    .eq('id', post_id)
    .eq('author_id', author_id)
  if (deleteError) {
    console.error('delete-post failed', deleteError.message)
    return new Response('Internal error', { status: 500 })
  }

  return new Response(JSON.stringify({ deleted: post_id }), {
    headers: { 'Content-Type': 'application/json' },
  })
})