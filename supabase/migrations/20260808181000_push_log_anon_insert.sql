create policy "diagnostic: anyone can log push events"
  on public.push_log for insert
  to anon, authenticated
  with check (true);