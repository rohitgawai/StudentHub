create policy "diagnostic: anyone can read push logs"
  on public.push_log for select
  to anon, authenticated
  using (true);