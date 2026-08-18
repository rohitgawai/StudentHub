-- Hardens the wide-open anon policies left by earlier iterations.
--
-- The app is anonymous-key based (no Supabase Auth accounts), so anon
-- SELECT/INSERT/UPDATE are required for it to function. The danger spots are
-- the operations the app does NOT need:
--
-- 1. posts.DELETE: the app never deletes post rows directly anymore — deletion
--    runs through the delete-post / delete-user edge functions (service role,
--    author/admin verified). Before this change any anon key holder could
--    delete ANY post row directly, bypassing the function's ownership check.
-- 2. device_tokens.DELETE/SELECT: the app only upserts its own token; token
--    rows are removed by delete-user (service role).
-- 3. reported_posts.DELETE: the app inserts reports, the admin panel resolves
--    them with an UPDATE. No delete path exists.
-- 4. push_log: nothing in the app or admin reads/writes it with the anon key —
--    send-push writes with the service role (RLS bypassed), so the diagnostic
--    policies are pure attack surface.

-- posts ---------------------------------------------------------
drop policy if exists "posts: manage" on public.posts;
drop policy if exists "posts: select" on public.posts;
drop policy if exists "posts: insert" on public.posts;
drop policy if exists "posts: update" on public.posts;
create policy "posts: select"
  on public.posts for select to anon, authenticated using (true);
create policy "posts: insert"
  on public.posts for insert to anon, authenticated with check (true);
create policy "posts: update"
  on public.posts for update to anon, authenticated using (true) with check (true);

-- device_tokens -------------------------------------------------
drop policy if exists "device_tokens: manage" on public.device_tokens;
drop policy if exists "device_tokens: upsert" on public.device_tokens;
drop policy if exists "device_tokens: update" on public.device_tokens;
create policy "device_tokens: upsert"
  on public.device_tokens for insert to anon, authenticated with check (true);
create policy "device_tokens: update"
  on public.device_tokens for update to anon, authenticated using (true) with check (true);

-- reported_posts ------------------------------------------------
drop policy if exists "reported_posts: manage" on public.reported_posts;
drop policy if exists "reported_posts: select" on public.reported_posts;
drop policy if exists "reported_posts: insert" on public.reported_posts;
drop policy if exists "reported_posts: update" on public.reported_posts;
create policy "reported_posts: select"
  on public.reported_posts for select to anon, authenticated using (true);
create policy "reported_posts: insert"
  on public.reported_posts for insert to anon, authenticated with check (true);
create policy "reported_posts: update"
  on public.reported_posts for update to anon, authenticated using (true) with check (true);

-- push_log ------------------------------------------------------
drop policy if exists "diagnostic: anyone can log push events" on public.push_log;
drop policy if exists "diagnostic: anyone can read push logs" on public.push_log;
