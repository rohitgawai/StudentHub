create table if not exists public.role_requests (
  id text primary key,
  user_id text not null default '',
  user_name text not null default '',
  user_email text not null default '',
  department text not null default '',
  student_id text not null default '',
  requested_role text not null default '',
  reason text not null default '',
  phone_number text not null default '',
  status text not null default 'pending',
  admin_notes text,
  is_limited_access boolean not null default false,
  duration_days int,
  submitted_at timestamptz not null default now()
);

alter table public.role_requests enable row level security;

drop policy if exists "role_requests: select" on public.role_requests;
create policy "role_requests: select"
  on public.role_requests for select to anon, authenticated using (true);

drop policy if exists "role_requests: insert" on public.role_requests;
create policy "role_requests: insert"
  on public.role_requests for insert to anon, authenticated with check (true);

drop policy if exists "role_requests: update" on public.role_requests;
create policy "role_requests: update"
  on public.role_requests for update to anon, authenticated using (true) with check (true);