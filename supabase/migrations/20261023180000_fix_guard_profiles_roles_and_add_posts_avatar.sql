-- 1. Fix guard_profiles_roles function:
-- Previously it compared new.roles (text[]) with '[]'::jsonb which caused
-- PostgreSQL error 42883: "operator does not exist: text[] <> jsonb",
-- completely breaking all profile upserts.
create or replace function public.guard_profiles_roles()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') not in ('service_role', 'supabase_admin') then
    if tg_op = 'INSERT' then
      -- Allow default student role or empty array on client-side insert
      if new.roles is not null 
         and new.roles is distinct from array['student'::text] 
         and new.roles is distinct from array[]::text[] then
        raise exception 'roles can only be set server-side';
      end if;
    elsif tg_op = 'UPDATE' then
      if new.roles is distinct from old.roles then
        raise exception 'roles can only be changed server-side';
      end if;
    end if;
  end if;
  return new;
end;
$$;

-- 2. Add author_avatar_url to public.posts table so avatars persist directly on posts
alter table public.posts 
add column if not exists author_avatar_url text not null default '';

-- 3. Backfill existing posts with the author's current avatar from public.profiles
update public.posts p
set author_avatar_url = coalesce(pr.avatar_url, '')
from public.profiles pr
where p.author_id = pr.user_id
  and coalesce(pr.avatar_url, '') <> '';
