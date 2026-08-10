-- Event/workflow registration forms: posts get an optional attached form and
-- optional external links; submissions are stored per (post, user).

alter table public.posts
  add column if not exists links text not null default '[]';
alter table public.posts
  add column if not exists form text not null default '{}';

create table if not exists public.form_submissions (
  id uuid primary key default gen_random_uuid(),
  post_id text not null,
  user_id text not null default '',
  form_id text not null default '',
  answers jsonb not null default '[]'::jsonb,
  status text not null default 'pending',
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, form_id, user_id)
);

alter table public.form_submissions enable row level security;

drop policy if exists "form_submissions: manage" on public.form_submissions;
create policy "form_submissions: manage"
  on public.form_submissions for all to anon, authenticated
  using (true) with check (true);

-- Local quick-registration inserts a submission row per attendance; keep
-- uniqueness per user even when form_id is blank (attendance-only events).
create unique index if not exists form_submissions_post_user_key
  on public.form_submissions (post_id, user_id)
  where form_id = '';