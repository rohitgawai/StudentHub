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

interface PushRoleDecisionOpts {
  userId: string
  requestId: string
  approved: boolean
  roleName: string
  notes: string | null
  adminUserId: string
}

async function pushRoleDecision(opts: PushRoleDecisionOpts): Promise<void> {
  try {
    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
    if (!serviceAccountJson) {
      console.error('FCM_SERVICE_ACCOUNT_JSON not configured — role push skipped')
      return
    }

    const serviceAccount = JSON.parse(serviceAccountJson)

    const { data: devices } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', opts.userId)

    const tokens = (devices ?? [])
      .map((d: any) => String(d.token ?? ''))
      .filter((t: string) => t.length > 0)

    if (tokens.length === 0) return

    const { GoogleAuth } = await import('npm:google-auth-library@9')
    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    const client = await auth.getClient()
    const accessToken = await client.getAccessToken()
    const bearer = accessToken?.token

    if (!bearer) return

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

    const hasNote = opts.notes != null && opts.notes.trim().length > 0
    const title = opts.approved ? '🎖️ Role Approved!' : '⛔ Role Request Rejected'
    const body = opts.approved
      ? hasNote
        ? `Congratulations! You are now ${opts.roleName}.\nMessage: ${opts.notes}`
        : `Congratulations! You are now ${opts.roleName}.`
      : hasNote
        ? `Your application for ${opts.roleName} was rejected.\nReason: ${opts.notes}`
        : `Your application for ${opts.roleName} was rejected.`

    let sent = 0
    const toRemove: string[] = []

    for (const token of tokens) {
      const message = {
        message: {
          token,
          notification: { title, body },
          data: {
            type: 'role_update',
            post_id: opts.requestId,
            category: 'announcement',
            author_id: opts.adminUserId,
            registrant_name: '',
          },
          android: {
            priority: 'HIGH',
            notification: { channel_id: 'account_security' },
          },
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
        console.error('role push failed', res.status, raw)
      }
    }

    if (toRemove.length > 0) {
      await supabase.from('device_tokens').delete().in('token', toRemove)
    }

    const { error: logErr } = await supabase.from('push_log').insert({
      post_id: opts.requestId,
      title,
      category: 'announcement',
      author_id: opts.adminUserId,
      type: 'role_update',
      registrant_name: '',
      targets: tokens.length,
      sent,
      removed: toRemove.length,
    })

    if (logErr) console.error('role push log failed', logErr.message)
  } catch (e) {
    console.error('role push error', String(e))
  }
}

interface RequestPayload {
  request_id?: string
  admin_user_id?: string
  status?: string
  notes?: string
}

interface ProfileRow {
  user_id: string
  roles: string[] | null
}

interface RoleRequestRow {
  id: string
  user_id: string
  user_name: string | null
  user_email: string | null
  department: string | null
  student_id: string | null
  requested_role: string | null
  is_limited_access: boolean | null
  duration_days: number | null
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

  const { request_id, admin_user_id, status, notes } = payload

  if (!request_id || !admin_user_id || !status) {
    return corsError('Missing request_id, admin_user_id, or status', 400)
  }

  if (status !== 'approved' && status !== 'rejected') {
    return corsError('Invalid status', 400)
  }

  const { data: admins, error: adminError } = await supabase
    .from('profiles')
    .select('roles')
    .eq('user_id', admin_user_id)
    .limit(1)

  if (adminError) {
    console.error('review-role admin lookup failed', adminError.message)
    return corsError('Internal error', 500)
  }

  const isAdmin = (admins ?? []).some(
    (p: ProfileRow) => Array.isArray(p.roles) && p.roles.includes('admin'),
  )

  if (!isAdmin) {
    return corsError('Not an admin', 403)
  }

  const { data: requests, error: reqError } = await supabase
    .from('role_requests')
    .select(
      'id, user_id, user_name, user_email, department, student_id, requested_role, is_limited_access, duration_days',
    )
    .eq('id', request_id)
    .limit(1)

  if (reqError) {
    console.error('review-role fetch failed', reqError.message)
    return corsError('Internal error', 500)
  }

  if (!requests || requests.length === 0) {
    return corsError('Not found', 404)
  }

  const request = requests[0] as RoleRequestRow

  const { error: statusError } = await supabase
    .from('role_requests')
    .update({ status, admin_notes: notes ?? null })
    .eq('id', request_id)

  if (statusError) {
    console.error('review-role status update failed', statusError.message)
    return corsError('Internal error', 500)
  }

  if (status === 'approved') {
    const role = String(request.requested_role ?? '')

    if (!role) {
      return corsError('Request has no role', 400)
    }

    const { data: applicants, error: applicantError } = await supabase
      .from('profiles')
      .select('user_id, roles')
      .eq('user_id', request.user_id)
      .limit(1)

    if (applicantError) {
      console.error('review-role applicant lookup failed', applicantError.message)
      return corsError('Internal error', 500)
    }

    const existingRoles = Array.isArray(applicants?.[0]?.roles)
      ? applicants![0].roles
      : []

    const baseRoles = existingRoles.includes(role)
      ? [...existingRoles]
      : [...existingRoles, role]

    const updatedRoles =
      role === 'faculty'
        ? baseRoles.filter((r) => r !== 'student')
        : baseRoles

    if (applicants && applicants.length > 0) {
      const { error: grantError } = await supabase
        .from('profiles')
        .update({ roles: updatedRoles })
        .eq('user_id', request.user_id)

      if (grantError) {
        console.error('review-role grant failed', grantError.message)
        return corsError('Internal error', 500)
      }
    } else {
      const { error: grantError } = await supabase
        .from('profiles')
        .upsert(
          {
            user_id: request.user_id,
            name: String(request.user_name ?? ''),
            email: String(request.user_email ?? ''),
            student_or_employee_id: String(request.student_id ?? ''),
            department: String(request.department ?? ''),
            roles: updatedRoles,
          },
          { onConflict: 'user_id' },
        )

      if (grantError) {
        console.error('review-role grant (create) failed', grantError.message)
        return corsError('Internal error', 500)
      }
    }
  }

  await pushRoleDecision({
    userId: String(request.user_id),
    requestId: String(request_id),
    approved: status === 'approved',
    roleName: String(request.requested_role ?? ''),
    notes: notes ?? null,
    adminUserId: String(admin_user_id),
  })

  return corsResponse({ reviewed: request_id, status, user_id: request.user_id })
})