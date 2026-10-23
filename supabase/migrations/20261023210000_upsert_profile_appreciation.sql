-- Update toggle_profile_appreciation to upsert missing profile rows
-- so demo creators and newly registered users never return null or lose appreciation counts.

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
    insert into public.profiles (user_id, appreciated_by_user_ids, updated_at)
    values (p_target_user_id, array[p_liker_user_id], now())
    on conflict (user_id) do update
      set appreciated_by_user_ids = array_append(profiles.appreciated_by_user_ids, p_liker_user_id),
          updated_at = now();
    return 1;
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
