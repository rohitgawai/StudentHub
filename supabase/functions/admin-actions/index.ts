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

type AdminAction = 'set_roles' | 'ban' | 'unban' | 'verify_student'

interface RequestPayload {
  admin_user_id?: string
  action?: string
  user_id?: string
  roles?: string[]
}

interface ProfileRow {
  user_id: string
  roles: string[] | null
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

  const { admin_user_id, action, user_id, roles } = payload

  if (!admin_user_id || !action || !user_id) {
    return corsError('Missing admin_user_id, action, or user_id', 400)
  }

  const { data: admins, error: adminError } = await supabase
    .from('profiles')
    .select('roles')
    .eq('user_id', admin_user_id)
    .limit(1)

  if (adminError) {
    console.error('admin-actions admin lookup failed', adminError.message)
    return corsError('Internal error', 500)
  }

  const isAdmin = (admins ?? []).some(
    (p: ProfileRow) => Array.isArray(p.roles) && p.roles.includes('admin'),
  )

  if (!isAdmin) {
    return corsError('Not an admin', 403)
  }

  const { data: targets, error: targetError } = await supabase
    .from('profiles')
    .select('user_id, roles')
    .eq('user_id', user_id)
    .limit(1)

  if (targetError) {
    console.error('admin-actions target lookup failed', targetError.message)
    return corsError('Internal error', 500)
  }

  if (!targets || targets.length === 0) {
    return corsError('Target user not found', 404)
  }

  try {
    switch (action) {
      case 'set_roles': {
        if (!Array.isArray(roles)) {
          return corsError('Missing roles array', 400)
        }
        const { error: e } = await supabase
          .from('profiles')
          .update({ roles })
          .eq('user_id', user_id)
        if (e) {
          console.error('admin-actions set_roles failed', e.message)
          return corsError('Internal error', 500)
        }
        break
      }
      case 'ban': {
        const { error: e } = await supabase
          .from('profiles')
          .update({ roles: ['banned'] })
          .eq('user_id', user_id)
        if (e) {
          console.error('admin-actions ban failed', e.message)
          return corsError('Internal error', 500)
        }
        break
      }
      case 'unban': {
        const { error: e } = await supabase
          .from('profiles')
          .update({ roles: ['student'] })
          .eq('user_id', user_id)
        if (e) {
          console.error('admin-actions unban failed', e.message)
          return corsError('Internal error', 500)
        }
        break
      }
      case 'verify_student': {
        const { error: e } = await supabase
          .from('profiles')
          .update({ is_verified: true })
          .eq('user_id', user_id)
        if (e) {
          console.error('admin-actions verify_student failed', e.message)
          return corsError('Internal error', 500)
        }
        break
      }
      default:
        return corsError('Unknown action', 400)
    }
  } catch (e) {
    console.error('admin-actions unexpected error', String(e))
    return corsError('Internal error', 500)
  }

  return corsResponse({ ok: true, action, user_id })
})