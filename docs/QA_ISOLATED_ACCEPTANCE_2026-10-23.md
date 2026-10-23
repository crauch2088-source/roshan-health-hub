# Isolated QA environment — 2026-10-23

## Purpose

This branch and backend exist only to prepare the single comprehensive Roshan Health Hub acceptance session. Do not promote the QA branch or QA database to production.

- Git branch: `qa/isolated-acceptance-20261023`
- Supabase QA project: `roshan-health-hub-qa`
- Supabase project ref: `hopfohcnrtbiqjkgeukz`
- Region: `eu-west-1`
- Vercel environment variables: `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`, Preview-only and branch-scoped to this branch.
- Production Supabase project `jewzonxplxhogqrnhosl` and production environment variables were not modified.
- QA Auth email auto-confirm was briefly toggled for a standard-signup capability check, no accounts were created, and the original `mailer_autoconfirm=false` setting was restored.

## QA schema setup completed

Applied to QA only:
1. A QA-adapted v112 application-schema baseline, preserving Supabase-managed `auth.users` and `auth.uid()` and omitting extension-owned C function declarations provided by `pg_trgm`.
2. Phase 34 storage/realtime/lab verification migration.
3. Phase 36 audit and visit-lifecycle guards.
4. Phase 39 permissions/lab catalog/audit closure.
5. Phase 31 contract security cutover to revoke direct browser writes to `lab_order_items` and `medical_certificates`.
6. Phase 45 atomic visit/queue completion retry candidate.
7. ACL reconciliation using read-only production catalog metadata, plus matching PostgreSQL default privileges for the `postgres` role in `public`.

The first baseline application attempt failed on C-language function permissions and rolled back cleanly; the adapted baseline then succeeded. Read-only checks confirm the real platform `auth.uid()` remains present, `pg_trgm` is installed, Phase 45's `complete_visit_atomic(uuid)` function exists with retry repair and fail-closed missing-timestamp logic, and authenticated direct INSERT/UPDATE/DELETE on `lab_order_items` is denied.

## Catalog comparison

A direct, read-only comparison between current production and QA returned **zero differences** in the normalized arrays for:
- public column names/types/nullability/defaults;
- public constraints and definitions;
- public index names/definitions;
- public/private function signatures, SECURITY DEFINER flags, and search-path configuration;
- non-internal public triggers and definitions;
- public RLS policies and expressions;
- table ACLs, sequence ACLs, function ACLs, and public-schema default ACLs for the compared roles.

Counts from that comparison match on both sides: 838 public columns, 213 constraints, 238 indexes, 134 public/private functions, 64 non-internal public triggers, and 210 public RLS policies.

**Outstanding reconciliation note:** the stored `docs/live-catalog-fingerprint-v115.json` reports 844 columns, 214 constraints, and 239 indexes. That stored fingerprint's count definition/result does not match the direct metadata query above. Do not claim a fresh canonical 7/7 SHA-256 fingerprint comparison until the counting/query discrepancy is reconciled; do not guess missing SQL.

## Automated test evidence and limitation

- Phase 45 source and PostgreSQL 17 retry assertions passed the exact-head CI checks on PR #101 before merge.
- The legacy `db/tests/clinical_security_hardening_assertions.sql` is not directly portable to this Supabase QA project: it assumes older fixture column requirements and a CI-specific auth test setting. Its execution was wrapped in a transaction and failed before commit; the transaction rolled back. No synthetic patient/visit/financial fixture rows persisted.
- The standard signup API capability check was blocked by the available tool's safety controls. No direct writes were made to Supabase-managed Auth tables and no passwords or service-role secrets were retrieved. A supported Auth user-provisioning method is still required.

## Current QA data state

- Auth users: 0.
- Patient rows: 0.
- Visit rows: 0.
- Lab-order rows: 0.
- Prescription rows: 0.
- Invoice rows: 0.
- Queue-ticket rows: 0.
- Phase 45 is applied to QA only and remains unapplied to production.
- The Vercel branch-scoped variables are configured, but no new QA Preview build was triggered; the branch change is documentation-only and quota protection says to skip unnecessary builds.

## Required next steps

1. Reconcile the stored fingerprint count discrepancy, retaining the direct comparison evidence above.
2. Create synthetic QA-only Auth users through an approved, supported provisioning method and link application roles.
3. Trigger a branch-scoped Preview deployment when the QA Auth path is ready; avoid unnecessary Vercel builds.
4. Run automated smoke checks, then do the one comprehensive staff/user acceptance session with the user.
5. Keep Issue #95 open until that session passes and evidence is recorded.

## Data and release safety

- Never create patient, visit, laboratory, prescription, inventory, or financial test rows in production.
- Do not apply Phase 45 to production without a separate explicit release gate after QA evidence.
- Do not use paid database branches, paid services, or unnecessary builds.
