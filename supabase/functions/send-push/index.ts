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

// Short admin codes -> full department names stored in profiles.department.
const BRANCH_MAP: Record<string, string> = {
  CSE: 'Computer Science & Engineering',
  IT: 'Information Technology',
  ECE: 'Electronics & Communication',
  MECH: 'Mechanical Engineering',
  CIVIL: 'Civil Engineering',
}

// Short admin codes -> full academic year names stored in profiles.year.
const YEAR_MAP: Record<string, string> = {
  '1st Year': 'First Year',
  '2nd Year': 'Second Year',
  '3rd Year': 'Third Year',
  '4th Year': 'Final Year',
}

// Entry point guarded by a shared secret (set via `supabase secrets set`).
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', {
      status: 401,
      headers: corsHeaders,
    })
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
    recipient_user_ids?: string[]
    exclude_user_id?: string
    skip_sender_device?: boolean
    target_branch?: string
    target_year?: string
  }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400, headers: corsHeaders })
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
    recipient_user_ids,
    exclude_user_id,
    skip_sender_device,
    target_branch,
    target_year,
  } = payload
  const type = payload.type ?? 'new_post'
  if (!title) {
    return new Response('Missing title', { status: 400, headers: corsHeaders })
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
    return new Response('FCM not configured', {
      status: 500,
      headers: corsHeaders,
    })
  }
  const serviceAccount = JSON.parse(serviceAccountJson)

  const { data: devices, error } = await supabase
    .from('device_tokens')
    .select('token, user_id, device_id')
  if (error) {
    console.error('fetch device_tokens failed', error.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }

  // Resolve branch/year targeting (admin broadcasts) against the profiles
  // table. Short codes sent by the admin panel are mapped to the full names
  // stored on each user profile.
  let branchYearById: Map<string, { department: string; year: string }> | null =
    null
  const wantBranch = target_branch && target_branch !== 'ALL'
  const wantYear = target_year && target_year !== 'ALL'
  if (wantBranch || wantYear) {
    const { data: profiles } = await supabase
      .from('profiles')
      .select('user_id, department, year')
    branchYearById = new Map(
      (profiles ?? []).map((p) => [
        String(p.user_id),
        { department: String(p.department ?? ''), year: String(p.year ?? '') },
      ]),
    )
  }

  // Scope targets by recipient when given (host-only "X registered" pushes,
  // a registrant's own confirmation, or a batch of registrants), exclude an
  // entire user's devices (e.g. the publisher of a "new post" push), and when
  // skip_sender_device is true (default) exclude this device too, matching
  // device_id when present and falling back to the author's user_id.
  const recipientSet = new Set(
    (recipient_user_ids ?? []).map((id) => String(id)),
  )
  const targets = (devices ?? [])
    .filter((d) => {
      if (recipientSet.size > 0) return recipientSet.has(String(d.user_id ?? ''))
      return recipient_user_id ? String(d.user_id ?? '') === recipient_user_id : true
    })
    .filter((d) => {
      if (!branchYearById) return true
      const profile = branchYearById.get(String(d.user_id ?? ''))
      if (!profile) return false
      if (wantBranch) {
        const branchName =
          BRANCH_MAP[String(target_branch)] ?? String(target_branch)
        if (profile.department !== branchName) return false
      }
      if (wantYear) {
        const yearName = YEAR_MAP[String(target_year)] ?? String(target_year)
        if (profile.year !== yearName) return false
      }
      return true
    })
    .filter((d) =>
      exclude_user_id
        ? String(d.user_id ?? '') !== exclude_user_id
        : true)
    .filter((d) => {
      if (skip_sender_device === false) return true
      const isSenderDevice = device_id && String(d.device_id ?? '') === device_id
      const isAuthorUser = author_id && String(d.user_id ?? '') === author_id
      return !isSenderDevice && !isAuthorUser
    })
    .map((d) => String(d.token))
    .filter((t) => t.length > 0)

  // Persist ADMIN broadcasts to the broadcasts table (NOT the campus feed).
  // The mobile app syncs these rows into the in-app notification bell only.
  if (type === 'announcement' && author_id === 'admin_official') {
    const branchName =
      target_branch && target_branch !== 'ALL'
        ? (BRANCH_MAP[String(target_branch)] ?? String(target_branch))
        : 'ALL'
    const yearName =
      target_year && target_year !== 'ALL'
        ? (YEAR_MAP[String(target_year)] ?? String(target_year))
        : 'ALL'
    const { error: bErr } = await supabase.from('broadcasts').upsert({
      id: post_id ?? `announcement_${Date.now()}`,
      title,
      body: body ?? '',
      branch: branchName,
      year: yearName,
      author_name: 'Admin',
    }, { onConflict: 'id' })
    if (bErr) {
      console.error('admin broadcast insert failed', bErr.message)
    }
  }

  if (targets.length === 0) {
    await log({ total_tokens: (devices ?? []).length, targets: 0, sent: 0, removed: 0 })
    return new Response(JSON.stringify({ sent: 0, removed: 0 }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
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
    return new Response('Could not obtain FCM token', {
      status: 500,
      headers: corsHeaders,
    })
  }

  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

  let sent = 0
  const toRemove: string[] = []
  const isAdminBroadcast = type === 'announcement' && author_id === 'admin_official'
  const pushTitle = isAdminBroadcast ? `📢 ${title}` : title
  const pushBody = `${(body ?? title).slice(0, 200)}${isAdminBroadcast ? '\n\nBy Admin' : ''}`
  for (const token of targets) {
    const message = {
      message: {
        token,
        notification: { title: pushTitle, body: pushBody },
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
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  })
})