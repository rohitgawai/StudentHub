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
  user_id?: string
}

interface ProfileRow {
  user_id: string
  has_password: boolean
  roles?: string[]
  student_or_employee_id?: string
  is_verified?: boolean
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
  const explicitUserId = (payload.user_id ?? '').trim()

  if (!email || !password || !deviceId) {
    return errorResponse('Missing email, password, or device_id', 400)
  }
  if (password.length < 6) {
    return errorResponse('Password must be at least 6 characters', 400)
  }
  if (!ALLOWED_ACTIONS.includes(action as Action)) {
    return errorResponse('Invalid action', 400)
  }

  let profileQuery = supabase
    .from('profiles')
    .select('user_id, has_password, roles, student_or_employee_id, is_verified')
  
  if (explicitUserId) {
    profileQuery = profileQuery.eq('user_id', explicitUserId)
  } else {
    profileQuery = profileQuery.eq('email', email)
  }

  const { data: profiles, error: profileError } = await profileQuery.limit(5)

  if (profileError) {
    console.error('account-credentials profile lookup failed', profileError.message)
    return errorResponse('Internal error: ' + profileError.message, 500)
  }
  if (!profiles || profiles.length === 0) {
    return errorResponse('account_not_found', 404)
  }

  // Filter out soft-deleted profiles if multiple rows exist
  let bestProfile: ProfileRow = profiles[0] as ProfileRow
  if (profiles.length > 1) {
    let bestScore = -1
    for (const p of profiles as ProfileRow[]) {
      const roles = p.roles ?? []
      if (roles.includes('deleted')) continue
      let score = 0
      if ((p.student_or_employee_id ?? '').length > 0) score += 4
      if (p.is_verified) score += 1
      if (score > bestScore) {
        bestScore = score
        bestProfile = p
      }
    }
  }

  const userId = String(bestProfile.user_id)
  const hasPassword = Boolean(bestProfile.has_password)

  if (action === 'admin_clear_password') {
    const { error: delError } = await supabase.from('profile_credentials').delete().eq('user_id', userId)
    if (delError) {
      console.error('admin_clear_password cred delete failed', delError.message)
      return errorResponse('Database error clearing credentials: ' + delError.message, 500)
    }
    const { error: profError } = await supabase
      .from('profiles')
      .update({ has_password: false, active_device_id: '', updated_at: new Date().toISOString() })
      .eq('user_id', userId)
    if (profError) {
      console.error('admin_clear_password profile update failed', profError.message)
      return errorResponse('Database error updating profile: ' + profError.message, 500)
    }
    return jsonResponse({ ok: true, user_id: userId, message: 'Password requirement wiped. Student can set a new password on their next login.' })
  }

  if (action === 'admin_reset_password') {
    const newHash = bcrypt.hashSync(password, 10)
    const { error: credError } = await supabase.from('profile_credentials').upsert(
      {
        user_id: userId,
        password_hash: newHash,
        created_device_id: '', // Empty string, never null (satisfies NOT NULL default '')
      },
      { onConflict: 'user_id' },
    )
    if (credError) {
      console.error('admin_reset_password cred upsert failed', credError.message)
      return errorResponse('Database error resetting credentials: ' + credError.message, 500)
    }
    const { error: profError } = await supabase
      .from('profiles')
      .update({ has_password: true, active_device_id: '', updated_at: new Date().toISOString() })
      .eq('user_id', userId)
    if (profError) {
      console.error('admin_reset_password profile update failed', profError.message)
      return errorResponse('Database error updating profile: ' + profError.message, 500)
    }
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
    if (action === 'reset_password') {
      const newHash = bcrypt.hashSync(password, 10)
      const { error: upsertError } = await supabase.from('profile_credentials').upsert(
        {
          user_id: userId,
          password_hash: newHash,
          created_device_id: deviceId,
        },
        { onConflict: 'user_id' },
      )
      if (upsertError) {
        console.error('account-credentials reset upsert failed', upsertError.message)
        return errorResponse('Internal error: ' + upsertError.message, 500)
      }
      await supabase
        .from('profiles')
        .update({ active_device_id: deviceId, has_password: true, updated_at: new Date().toISOString() })
        .eq('user_id', userId)
      return jsonResponse({ ok: true, user_id: userId })
    }
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

  // If created_device_id was empty (e.g. wiped or set by admin for lost device recovery),
  // adopt this logging-in device as the new primary device.
  if (!createdDeviceId) {
    await supabase
      .from('profile_credentials')
      .update({ created_device_id: deviceId, updated_at: new Date().toISOString() })
      .eq('user_id', userId)
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