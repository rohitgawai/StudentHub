-- Content moderation: posts reported from the mobile app, reviewed in the
-- admin panel. The admin panel expected this table but it never existed, which
-- made every refresh's reported-content fetch fail (404).

create table if not exists public.reported_posts (
  id text primary key,
  post_id text not null default '',
  post_content text not null default '',
  author_name text not null default '',
  author_id text not null default '',
  reporter_name text not null default '',
  reporter_id text not null default '',
  reason text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.reported_posts enable row level security;

drop policy if exists "reported_posts: manage" on public.reported_posts;
create policy "reported_posts: manage"
  on public.reported_posts for all to anon, authenticated
  using (true) with check (true);