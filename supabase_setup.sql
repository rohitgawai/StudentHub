-- StudentHub Supabase setup
-- Run this in the Supabase Dashboard > SQL Editor once.
-- Creates all tables, Storage bucket `documents`, and permissive RLS
-- policies (anon read+write) so the app works end-to-end.

-- ============================================================================
-- 1. POSTS TABLE
-- ============================================================================
create table if not exists public.posts (
  id text primary key,
  title text not null default '',
  description text not null default '',
  category text not null default 'announcement',
  department text not null default '',
  target_year text,
  author_name text not null default '',
  author_role text not null default 'student',
  author_id text not null default '',
  image_url text,
  image_urls text[] not null default '{}',
  is_urgent boolean not null default false,
  is_pinned boolean not null default false,
  save_count integer not null default 0,
  congratulate_count integer not null default 0,
  like_count integer not null default 0,
  congratulated_user_ids text[] not null default '{}',
  liked_user_ids text[] not null default '{}',
  venue text,
  event_date timestamptz,
  registration_deadline timestamptz,
  max_participants integer,
  registered_user_ids text[] not null default '{}',
  links text not null default '[]',
  form text not null default '{}',
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Idempotent column additions for existing posts table
alter table public.posts add column if not exists congratulate_count integer not null default 0;
alter table public.posts add column if not exists congratulated_user_ids text[] not null default '{}';
alter table public.posts add column if not exists image_urls text[] not null default '{}';
alter table public.posts add column if not exists like_count integer not null default 0;
alter table public.posts add column if not exists liked_user_ids text[] not null default '{}';
alter table public.posts add column if not exists links text not null default '[]';
alter table public.posts add column if not exists form text not null default '{}';

alter table public.posts enable row level security;

drop policy if exists "posts_select_anon" on public.posts;
create policy "posts_select_anon" on public.posts for select using (true);

drop policy if exists "posts_insert_anon" on public.posts;
create policy "posts_insert_anon" on public.posts for insert with check (true);

drop policy if exists "posts_update_anon" on public.posts;
create policy "posts_update_anon" on public.posts for update using (true);

drop policy if exists "posts_delete_anon" on public.posts;
create policy "posts_delete_anon" on public.posts for delete using (true);

-- ============================================================================
-- 2. PROFILES TABLE
-- ============================================================================
create table if not exists public.profiles (
  user_id text primary key,
  name text not null default '',
  email text not null default '',
  mobile_number text not null default '',
  student_or_employee_id text not null default '',
  department text not null default '',
  year text not null default '',
  avatar_url text not null default '',
  roles text[] not null default '{"student"}',
  active_device_id text not null default '',
  has_completed_progressive_form boolean not null default false,
  saved_post_ids text[] not null default '{}',
  registered_event_ids text[] not null default '{}',
  congratulated_post_ids text[] not null default '{}',
  liked_post_ids text[] not null default '{}',
  is_verified boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Idempotent column additions for existing profiles table
alter table public.profiles add column if not exists mobile_number text not null default '';
alter table public.profiles add column if not exists active_device_id text not null default '';
alter table public.profiles add column if not exists has_completed_progressive_form boolean not null default false;
alter table public.profiles add column if not exists liked_post_ids text[] not null default '{}';

create index if not exists idx_profiles_email on public.profiles (email);

alter table public.profiles enable row level security;

drop policy if exists "profiles: read" on public.profiles;
create policy "profiles: read" on public.profiles for select to anon, authenticated using (true);

drop policy if exists "profiles: insert" on public.profiles;
create policy "profiles: insert" on public.profiles for insert to anon, authenticated with check (true);

drop policy if exists "profiles: update" on public.profiles;
create policy "profiles: update" on public.profiles for update to anon, authenticated using (true) with check (true);

-- ============================================================================
-- 3. FORM SUBMISSIONS TABLE
-- ============================================================================
create table if not exists public.form_submissions (
  id text primary key,
  post_id text not null,
  user_id text not null default '',
  form_id text not null default '',
  name text not null default '',
  student_or_employee_id text not null default '',
  department text not null default '',
  year text not null default '',
  mobile_number text not null default '',
  answers jsonb not null default '[]'::jsonb,
  status text not null default 'pending',
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Upgrade existing tables that used uuid primary key or lacked profile snapshot columns
alter table public.form_submissions alter column id type text;
alter table public.form_submissions alter column form_id drop not null;
alter table public.form_submissions alter column form_id set default '';
alter table public.form_submissions add column if not exists name text not null default '';
alter table public.form_submissions add column if not exists student_or_employee_id text not null default '';
alter table public.form_submissions add column if not exists department text not null default '';
alter table public.form_submissions add column if not exists year text not null default '';
alter table public.form_submissions add column if not exists mobile_number text not null default '';

create index if not exists form_submissions_post_id_idx on public.form_submissions (post_id);
create index if not exists form_submissions_user_id_idx on public.form_submissions (user_id);

drop index if exists form_submissions_post_user_key;
create unique index if not exists form_submissions_post_user_key
  on public.form_submissions (post_id, user_id)
  where (form_id = '' or form_id is null);

alter table public.form_submissions enable row level security;

drop policy if exists "form_submissions: manage" on public.form_submissions;
create policy "form_submissions: manage"
  on public.form_submissions for all to anon, authenticated
  using (true) with check (true);

-- ============================================================================
-- 4. DEVICE TOKENS TABLE (FCM PUSH NOTIFICATIONS)
-- ============================================================================
create table if not exists public.device_tokens (
  token text primary key,
  user_id text not null default '',
  device_id text not null default '',
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens add column if not exists device_id text not null default '';

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_insert_anon" on public.device_tokens;
create policy "device_tokens_insert_anon" on public.device_tokens for insert with check (true);

drop policy if exists "device_tokens_update_anon" on public.device_tokens;
create policy "device_tokens_update_anon" on public.device_tokens for update using (true);

drop policy if exists "device_tokens_select_anon" on public.device_tokens;
create policy "device_tokens_select_anon" on public.device_tokens for select using (true);

-- ============================================================================
-- 5. ACCOUNT CREDENTIALS (PASSWORD PROTECTION)
-- ============================================================================
-- Password hashes live in a private table with NO anon/authenticated RLS
-- policies: only the `account-credentials` Edge Function (service role) can
-- read/write it. `profiles.has_password` is the only password-related flag the
-- app can see (it decides "Set Password" vs "Enter Password" UI).
alter table public.profiles add column if not exists has_password boolean not null default false;

create table if not exists public.profile_credentials (
  user_id text primary key references public.profiles(user_id) on delete cascade,
  password_hash text not null,
  created_device_id text not null default '',
  updated_at timestamptz not null default now()
);

-- Deny everything for anon/authenticated (no policies = deny all). Only the
-- service role (inside Edge Functions) bypasses RLS.
alter table public.profile_credentials enable row level security;

-- ============================================================================
-- 6. STORAGE BUCKETS
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do update set public = true;

drop policy if exists "documents_insert_anon" on storage.objects;
create policy "documents_insert_anon" on storage.objects for insert with check (bucket_id = 'documents');

drop policy if exists "documents_select_anon" on storage.objects;
create policy "documents_select_anon" on storage.objects for select using (bucket_id = 'documents');

drop policy if exists "documents_delete_anon" on storage.objects;
create policy "documents_delete_anon" on storage.objects for delete using (bucket_id = 'documents');