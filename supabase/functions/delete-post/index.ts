import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

// Deletes a post ONLY when the caller proves they are its author. The app has
// no auth accounts, so the author's user id (stored on the post at publish
// time) doubles as the identity: `delete where id = ? AND author_id = ?`.
// A matching row must exist or the delete is refused.
Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: { post_id?: string; author_id?: string }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400 })
  }
  const { post_id, author_id } = payload
  if (!post_id || !author_id) {
    return new Response('Missing post_id/author_id', { status: 400 })
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