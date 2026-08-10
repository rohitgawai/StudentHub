-- The `posts` table was created manually before migrations existed, so it is
-- missing columns the app writes (image_urls, attachments, engagement stats,
-- event fields, ...). Every upsert therefore failed with PGRST204 and no post
-- ever reached the server (which also made the delete-post function return
-- "Not found or not the author"). Add every app-used column idempotently.

alter table public.posts add column if not exists target_year text;
alter table public.posts add column if not exists image_urls jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists attachments jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists is_urgent boolean not null default false;
alter table public.posts add column if not exists is_pinned boolean not null default false;
alter table public.posts add column if not exists save_count integer not null default 0;
alter table public.posts add column if not exists congratulate_count integer not null default 0;
alter table public.posts add column if not exists like_count integer not null default 0;
alter table public.posts add column if not exists congratulated_user_ids jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists liked_user_ids jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists registered_user_ids jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists venue text;
alter table public.posts add column if not exists event_date timestamptz;
alter table public.posts add column if not exists registration_deadline timestamptz;
alter table public.posts add column if not exists max_participants integer;

-- Mirror the app's anon-key access model in case the hand-created table never
-- had RLS policies (idempotent either way).
alter table public.posts enable row level security;

drop policy if exists "posts: manage" on public.posts;
create policy "posts: manage"
  on public.posts for all to anon, authenticated
  using (true) with check (true);