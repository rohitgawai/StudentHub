import { createClient } from 'jsr:@supabase/supabase-js@2'
import bcrypt from 'npm:bcryptjs@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

// Server-side password storage & verification for StudentHub accounts.
// Guarded by the shared push secret (same trust model as the other edge
// functions). Passwords are bcrypt-hashed and kept in `profile_credentials`,
// which has no anon/authenticated RLS, so hashes can never leak to the app.
//
// Actions:
//   set_password   - first password for an account (only when has_password=false)
//   verify_login   - password check; on success rotates profiles.active_device_id
//                    (kicks the previous device) so new-device logins are
//                    single-session like everything else
//   reset_password - only allowed from the device that originally set the
//                    password (created_device_id match)
Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: {
    action?: string
    email?: string
    password?: string
    device_id?: string
  }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400 })
  }
  const action = payload.action ?? ''
  const email = (payload.email ?? '').trim().toLowerCase()
  const password = payload.password ?? ''
  const deviceId = payload.device_id ?? ''

  if (!email || !password || !deviceId) {
    return new Response('Missing email/password/device_id', { status: 400 })
  }
  if (password.length < 6) {
    return new Response('Password must be at least 6 characters', { status: 400 })
  }
  if (!['set_password', 'verify_login', 'reset_password'].includes(action)) {
    return new Response('Invalid action', { status: 400 })
  }

  const { data: profiles, error: profileError } = await supabase
    .from('profiles')
    .select('user_id, has_password')
    .eq('email', email)
    .limit(1)
  if (profileError) {
    console.error('account-credentials profile lookup failed', profileError.message)
    return new Response('Internal error', { status: 500 })
  }
  if (!profiles || profiles.length === 0) {
    return new Response(JSON.stringify({ error: 'account_not_found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  const profile = profiles[0]
  const userId = String(profile.user_id)
  const hasPassword = Boolean(profile.has_password)

  if (action === 'set_password') {
    if (hasPassword) {
      return new Response(JSON.stringify({ error: 'password_already_set' }), {
        status: 409,
        headers: { 'Content-Type': 'application/json' },
      })
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
      return new Response('Internal error', { status: 500 })
    }
    const { error: flagError } = await supabase
      .from('profiles')
      .update({ has_password: true, active_device_id: deviceId })
      .eq('user_id', userId)
    if (flagError) {
      console.error('account-credentials flag update failed', flagError.message)
      return new Response('Internal error', { status: 500 })
    }
    return new Response(JSON.stringify({ ok: true, user_id: userId }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { data: creds, error: credError } = await supabase
    .from('profile_credentials')
    .select('password_hash, created_device_id')
    .eq('user_id', userId)
    .limit(1)
  if (credError) {
    console.error('account-credentials fetch failed', credError.message)
    return new Response('Internal error', { status: 500 })
  }
  if (!creds || creds.length === 0) {
    return new Response(JSON.stringify({ error: 'credentials_missing' }), {
      status: 409,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  const hash = String(creds[0].password_hash)
  const createdDeviceId = String(creds[0].created_device_id ?? '')

  if (action === 'reset_password') {
    if (createdDeviceId !== deviceId) {
      return new Response(JSON.stringify({ error: 'device_mismatch' }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' },
      })
    }
    const newHash = bcrypt.hashSync(password, 10)
    const { error: updateError } = await supabase
      .from('profile_credentials')
      .update({ password_hash: newHash })
      .eq('user_id', userId)
    if (updateError) {
      console.error('account-credentials reset failed', updateError.message)
      return new Response('Internal error', { status: 500 })
    }
    return new Response(JSON.stringify({ ok: true, user_id: userId }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // verify_login
  if (!bcrypt.compareSync(password, hash)) {
    // Throttle brute force: cheap delay before answering a wrong password.
    await new Promise((r) => setTimeout(r, 1000))
    return new Response(JSON.stringify({ error: 'wrong_password' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  const { error: deviceError } = await supabase
    .from('profiles')
    .update({ active_device_id: deviceId, updated_at: new Date().toISOString() })
    .eq('user_id', userId)
  if (deviceError) {
    console.error('account-credentials device rotation failed', deviceError.message)
    return new Response('Internal error', { status: 500 })
  }
  return new Response(JSON.stringify({ ok: true, user_id: userId }), {
    headers: { 'Content-Type': 'application/json' },
  })
})