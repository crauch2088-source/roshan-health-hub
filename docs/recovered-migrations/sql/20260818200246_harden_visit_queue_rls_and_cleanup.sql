-- Harden the two tables at the heart of the visit/queue workflow.
-- The queue ticket is created by a SECURITY DEFINER trigger, so clients do not need INSERT.

drop policy if exists optimized_auth_policy_visits on public.visits;
drop policy if exists optimized_auth_policy_queue_tickets on public.queue_tickets;

drop policy if exists visits_sel on public.visits;
drop policy if exists visits_ins on public.visits;
drop policy if exists visits_upd on public.visits;
drop policy if exists visits_del on public.visits;
create policy visits_sel on public.visits
  for select to authenticated using (public.app_has_perm('visits.read'));
create policy visits_ins on public.visits
  for insert to authenticated with check (public.app_has_perm('visits.create'));
create policy visits_upd on public.visits
  for update to authenticated
  using (public.app_has_perm('visits.update'))
  with check (public.app_has_perm('visits.update'));
create policy visits_del on public.visits
  for delete to authenticated using (public.is_super_admin());

drop policy if exists queue_tickets_sel on public.queue_tickets;
drop policy if exists queue_tickets_ins on public.queue_tickets;
drop policy if exists queue_tickets_upd on public.queue_tickets;
drop policy if exists queue_tickets_del on public.queue_tickets;
create policy queue_tickets_sel on public.queue_tickets
  for select to authenticated using (public.app_has_perm('queue.read'));
create policy queue_tickets_ins on public.queue_tickets
  for insert to authenticated
  with check (public.app_has_perm('queue.create'));
create policy queue_tickets_upd on public.queue_tickets
  for update to authenticated
  using (public.app_has_perm('queue.update'))
  with check (public.app_has_perm('queue.update'));
create policy queue_tickets_del on public.queue_tickets
  for delete to authenticated using (public.is_super_admin());

-- Keep queue allocation functions executable only by signed-in application users.
revoke execute on function public.next_queue_number(date) from anon;
grant execute on function public.next_queue_number(date) to authenticated;
