-- ADMIN broadcast notifications: persisted from the admin panel's
-- send-push edge function so the mobile app can show them in the
-- in-app notification bell (never in the campus feed).

create table if not exists public.broadcasts (
  id text primary key,
  title text not null default '',
  body text not null default '',
  branch text not null default 'ALL',
  year text not null default 'ALL',
  author_name text not null default 'Admin',
  created_at timestamptz not null default now()
);

alter table public.broadcasts enable row level security;

drop policy if exists "broadcasts: read" on public.broadcasts;
create policy "broadcasts: read"
  on public.broadcasts for select to anon, authenticated
  using (true);

drop policy if exists "broadcasts: insert" on public.broadcasts;
create policy "broadcasts: insert"
  on public.broadcasts for insert to anon, authenticated
  with check (true);