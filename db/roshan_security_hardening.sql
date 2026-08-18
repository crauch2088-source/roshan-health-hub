-- =====================================================================
-- ROSHAN MEDICAL CENTER
-- SECURITY HARDENING v2
--
-- ADDITIVE MIGRATION
--
-- IMPORTANT:
-- 1. Do NOT run roshan_phase1_migration.sql again.
-- 2. Run this AFTER the existing Phase 1 migration.
-- 3. This migration deliberately avoids replacing the complete RLS
--    architecture until it has been audited table-by-table.
--
-- Main fixes:
--   - fail-closed permission helpers
--   - append-only audit log
--   - locked visit protection
--   - concurrency-safe visit numbering
--   - unique daily visit numbers
--   - basic numeric integrity constraints
--   - SECURITY DEFINER search_path hardening
-- =====================================================================

begin;


-- =====================================================================
-- 1. APPLICATION USER HELPERS
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
    and coalesce(u.active, true) = true
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
  join public.roles r
    on r.id = u.role_id
  where u.auth_user_id = auth.uid()
    and coalesce(u.active, true) = true
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


create or replace function public.app_has_perm(
  _code text
)
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
        and coalesce(u.active, true) = true
        and p.code = _code
    )
$$;


grant execute
on function public.current_app_user_id()
to authenticated;

grant execute
on function public.current_role_code()
to authenticated;

grant execute
on function public.is_super_admin()
to authenticated;

grant execute
on function public.app_has_perm(text)
to authenticated;


-- =====================================================================
-- 2. AUDIT LOG — APPEND ONLY
-- =====================================================================

/*
 * Normal authenticated clients must never be able to:
 *
 * INSERT
 * UPDATE
 * DELETE
 *
 * audit rows.
 *
 * The existing SECURITY DEFINER audit trigger remains responsible for
 * creating records.
 */

revoke insert, update, delete
on public.audit_logs
from authenticated;

revoke all
on public.audit_logs
from anon;


drop policy if exists audit_logs_ins
on public.audit_logs;

drop policy if exists audit_logs_upd
on public.audit_logs;

drop policy if exists audit_logs_del
on public.audit_logs;

drop policy if exists audit_logs_sel
on public.audit_logs;

drop policy if exists audit_logs_select
on public.audit_logs;


grant select
on public.audit_logs
to authenticated;


create policy audit_logs_select
on public.audit_logs
for select
to authenticated
using (
  public.app_has_perm('audit.read')
);


-- =====================================================================
-- 3. LOCKED VISITS
-- =====================================================================

/*
 * A locked visit is a clinical record that has been closed.
 *
 * Normal users cannot modify or delete it.
 *
 * Super Admin can perform an emergency correction.
 */

create or replace function public.prevent_locked_visit_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

  if coalesce(old.is_locked, false) = true
     and not public.is_super_admin()
  then

    raise exception
      'This visit is locked and cannot be modified.';

  end if;

  return coalesce(new, old);

end;
$$;


drop trigger if exists trg_prevent_locked_visit_mutation
on public.visits;


create trigger trg_prevent_locked_visit_mutation
before update or delete
on public.visits
for each row
execute function public.prevent_locked_visit_mutation();


-- =====================================================================
-- 4. CONCURRENCY-SAFE VISIT NUMBERING
-- =====================================================================

/*
 * OLD BEHAVIOUR:
 *
 * Math.random()
 *
 * This is not suitable for a medical queue.
 *
 * NEW BEHAVIOUR:
 *
 * PostgreSQL generates the number.
 *
 * Example:
 *
 * 001
 * 002
 * 003
 * ...
 *
 * A transaction advisory lock prevents two simultaneous registrations
 * from receiving the same number.
 */

create or replace function public.next_visit_number(
  _visit_date date
)
returns text
language plpgsql
security definer
set search_path = public
as $$

declare
  next_number integer;

begin

  if _visit_date is null then

    raise exception
      'visit_date is required';

  end if;


  perform pg_advisory_xact_lock(
    hashtextextended(
      'roshan.visit.' || _visit_date::text,
      0
    )
  );


  select
    coalesce(
      max(
        case
          when visit_number ~ '^[0-9]+$'
          then visit_number::integer
          else null
        end
      ),
      0
    ) + 1

  into next_number

  from public.visits

  where visit_date = _visit_date
    and deleted_at is null;


  return lpad(
    next_number::text,
    3,
    '0'
  );

end;
$$;


grant execute
on function public.next_visit_number(date)
to authenticated;


-- =====================================================================
-- 5. UNIQUE DAILY VISIT NUMBER
-- =====================================================================

/*
 * This database constraint is the final safety net.
 *
 * Even if a buggy client tries to insert the same number twice,
 * PostgreSQL will reject the duplicate.
 */

do $$

begin

  alter table public.visits

    add constraint visits_visit_number_day_key

    unique (
      visit_date,
      visit_number
    );

exception

  when duplicate_object then

    null;

end $$;


-- =====================================================================
-- 6. NON-NEGATIVE PHARMACY QUANTITY
-- =====================================================================

do $$

begin

  alter table public.pharmacy_inventory

    add constraint pharmacy_inventory_quantity_nonnegative

    check (
      quantity >= 0
    );

exception

  when duplicate_object then

    null;

end $$;


-- =====================================================================
-- 7. NON-NEGATIVE DISPENSED QUANTITY
-- =====================================================================

do $$

begin

  alter table public.prescription_items

    add constraint prescription_items_dispensed_quantity_nonnegative

    check (
      coalesce(
        dispensed_quantity,
        0
      ) >= 0
    );

exception

  when duplicate_object then

    null;

end $$;


-- =====================================================================
-- 8. INVOICE ITEM QUANTITY
-- =====================================================================

do $$

begin

  alter table public.invoice_items

    add constraint invoice_items_quantity_nonnegative

    check (
      coalesce(
        quantity,
        0
      ) >= 0
    );

exception

  when duplicate_object then

    null;

end $$;


-- =====================================================================
-- 9. INVOICE DISCOUNT
-- =====================================================================

do $$

begin

  alter table public.invoice_items

    add constraint invoice_items_discount_nonnegative

    check (
      coalesce(
        discount,
        0
      ) >= 0
    );

exception

  when duplicate_object then

    null;

end $$;


-- =====================================================================
-- 10. SECURITY DEFINER SEARCH PATH HARDENING
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


alter function public.next_visit_number(date)
set search_path = public;


commit;


-- =====================================================================
-- POST-MIGRATION VERIFICATION
-- =====================================================================

/*
 * After successful migration, run these individually in Supabase SQL
 * Editor.
 *
 * 1.
 *
 * select public.current_role_code();
 *
 *
 * 2.
 *
 * select public.is_super_admin();
 *
 *
 * 3.
 *
 * select public.app_has_perm('patients.read');
 *
 *
 * 4.
 *
 * select public.next_visit_number(current_date);
 *
 *
 * IMPORTANT:
 *
 * next_visit_number() does NOT insert anything.
 * It is intended to be called inside the visit creation workflow.
 *
 * Do not repeatedly call it as a production test.
 *
 * ===================================================================
 */