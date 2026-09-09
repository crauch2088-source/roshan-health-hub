-- =====================================================================
-- ROSHAN — Phase 4 finance follow-up
--
-- Context: db/roshan_phase4_finance.sql existed in the repo but had only
-- been partially applied live (tables + a few permission rows existed;
-- the views, triggers, atomic RPCs, and RLS switch had not). This session
-- applied that file to the live database in full.
--
-- That file's own RLS section grants the new suppliers.read/create/update
-- codes to super_admin, admin, accountant, and cashier — but NOT to
-- pharmacist, even though Phase 3 gave the pharmacist role day-to-day
-- supplier management (receiving stock, adding suppliers) via the
-- suppliers table's older pharmacy.* policies. Those older policies are
-- still in place (this migration does not touch them — RLS policies are
-- OR'd together, so pharmacy.* continues to work), but granting the new
-- canonical suppliers.* codes too keeps the permission model coherent
-- going forward instead of relying on two different code families
-- happening to both work.
--
-- Safe to re-run: guarded by NOT EXISTS.
-- =====================================================================

begin;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'pharmacist'
  and p.code in ('suppliers.read', 'suppliers.create', 'suppliers.update')
  and not exists (
    select 1 from public.role_permissions rp
    where rp.role_id = r.id and rp.permission_id = p.id
  );

commit;
