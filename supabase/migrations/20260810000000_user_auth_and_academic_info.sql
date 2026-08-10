-- SQL Migration: User Auth Details, Academic (Progressive) Information & Single Device Session Tracking

-- Ensure profiles table has all required columns for single login, academic onboarding, and single device session
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

-- Safely add any columns if profiles table pre-existed without them
alter table public.profiles add column if not exists mobile_number text not null default '';
alter table public.profiles add column if not exists active_device_id text not null default '';
alter table public.profiles add column if not exists has_completed_progressive_form boolean not null default false;
alter table public.profiles add column if not exists liked_post_ids text[] not null default '{}';

-- Index on email for quick login lookup
create index if not exists idx_profiles_email on public.profiles (email);

-- Unique index on student_or_employee_id (MIT ID) ensuring every user MIT ID is unique across server
create unique index if not exists idx_profiles_unique_mit_id
  on public.profiles (student_or_employee_id)
  where student_or_employee_id <> '';

-- Enable RLS
alter table public.profiles enable row level security;

-- Policies for public profiles access
drop policy if exists "profiles: read" on public.profiles;
create policy "profiles: read"
  on public.profiles for select to anon, authenticated using (true);

drop policy if exists "profiles: insert" on public.profiles;
create policy "profiles: insert"
  on public.profiles for insert to anon, authenticated with check (true);

drop policy if exists "profiles: update" on public.profiles;
create policy "profiles: update"
  on public.profiles for update to anon, authenticated using (true) with check (true);
