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

// Best-effort FCM push to the applicant's devices so they learn the decision
// instantly — even with the app closed. The app's foreground handler shows the
// system notification and triggers a sync (type 'role_update'), which adopts
// the new status, grants the role and adds the in-app bell entry. Never fails
// the review: push problems are logged and ignored.
async function pushRoleDecision(opts: {
  userId: string
  requestId: string
  approved: boolean
  roleName: string
  notes: string | null
  adminUserId: string
}) {
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
      .map((d) => String(d.token ?? ''))
      .filter((t) => t.length > 0)
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

    const fcmUrl =
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`
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

// Server-side role application review. Guarded by the shared push secret. The
// reviewer must hold the admin role in `profiles` (same trust model as
// delete-post). Approving seeds the granted role (with expiry for temporary
// access) into the applicant's `profiles.roles` row so every device sees the
// new role via sync — even if the admin's app dies right after.
Deno.serve(async (req) => {
  // Browser CORS preflight must succeed BEFORE the secret check, otherwise the
  // panel (Flutter web) silently fails every admin action with a 401.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  let payload: {
    request_id?: string
    admin_user_id?: string
    status?: string
    notes?: string
  }
  try {
    payload = await req.json()
  } catch {
    return new Response('Bad request', { status: 400, headers: corsHeaders })
  }
  const { request_id, admin_user_id, status, notes } = payload
  if (!request_id || !admin_user_id || !status) {
    return new Response('Missing request_id/admin_user_id/status', {
      status: 400,
      headers: corsHeaders,
    })
  }
  if (status !== 'approved' && status !== 'rejected') {
    return new Response('Invalid status', { status: 400, headers: corsHeaders })
  }

  // Reviewer must be an admin.
  const { data: admins, error: adminError } = await supabase
    .from('profiles')
    .select('roles')
    .eq('user_id', admin_user_id)
    .limit(1)
  if (adminError) {
    console.error('review-role admin lookup failed', adminError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  const isAdmin = (admins ?? []).some((p) =>
    Array.isArray(p.roles) && p.roles.includes('admin'))
  if (!isAdmin) {
    return new Response('Not an admin', { status: 403, headers: corsHeaders })
  }

  // Load the request.
  const { data: requests, error: reqError } = await supabase
    .from('role_requests')
    .select(
      'id, user_id, user_name, user_email, department, student_id, requested_role, is_limited_access, duration_days',
    )
    .eq('id', request_id)
    .limit(1)
  if (reqError) {
    console.error('review-role fetch failed', reqError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }
  if (!requests || requests.length === 0) {
    return new Response('Not found', { status: 404, headers: corsHeaders })
  }
  const request = requests[0]

  const { error: statusError } = await supabase
    .from('role_requests')
    .update({ status, admin_notes: notes ?? null })
    .eq('id', request_id)
  if (statusError) {
    console.error('review-role status update failed', statusError.message)
    return new Response('Internal error', { status: 500, headers: corsHeaders })
  }

  if (status === 'approved') {
    const role = String(request.requested_role ?? '')
    if (!role) {
      return new Response('Request has no role', { status: 400, headers: corsHeaders })
    }

    const { data: applicants, error: applicantError } = await supabase
      .from('profiles')
      .select('user_id, roles')
      .eq('user_id', request.user_id)
      .limit(1)
    if (applicantError) {
      console.error('review-role applicant lookup failed', applicantError.message)
      return new Response('Internal error', { status: 500, headers: corsHeaders })
    }
    const existingRoles = Array.isArray(applicants?.[0]?.roles)
      ? applicants![0].roles
      : []
    // Faculty is a strict upgrade: it replaces the Student role everywhere.
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
        return new Response('Internal error', { status: 500, headers: corsHeaders })
      }
    } else {
      // Applicant has no profile row yet (a request from an offline device):
      // create one so the role grant survives; display fields are filled in by
      // the device on its next sync.
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
        return new Response('Internal error', { status: 500, headers: corsHeaders })
      }
    }
  }

  // Push the decision to the applicant's devices (best-effort, after the
  // server state is final so a foreground sync sees the new status).
  await pushRoleDecision({
    userId: String(request.user_id),
    requestId: String(request_id),
    approved: status === 'approved',
    roleName: String(request.requested_role ?? ''),
    notes: notes ?? null,
    adminUserId: String(admin_user_id),
  })

  return new Response(
    JSON.stringify({ reviewed: request_id, status, user_id: request.user_id }),
    { headers: { 'Content-Type': 'application/json', ...corsHeaders } },
  )
})