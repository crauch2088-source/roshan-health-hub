drop policy if exists optimized_auth_policy_appointments on public.appointments;

create policy appointments_select
on public.appointments
for select
to authenticated
using (app_has_perm('appointments.read'));

create policy appointments_insert
on public.appointments
for insert
to authenticated
with check (
  app_has_perm('appointments.create')
  and created_by = (select auth.uid())
);

create policy appointments_update
on public.appointments
for update
to authenticated
using (app_has_perm('appointments.update'))
with check (app_has_perm('appointments.update'));

create policy appointments_delete
on public.appointments
for delete
to authenticated
using (app_has_perm('appointments.delete'));

create index if not exists appointments_date_active_idx
on public.appointments (appointment_date)
where deleted_at is null;
