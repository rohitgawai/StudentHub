/// <reference path="../deno.d.ts" />
import { createClient } from 'jsr:@supabase/supabase-js@2.45.0'
import bcrypt from 'npm:bcryptjs@2.4.3'

const supabaseUrl = Deno.env.get('SUPABASE_URL')
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing required environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY')
  Deno.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') ?? '*'

const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-push-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
} as const

function corsResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
}

function corsError(message: string, status = 400): Response {
  return corsResponse({ error: message }, status)
}

interface RequestPayload {
  email?: string
  password?: string
}

interface ProfileRow {
  user_id: string
  name: string | null
  email: string
  roles: string[] | null
}

interface CredentialRow {
  password_hash: string
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return corsError('Unauthorized', 401)
  }

  if (req.method !== 'POST') {
    return corsError('Method not allowed', 405)
  }

  const contentType = req.headers.get('content-type') ?? ''
  if (!contentType.includes('application/json')) {
    return corsError('Content-Type must be application/json', 400)
  }

  let payload: RequestPayload
  try {
    payload = await req.json()
  } catch {
    return corsError('Bad request: invalid JSON', 400)
  }

  const email = (payload.email ?? '').trim().toLowerCase()
  const password = payload.password ?? ''

  if (!email || !password) {
    return corsError('Missing email or password', 400)
  }

  const { data: profiles, error: profileError } = await supabase
    .from('profiles')
    .select('user_id, name, email, roles')
    .eq('email', email)
    .limit(1)

  if (profileError) {
    console.error('verify-admin profile lookup failed', profileError.message)
    return corsError('Internal error', 500)
  }

  const profile = profiles?.[0] as ProfileRow | undefined
  if (!profile) {
    return corsError('account_not_found', 404)
  }

  const isAdmin = Array.isArray(profile.roles) && profile.roles.includes('admin')
  if (!isAdmin) {
    return corsError('not_admin', 403)
  }

  const { data: creds, error: credError } = await supabase
    .from('profile_credentials')
    .select('password_hash')
    .eq('user_id', String(profile.user_id))
    .limit(1)

  if (credError) {
    console.error('verify-admin credentials lookup failed', credError.message)
    return corsError('Internal error', 500)
  }

  const hash = creds?.[0]?.password_hash
  if (!hash || !bcrypt.compareSync(password, String(hash))) {
    await new Promise((r) => setTimeout(r, 1000))
    return corsError('wrong_password', 401)
  }

  return corsResponse({
    ok: true,
    user_id: String(profile.user_id),
    name: String(profile.name ?? ''),
    email,
  })
})