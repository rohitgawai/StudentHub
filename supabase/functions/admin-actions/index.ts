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

// Server-side admin actions: role grants/revocations, bans and student
// verification. The caller proves they hold the admin role in `profiles`
// (same trust model as delete-post), so the anon key alone can never grant
// roles — closing the client-side privilege escalation hole.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  let payload: {
    admin_user_id?: string
    action?: string
    user_id?: string
    roles?: string[]
  }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400, headers: corsHeaders })
  }
  const { admin_user_id, action, user_id, roles } = payload
  if (!admin_user_id || !action || !user_id) {
    return new Response('Missing admin_user_id/action/user_id', {
      status: 400,
      headers: corsHeaders,
    })
  }

  // The caller must be an admin.
  const { data: admins, error: adminError } = await supabase
    .from('profiles')
    .select('roles')
    .eq('user_id', admin_user_id)
    .limit(1)
  if (adminError) {
    console.error('admin-actions admin lookup failed', adminError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  const isAdmin = (admins ?? []).some((p) =>
    Array.isArray(p.roles) && p.roles.includes('admin'))
  if (!isAdmin) {
    return new Response('Not an admin', { status: 403, headers: corsHeaders })
  }

  // Load the target profile once; fail early when it does not exist.
  const { data: targets, error: targetError } = await supabase
    .from('profiles')
    .select('user_id, roles')
    .eq('user_id', user_id)
    .limit(1)
  if (targetError) {
    console.error('admin-actions target lookup failed', targetError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  if (!targets || targets.length === 0) {
    return new Response('Target user not found', {
      status: 404,
      headers: corsHeaders,
    })
  }

  switch (action) {
    case 'set_roles': {
      if (!Array.isArray(roles)) {
        return new Response('Missing roles array', {
          status: 400,
          headers: corsHeaders,
        })
      }
      const { error: e } = await supabase
        .from('profiles')
        .update({ roles })
        .eq('user_id', user_id)
      if (e) {
        console.error('admin-actions set_roles failed', e.message)
        return new Response('Internal error', { status: 500, headers: corsHeaders })
      }
      break
    }
    case 'ban': {
      const { error: e } = await supabase
        .from('profiles')
        .update({ roles: ['banned'] })
        .eq('user_id', user_id)
      if (e) {
        console.error('admin-actions ban failed', e.message)
        return new Response('Internal error', { status: 500, headers: corsHeaders })
      }
      break
    }
    case 'unban': {
      const { error: e } = await supabase
        .from('profiles')
        .update({ roles: ['student'] })
        .eq('user_id', user_id)
      if (e) {
        console.error('admin-actions unban failed', e.message)
        return new Response('Internal error', { status: 500, headers: corsHeaders })
      }
      break
    }
    case 'verify_student': {
      const { error: e } = await supabase
        .from('profiles')
        .update({ is_verified: true })
        .eq('user_id', user_id)
      if (e) {
        console.error('admin-actions verify_student failed', e.message)
        return new Response('Internal error', { status: 500, headers: corsHeaders })
      }
      break
    }
    default:
      return new Response('Unknown action', { status: 400, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ ok: true, action, user_id }), {
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
})