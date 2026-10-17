-- REPLAY-SAFE HISTORICAL VARIANT — NOT A CANONICAL DEPLOYMENT MIGRATION
-- Reconstructed from the applied migration 20260818191254_fix_patients_rls_and_admin_link.
-- The original includes one environment-specific Auth-to-app-user identity UPDATE.
-- That UPDATE is intentionally omitted here; no email or identity UUID is included.
-- The remaining patient RLS policy repair is preserved for isolated fixture testing.
-- This is not proof of the full historical migration chain and requires a reviewed baseline.

begin;

-- Replay-safe omission: do not map an environment-specific Auth identity to an application user.

-- Replace the stale employees/auth.uid() policy with the actual Roshan RBAC model.
drop policy if exists optimized_auth_policy_patients on public.patients;

create policy patients_select
on public.patients
for select
to authenticated
using (public.app_has_perm('patients.read'));

create policy patients_insert
on public.patients
for insert
to authenticated
with check (public.app_has_perm('patients.create'));

create policy patients_update
on public.patients
for update
to authenticated
using (public.app_has_perm('patients.update'))
with check (public.app_has_perm('patients.update'));

create policy patients_delete
on public.patients
for delete
to authenticated
using (public.app_has_perm('patients.delete'));

commit;
