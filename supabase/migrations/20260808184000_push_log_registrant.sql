alter table public.push_log
  add column if not exists registrant_name text;
