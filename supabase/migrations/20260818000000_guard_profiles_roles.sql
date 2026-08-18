-- Protects profiles.roles from client-side writes.
--
-- Before this migration, the `profiles: update` RLS policy allowed ANY anon
-- client to update ANY profile row (using (true)), which meant a user could
-- change their own roles to ['admin'] with just the public anon key. All role
-- grants/revocations, bans and un-bans now flow through the `admin-actions`
-- and `review-role-request` edge functions, which run with the service role
-- and verify the caller is an admin server-side.
--
-- The trigger allows writes from the service role (edge functions) and blocks
-- role mutations from anon/authenticated sessions. The mobile app no longer
-- writes the `roles` column at all (see mock_data_service `_persistProfile`),
-- so this does not break the app.

create or replace function public.guard_profiles_roles()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') not in ('service_role', 'supabase_admin') then
    if tg_op = 'INSERT' then
      if new.roles is not null and new.roles <> '[]'::jsonb then
        raise exception 'roles can only be set server-side';
      end if;
    elsif new.roles is distinct from old.roles then
      raise exception 'roles can only be changed server-side';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_profiles_roles on public.profiles;

create trigger guard_profiles_roles
before insert or update on public.profiles
for each row execute function public.guard_profiles_roles();