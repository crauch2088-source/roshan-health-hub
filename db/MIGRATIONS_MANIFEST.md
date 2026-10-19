# Database migration manifest

Last verified against production catalog: **2026-10-19**, PostgreSQL **17.6**, migration ledger version **112** (20261019061315_roshan_phase32_medical_certificate_visit_index).

## Canonical clean-room baseline

- File: db/baseline/0000_roshan_pg17_baseline_v112.sql
- Purpose: replay the application schema snapshot on a disposable PostgreSQL 17 database without depending on missing historical Supabase migration-ledger entries before 20260818.
- Source: read-only catalog extraction from Supabase project jewzonxplxhogqrnhosl; no production DDL or DML was run to generate it.
- Captured application objects: 56 public tables, 213 table constraints, 163 non-constraint indexes, 126 functions/procedures in public and private, 47 public triggers, 203 public RLS policies, RLS enablement, views, sequence ownership, and effective table/sequence/schema/function ACLs.
- Platform compatibility: creates a minimal auth.users / auth.uid() shim and roles needed for plain PostgreSQL CI. It is not a replacement for Supabase-managed platform schemas/services (storage, realtime, Vault, Edge Functions, Auth configuration) and must never be applied to production.
- Data policy: schema only. No patient, visit, result, certificate, financial, inventory, or other business rows are exported.
- CI: clinical-e2e-acceptance replays this file against an empty postgres:17 database and separately runs the synthetic clinical acceptance workflow in another disposable database.

## Clinical acceptance workflow

- SQL acceptance: db/tests/clinical_e2e_acceptance_workflow.sql
- Fixture: db/tests/clinical_security_hardening_fixture.sql
- Assertions run after Phase 31 Expand and Contract SQL on a separate PostgreSQL 17 database.
- Covers receptionist registration + visit/queue creation, lab technician partial result save, item completion and idempotent resave, atomic doctor visit/queue completion, visit-linked certificate serial generation, pharmacist rejection, and cancelled-visit rejection.
- All test writes are enclosed in a transaction and rolled back. The SQL test contains synthetic UUIDs and explicitly forbids production use.
- Frontend/service contract test: tests/clinical-e2e-acceptance.test.ts, included in npm run test:guard.

## Reconciliation rules

1. Treat the baseline as the canonical application-schema starting point for new clean-room PostgreSQL 17 CI tests.
2. New database changes still require a forward migration file, a focused fixture/assertion, and updates to the CI baseline/replay checks when the canonical snapshot intentionally advances.
3. Never use the baseline as a production migration and never point the acceptance fixture at the live Supabase project.
4. Before changing the snapshot version, capture the live ledger and catalog counts again and update this manifest, the baseline header, and the CI assertions in one PR.


## Phase 33 staged Storage/Realtime migration

- Candidate: `db/roshan_phase33_storage_and_realtime.sql`; three private clinical buckets with branch UUID folder scoping and permission checks.
- Private topics use `branch:<uuid>:queue` and `branch:<uuid>:lab`; browser publishing is intentionally not granted. If `supabase_realtime` exists, queue and lab source tables are added only when missing; existing source-table RLS remains the Postgres Changes row boundary.
- CI fixture/assertions: `db/tests/phase33_storage_realtime_fixture.sql` and `db/tests/phase33_storage_realtime_assertions.sql`, replayed after the canonical baseline in isolated PostgreSQL 17.
- This migration is staged in PR #80 only; do not apply it to the live Supabase project as part of this task.
