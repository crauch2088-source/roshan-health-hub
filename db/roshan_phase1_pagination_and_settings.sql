-- ============================================================================
-- ROSHAN HEALTH HUB — Phase 1 migration
-- Security: least-privilege system_settings + pagination-supporting index.
--
-- SAFE / ADDITIVE:
--   - Adds one nullable-then-defaulted column (is_public) to system_settings.
--   - Backfills it for the rows that already exist today (the seven public
--     UI-facing keys seeded in the phase 1 migration).
--   - Replaces ONE policy (system_settings_sel) with a stricter version.
--     No table is dropped, no row is deleted, no other policy is touched.
--   - Adds a supporting index for the new patients search/pagination.
--
-- Run this after roshan_phase1_migration.sql and roshan_security_hardening.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. system_settings: least privilege
--
-- BEFORE: `system_settings_sel` used `using (true)` — every authenticated
--   user (reception, pharmacist, lab assistant, etc.) could read every row
--   in this table. Today's seeded rows are harmless (center name, currency,
--   invoice footer...), but the table is a free-form key/value store with
--   no schema, so nothing stopped a future setting — an SMTP password, a
--   payment API key, an internal note — from being just as exposed the
--   moment someone inserted it.
--
-- AFTER: rows are readable by everyone only when explicitly marked
--   `is_public = true`. Anything not explicitly marked public requires the
--   `settings.read` permission (Admin / Super Admin today). New settings
--   default to PRIVATE unless a developer/admin deliberately opts them in,
--   which is the safe default direction for a system that may later store
--   sensitive configuration in this table.
-- ----------------------------------------------------------------------------

alter table public.system_settings
  add column if not exists is_public boolean not null default false;

-- Backfill: the seven keys the Settings screen manages are genuinely
-- public/UI configuration (center identity, currency, invoice footer) and
-- are already displayed on invoices/receipts, so they stay readable by
-- every authenticated user.
update public.system_settings
set is_public = true
where setting_key in (
  'center_name',
  'center_name_ar',
  'currency',
  'phone',
  'address',
  'invoice_footer',
  'receipt_footer',
  'tax_percent'
);

drop policy if exists system_settings_sel on public.system_settings;
create policy system_settings_sel
on public.system_settings
for select
to authenticated
using (
  is_public = true
  or public.app_has_perm('settings.read')
);

-- ----------------------------------------------------------------------------
-- 2. Supporting index for the new patients search + pagination
--
-- patients.tsx now does server-side search across full_name/phone/mrn/
-- national_id combined with `.range()` pagination ordered by created_at.
-- This composite index lets Postgres satisfy "recent first" pagination
-- without a full table scan as the patients table grows.
--
-- NOTE: intentionally NOT using CREATE INDEX CONCURRENTLY here. Supabase's
-- SQL editor sends a pasted multi-statement script as one implicit
-- transaction block, and CONCURRENTLY cannot run inside a transaction
-- block — it would error out. At the current table size a brief write
-- lock during index creation is a safe tradeoff; if the tables are
-- already large in your production project, run each CREATE INDEX
-- statement below separately (paste + run one at a time) during low
-- traffic so you can use CONCURRENTLY instead.
-- ----------------------------------------------------------------------------

create index if not exists patients_created_at_idx
  on public.patients (created_at desc)
  where deleted_at is null;

-- Trigram-accelerated name search (falls back gracefully if the pg_trgm
-- extension isn't available — comment out this block if your Supabase
-- project doesn't have it enabled under Database → Extensions).
create extension if not exists pg_trgm;

create index if not exists patients_full_name_trgm_idx
  on public.patients using gin (full_name gin_trgm_ops);

create index if not exists audit_logs_created_at_idx
  on public.audit_logs (created_at desc);
