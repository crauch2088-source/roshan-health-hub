# Roshan Health Hub — Master Plan and current execution status

**Execution source of truth.** Last refreshed: 2026-11-14. Repository: crauch2088-source/roshan-health-hub. This status block supersedes stale dated snapshots and historical phase notes below.

## Current verified orientation

- **Main baseline:** a9040601702972bdf144fc96b9658eebd5a6d31a.
- **Active work:** PR #250, Draft, branch fix/phase61c-atomic-dispense-role-boundary-20261114; last branch compare showed 24 commits ahead and 0 behind main. Recheck live PR/head before further changes.
- **Current code candidate:** Phase 61C atomic pharmacy-dispense role boundary. Canonical pharmacist remains allowed only with the required permission pair; legacy pharmacist is excluded because it has no active assignments and lacks the permission pair.
- **Exact-head verification recorded:** Phase 61 PostgreSQL 17 integration, full CI, and insurance workflow passed on the tested code head; authenticated clinical acceptance was intentionally skipped and remains open. No independent review is recorded. Do not infer approval from CI.
- **Hosted databases:** Production Supabase ref jewzonxplxhogqrnhosl; QA ref hopfohcnrtbiqjkgeukz. Last recorded read-only ledgers: Production 129 migrations (latest 20261102232941), QA 27 migrations (latest 20261113232719). Re-read the live ledger before any migration; these counts are a dated checkpoint, not a substitute for preflight.
- **Deployment:** canonical Vercel project roshan-health-hub, production alias https://roshan-health-hub.vercel.app/. Last verified READY deployment was on main SHA a9040601702972bdf144fc96b9658eebd5a6d31a; recheck before any release.
- **Data classification and authority:** all currently existing QA and Production rows are synthetic/test data; the owner has explicitly authorized resetting those existing rows and rebuilding affected schema objects under Constitution Section X. This authorization is durable; do not ask again. It does not authorize creating new synthetic clinical/business transactions in Production. Preserve project identity, Auth recovery, credentials, secrets, environment bindings and platform configuration.
- **Backup status:** an encrypted PostgreSQL archive was last verified by Drive metadata on 2026-11-14; it was not downloaded/decrypted in that session. The most recent recorded restore evidence is older than the current runner head. Do not call this a fresh current-main backup or complete platform backup; Storage bytes and Vault secrets were outside its scope.
- **Readiness reporting:** the last separately stated estimate was 62% engineering release-candidate completion and 15% operational readiness, with 17–30 focused engineering hours estimated at that time. Treat these as historical estimates and recompute from current evidence before repeating them.

## Execution order

1. Independently review PR #250 complete SQL diff and role/permission semantics; verify canonical and legacy role behavior, RLS/grants, idempotency, audit, inventory and billing invariants. No hosted migration until this review and QA plan pass.
2. Reconcile migration source/ledger history and baseline/replay evidence using live ledgers and docs/DB_MIGRATION_RECONCILIATION.md; never edit migration history to force parity.
3. Resolve high-priority open security/data-integrity work from live Issues/PRs, including patient search and branch/role boundaries. Re-read live issue state; old lists below are not authoritative.
4. Complete the 22 authenticated application screens and end-to-end module workflows using source-backed acceptance criteria; prioritize high-frequency reception, GP, lab, pharmacy and finance paths.
5. Close release blockers: independent security review, backup/restore rehearsal, role × operation × branch tests, authenticated clinical/staff acceptance in a safe environment, and controlled launch checklist.

## Status interpretation

- A task is complete only with source change (when required), observable acceptance evidence, and exact-candidate verification.
- Audits, plans, PR creation, green CI from another SHA, skipped tests, and successful deployment alone do not count as implementation or clinical acceptance.
- Current live facts must be refreshed from GitHub, Supabase, Vercel and the relevant workflow before any write.

---

# Roshan Health Hub — Master Plan to Production

**Single source of truth:** keep this plan updated until launch. Snapshot date: 2026-10-16. Repository: https://github.com/crauch2088-source/roshan-health-hub



## Live verification update — 2026-10-17 (session continuation)

- Read in required order from `main`: `README.md`, `docs/MASTER_PLAN.md`, `docs/DB_MIGRATION_RECONCILIATION.md`, and `docs/PLUGIN_TOOLING_MAP.md` before new work.
- `main` was `4d141ca0805265b8786a570105d4a4ba31a3fbcf` at session start. CodeQL and the 10 application/DB checks reported success on that SHA (11 check runs total); the subsequent doc-only inventory-header fix is `90c30ea600afc876afbe77b5d0c5df07f2e5fdc8`, whose checks were still in progress at the last poll.
- PRs #50–#54 remain open, draft, and unmerged. They are source-only proposals; none of their SQL was applied to production during this session. Each has dedicated PostgreSQL 17 regression evidence and reported full CI success in PR descriptions, but migration replay parity is still a blocker. Their bases are not all the same/current, so re-evaluate stacked dependencies before merge.
- Supabase project `jewzonxplxhogqrnhosl` is `ACTIVE_HEALTHY`, PostgreSQL 17.6, region `eu-west-1`. Live ledger contains 93 entries; latest is `20261016222009_roshan_phase25_current_app_profile_20261016`. Security Advisor now reports 22 authenticated-callable SECURITY DEFINER warnings, one `pg_trgm`-in-public-schema warning, and leaked-password protection warning (count/details to be triaged function-by-function); Performance Advisor reports 90 unused-index findings. These are review signals, not grounds for blanket revocation or index deletion.
- Vercel list access works at this check (the previous 403 scope issue was not reproduced). One linked project `roshan-health-hub` exists. Latest listed production deployment is READY on SHA `710f1232b8c972c0d1a5d9720c2cf8e03c8a96e7`; it does not match the latest documentation commit, and a Vercel check on the docs SHA reports build-rate-limit failure. Do not deploy manually or bypass the limit; verify alias/target before any future release.
- Corrected the stale migration reconciliation header from 79 to 93 and recorded the exact latest ledger version in commit `90c30ea600afc876afbe77b5d0c5df07f2e5fdc8`. This was documentation-only; no SQL was applied.
- Next: complete exact historical source mapping for all 93 entries; build and prove a clean replay in a disposable PostgreSQL/Supabase environment; only then resume PR #50–#54 merge decisions. If disposable Supabase branch/project incurs nonzero cost, obtain the quoted cost and explicit agreement before creating it.



## Migration reconciliation evidence — 2026-10-17

- The connected Supabase migration-history API returned all **93/93** applied versions and their exact stored SQL bodies. Compared those bodies with **105** tracked migration-source files (79 timestamped historical recovery files and 26 top-level `db/` SQL files): **92 normalized text matches, 1 intentionally redacted exception, 0 unmapped ledger entries**. The comparison ignores comments and whitespace and is not a SQL-parser semantic proof.
- Exception: `20260818191254_fix_patients_rls_and_admin_link` includes a one-time environment-specific Auth-to-app-user identity link. The public source is deliberately redacted to avoid publishing its email/user UUID; it cannot be replayed as-is. Do not restore those literals to public docs or repository history.
- The 93 migrations are not yet a proven clean bootstrap: earliest migrations assume pre-existing objects. A reviewed baseline schema and replay-only variant that omits the environment-specific identity UPDATE are still required.
- Supabase quoted development-branch cost is **US$0.01344/hour**. No branch was created because nonzero recurring cost requires explicit user agreement. Continue static/source work while waiting; do not use production as replay target.
- Vercel team/project listing now succeeds, so the old 403 was not reproduced. Project `roshan-health-hub` and canonical domain aliases are visible; latest production deployment reports READY. The newest source commit's Vercel check still points to the build-rate-limit page; do not bypass or force deployment.

## Security PR review update — 2026-10-17

- Current main snapshot at the latest manifest correction: `838e696d4d7a9d9ce4817e47c4fbcf95dc2b1e4c` (documentation-only). CI/CodeQL checks for later documentation commits must be re-queried; do not inherit a previous SHA’s green status.

- Per-version manifest: [docs/recovered-migrations/source-parity-report.json](recovered-migrations/source-parity-report.json) records 93 live migrations and SHA-256 hashes of normalized SQL; 92 match tracked source, one is intentionally redacted, zero are unmapped.
- Detailed source review: [docs/SECURITY_PR_REVIEW.md](SECURITY_PR_REVIEW.md). PR #50 needs a parent-changing UPDATE regression; #51 needs null-patient/visit linkage to fail closed, reliable fixture postconditions, and helper grant assertions; #52 needs equivalent null-linkage coverage, super-admin cross-branch DELETE verification, and parent-changing UPDATE tests; #53 needs parent-reassignment UPDATE tests; #54 remains blocked by full replay and exhaustive role × operation × RPC validation.
- Read-only schema/function inspection confirmed nullable patient/visit columns for followups, queue tickets, patient discounts, and procedure orders. Do not treat this as a demonstrated cross-branch exploit, but resolve the linkage-integrity gap before merging.
- Supabase branch cost quote is US$0.01344/hour. No branch was created; nonzero recurring cost needs explicit user agreement. Continue independent source work while replay environment is blocked.



## Live authorization-surface baseline — 2026-10-17

Read-only inspection of the connected production project found:

- All 56/56 public base tables have RLS enabled, and none of those tables is missing all RLS policies. This is only a configuration baseline; it does not prove each policy is correct.
- `anon` has no `USAGE` on schema `private`, while `authenticated` does. A few private `SECURITY DEFINER` helpers show `anon EXECUTE` ACLs, but the missing schema `USAGE` blocks direct schema access; review these as defense-in-depth cleanup candidates, not a demonstrated exposed endpoint.
- Security Advisor currently reports 22 public `SECURITY DEFINER` functions callable by `authenticated`, one `pg_trgm` extension-in-public-schema warning, and disabled leaked-password protection. Review each RPC's authorization, branch checks, grants, and fixed `search_path`; do not revoke all RPCs wholesale.
- Performance Advisor reports 90 unused-index findings. Do not drop indexes based on this signal alone.
- The live grants inventory still shows `authenticated` DML grants on many public objects. RLS remains the row filter, but this makes the full role × object × operation matrix and PR #54's focused finance revocations important. No production grants or policies were changed by this audit.

## Operating rules — current

- Follow .specify/memory/constitution.md for durable safety, clinical, privacy, production and data-reset authority.
- Follow AGENTS.md for execution mechanics; do not duplicate or override it here.
- The owner confirms all existing rows in QA and Production are synthetic/test data and authorizes resetting those existing rows and rebuilding affected schema objects under the Constitution safeguards. Do not ask for this confirmation again.
- This does not authorize creating new synthetic patient, clinical, pharmacy, laboratory, inventory, or financial transactions in Production. Use disposable PostgreSQL or QA for tests.
- Production changes may proceed under standing delegated authority only after exact-target preflight, complete diff review, exact-head tests, migration provenance/recovery, least-privilege/RLS review, zero-cost checks, and safe post-change verification. Stop if scope, backup/recovery, or data classification is uncertain.
- Never invent clinical policy. Clinical protocols and medication decision-support require explicit clinician-approved specifications.
- A skipped check is not a pass. CI/deployment is not clinical acceptance. Keep engineering release-candidate completion separate from real-world operational readiness.
- Old phase checklists and dated entries below are historical evidence unless revalidated against current source, tests, and live read-only state.

## Phases and exit criteria

### 0. Baseline and ownership — IN PROGRESS
- [x] Confirmed `main` SHA `a64f804679aeaae7299b034176f2265ac1806db0` and successful GitHub Actions CI run #38649354331: install/lockfile, dependency security audit, patched TanStack versions, guard tests, typecheck, lint, and build passed.
- [x] Confirmed PR #5 was superseded by redaction code already present in `main`; closed it without merging. PR #9 remains a draft/open plan PR; its CI passed, but its base is stale.
- [x] Consolidated Vercel to the single project `roshan-health-hub`; removed duplicate `roshan-health-hub-hjfy`; verified only one matching project remains. Both projects’ Node setting had been aligned to `22.x` before deletion. Canonical verified domain is `roshan-health-hub.vercel.app`.
- [ ] Perform authenticated live smoke tests for login, role gates, patient lookup, queue, and server-rendered routes. Vercel production deployment for billing merge SHA `a4e53787bed97f9f2d34038641a2a839b12c01ba` is READY; browser/login tests remain pending because no browser automation connection is active and no credentials were supplied.
- [x] Verified PostHog `Default project` is connected but has ingested no events; `package.json` has no PostHog SDK dependency, so app instrumentation is not wired. Privacy defaults were tightened on 2026-10-16: IP anonymization enabled, console-log capture disabled, session recordings remain disabled, and project timezone set to `Africa/Khartoum`. Do not add instrumentation until event payloads and clinical-screen exclusions are reviewed.
- [x] Confirmed Supabase target `jewzonxplxhogqrnhosl` is healthy on PostgreSQL 17.6 and 56/56 public tables have RLS enabled. Live migration ledger has 88 entries, latest `20261016183152_roshan_phase16_billing_idempotency`; 79 historical rows remain in the original inventory plus 9 later tracked migrations. [ ] Reconcile historical SQL artifacts/replayability; do not replay recovered SQL without source and rollback validation.
**Exit:** pending authenticated runtime smoke tests, privacy review, and migration-history parity.

### 1. Security, privacy, and repository hygiene
- [ ] Audit current files/history for exposed credentials; report paths/types, never values. Rotate/revoke any real exposed credential before history rewriting.
- [x] Read-only scan of current main for common Supabase/service-role/access-token/database-URL patterns found no hard-coded credential assignment. `src/lib/supabase-admin.ts` reads `SUPABASE_SECRET_KEY` / legacy `SUPABASE_SERVICE_ROLE_KEY` only from `process.env`; `.npmrc` contains only the public npm registry, and root environment files are `.env.example` only. This does not inspect every historical commit or prove the absence of all secret formats; history exposure remains unverified.
- [x] Enabled GitHub secret scanning and push protection on the public repository (2026-10-16); verified both settings enabled and the open-alert query returned zero alerts. This does not prove historical secret exposure is absent.
- [x] Configured GitHub CodeQL default setup for JavaScript/TypeScript using the default query suite and GitHub-hosted runner. Initial setup workflow #38969319514 was still in progress at the last check; code-scanning alert API reports no results because a scan has not completed yet.
- [ ] Enable Dependabot vulnerability alerts/security updates. The repository currently reports these disabled; the connected tool surface did not expose a supported toggle, so do not mark this complete.
- [ ] Decide on main-branch protection. No branch rules are currently active; avoid introducing required-check gates until they are aligned with the user's direct-main workflow.
- [x] Initial read-only review of all 15 authenticated-callable SECURITY DEFINER RPCs: no anon EXECUTE, empty `search_path`, and internal permission checks observed. [ ] Finish function-by-function adversarial tests for cross-branch IDs, invalid financial inputs, and branchless super-admin inventory/cashbox paths.
- [ ] Insurance financial integrity remains incomplete and implementation is paused at the user's request. PR #13 remains unapplied; do not resume insurance-specific changes until the user asks.
- [ ] Review RLS policies/grants for identity, patient, clinical, lab, pharmacy, inventory, finance, and insurance tables.
- [ ] Verify historical environment-file exposure and enable secret scanning/push protection if available. Tracked in [Issue #25](https://github.com/crauch2088-source/roshan-health-hub/issues/25); current `main` has `.env.example` only, while the historical leak status remains unverified.
- [x] Fix prescription header/items non-atomic save: PR #22 merged as `18c377dd480791332e4c4369891310587c30036f` and deployed as part of billing release commit `a4e53787bed97f9f2d34038641a2a839b12c01ba`; RPC installed under `20261016172209`, simulated-auth DB smoke verified one item and server-derived catalog price, and no patient/visit/prescription/audit test rows remain. Authenticated browser/login smoke remains pending. The prior branch-data gate was resolved by the user-authorized reset: patient/visit rows are empty, non-super-admin staff are assigned to ROS-MAIN, and unopened MAIN is inactive.
- [x] PR #22 for atomic prescription creation: merged; all 9 PR checks and 4 main CI jobs passed. The code is included in production deployment `a4e53787bed97f9f2d34038641a2a839b12c01ba`; authenticated browser smoke remains pending.
- [ ] Fix patient snapshot outstanding balance completeness/error states: source review found a 1,000-invoice cap, missing `total_amount` fallback, and query errors that render like zero values. Tracked in [Issue #18](https://github.com/crauch2088-source/roshan-health-hub/issues/18).
- [x] Fix invoice header/items non-atomic writes and server-side amount validation. PR #23 merged as `a4e53787bed97f9f2d34038641a2a839b12c01ba`; five SQL migrations installed; all 11 PR checks and 7 main CI jobs passed. Live simulated-auth smoke verified consultation+lab consolidation, idempotent retries, and an explicit secondary invoice; no test rows remain. Browser/UI smoke remains pending.
- [x] Reviewed and merged PR #23 for atomic invoice creation and server-side financial invariants. Default is one itemized primary invoice per visit; secondary invoices require an explicit choice. Phase16 idempotency is installed as `20261016183152`; phase17 legacy-dispense revocation remains deferred until authenticated UI smoke passes.
- [x] PR #23 follow-up: durable request-key wrappers for laboratory orders and manual billing are installed and merged; request-payload fingerprint checks and PostgreSQL retry tests passed. The PR is no longer draft/unmerged; see execution batch H for the five applied migrations and live smoke evidence.
- [ ] Add automated unauthenticated, wrong-role, cross-branch, and forbidden-write tests.
**Exit:** no unresolved critical/high-risk access-control issue; repeatable checks and evidence.

### 2. Runtime and CI reproducibility
- [x] Align Node version in package.json, CI, lockfile, and the retained Vercel project at `22.x`.
- [x] Run guard tests, typecheck, lint, production build, and dependency/security checks on frozen main candidate `3166f0bef5b734dad541516fb37fa003accfed2f`; GitHub Actions run [#38932545934](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38932545934) passed all four jobs.
- [ ] Verify SSR log redaction with synthetic tokens, cookies, UUIDs, emails, and query strings.
- [ ] Resolve lint/format debt narrowly; avoid unrelated sweeping rewrites.
**Exit:** reproducible green checks and documented deployment target.

### 3. Database and migrations
- [ ] Compare the 88-entry applied database migration ledger to repo SQL artifacts. The five billing migrations and four earlier tracked migrations are recorded, but the 79 historical entries still need exact source mapping and replayability review; no timestamped `supabase/migrations` directory exists on `main`.
- [ ] Determine whether `medicines` / `medicines_2` are active/legacy before any change.
- [ ] Verify FK/unique constraints, soft-delete behavior, audit relationships, pagination, and indexes.
- [ ] Test broader candidate migrations on a confirmed disposable dev branch/database. The five billing migrations passed isolated PostgreSQL 17 integration tests and a rollback-only live-schema/behavior dry run before application; no disposable Supabase branch exists, so broader RLS/finance candidates still need isolated validation.
**Exit:** reviewed schema map, migration parity, recoverability; no unexplained drift.

### 4. Clinical workflows
- [ ] Test registration → duplicate detection/MRN → branch assignment → queue → visit.
- [ ] Test consultation, vitals, ICD-10 diagnosis, notes, prescriptions, referrals, follow-up.
- [ ] Test lab order → sample → processing → result entry/verification → clinician visibility.
- [ ] Test role-specific edit permissions, audit history, retries, double-submit, and network failure.
**Exit:** synthetic end-to-end clinical workflow matrix passes.

### 5. Pharmacy, inventory, and finance

#### Billing decision — 2026-10-16 (authoritative)
- Default to one fully itemized primary invoice per visit/clinical transaction, combining consultation, laboratory tests, dispensed medicines, procedures, and other billable items where the relevant workflow permits it.
- Keep explicit support for separate/secondary invoices when required; do not enforce an absolute one-invoice-per-visit rule.
- Preserve patient, visit, branch, item, payment, discount, adjustment, cancellation, and audit relationships. Recompute totals transactionally and never reduce the invoice net below already recorded payments.
- Prevent duplicate charges and duplicate clinical/service records when a client retries after a timeout. Atomicity alone is not idempotency: RPCs need a durable request key or an equivalent verified duplicate guard.
- PR #23 proposes the primary/secondary invoice model and atomic consultation/lab/pharmacy/manual billing paths. Phase16 adds durable request-key idempotency for lab and manual billing, with PostgreSQL retry tests for default and explicit secondary invoice flows plus rejection of changed payloads under a reused key. CI passed on head `a5edda2a79ad393c4b0022912c45a3ccd063749b` in run [#38870998242](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38870998242); remaining gates are migration-source reconciliation, isolated Supabase validation, and authenticated workflow smoke tests.
- Keep all proposed SQL unapplied until canonical migration-source reconciliation, isolated PostgreSQL/Supabase validation, and authenticated workflow smoke tests are complete. Do not apply recovered SQL to production.

- [ ] Test receiving batches, expiry, FEFO dispensing, stock movements/returns, and expired/negative stock prevention.
- [ ] Test concurrency/idempotency for dispensing, invoices, payments, cashbox entries/reversals, supplier bills/payments, and expenses.
- [ ] Insurance claims UI/RPC mismatch fix merged as PR #12; its client-validation UI is now included in the READY production deployment `a4e537...`. Authenticated smoke is pending; server-side insurance integrity remains incomplete and paused at the user's request.
- [ ] Reconcile ledger totals and stock movement history; test branch isolation and audit trail.
- [ ] Verify exact dashboard counts and pagination for large datasets.
**Exit:** no unexplained stock or ledger discrepancy across end-to-end and concurrency tests.

### 6. Mobile UI and bilingual UX
- [ ] Test 320–430px widths, Arabic RTL/English LTR, nested routes, touch targets, keyboard focus, dialogs, and role-aware navigation.
- [ ] Verify server/database permissions independently of UI visibility.
- [ ] Test loading/empty/error states, search, pagination, date/currency formatting, and recoverable failures.
**Exit:** signed-off role/language/viewport matrix with no launch-blocking UX defects.

### 7. Observability and privacy
- [ ] Confirm PostHog project/retention/access controls before enabling analytics.
- [ ] Never send names, phone numbers, MRNs, diagnoses, notes, or other patient-identifying/clinical details to analytics.
- [ ] Use only minimal aggregate events for route errors, workflow completion/failure, latency, and release version.
- [ ] Document uptime/error monitoring, alert owner, and incident response.
**Exit:** operational visibility without patient-data leakage.

### 8. UAT and launch rehearsal
- [ ] Build synthetic test dataset and acceptance checklist for reception, GP, dentist, specialist, lab, pharmacy, admin, super admin.
- [ ] Rehearse registration → queue → consultation → lab/pharmacy → payment → closeout/report.
- [ ] Verify account lifecycle, password reset, session expiry, backup restore, printer/PDF/export, clinic services/prices, payment method, and Arabic content.
- [ ] Prepare rollback, downtime, and manual fallback procedures.
**Exit:** user acceptance and staff readiness signed off; restore rehearsal succeeds.

### 9. Release gate and controlled launch
- [ ] Freeze candidate SHA; review full diff, tests, RLS tests, dependency report, limitations, and migration plan.
- [ ] Verify backup/recovery point, environment configuration, domain/TLS, and rollback.
- [x] User explicitly authorized production SQL, merges, and deployment for this in-scope batch on 2026-10-16. This approval does not waive post-deployment verification or authorize unrelated destructive changes.
- [ ] Deploy in a controlled window; smoke-test auth/roles, patient, queue, visit, lab, pharmacy, payment, and reports using approved test workflow.
- [ ] Monitor redacted logs and errors; roll back if critical acceptance checks fail.
**Exit:** release report with deployed SHA, smoke-test evidence, monitoring status, and remaining non-blocking issues.

### 10. Stabilization
- [ ] Monitor first day/week for errors, performance, integrity, and user blockers.
- [ ] Fix critical issues via isolated changes and regression tests; verify backups and privacy-safe analytics.
**Exit:** stable service and agreed maintenance cadence.

## Immediate next actions — refreshed 2026-10-17

1. **Completed post-merge CI** for main commit `f08ad543cefa8e94aff4500d6361d71f4aa3060f`: CodeQL run [#39012087070](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39012087070) and application CI [#39012087462](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39012087462) both completed successfully; all 10 application jobs passed.
2. **Keep the production release gated.** PR #49 is merged, but its automatically created production deployment was canceled before completion because clinician review of pediatric safety wording, device/accessibility QA, and full synthetic-data E2E are still outstanding. Latest verified READY production SHA remains `1d23c39d15b3cd9399c81169830086694bcafc6`; do not describe the newly merged UI as production-live.
3. After the release gates are met and a new deployment is authorized by the release criteria, deploy current `main` and run authenticated production smoke tests for registration, role/branch access, visit/queue, consultation, lab order/result verification, prescription, dispensing, consolidated/separate invoices, payment, cashbox and reports. The saved TinyFish profile is available; its metadata still does not list the app under `signed_in_sites`, so validate authentication at run start.
4. Reconcile the **93-entry** Supabase migration ledger against archived `docs/recovered-migrations/`, `db/*.sql`, and applied later phases. There is still no canonical timestamped `supabase/migrations/` sequence. Keep recovered historical SQL quarantined; do not replay it or apply unrelated candidate migrations until semantic mapping, clean PostgreSQL 17 replay, rollback, and Supabase-specific checks pass.
5. Continue independent authorization tests for all 22 authenticated-callable public SECURITY DEFINER overloads, including cross-branch IDs, branchless super-admin cases, invalid financial values, retries and forbidden writes. Current read-only snapshot: 56/56 public tables have RLS, 44 public SECURITY DEFINER functions, zero anon-callable SECURITY DEFINER functions, and all 44 have a function-level `search_path` setting. This is not proof of correct function logic.
6. Keep the live stock discrepancy untouched until the legacy-versus-batch source of truth and branch ownership are established. Do not copy aggregate quantities or invent stock batches.
7. Keep insurance-specific implementation paused until invoice-line linkage and insurer/patient split rules are defined; do not merge/apply insurance-related draft SQL just because fixture CI passes.
8. Keep PR #29 (pharmacy receiving) and PR #34 (clinical child-row branch isolation, currently coupled to an insurance prior-authorization policy) in draft until their migration/live-schema and scope gates are satisfied.
9. Review Supabase warnings for `pg_trgm` in `public`, 22 authenticated-callable SECURITY DEFINER functions, and disabled leaked-password protection. Do not blindly revoke intentional RPCs or move the extension until dependencies and client compatibility are proven.
10. Reconcile production operational-row baseline before any cleanup: latest read-only counts were 1 soft-deleted patient, 7 soft-deleted visits, zero queue tickets/invoices/payments, and 16 audit rows. No data was deleted in this batch.

- Historical: PR #14 remains only for comparison and must not be merged.
- Historical: the old PR #9/PR #24 plan references are superseded by the current master-plan state and the migration inventory under review.

## Historical execution log

The chronological execution log and the previous pre-plan notes have been moved without deletion to docs/archive/MASTER_PLAN_HISTORY.md. Consult that archive only when a specific historical decision or evidence item is needed. It is not an active task list.
