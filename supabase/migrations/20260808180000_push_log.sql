create table if not exists public.push_log (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  post_id text,
  title text,
  category text,
  author_id text,
  device_id text,
  total_tokens int not null default 0,
  targets int not null default 0,
  sent int not null default 0,
  removed int not null default 0
);

alter table public.push_log enable row level security;
