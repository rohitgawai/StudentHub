create table if not exists public.profiles (
  user_id text primary key,
  name text not null default '',
  email text not null default '',
  student_or_employee_id text not null default '',
  department text not null default '',
  year text not null default '',
  mobile_number text not null default '',
  avatar_url text not null default '',
  roles text[] not null default '{}',
  saved_post_ids text[] not null default '{}',
  registered_event_ids text[] not null default '{}',
  congratulated_post_ids text[] not null default '{}',
  is_verified boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles: read" on public.profiles;
create policy "profiles: read"
  on public.profiles for select to anon, authenticated using (true);

drop policy if exists "profiles: insert" on public.profiles;
create policy "profiles: insert"
  on public.profiles for insert to anon, authenticated with check (true);

drop policy if exists "profiles: update" on public.profiles;
create policy "profiles: update"
  on public.profiles for update to anon, authenticated using (true) with check (true);