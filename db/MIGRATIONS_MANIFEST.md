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


## Phase 46/47 production application record — 2026-10-31

- Phase 46 `roshan_phase46_uat_schema_compatibility` applied to production as version `20261031071119` and QA as `20261031065937`.
- Phase 47 `roshan_phase47_queue_branch_attribution` applied to production as version `20261031071122` and QA as `20261031070544`.
- Phase 46/47 are now applied forward migrations, not candidates. Historical Phase 39 migration `20261020232033` remains unchanged and is already applied.
- Production post-apply catalog and branch-integrity checks passed. See `docs/PRODUCTION_ROLLOUT_2026-10-31.md`.




## Phase 48 candidate — Storage entity/branch binding (2026-10-31)

- Candidate: `db/roshan_phase48_storage_entity_branch_binding.sql`; Phase 47 is already reserved for visit/queue branch attribution and is applied to QA and production. Phase 48 remains a source candidate only.
- Supported private upload contracts resolve lab-report UUIDs to `lab_orders.id` and certificate integer IDs to `medical_certificates.id`. Both require active entity/parent rows and exact path-branch equality; linked visits must belong to the same patient and have the same explicit branch. Branchless visits fail closed.
- `roshan-clinical-attachments` remains fail-closed because no active uploader or approved entity-key contract exists. A generic `attachments` row is not an implicit Storage contract; typed client upload support is removed and the database boundary denies the bucket even when a matching synthetic row exists.
- The helper is `STABLE SECURITY DEFINER`, uses an empty fixed `search_path`, and is not directly executable by browser/service roles. The existing Phase 34 permission matrix remains unchanged for the two supported buckets.
- **Test-first:** the new source guard failed against the previous Phase 47 candidate before the correction (3/4 focused assertions passed). An initial exact-head lint run caught one Prettier wrapping issue; it was fixed in commit `355d24c04afc333ea8d2848131efbcb87eb38fff`.
- **Exact-head PostgreSQL 17: PASS** — PR #148 current head `1cd9f71bbb769615ba702e836d4620810480e504` (code-bearing commit `355d24c04afc333ea8d2848131efbcb87eb38fff`), workflow run [41180748822](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41180748822), job `124477494190`. It replayed the canonical v112 baseline, Phase 34 Storage migration, Phase 33 assertions, Phase 48 candidate, and Phase 48 assertions; focused source suite reported 15/15 pass, 0 fail.
- **Aggregate CI: PASS** — run [41180748870](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41180748870), job `124477494519`. Node 22 lockfile install, production dependency audit, complete-tree high/critical audit, role-guard tests, typecheck, lint, and production build all passed. Production dependency audit found 0 vulnerabilities. The complete development-inclusive tree still reports 14 moderate `minimatch <11.0.1` advisories; the current gate allows moderate dev-only findings but blocks high/critical. These advisories are **not fixed** and remain a separate dependency follow-up.
- Exact-head PR check inventory: **27 success, 1 intentionally skipped, 0 failures**. The skipped canonical PG17/authenticated clinical acceptance job remains deferred by design. Local Node 24 source regressions also passed 4/4 (`phase33-storage-realtime`) and 11/11 (`phase34-consolidated`); the temporary shell's full guard attempt was 220/221 because it lacked installed `zod`, so GitHub CI is the authoritative complete runtime check.
- No QA/production migration, Storage configuration, object, patient, clinical, or financial record was changed. PR #148 remains draft/open pending independent review and separate live-apply authorization; Issue #95 remains open and authenticated clinical E2E remains deferred.
- **Next:** obtain independent review of the Phase 48 candidate and assess the separate release gate; then address the 14 moderate development-tree `minimatch` advisories without forced major downgrades, followed by Issue #146's setup RPC exposure. Do not apply Phase 48 to QA or production without separate explicit authorization.


## Phase 49 candidate — atomic pharmacy dispense and stock ledger RLS (2026-10-31)

- Adds private.pharmacy_dispense_idempotency and public.atomic_pharmacy_dispense(uuid,boolean,uuid); identical request IDs replay the prior batch result; key/actor/payload mismatch is rejected.
- FEFO now requires exact patient-branch batch ownership and known, non-expired expiry. Super-admin status does not make branch stock fungible.
- Revokes dispense-only fn_dispense_prescription(uuid). The invoice-coupled legacy function remains temporarily callable until frontend cutover.
- Browser writes to stock_movements are revoked; authenticated SELECT remains permission-checked and branch-scoped.
- Candidate only: not applied to QA or production.

## Phase 50 candidate — clinical visit completion and consultation billing (2026-10-31)

- Adds complete_clinical_visit_and_bill(uuid): checks permission, active patient/visit, exact branch match, cancelled status and finite two-decimal consultation fee; bills before completing; aligns queue tickets to one timestamp.
- Existing complete_visit_atomic(uuid) remains as a compatibility wrapper.
- Disposable PG17 critical-path workflow verifies same-invoice pharmacy + consultation lines, no double charge on retry, expired batch rollback, idempotent dispense replay, and stock-ledger privilege boundary.
- Candidate only: not applied to QA or production.


### Phase 49 additional inventory guards

- Browser access to pharmacy_inventory is SELECT-only; receipt and dispense remain the supported write workflows.
- Positive-quantity batches require a known expiry; legacy NULL-expiry rows remain stored but non-dispensable.
- Direct authenticated changes to medicines.stock_quantity are rejected; the aggregate is maintained by atomic receive/dispense RPCs.
- Stock movement branch attribution for super-admin no-visit dispensing is anchored to the patient's branch.


### Phase 49 stock-entry source-of-truth correction

- New medicine master records are created with stock_quantity = 0; initial quantities must enter through the atomic batch receipt RPC.
- Batch receipt requires expiry at both UI and database layers. Existing legacy NULL-expiry rows are retained but cannot be dispensed.
- Direct authenticated changes to medicines.stock_quantity are rejected; pharmacy_inventory and stock_movements are browser SELECT-only.


The combined PG17 critical-path replay follows the canonical Phase 48 fixture order: v112 baseline, Storage/Realtime fixture, Phase 34, Phase 48, then Phases 49 and 50. Phase 46 and 47 remain covered by their own isolated fixture workflows and are intentionally not replayed into this baseline test.


- Browser acceptance: `docs/PHASE49_50_E2E_ACCEPTANCE_RUNBOOK_2026-10-31.md` — manual QA scenarios prepared; not executed. The PG17 integration suite is not a substitute for staff/browser E2E.
