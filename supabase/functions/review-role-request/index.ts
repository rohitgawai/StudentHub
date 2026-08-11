import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

// Server-side role application review. Guarded by the shared push secret. The
// reviewer must hold the admin role in `profiles` (same trust model as
// delete-post). Approving seeds the granted role (with expiry for temporary
// access) into the applicant's `profiles.roles` row so every device sees the
// new role via sync — even if the admin's app dies right after.
Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET')
  if (!secret || req.headers.get('X-Push-Secret') !== secret) {
    return new Response('Unauthorized', { status: 401 })
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
    return new Response('Bad request', { status: 400 })
  }
  const { request_id, admin_user_id, status, notes } = payload
  if (!request_id || !admin_user_id || !status) {
    return new Response('Missing request_id/admin_user_id/status', {
      status: 400,
    })
  }
  if (status !== 'approved' && status !== 'rejected') {
    return new Response('Invalid status', { status: 400 })
  }

  // Reviewer must be an admin.
  const { data: admins, error: adminError } = await supabase
    .from('profiles')
    .select('roles')
    .eq('user_id', admin_user_id)
    .limit(1)
  if (adminError) {
    console.error('review-role admin lookup failed', adminError.message)
    return new Response('Internal error', { status: 500 })
  }
  const isAdmin = (admins ?? []).some((p) =>
    Array.isArray(p.roles) && p.roles.includes('admin'))
  if (!isAdmin) {
    return new Response('Not an admin', { status: 403 })
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
    return new Response('Internal error', { status: 500 })
  }
  if (!requests || requests.length === 0) {
    return new Response('Not found', { status: 404 })
  }
  const request = requests[0]

  const { error: statusError } = await supabase
    .from('role_requests')
    .update({ status, admin_notes: notes ?? null })
    .eq('id', request_id)
  if (statusError) {
    console.error('review-role status update failed', statusError.message)
    return new Response('Internal error', { status: 500 })
  }

  if (status === 'approved') {
    const role = String(request.requested_role ?? '')
    if (!role) {
      return new Response('Request has no role', { status: 400 })
    }

    const { data: applicants, error: applicantError } = await supabase
      .from('profiles')
      .select('user_id, roles')
      .eq('user_id', request.user_id)
      .limit(1)
    if (applicantError) {
      console.error('review-role applicant lookup failed', applicantError.message)
      return new Response('Internal error', { status: 500 })
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
        return new Response('Internal error', { status: 500 })
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
        return new Response('Internal error', { status: 500 })
      }
    }
  }

  return new Response(
    JSON.stringify({ reviewed: request_id, status, user_id: request.user_id }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
