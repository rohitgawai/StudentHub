-- The app writes form submissions with text ids ('sub_...') and a full
-- profile snapshot (name, MIT id, department, year, mobile). The original
-- table used uuid ids and lacked the profile columns, so every submission
-- upsert failed silently (PGRST204 / invalid uuid) and hosts on other devices
-- never saw real attendee data for quick (no-form) registrations.
-- Idempotent: safe to re-run.

alter table public.form_submissions alter column id type text;
alter table public.form_submissions alter column form_id drop not null;
alter table public.form_submissions alter column form_id set default '';

alter table public.form_submissions add column if not exists name text not null default '';
alter table public.form_submissions add column if not exists student_or_employee_id text not null default '';
alter table public.form_submissions add column if not exists department text not null default '';
alter table public.form_submissions add column if not exists year text not null default '';
alter table public.form_submissions add column if not exists mobile_number text not null default '';

create index if not exists form_submissions_post_id_idx on public.form_submissions (post_id);
create index if not exists form_submissions_user_id_idx on public.form_submissions (user_id);

drop index if exists form_submissions_post_user_key;
create unique index if not exists form_submissions_post_user_key
  on public.form_submissions (post_id, user_id)
  where (form_id = '' or form_id is null);