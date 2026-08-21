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

interface RequestPayload {
  user_id?: string
  admin_user_id?: string
}

interface ProfileRow {
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

  const userId = (payload.user_id ?? '').trim()
  if (!userId) {
    return corsError('Missing user_id', 400)
  }

  const adminUserId = (payload.admin_user_id ?? '').trim()
  if (!adminUserId) {
    return corsError('Missing admin_user_id', 400)
  }

  const { data: admins, error: adminError } = await supabase
    .from('profiles')
    .select('roles')
    .eq('user_id', adminUserId)
    .limit(1)

  if (adminError) {
    console.error('delete-user admin lookup failed', adminError.message)
    return corsError('Internal error', 500)
  }

  const isAdmin = (admins ?? []).some(
    (p: ProfileRow) => Array.isArray(p.roles) && p.roles.includes('admin'),
  )

  if (!isAdmin) {
    return corsError('Not an admin', 403)
  }

  const { data: existing, error: lookupError } = await supabase
    .from('profiles')
    .select('user_id')
    .eq('user_id', userId)
    .limit(1)

  if (lookupError) {
    console.error('delete-user lookup failed', lookupError.message)
    return corsError('Internal error', 500)
  }

  if (!existing || existing.length === 0) {
    return corsError('account_not_found', 404)
  }

  const simpleDeletes: [string, string][] = [
    ['device_tokens', 'user_id'],
    ['form_submissions', 'user_id'],
    ['role_requests', 'user_id'],
    ['posts', 'author_id'],
    ['push_log', 'author_id'],
  ]

  for (const [table, column] of simpleDeletes) {
    const { error } = await supabase.from(table).delete().eq(column, userId)
    if (error) {
      console.error(`delete-user ${table} failed`, error.message)
      return corsError('Internal error', 500)
    }
  }

  const { error: reportError } = await supabase
    .from('reported_posts')
    .delete()
    .or(`author_id.eq.${userId},reporter_id.eq.${userId}`)

  if (reportError) {
    console.error('delete-user reported_posts failed', reportError.message)
    return corsError('Internal error', 500)
  }

  const { error: profileError } = await supabase
    .from('profiles')
    .delete()
    .eq('user_id', userId)

  if (profileError) {
    console.error('delete-user profiles failed', profileError.message)
    return corsError('Internal error', 500)
  }

  return corsResponse({ deleted: userId })
})