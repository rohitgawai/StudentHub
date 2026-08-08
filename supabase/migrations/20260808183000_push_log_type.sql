alter table public.push_log
  add column if not exists type text not null default 'new_post';