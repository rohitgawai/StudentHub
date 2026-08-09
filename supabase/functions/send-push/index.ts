import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

// Entry point guarded by a shared secret (set via `supabase secrets set`).
Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: {
    post_id?: string
    title?: string
    body?: string
    category?: string
    author_id?: string
    device_id?: string
    type?: string
    registrant_name?: string
    recipient_user_id?: string
    skip_sender_device?: boolean
  }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400 })
  }
  const {
    post_id,
    title,
    body,
    category,
    author_id,
    device_id,
    registrant_name,
    recipient_user_id,
    skip_sender_device,
  } = payload
  const type = payload.type ?? 'new_post'
  if (!title) {
    return new Response('Missing title', { status: 400 })
  }
  const log = async (fields: Record<string, unknown>) => {
    const { error: e } = await supabase.from('push_log').insert({
      post_id,
      title,
      category,
      author_id,
      device_id,
      type,
      registrant_name,
      ...fields,
    })
    if (e) console.error('push_log insert failed', e.message)
    return e?.message ?? null
  }

  const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
  if (!serviceAccountJson) {
    console.error('FCM_SERVICE_ACCOUNT_JSON is not configured')
    return new Response('FCM not configured', { status: 500 })
  }
  const serviceAccount = JSON.parse(serviceAccountJson)

  const { data: devices, error } = await supabase
    .from('device_tokens')
    .select('token, user_id')
  if (error) {
    console.error('fetch device_tokens failed', error.message)
    return new Response('Internal error', { status: 500 })
  }

  // Scope targets by recipient when given (host-only "X registered" pushes,
  // or a registrant's own confirmation). When skip_sender_device is true
  // (default) this device is excluded, matching device_id when present and
  // falling back to the author's user_id.
  const targets = (devices ?? [])
    .filter((d) =>
      recipient_user_id
        ? String(d.user_id ?? '') === recipient_user_id
        : true)
    .filter((d) => {
      if (skip_sender_device === false) return true
      return device_id
        ? String(d.device_id ?? '') !== device_id
        : d.user_id !== author_id
    })
    .map((d) => String(d.token))
    .filter((t) => t.length > 0)

  if (targets.length === 0) {
    await log({ total_tokens: (devices ?? []).length, targets: 0, sent: 0, removed: 0 })
    return new Response(JSON.stringify({ sent: 0, removed: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Mint an OAuth access token from the Firebase service account, then POST to
  // the HTTP v1 endpoint (legacy firebase keys no longer work).
  const { GoogleAuth } = await import('npm:google-auth-library@9')
  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const client = await auth.getClient()
  const accessToken = await client.getAccessToken()
  const bearer = accessToken?.token
  if (!bearer) {
    return new Response('Could not obtain FCM token', { status: 500 })
  }

  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

  let sent = 0
  const toRemove: string[] = []
  for (const token of targets) {
    const message = {
      message: {
        token,
        notification: { title, body: (body ?? title).slice(0, 200) },
        data: {
          type,
          post_id: post_id ?? '',
          category: category ?? 'announcement',
          author_id: author_id ?? '',
          registrant_name: registrant_name ?? '',
        },
        android: { priority: 'HIGH' },
      },
    }
    const res = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${bearer}`,
      },
      body: JSON.stringify(message),
    })
    if (res.ok) {
      sent += 1
      continue
    }
    const raw = await res.text()
    if (res.status === 404 || raw.includes('UNREGISTERED')) {
      toRemove.push(token)
    } else {
      console.error('FCM send failed', res.status, raw)
    }
  }

  if (toRemove.length > 0) {
    await supabase.from('device_tokens').delete().in('token', toRemove)
  }

  const sentText = JSON.stringify({ sent, removed: toRemove.length })

  await log({
    total_tokens: (devices ?? []).length,
    targets: targets.length,
    sent,
    removed: toRemove.length,
  })

  return new Response(sentText, {
    headers: { 'Content-Type': 'application/json' },
  })
})