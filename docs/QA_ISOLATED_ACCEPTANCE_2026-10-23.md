# Isolated QA environment — 2026-10-23

## Purpose

This branch and backend exist only to prepare the single comprehensive Roshan Health Hub acceptance session. Do not promote the QA branch or QA database to production.

- Git branch: `qa/isolated-acceptance-20261023`
- Supabase QA project: `roshan-health-hub-qa`
- Supabase project ref: `hopfohcnrtbiqjkgeukz`
- Region: `eu-west-1`
- Vercel environment: Preview only, branch-scoped to this branch.
- QA browser variables: `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`; both are scoped to this branch's Preview deployment.
- Production Supabase project `jewzonxplxhogqrnhosl` and production environment variables were not modified.

## QA schema setup completed

Applied to QA only:
1. A QA-adapted v112 application-schema baseline, preserving Supabase-managed `auth.users` and `auth.uid()` and omitting extension-owned C function declarations provided by `pg_trgm`.
2. Phase 34 storage/realtime/lab verification migration.
3. Phase 36 audit and visit-lifecycle guards.
4. Phase 39 permissions/lab catalog/audit closure.
5. Phase 31 contract security cutover to ensure direct browser writes to `lab_order_items` and `medical_certificates` are revoked.
6. Phase 45 atomic visit/queue completion retry candidate.

The first baseline application attempt failed on C-language function permissions and rolled back cleanly; the adapted baseline then succeeded. Read-only checks confirm the real platform `auth.uid()` remains present, `pg_trgm` is installed, 56 public tables and 210 public RLS policies exist, Phase 45's `complete_visit_atomic(uuid)` function exists, and authenticated direct INSERT/UPDATE/DELETE on `lab_order_items` is denied.

## Remaining schema-parity gate

The QA catalog currently reports 838 public columns, 213 constraints, and 238 indexes, while the repository's v115 production fingerprint records 844 columns, 214 constraints, and 239 indexes. Do not claim exact structural parity or proceed to authenticated clinical acceptance until the six-column/one-constraint/one-index delta is explained from trusted source. Do not guess missing historical SQL.

The legacy `db/tests/clinical_security_hardening_assertions.sql` is not directly portable to this Supabase QA project: it assumes older fixture column requirements and a CI-specific auth test setting. Its execution was wrapped in a transaction and failed before commit; the transaction rolled back. No synthetic patient/visit/financial fixture rows persisted. Adapt the test harness to the actual Supabase schema and use a supported Auth user-provisioning path before rerunning.

## Current QA data state

- Auth users: 0.
- Patient rows: 0.
- Visit rows: 0.
- Invoice rows: 0.
- Queue-ticket rows: 0.
- No staff/test accounts have been provisioned yet.
- Phase 45 is applied to QA only and remains unapplied to production.

## Required next steps

1. Reconcile the catalog delta from the exact tracked baseline/migration sources, without inventing SQL.
2. Create synthetic QA-only Auth users using a supported Supabase Auth provisioning method and link their application roles.
3. Trigger a branch-scoped Preview deployment only after the QA schema gate is resolved; avoid unnecessary Vercel builds.
4. Run automated smoke checks, then do the one comprehensive staff/user acceptance session with the user.
5. Keep Issue #95 open until that session passes and evidence is recorded.

## Data and release safety

- Never create patient, visit, laboratory, prescription, inventory, or financial test rows in production.
- Do not apply Phase 45 to production without a separate explicit release gate after QA evidence.
- Do not use paid database branches, paid services, or unnecessary builds.
