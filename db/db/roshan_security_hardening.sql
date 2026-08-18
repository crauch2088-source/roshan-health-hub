-- =====================================================================
-- ROSHAN MEDICAL CENTER
-- SECURITY HARDENING + DATA INTEGRITY
--
-- IMPORTANT:
-- This is an ADDITIVE follow-up migration.
-- Do NOT delete or replace roshan_phase1_migration.sql.
--
-- Run AFTER:
--   db/roshan_phase1_migration.sql
--
-- Purpose:
--   1. Fail-closed permissions
--   2. Protect audit logs
--   3. Prevent mutation of locked visits
--   4. Make MRN/invoice/queue numbering concurrency-safe
--   5. Tighten role semantics
--   6. Add basic integrity constraints
-- =====================================================================

begin;

-- =====================================================================
-- 1. BASIC DATA INTEGRITY
-- =====================================================================

-- Pharmacy inventory must never contain negative stock.
do $$
begin
  alter table public.pharmacy_inventory
    add constraint pharmacy_inventory_quantity_nonnegative
    check (quantity >= 0);
exception
  when duplicate_object then null;
end $$;

-- Dispensed quantity must never be negative.
do $$
begin
  alter table public.prescription_items
    add constraint prescription_items_dispensed_quantity_nonnegative
    check (coalesce(dispensed_quantity, 0) >= 0);
exception
  when duplicate_object then null;
end $$;

-- Prices/amounts should not become negative.
do $$
begin
  alter table public.invoice_items
    add constraint invoice_items_amount_nonnegative
    check (coalesce(quantity, 0) >= 0 and coalesce(discount, 0) >= 0);
exception
  when duplicate_object then null;
end $$;


-- =====================================================================
-- 2. SECURITY DEFINER HELPERS
-- =====================================================================

create or replace function public.current_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select u.id
  from public.users u
  where u.auth_user_id = auth.uid()
    and coalesce(u.active, false) = true
  limit 1
$$;

create or replace function public.current_role_code()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select r.code
  from public.users u
  join public.roles r on r.id = u.role_id
  where u.auth_user_id = auth.uid()
    and coalesce(u.active, false) = true
  limit 1
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.current_role_code() = 'super_admin',
    false
  )
$$;

create or replace function public.app_has_perm(permission_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_super_admin()
    or exists (
      select 1
      from public.users u
      join public.role_permissions rp
        on rp.role_id = u.role_id
      join public.permissions p
        on p.id = rp.permission_id
      where u.auth_user_id = auth.uid()
        and coalesce(u.active, false) = true
        and p.code = permission_code
    )
$$;

grant execute on function public.current_app_user_id()
  to authenticated;

grant execute on function public.current_role_code()
  to authenticated;

grant execute on function public.is_super_admin()
  to authenticated;

grant execute on function public.app_has_perm(text)
  to authenticated;


-- =====================================================================
-- 3. AUDIT LOG PROTECTION
-- =====================================================================

/*
 * Application users must NOT be able to directly insert/update/delete
 * audit records.
 *
 * audit_row_change() is SECURITY DEFINER and remains responsible for
 * generating audit entries.
 */

revoke all on public.audit_logs from anon;
revoke insert, update, delete on public.audit_logs from authenticated;

drop policy if exists audit_logs_ins on public.audit_logs;
drop policy if exists audit_logs_upd on public.audit_logs;
drop policy if exists audit_logs_del on public.audit_logs;

-- Only authorized audit readers may SELECT.
drop policy if exists audit_logs_sel on public.audit_logs;

create policy audit_logs_sel
on public.audit_logs
for select
to authenticated
using (
  public.app_has_perm('audit.read')
);


-- =====================================================================
-- 4. LOCKED VISIT PROTECTION
-- =====================================================================

/*
 * Once a visit is locked, normal users cannot modify or delete it.
 * Super Admin remains the emergency override.
 */

create or replace function public.prevent_locked_visit_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(old.is_locked, false)
     and not public.is_super_admin() then

    raise exception
      'This visit is locked and cannot be modified.';
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_prevent_locked_visit_update
on public.visits;

create trigger trg_prevent_locked_visit_update
before update or delete
on public.visits
for each row
execute function public.prevent_locked_visit_mutation();


-- =====================================================================
-- 5. CONCURRENCY-SAFE NUMBER GENERATORS
-- =====================================================================

/*
 * The previous implementation used COUNT(*) + 1.
 *
 * That is unsafe:
 *
 * Request A -> count = 10
 * Request B -> count = 10
 * A -> number 11
 * B -> number 11
 *
 * Advisory transaction locks serialize number generation.
 */

create or replace function public.next_mrn()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  next_number bigint;
begin
  perform pg_advisory_xact_lock(
    hashtextextended('roshan.mrn.numbering', 0)
  );

  select coalesce(
    max(
      substring(mrn from 'RMC([0-9]+)$')::bigint
    ),
    0
  ) + 1
  into next_number
  from public.patients
  where mrn ~ '^RMC[0-9]+$';

  return 'RMC' || lpad(next_number::text, 6, '0');
end;
$$;


create or replace function public.next_invoice_number()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  prefix text;
  next_number bigint;
begin
  prefix := 'INV-' || to_char(now(), 'YYYYMM') || '-';

  perform pg_advisory_xact_lock(
    hashtextextended('roshan.invoice.' || prefix, 0)
  );

  select coalesce(
    max(
      substring(invoice_number from
        ('^' || prefix || '([0-9]+)$')
      )::bigint
    ),
    0
  ) + 1
  into next_number
  from public.invoices
  where invoice_number like prefix || '%';

  return prefix || lpad(next_number::text, 5, '0');
end;
$$;


create or replace function public.next_queue_number(_date date)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  next_number bigint;
begin
  perform pg_advisory_xact_lock(
    hashtextextended(
      'roshan.queue.' || _date::text,
      0
    )
  );

  select coalesce(max(queue_number), 0) + 1
  into next_number
  from public.queue_tickets
  where visit_date = _date;

  return 'Q' || lpad(next_number::text, 3, '0');
end;
$$;


grant execute on function public.next_mrn()
  to authenticated;

grant execute on function public.next_invoice_number()
  to authenticated;

grant execute on function public.next_queue_number(date)
  to authenticated;


-- =====================================================================
-- 6. REMOVE DANGEROUS "EMPTY PERMISSIONS = ALLOW" CONCEPT
-- =====================================================================

/*
 * The frontend now fails closed.
 *
 * The database already uses app_has_perm(), but we explicitly ensure
 * that no anonymous role receives table privileges.
 */

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'users',
    'patients',
    'visits',
    'vitals',
    'clinical_notes',
    'diagnoses',
    'followups',
    'certificates',
    'appointments',
    'queue_tickets',
    'lab_tests',
    'lab_parameters',
    'lab_reference_ranges',
    'lab_orders',
    'lab_order_items',
    'lab_results',
    'medicines',
    'pharmacy_inventory',
    'prescriptions',
    'prescription_items',
    'suppliers',
    'procedures_catalog',
    'procedure_orders',
    'procedure_results',
    'invoices',
    'invoice_items',
    'payments',
    'expenses',
    'corporate_accounts',
    'attachments',
    'system_settings',
    'branches',
    'departments'
  ]
  loop

    execute format(
      'revoke all on public.%I from anon',
      table_name
    );

  end loop;
end $$;


-- =====================================================================
-- 7. USER SELF-READ ONLY + AUTHORIZATION
-- =====================================================================

drop policy if exists users_sel on public.users;

create policy users_sel
on public.users
for select
to authenticated
using (
  auth_user_id = auth.uid()
  or public.app_has_perm('users.read')
);


-- Users cannot arbitrarily change their own role.
drop policy if exists users_upd on public.users;

create policy users_upd
on public.users
for update
to authenticated
using (
  public.app_has_perm('users.update')
)
with check (
  public.app_has_perm('users.update')
);


-- =====================================================================
-- 8. ROLE TABLES ARE REFERENCE DATA
-- =====================================================================

drop policy if exists roles_sel on public.roles;

create policy roles_sel
on public.roles
for select
to authenticated
using (true);


drop policy if exists permissions_sel on public.permissions;

create policy permissions_sel
on public.permissions
for select
to authenticated
using (true);


drop policy if exists role_permissions_sel
on public.role_permissions;

create policy role_permissions_sel
on public.role_permissions
for select
to authenticated
using (true);


-- Only Super Admin may mutate role/permission definitions.
drop policy if exists roles_ins on public.roles;
drop policy if exists roles_upd on public.roles;
drop policy if exists roles_del on public.roles;

create policy roles_ins
on public.roles
for insert
to authenticated
with check (public.is_super_admin());

create policy roles_upd
on public.roles
for update
to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

create policy roles_del
on public.roles
for delete
to authenticated
using (public.is_super_admin());


drop policy if exists permissions_ins on public.permissions;
drop policy if exists permissions_upd on public.permissions;
drop policy if exists permissions_del on public.permissions;

create policy permissions_ins
on public.permissions
for insert
to authenticated
with check (public.is_super_admin());

create policy permissions_upd
on public.permissions
for update
to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

create policy permissions_del
on public.permissions
for delete
to authenticated
using (public.is_super_admin());


drop policy if exists role_permissions_ins
on public.role_permissions;

drop policy if exists role_permissions_upd
on public.role_permissions;

drop policy if exists role_permissions_del
on public.role_permissions;

create policy role_permissions_ins
on public.role_permissions
for insert
to authenticated
with check (public.is_super_admin());

create policy role_permissions_upd
on public.role_permissions
for update
to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

create policy role_permissions_del
on public.role_permissions
for delete
to authenticated
using (public.is_super_admin());


-- =====================================================================
-- 9. PREVENT DIRECT AUDIT LOG MANIPULATION THROUGH GRANTS
-- =====================================================================

revoke all on public.audit_logs from anon;
revoke all on public.audit_logs from authenticated;


-- =====================================================================
-- 10. SECURITY SEARCH_PATH HARDENING
-- =====================================================================

alter function public.current_app_user_id()
  set search_path = public;

alter function public.current_role_code()
  set search_path = public;

alter function public.is_super_admin()
  set search_path = public;

alter function public.app_has_perm(text)
  set search_path = public;

alter function public.audit_row_change()
  set search_path = public;

alter function public.prevent_locked_visit_mutation()
  set search_path = public;

alter function public.next_mrn()
  set search_path = public;

alter function public.next_invoice_number()
  set search_path = public;

alter function public.next_queue_number(date)
  set search_path = public;


commit;


-- =====================================================================
-- POST-MIGRATION VERIFICATION
-- =====================================================================

/*
 * Run these SELECT statements separately after the migration.
 *
 * 1. Verify current user:
 *
 * select
 *   public.current_app_user_id(),
 *   public.current_role_code(),
 *   public.is_super_admin();
 *
 * 2. Verify permission:
 *
 * select public.app_has_perm('patients.read');
 *
 * 3. Verify numbering:
 *
 * select public.next_mrn();
 * select public.next_invoice_number();
 * select public.next_queue_number(current_date);
 *
 * 4. Verify audit grants:
 *
 * select grantee, privilege_type
 * from information_schema.role_table_grants
 * where table_schema = 'public'
 *   and table_name = 'audit_logs';
 */