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

const ALLOWED_ACTIONS = [
  'set_password',
  'verify_login',
  'reset_password',
  'admin_reset_password',
  'admin_clear_password',
] as const

type Action = (typeof ALLOWED_ACTIONS)[number]

interface RequestPayload {
  action?: string
  email?: string
  password?: string
  device_id?: string
  admin_user_id?: string
}

interface ProfileRow {
  user_id: string
  has_password: boolean
}

interface CredentialRow {
  password_hash: string
  created_device_id: string | null
}

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-push-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
} as const

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
}

function errorResponse(message: string, status = 400, extra?: Record<string, unknown>): Response {
  return jsonResponse({ error: message, ...extra }, status)
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return errorResponse('Unauthorized', 401)
  }

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405)
  }

  const contentType = req.headers.get('content-type') ?? ''
  if (!contentType.includes('application/json')) {
    return errorResponse('Content-Type must be application/json', 400)
  }

  let payload: RequestPayload
  try {
    payload = await req.json()
  } catch {
    return errorResponse('Bad request: invalid JSON', 400)
  }

  const action = (payload.action ?? '').trim()
  const email = (payload.email ?? '').trim().toLowerCase()
  const password = payload.password ?? ''
  const deviceId = (payload.device_id ?? '').trim()

  if (!email || !password || !deviceId) {
    return errorResponse('Missing email, password, or device_id', 400)
  }
  if (password.length < 6) {
    return errorResponse('Password must be at least 6 characters', 400)
  }
  if (!ALLOWED_ACTIONS.includes(action as Action)) {
    return errorResponse('Invalid action', 400)
  }

  const { data: profiles, error: profileError } = await supabase
    .from('profiles')
    .select('user_id, has_password')
    .eq('email', email)
    .limit(1)

  if (profileError) {
    console.error('account-credentials profile lookup failed', profileError.message)
    return errorResponse('Internal error', 500)
  }
  if (!profiles || profiles.length === 0) {
    return errorResponse('account_not_found', 404)
  }

  const profile = profiles[0] as ProfileRow
  const userId = String(profile.user_id)
  const hasPassword = Boolean(profile.has_password)

  if (action === 'admin_clear_password') {
    await supabase.from('profile_credentials').delete().eq('user_id', userId)
    await supabase
      .from('profiles')
      .update({ has_password: false, active_device_id: null, updated_at: new Date().toISOString() })
      .eq('user_id', userId)
    return jsonResponse({ ok: true, user_id: userId, message: 'Password cleared. User will set a new one on next login.' })
  }

  if (action === 'admin_reset_password') {
    const newHash = bcrypt.hashSync(password, 10)
    await supabase.from('profile_credentials').upsert(
      {
        user_id: userId,
        password_hash: newHash,
        created_device_id: null,
      },
      { onConflict: 'user_id' },
    )
    await supabase
      .from('profiles')
      .update({ has_password: true, updated_at: new Date().toISOString() })
      .eq('user_id', userId)
    return jsonResponse({ ok: true, user_id: userId, message: 'Password reset successfully by admin.' })
  }

  if (action === 'set_password') {
    if (hasPassword) {
      return errorResponse('password_already_set', 409)
    }
    const hash = bcrypt.hashSync(password, 10)
    const { error: credError } = await supabase.from('profile_credentials').upsert(
      {
        user_id: userId,
        password_hash: hash,
        created_device_id: deviceId,
      },
      { onConflict: 'user_id' },
    )
    if (credError) {
      console.error('account-credentials upsert failed', credError.message)
      return errorResponse('Internal error', 500)
    }
    const { error: flagError } = await supabase
      .from('profiles')
      .update({ has_password: true, active_device_id: deviceId })
      .eq('user_id', userId)
    if (flagError) {
      console.error('account-credentials flag update failed', flagError.message)
      return errorResponse('Internal error', 500)
    }
    return jsonResponse({ ok: true, user_id: userId })
  }

  const { data: creds, error: credError } = await supabase
    .from('profile_credentials')
    .select('password_hash, created_device_id')
    .eq('user_id', userId)
    .limit(1)

  if (credError) {
    console.error('account-credentials fetch failed', credError.message)
    return errorResponse('Internal error', 500)
  }
  if (!creds || creds.length === 0) {
    return errorResponse('credentials_missing', 409)
  }

  const cred = creds[0] as CredentialRow
  const hash = String(cred.password_hash)
  const createdDeviceId = cred.created_device_id ?? ''

  if (action === 'reset_password') {
    if (createdDeviceId && createdDeviceId !== deviceId) {
      return errorResponse(
        'device_mismatch',
        403,
        { message: 'Password reset is only allowed from your primary registered phone. If you switched phones, please contact your College Admin.' },
      )
    }

    const newHash = bcrypt.hashSync(password, 10)
    const { error: updateError } = await supabase
      .from('profile_credentials')
      .update({ password_hash: newHash, created_device_id: deviceId })
      .eq('user_id', userId)
    if (updateError) {
      console.error('account-credentials reset failed', updateError.message)
      return errorResponse('Internal error', 500)
    }

    await supabase
      .from('profiles')
      .update({ active_device_id: deviceId, has_password: true, updated_at: new Date().toISOString() })
      .eq('user_id', userId)

    return jsonResponse({ ok: true, user_id: userId })
  }

  if (!bcrypt.compareSync(password, hash)) {
    await new Promise((r) => setTimeout(r, 1000))
    return errorResponse('wrong_password', 401)
  }

  const { error: deviceError } = await supabase
    .from('profiles')
    .update({ active_device_id: deviceId, updated_at: new Date().toISOString() })
    .eq('user_id', userId)
  if (deviceError) {
    console.error('account-credentials device rotation failed', deviceError.message)
    return errorResponse('Internal error', 500)
  }

  return jsonResponse({ ok: true, user_id: userId })
})