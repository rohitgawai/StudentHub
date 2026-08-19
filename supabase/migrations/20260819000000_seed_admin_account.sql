-- Creates the dedicated admin account for the admin panel (verify-admin /
-- admin-actions edge functions check the admin role in `profiles`).
-- The guard trigger is disabled around the insert because migration
-- sessions run as `postgres` (auth.role() = '') and would otherwise
-- reject a row carrying the admin role. The password is NOT stored here;
-- it is seeded via the account-credentials edge function (set_password)
-- which bcrypt-hashes it into profile_credentials.

alter table public.profiles disable trigger guard_profiles_roles;

insert into public.profiles (
  user_id,
  name,
  email,
  roles,
  has_password,
  is_verified,
  updated_at
)
values (
  'usr_admin_official',
  'Admin',
  'rgawai371@gmail.com',
  ARRAY['admin'],
  false,
  true,
  now()
)
on conflict (user_id) do nothing;

alter table public.profiles enable trigger guard_profiles_roles;