import { createClient } from 'jsr:@supabase/supabase-js@2'
import bcrypt from 'npm:bcryptjs@2'

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

// Admin login verification. The caller proves the account email + password
// against the bcrypt-hashed profile_credentials table (no anon RLS there),
// AND the profile must carry the admin role. No credentials are ever
// hardcoded or shipped in the client.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  let payload: { email?: string; password?: string }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400, headers: corsHeaders })
  }
  const email = (payload.email ?? '').trim().toLowerCase()
  const password = payload.password ?? ''
  if (!email || !password) {
    return new Response('Missing email/password', {
      status: 400,
      headers: corsHeaders,
    })
  }

  const { data: profiles, error: profileError } = await supabase
    .from('profiles')
    .select('user_id, name, email, roles')
    .eq('email', email)
    .limit(1)
  if (profileError) {
    console.error('verify-admin profile lookup failed', profileError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  const profile = profiles?.[0]
  if (!profile) {
    return new Response(JSON.stringify({ error: 'account_not_found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }
  const isAdmin = Array.isArray(profile.roles) && profile.roles.includes('admin')
  if (!isAdmin) {
    return new Response(JSON.stringify({ error: 'not_admin' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }

  const { data: creds, error: credError } = await supabase
    .from('profile_credentials')
    .select('password_hash')
    .eq('user_id', String(profile.user_id))
    .limit(1)
  if (credError) {
    console.error('verify-admin credentials lookup failed', credError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  const hash = creds?.[0]?.password_hash
  if (!hash || !bcrypt.compareSync(password, String(hash))) {
    await new Promise((r) => setTimeout(r, 1000))
    return new Response(JSON.stringify({ error: 'wrong_password' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }

  return new Response(
    JSON.stringify({
      ok: true,
      user_id: String(profile.user_id),
      name: String(profile.name ?? ''),
      email: email,
    }),
    { headers: { 'Content-Type': 'application/json', ...corsHeaders } },
  )
})