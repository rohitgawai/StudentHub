create table if not exists public.device_tokens (
  token text primary key,
  user_id text not null default '',
  device_id text not null default '',
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens: manage" on public.device_tokens;
create policy "device_tokens: manage"
  on public.device_tokens for all to anon, authenticated
  using (true) with check (true);

-- Guarantee the app's upsert(onConflict: 'token') keeps working even when the
-- table pre-existed without a unique constraint on token.
create unique index if not exists device_tokens_token_key
  on public.device_tokens (token);