-- StudentHub Supabase setup
-- Run this in the Supabase Dashboard > SQL Editor once.
-- Creates the posts table, Storage bucket `documents`, and demo-permissive RLS
-- (anon read+write) so the app works end-to-end without real auth turned on yet.

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
  is_urgent boolean not null default false,
  is_pinned boolean not null default false,
  save_count integer not null default 0,
  congratulate_count integer not null default 0,
  congratulated_user_ids text[] not null default '{}',
  venue text,
  event_date timestamptz,
  registration_deadline timestamptz,
  max_participants integer,
  registered_user_ids text[] not null default '{}',
  attachments jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Migrate tables created before the congratulate feature existed, so upserts
-- from the app never fail on missing columns (idempotent, safe to re-run).
alter table public.posts add column if not exists congratulate_count integer not null default 0;
alter table public.posts add column if not exists congratulated_user_ids text[] not null default '{}';

alter table public.posts enable row level security;

drop policy if exists "posts_select_anon" on public.posts;
create policy "posts_select_anon" on public.posts
  for select using (true);

drop policy if exists "posts_insert_anon" on public.posts;
create policy "posts_insert_anon" on public.posts
  for insert with check (true);

drop policy if exists "posts_update_anon" on public.posts;
create policy "posts_update_anon" on public.posts
  for update using (true);

drop policy if exists "posts_delete_anon" on public.posts;
create policy "posts_delete_anon" on public.posts
  for delete using (true);

-- Storage bucket for PDF attachments (public read, anon upload)
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do update set public = true;

drop policy if exists "documents_insert_anon" on storage.objects;
create policy "documents_insert_anon" on storage.objects
  for insert with check (bucket_id = 'documents');

drop policy if exists "documents_select_anon" on storage.objects;
create policy "documents_select_anon" on storage.objects
  for select using (bucket_id = 'documents');

drop policy if exists "documents_delete_anon" on storage.objects;
create policy "documents_delete_anon" on storage.objects
  for delete using (bucket_id = 'documents');

-- FCM push: every device registers its token here so the send-push Edge
-- Function can broadcast new posts/events to the whole campus. device_id
-- uniquely identifies the install so the uploader's own device is skipped.
create table if not exists public.device_tokens (
  token text primary key,
  user_id text not null default '',
  device_id text not null default '',
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Existing databases: add the column without touching rows.
alter table public.device_tokens add column if not exists device_id text not null default '';

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_insert_anon" on public.device_tokens;
create policy "device_tokens_insert_anon" on public.device_tokens
  for insert with check (true);

drop policy if exists "device_tokens_update_anon" on public.device_tokens;
create policy "device_tokens_update_anon" on public.device_tokens
  for update using (true);

drop policy if exists "device_tokens_select_anon" on public.device_tokens;
create policy "device_tokens_select_anon" on public.device_tokens
  for select using (true);