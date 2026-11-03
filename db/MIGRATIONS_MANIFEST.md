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


## Phase 48 application record — 2026-10-31 (read-back 2026-11-01)

- Forward migration source: `db/roshan_phase48_storage_entity_branch_binding.sql`.
- Supabase migration ledger confirms production version `20261031103927` and isolated QA version `20261031103912`; current ledger counts are 118 production entries and 12 QA entries.
- Read-only catalog checks in both projects confirm the helper `private.phase48_storage_entity_branch_matches(text,text)` is STABLE SECURITY DEFINER with an empty search path and no direct EXECUTE grant to anon, authenticated, or service_role.
- The four Phase 34 restrictive Storage boundary policies remain RESTRICTIVE for SELECT, INSERT, UPDATE, and DELETE in both projects. The helper is called from the existing SECURITY DEFINER boundary; it is not exposed as a browser RPC.
- This supersedes the earlier Phase 48 candidate-only note. No additional migration was applied during the 2026-11-01 verification.


## QA view security-invoker reconciliation — 2026-11-01 read-back

- Isolated QA migration `20261031071243 qa_restore_security_invoker_on_exposed_views` is already present in the ledger; it is a QA-only reconciliation and is not part of the production migration chain.
- Read-only QA and production catalog checks confirm `security_invoker=true` on `public.cashbox_balance`, `public.follow_ups`, `public.v_patient_receivables`, and `public.v_supplier_outstanding`. Authenticated SELECT remains true and anon SELECT false for all four views.
- PR #141 still needs a current-main refresh so the canonical v112 baseline preserves these options and the disposable PostgreSQL 17 replay proves idempotence. Do not rerun the already-applied QA script.


## QA view security-invoker baseline closure — 2026-11-02

- PR [#141](https://github.com/crauch2088-source/roshan-health-hub/pull/141) was squash-merged as `9f17d2bb6d3290b036de71da9cb147540707d17a`.
- The canonical v112 baseline now defines `security_invoker=true` on `cashbox_balance`, `follow_ups`, `v_patient_receivables`, and `v_supplier_outstanding`, with a fail-closed catalog assertion inside the baseline transaction before its final COMMIT.
- The Phase 37 PostgreSQL 17 CI replay resets these options in its disposable database, applies `db/qa/20261030_restore_security_invoker_on_qa_views.sql` twice, and verifies the contract. PR-head checks were 26 success / 1 intentional clinical-acceptance skip / 0 failures; post-merge main CI [41398491594](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41398491594) was 22 success / 1 intentional skip / 0 failures.
- The QA-only reconciliation was already applied as migration `20261031071243` before this merge. It was not rerun, and no production migration or business-data write was made.
- Read-only QA/production catalog evidence confirms all four view options and the prior Security Advisor recheck found no view-specific findings. Issue [#140](https://github.com/crauch2088-source/roshan-health-hub/issues/140) is closed. The unrelated pg_trgm, SECURITY DEFINER function, and leaked-password-protection findings remain separate.
- This is baseline/QA fidelity closure, not authenticated clinical acceptance. Issue #95 remains open and clinical E2E stays deferred.


## Phase 51 candidate — anonymous setup status RPC (2026-11-02)

- Candidate: db/roshan_phase51_public_setup_required_anon.sql; source-only, not applied to QA or production.
- Replaces only the public zero-argument boolean wrapper with STABLE SECURITY DEFINER and an empty fixed search_path, calling the unchanged private.setup_required() helper by its qualified name.
- Direct EXECUTE is reset and granted only to anon and authenticated. The private helper's body, owner, ACL, and private-schema grants remain unchanged; anon cannot execute it or use the private schema.
- Disposable PostgreSQL 17 assertions check exact direct grants, function flags/return type, anon true when public.users is empty, anon false after one synthetic user row, and private-helper denial. The synthetic row is in a transaction that is rolled back.
- CI applies the candidate after the v115 catalog fingerprint comparison, leaving the canonical v115 fingerprint contract unchanged. Source regression is included in npm run test:guard.
- Phase 49 and Phase 50 are already used by the draft PR #149 pharmacy/billing candidate. Do not reuse stale migration version 117; recheck the live ledger and PR #149 merge order before assigning an actual Supabase migration timestamp.


### Phase 51 validation addendum — 2026-11-02

- PR #150 corrected code head: ef66e4bdc1d2e93e293c4bcc776a331e4e950906; exact-head inventory 29 checks, 28 success, one intentional clinical-acceptance skip, zero failures.
- CI 41399729647 passed. The Phase 51 PostgreSQL 17 step passed after the v115 7/7 catalog fingerprint check; source guard, typecheck, lint, and build passed.
- Read-only live recheck: production ledger 118 entries/latest 20261031103927; QA ledger 12/latest 20261031103912. Both still have the pre-migration public wrapper (STABLE SECURITY INVOKER, empty search_path, anon EXECUTE false); authenticated EXECUTE true. Authenticator inherits anon/authenticated/service_role membership in both environments.
- PR #150 remains Draft pending independent review. No migration timestamp has been assigned and no QA/production migration or privilege change was made.



## Phase 51 QA application — 2026-11-02

- Applied migration name `roshan_phase51_public_setup_required_anon` to isolated QA project `hopfohcnrtbiqjkgeukz`; Supabase ledger version **20261102122437**.
- Read-back confirms public.setup_required() is STABLE SECURITY DEFINER, fixed empty search_path, owned by postgres, executable by anon/authenticated only as direct grants. Anon cannot execute private.setup_required() or use schema private.
- Read-only `SET ROLE anon` execution returned the expected boolean false in initialized QA. No user, clinical, or financial rows were inserted or changed.
- Production remains at 118 entries/latest `20261031103927`; Phase 51 is **not applied** to production pending manual logical backup, off-site storage, and restore rehearsal required by the production rollout gate.
- Source PR #150 merged as `0bb8bab7acee6acccb1fadeb0ae7a5270f097c4a`; exact-head CI [41400152008](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41400152008) passed 28 checks with one intentional clinical-acceptance skip and zero failures.


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


## Phase 52 candidate — reporting and analytics (2026-11-02)

- Candidate migration: `db/roshan_phase52_reporting_analytics.sql`; source-only and **not applied** to QA or production.
- Adds `public.get_reporting_analytics(date,date,uuid)`, a STABLE SECURITY INVOKER read-only RPC. It requires `reports.read`, a valid authenticated app user, an inclusive date range no longer than 366 days, and branch access when a branch is explicitly requested.
- The RPC relies on underlying table grants/RLS, returns aggregates only (summary KPIs, monthly cash/visit trends, department/doctor/test/diagnosis counts), and never returns patient identifiers, notes, or raw clinical rows. It uses Africa/Khartoum clinic-local date boundaries.
- EXECUTE is revoked from PUBLIC, anon and service_role; authenticated receives the only application grant. No SECURITY DEFINER is introduced. The payload includes per-domain permission coverage flags so restricted domains (notably insurance for legacy-admin roles) cannot be mistaken for true zero totals.
- Disposable PostgreSQL 17 workflow replays the canonical v112 baseline and Phase 34/46/47/48/49/50/51 prerequisites before Phase 52 catalog/ACL assertions. Source guard tests date bounds, route RPC usage, aggregate-only export, and workflow isolation.
- UI candidate updates `src/routes/_authenticated/reports.tsx` to use the bounded aggregate RPC, monthly trend export and summary CSV; `src/lib/reporting.ts` validates dates. Arabic/English labels are added in `src/lib/i18n.tsx`.
- No receipt/prescription print templates, inter-branch stock transfer writes, or insurance claim workflow changes are included. Those are separate phases below in the roadmap document; they need their own domain-specific safety and accounting contracts.

## Phase 49–52 production/QA provenance update — 2026-11-03

- Read-only ledger/catalog verification now confirms 129 production migration rows (latest `20261102232941`) and 17 QA rows (latest `20261102232905`). This supersedes the earlier candidate-only status notes for Phases 49–52.
- Production rows `20261102232823`, `20261102232849`, `20261102232852`, and `20261102232855` match the current Phase 49–52 source files after removing only the terminal `COMMIT;` wrapper and trailing whitespace. Exact SHA-256 mappings and source Git blob SHAs are in `docs/recovered-migrations/phase49-52-provenance.json`.
- Production row `20261102232819` is an unmapped table/index rename; its exact SQL is quarantined under `docs/recovered-migrations/sql/` and is not a canonical deployment migration.
- Production row `20261102232941` is an unmapped cleanup/reversal `DO` block. The public copy is redacted because the stored SQL contains fixed production UUIDs. Its original ledger SHA-256 is preserved in the scoped provenance report; the redacted artifact is non-replayable.
- Four earlier 134-byte production ledger rows are placeholder statements, not the Phase 49–52 migration bodies. The private archive does not contain full migration SQL.
- This is a scoped provenance reconciliation, not full migration-chain replay, full schema parity, or data-level validation. Backup/restore remains unverified; no further production database change is authorized by this documentation update.

## Live migration addendum — 2026-11-03

The historical entries above remain unchanged. Current environment ledgers and forward phases:

| Phase | Source file | QA applied version | Production state |
|---|---|---|---|
| 54 | `db/roshan_phase54_source_aware_financial_reversal.sql` | `20261103114242` | Not applied |
| 54B | `db/roshan_phase54b_payment_updated_at_compat.sql` | `20261103114612` | Not applied |
| 54C | `db/roshan_phase54c_branchless_receipt_integrity.sql` | `20261103115649` | Not applied |
| 55 | `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` | Candidate; PR #172 | Not applied |

As checked on 2026-11-03, production records 129 migrations and QA records 20. These counts do not establish schema parity; see `docs/SCHEMA_PARITY_AUDIT_2026-11-03.md` for the read-only catalog fingerprints and known function/ACL differences. Phase54/54B/54C are applied only in QA. Phase55 is not yet applied to either environment.

**Production safety:** no production Phase54/54B/54C/55 DDL is authorized until an encrypted backup and isolated restore are verified. Do not replay the redacted production migration `20261102232941`.
