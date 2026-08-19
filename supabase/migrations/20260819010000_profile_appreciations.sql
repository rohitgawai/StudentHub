-- Profile appreciations (creator profile likes) persisted server-side so the
-- count is accurate across devices and survives app restarts.
-- Previously these were device-local only and incremented solely by live
-- realtime broadcasts, so a creator whose app was offline at the moment of an
-- appreciation never saw the count.

alter table public.profiles
  add column if not exists appreciated_by_user_ids text[] not null default '{}';

-- Atomically toggles a liker on a target profile and returns the new count.
-- SECURITY DEFINER: any anon user may appreciate any profile, but RLS would
-- block updating someone else's row, so this runs with table-owner privileges.
-- The guard_profiles_roles trigger only blocks `roles` mutations, so this is
-- unaffected.
create or replace function public.toggle_profile_appreciation(p_target_user_id text, p_liker_user_id text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids text[] := '{}';
begin
  if p_target_user_id is null or p_liker_user_id is null or p_target_user_id = p_liker_user_id then
    return null;
  end if;

  select coalesce(appreciated_by_user_ids, '{}') into v_ids
  from public.profiles
  where user_id = p_target_user_id
  for update;

  if not found then
    return null;
  end if;

  if array_position(v_ids, p_liker_user_id) is not null then
    v_ids := array_remove(v_ids, p_liker_user_id);
  else
    v_ids := array_append(v_ids, p_liker_user_id);
  end if;

  update public.profiles
     set appreciated_by_user_ids = v_ids,
         updated_at = now()
   where user_id = p_target_user_id;

  return coalesce(array_length(v_ids, 1), 0);
end;
$$;

revoke execute on function public.toggle_profile_appreciation(text, text) from public;
grant execute on function public.toggle_profile_appreciation(text, text) to anon, authenticated, service_role;