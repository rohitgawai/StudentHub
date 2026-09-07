/// <reference path="../deno.d.ts" />
import { createClient } from 'jsr:@supabase/supabase-js@2.45.0'

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

const BRANCH_MAP: Record<string, string> = {
  CSE: 'Computer Science & Engineering',
  IT: 'Information Technology',
  ECE: 'Electronics & Communication',
  MECH: 'Mechanical Engineering',
  CIVIL: 'Civil Engineering',
}

const YEAR_MAP: Record<string, string> = {
  '1st Year': 'First Year',
  '2nd Year': 'Second Year',
  '3rd Year': 'Third Year',
  '4th Year': 'Final Year',
}

interface RequestPayload {
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

interface DeviceTokenRow {
  token: string
  user_id: string
  device_id: string
}

interface ProfileRow {
  user_id: string
  department: string | null
  year: string | null
}

interface PushLogFields {
  post_id?: string
  title: string
  category: string | undefined
  author_id?: string
  device_id?: string
  type: string
  registrant_name?: string
  total_tokens?: number
  targets?: number
  sent?: number
  removed?: number
}

async function logPush(fields: PushLogFields): Promise<string | null> {
  const { error: e } = await supabase.from('push_log').insert(fields)
  if (e) console.error('push_log insert failed', e.message)
  return e?.message ?? null
}

function getChannelId(type: string, category?: string): string {
  const t = type.toLowerCase()
  if (t.includes('like') || t.includes('appreciat')) return 'social_activity'
  if (t.includes('ban') || t.includes('role') || t.includes('security')) return 'account_security'
  const c = (category ?? '').toLowerCase()
  if (c === 'event' || c === 'workshop') return 'events_workshops'
  return 'campus_updates'
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
    return corsError('Missing title', 400)
  }

  const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
  if (!serviceAccountJson) {
    console.error('FCM_SERVICE_ACCOUNT_JSON is not configured')
    return corsError('FCM not configured', 500)
  }

  let serviceAccount: { project_id: string; [key: string]: unknown }
  try {
    serviceAccount = JSON.parse(serviceAccountJson)
  } catch {
    console.error('FCM_SERVICE_ACCOUNT_JSON is invalid JSON')
    return corsError('FCM configuration error', 500)
  }

  const { data: devices, error: deviceError } = await supabase
    .from('device_tokens')
    .select('token, user_id, device_id')

  if (deviceError) {
    console.error('fetch device_tokens failed', deviceError.message)
    return corsError('Internal error', 500)
  }

  let branchYearById: Map<string, { department: string; year: string }> | null = null
  const wantBranch = target_branch && target_branch !== 'ALL'
  const wantYear = target_year && target_year !== 'ALL'

  if (wantBranch || wantYear) {
    const { data: profiles } = await supabase
      .from('profiles')
      .select('user_id, department, year')

    branchYearById = new Map(
      (profiles ?? []).map((p: ProfileRow) => [
        String(p.user_id),
        { department: String(p.department ?? ''), year: String(p.year ?? '') },
      ]),
    )
  }

  const recipientSet = new Set(
    (recipient_user_ids ?? []).map((id) => String(id)),
  )

  const targets = (devices ?? [])
    .filter((d: DeviceTokenRow) => {
      if (recipientSet.size > 0) return recipientSet.has(String(d.user_id ?? ''))
      return recipient_user_id ? String(d.user_id ?? '') === recipient_user_id : true
    })
    .filter((d: DeviceTokenRow) => {
      if (!branchYearById) return true
      const profile = branchYearById.get(String(d.user_id ?? ''))
      if (!profile) return false
      if (wantBranch) {
        const branchName = BRANCH_MAP[String(target_branch)] ?? String(target_branch)
        if (profile.department !== branchName) return false
      }
      if (wantYear) {
        const yearName = YEAR_MAP[String(target_year)] ?? String(target_year)
        if (profile.year !== yearName) return false
      }
      return true
    })
    .filter((d: DeviceTokenRow) =>
      exclude_user_id ? String(d.user_id ?? '') !== exclude_user_id : true,
    )
    .filter((d: DeviceTokenRow) => {
      if (skip_sender_device === false) return true
      const isSenderDevice = device_id && String(d.device_id ?? '') === device_id
      const isAuthorUser = author_id && String(d.user_id ?? '') === author_id
      return !isSenderDevice && !isAuthorUser
    })
    .map((d: DeviceTokenRow) => String(d.token))
    .filter((t: string) => t.length > 0)

  if ((type === 'announcement' || type === 'app_update') && author_id === 'admin_official') {
    const branchName =
      target_branch && target_branch !== 'ALL'
        ? (BRANCH_MAP[String(target_branch)] ?? String(target_branch))
        : 'ALL'
    const yearName =
      target_year && target_year !== 'ALL'
        ? (YEAR_MAP[String(target_year)] ?? String(target_year))
        : 'ALL'

    const { error: bErr } = await supabase.from('broadcasts').upsert(
      {
        id: post_id ?? `announcement_${Date.now()}`,
        title,
        body: body ?? '',
        branch: branchName,
        year: yearName,
        author_name: 'Admin',
      },
      { onConflict: 'id' },
    )

    if (bErr) {
      console.error('admin broadcast insert failed', bErr.message)
    }
  }

  if (targets.length === 0) {
    await logPush({
      total_tokens: (devices ?? []).length,
      targets: 0,
      sent: 0,
      removed: 0,
      post_id,
      title,
      category,
      author_id,
      device_id,
      type,
      registrant_name,
    })
    return corsResponse({ sent: 0, removed: 0 })
  }

  const { GoogleAuth } = await import('npm:google-auth-library@9')
  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const client = await auth.getClient()
  const accessToken = await client.getAccessToken()
  const bearer = accessToken?.token

  if (!bearer) {
    return corsError('Could not obtain FCM token', 500)
  }

  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

  let sent = 0
  const toRemove: string[] = []
  const isAppUpdate = type === 'app_update' || post_id?.startsWith('announcement_update_') || title.toLowerCase().includes('update')
  const isAdminBroadcast = (type === 'announcement' || isAppUpdate) && author_id === 'admin_official'
  const pushTitle = isAppUpdate ? (title.startsWith('🚀') ? title : `🚀 ${title}`) : (isAdminBroadcast ? `📢 ${title}` : title)
  const pushBody = isAppUpdate ? (body ?? title) : `${(body ?? title).slice(0, 200)}${isAdminBroadcast ? '\n\nBy Admin' : ''}`
  const channelId = getChannelId(type, category)

  const sendTasks = targets.map(async (token) => {
    const message = {
      message: {
        token,
        notification: { title: pushTitle, body: pushBody },
        data: {
          type: isAppUpdate ? 'app_update' : type,
          post_id: post_id ?? '',
          category: category ?? 'announcement',
          author_id: author_id ?? '',
          registrant_name: registrant_name ?? '',
        },
        android: {
          priority: 'HIGH',
          notification: {
            channel_id: channelId,
            notification_priority: 'PRIORITY_MAX',
            default_sound: true,
            default_vibrate_timings: true,
          },
        },
      },
    }

    try {
      const res = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${bearer}`,
        },
        body: JSON.stringify(message),
      })

      if (res.ok) {
        return { ok: true, token }
      }

      const raw = await res.text()
      if (res.status === 404 || raw.includes('UNREGISTERED')) {
        return { ok: false, token, unregistered: true }
      } else {
        console.error('FCM send failed', res.status, raw)
        return { ok: false, token, unregistered: false }
      }
    } catch (e) {
      console.error('FCM fetch error', e)
      return { ok: false, token, unregistered: false }
    }
  })

  const results = await Promise.allSettled(sendTasks)
  for (const r of results) {
    if (r.status === 'fulfilled') {
      if (r.value.ok) {
        sent += 1
      } else if (r.value.unregistered) {
        toRemove.push(r.value.token)
      }
    }
  }

  if (toRemove.length > 0) {
    await supabase.from('device_tokens').delete().in('token', toRemove)
  }

  await logPush({
    total_tokens: (devices ?? []).length,
    targets: targets.length,
    sent,
    removed: toRemove.length,
    post_id,
    title,
    category,
    author_id,
    device_id,
    type,
    registrant_name,
  })

  return corsResponse({ sent, removed: toRemove.length })
})