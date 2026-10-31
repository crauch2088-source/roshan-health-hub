# Database migration manifest

Last captured catalog fingerprint: **2026-10-21**, PostgreSQL **17.6**, schema snapshot at migration **115** (`20261020232033_roshan_phase39_permissions_lab_catalog_and_audit_closure`). The seven-category SHA-256 fingerprint is recorded in `docs/live-catalog-fingerprint-v115.json`; clean-room CI replays migrations 113–115 and requires exact count + digest matches.

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

- Candidate: `db/roshan_phase33_storage_and_realtime.sql`; three private clinical buckets with branch UUID folder scoping, permission checks, and restrictive boundary policies that cannot be bypassed by older permissive policies.
- Private topics use `branch:<uuid>:queue` and `branch:<uuid>:lab`; browser publishing is intentionally not granted. If `supabase_realtime` exists, queue and lab source tables are added only when missing; existing source-table RLS remains the Postgres Changes row boundary.
- CI fixture/assertions: `db/tests/phase33_storage_realtime_fixture.sql` and `db/tests/phase33_storage_realtime_assertions.sql`, replayed after the canonical baseline in isolated PostgreSQL 17.
- This migration is staged in PR #80 only; do not apply it to the live Supabase project as part of this task.


## Phase 34 production closure and Phase 35 frontend wiring — 2026-10-20

- Live Supabase ledger: **113 migrations**, latest `20261020090350_roshan_phase34_storage_guard_lab_verify_realtime`.
- The consolidated SQL uses guarded Storage and Realtime policy DDL and does not attempt to change ownership-controlled `storage.objects` RLS.
- Read-only live verification confirmed the three private clinical buckets, `public.verify_lab_order(uuid)`, lab verification columns, audit mutation triggers, and publication membership for `queue_tickets`, `lab_orders`, and `visits`.
- Phase 35 wires branch-scoped Realtime invalidation into consultation, queue, lab list/detail, and certificate screens. Server lab verification and Realtime default on unless `VITE_ROSHAN_PHASE34_ENABLED=false`; direct browser Storage upload remains opt-in via `VITE_ROSHAN_STORAGE_DIRECT_UPLOAD_ENABLED=true`.
- No production business data was used. Historical snapshot remains 93 mappings; forward-source delta now tracks 17 migrations through version `20261020090350`.


## Phase 36 live-ledger update — 2026-10-20

- Verified live migration ledger: **114 entries**, latest `20261020111126_roshan_phase36_audit_coverage_and_visit_lifecycle_guards`.
- Tracked source: `db/roshan_phase36_audit_coverage_and_visit_lifecycle_guards.sql`. It adds audit coverage on insurance prior authorizations, medical certificates, and patient discounts; clinical parent-link/cancelled-visit guards on five tables; and publication membership for prescriptions and invoices.
- The forward delta retains the frozen 93-entry historical snapshot and tracks 18 forward-source mappings. CI verifies normalized repository SQL SHA-256; the Supabase migration-history interface does not expose stored SQL, so independent live SQL hash equality is not claimed.
- Frontend Realtime invalidates pharmacy/billing query keys. Direct clinical Storage remains opt-in; print remains available when the feature flag is off.


## Phase 39 — migration 115 and catalog closure

- Live ledger: 115 migrations, latest version `20261020232033`.
- The read-only production query confirmed `public.permissions` contains `visits.delete`; the captured row was reduced to the permission code/name in documentation, with no user or patient data involved.
- The seven-category in-database SHA-256 fingerprint is stored in `docs/live-catalog-fingerprint-v115.json`. Compared with v114, the trigger category advances from 57 to 64 objects, matching the seven Phase 39 audit triggers; other six category fingerprints remain unchanged.
- CI applies the canonical v112 baseline, migration 113 (Phase 34), migration 114 (Phase 36), and migration 115 (Phase 39) in order on disposable PostgreSQL 17 before computing the fingerprint. Production is read-only and is never used for replay.
- The live migration ledger does not expose persisted migration SQL bytes; the tracked normalized source hash is not claimed as a byte-for-byte live SQL hash.

## Phase 40 — final release seal

- Captured the v115 fingerprint with one read-only PostgreSQL SELECT that computes all seven SHA-256 digests in the database.
- Release seal is complete only when the exact replay comparator reports `exact_match: true`, `matched_categories: 7`, `total_categories: 7` on the Phase 40 PR head and the PR is squash-merged.


## Phase 45 candidate — atomic visit/queue completion retry

- Candidate source: `db/roshan_phase45_atomic_visit_queue_completion_retry.sql`.
- First completion assigns one server-side timestamp to the visit and linked queue tickets; retry repairs active tickets using the visit's authoritative timestamp, even if the ticket carries a stale completion time. A completed visit missing its timestamp fails closed for manual repair rather than mutating the visit row.
- The UI delegates linked visit completion to `complete_visit_atomic` and performs no second browser-side ticket update.
- PostgreSQL 17 isolated CI asserts retry repair, timestamp alignment, and preservation of the visit's original completion timestamp and `updated_at`.
- **Candidate only; not applied to production.** Production migration remains gated on exact-head CI, migration review, and explicit release approval.


## Phase 46 candidate — UAT schema compatibility (2026-10-31)

- Candidate: `db/roshan_phase46_uat_schema_compatibility.sql`.
- Adds `patients.allergies text` and `prescriptions.branch_id uuid` for the two missing columns independently observed on production and isolated QA during live browser UAT.
- Prescription branch is copied only from the linked visit; the migration aborts on malformed patient/visit links or conflicting pre-existing branch values. A private SECURITY DEFINER trigger with an empty fixed search_path derives branch_id for future visit-linked prescriptions and rejects wrong patient, wrong branch, missing/deleted visit, or new unlinked prescription. Legacy unlinked prescriptions remain NULL and can receive non-identity updates.
- FK and branch/status/created_at index are included. No NOT NULL constraint is imposed because historical unlinked rows are retained without guessed attribution.
- Disposable PG17 fixture/assertions: `db/tests/phase46_uat_schema_compatibility_fixture.sql` and `db/tests/phase46_uat_schema_compatibility_assertions.sql`; focused workflow: `.github/workflows/ci-phase46-uat-schema-compatibility.yml`.
- **Candidate only:** not applied to QA or production. Do not update the canonical v115 baseline/fingerprint until a separately approved live migration and catalog capture establish the next canonical snapshot.
- Full UAT evidence: `docs/UAT_PHASE46_SCHEMA_COMPATIBILITY_2026-10-31.md`.


## Phase 47 candidate — visit and queue branch attribution (2026-10-31)

- Candidate: `db/roshan_phase47_queue_branch_attribution.sql`.
- Adds `queue_tickets.branch_id uuid`, FK and branch/date/status index because the live Queue route selects the field but the production table lacked it.
- In a deployment with exactly one active branch, backfills branchless visits only from the patient's explicitly assigned branch; with multiple active branches, inactive branches, or unassigned patients, it does not guess.
- Backfills queue tickets from the authoritative visit and adds invoker triggers that keep new visit and queue-ticket branch attribution consistent.
- Disposable PostgreSQL 17 fixture/assertions: `db/tests/phase47_queue_branch_fixture.sql` and `db/tests/phase47_queue_branch_assertions.sql`; exact-head workflow is part of `.github/workflows/ci-phase46-uat-schema-compatibility.yml` and also has a dedicated workflow file.
- Applied and read back in isolated QA as migration `roshan_phase47_queue_branch_attribution` (version `20261031070544`). Production remains unchanged until the reviewed PR is merged and the required backup/release gate is satisfied.
