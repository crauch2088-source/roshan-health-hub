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

## Operating rules
- Execute work directly with connected tools. Request any missing integration/permission explicitly.
- If a specific step repeatedly fails despite reasonable diagnosis, stop looping, ask the user to use Claude for that step, then resume the remaining plan.
- Standing user authorization (2026-10-16): maximize concrete progress using Composio and any available connected tools; search current web guidance when useful; continue across multiple independent workstreams and batches; merge any PR whose dependencies, code, CI, and risk gates are satisfied; execute SQL needed for the project without asking for separate permission each time. The user states current stored patient/financial data is disposable test data and may be deleted if a specific task requires it.
- This authorization removes the need to ask again for routine in-scope merges or SQL, but does not justify unbounded deletion, unnecessary data loss, exposing secrets, or bypassing correctness checks. Verify the exact project/environment and affected objects; prefer tracked migrations, isolated validation, idempotent SQL, least privilege, and rollback plans. If production is the only connected database, use narrow, reversible changes and verify immediately afterward.
- Never expose or commit secrets, credentials, tokens, or patient-identifying data.
- Do not stop at reporting a blocker: continue useful independent workstreams while diagnosing it, and report verified results, blocked gates, and the checklist-based completion percentage. Do not count audits as implementation completion.
- Treat security advisor warnings as leads, not proof of exploitability. Preserve indexes unless workload evidence supports removal.

## Verified starting point
- Recent repository commits indicate PR #10 (SSR log redaction) and #11 (cashbox reversal concurrency) merged; merge commits include `533dcb5` and `4ae13ef`.
- PR #8 (shell redesign, page patterns, dashboard data accuracy) subsequently merged at `a64f804679aeaae7299b034176f2265ac1806db0`. Merge conflict resolution in `3667bafd` combined `test:guard` lists.
- PR #9 is CLOSED as superseded by PR #24, the refreshed canonical plan/migration-inventory draft. PR #24 remains OPEN + DRAFT on `audit/roshan-health-hub-hardening-plan-v2`, based on current `main`; it is documentation-only and must not be treated as a release. PR #5 was CLOSED as superseded: current `main` already contains SSR redaction in `src/lib/redact.ts`, `src/lib/error-capture.ts`, and `tests/ssr-log-redaction.test.ts`.
- Branches seen: `main`, `audit/roshan-health-hub-hardening-plan-v2`, `feat/nav-consistency-ux-pass`, `feat/responsive-shell-lab-ui`, `feat/shell-redesign`, `fix/cashbox-reversal-concurrency`, `fix/ssr-error-logging-redaction`, `fix/ssr-log-object-redaction`, `fix/vercel-node22-runtime`, `pr8-visual-artifacts`.
- Main `package.json` declares Node `22.x` and has `test:guard`, `typecheck`, `lint`, and `build` scripts.
- Vercel is consolidated to one project: `roshan-health-hub` (`prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`), linked to `crauch2088-source/roshan-health-hub`, canonical verified domain `roshan-health-hub.vercel.app`, Node `22.x`. Duplicate project `roshan-health-hub-hjfy` was deleted and verified absent. The current production alias is READY on deployment SHA `1d23c39d15b3cd9399c81169830086694bcafc6`; source comparison confirms it contains the Phase 22 clinic-local queue-date UI fix. Main has since advanced with Phase 23 database/tests and documentation.
- Connected Supabase project `jewzonxplxhogqrnhosl` is named “Project Name: Roshan Production”, ACTIVE_HEALTHY, PostgreSQL 17.6, region eu-west-1. Applied migration ledger now extends through `20261016215806_roshan_phase23_legacy_queue_allocator_20261016` (91 entries; historical replay parity remains unresolved).
- Supabase security advisor reports `pg_trgm` in `public`, 15 SECURITY DEFINER functions executable by `authenticated`, and leaked-password protection disabled. Read-only review found all 56 public tables have RLS enabled; no table grants `anon` SELECT/INSERT in the sampled inventory; no `anon` EXECUTE privilege on public SECURITY DEFINER functions; the 15 callable authenticated functions each contain an app permission check and have `search_path` set to empty. Branch checks are present in the branch-sensitive RPCs inspected. The two `stock_movements` policies target `public` but both enforce app permission and branch access, and neither is unconditional. Review the [Supabase leaked-password protection guidance](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection); the Auth setting was not changed. This is a positive initial review, not yet a full adversarial authorization test.
- Current Supabase target `jewzonxplxhogqrnhosl` is `Roshan Production`, `ACTIVE_HEALTHY`, PostgreSQL 17.6, region `eu-west-1`. The live migration ledger now has 93 entries through `20261016222009_roshan_phase25_current_app_profile_20261016`. The repository has the Phase 24 and Phase 25 migration sources under `db/` plus their PostgreSQL regression fixtures, but still has no timestamped `supabase/migrations/` canonical sequence. The original 79-row historical inventory and the nine-entry billing rollout have been supplemented by Phase 21 privileges and Phases 22–25; content-level parity across all 93 ledger entries remains unverified. Historical SQL/source mapping remains a release gate, so do not apply draft billing/finance/pharmacy migrations until this is reconciled. All 56 public tables have RLS enabled. The performance advisor snapshot reported 127 unused-index findings on 2026-10-16; do not drop indexes based on this signal alone. Schema inventory includes both `medicines` and `medicines_2`; verify usage before changing.
- GitHub native file update returned 403 “Resource not accessible by integration”; use the active Composio GitHub connection for repo writes.

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

## Change log
- 2026-10-15: Initialized from connected-tool inspection. No database writes, destructive changes, merges, or deployments performed.
- 2026-10-15: Vercel consolidation completed via Composio: deleted duplicate `roshan-health-hub-hjfy`, verified only `roshan-health-hub` remains, and retained canonical domain `roshan-health-hub.vercel.app`.
- 2026-10-15: Closed PR #5 as superseded after confirming the redaction implementation and tests are already in `main`; no merge occurred.
- 2026-10-15: Read-only Supabase audit: 56/56 public tables have RLS enabled; no anon SELECT/INSERT grants in the reviewed inventory and no anon EXECUTE on public SECURITY DEFINER functions. All 15 authenticated-callable SECURITY DEFINER functions inspected have empty `search_path` and app-level permission checks. Migration head is `20261014164131_roshan_cashbox_reversal_concurrency` (79 migrations); repository migration parity remains unresolved. No Supabase writes.
- 2026-10-15: Confirmed insurance claim UI sent `invoiceId: null` despite the database RPC requiring an invoice. Added regression tests first (red on missing helper), then implemented invoice picker + validation in PR #12. CI run #38655085321 passed install, security audit, guard tests, typecheck, lint, and build on `a2cd2dd752d5577506674284db239865d1fc5459`; Vercel preview is READY. Static review found no blocking defect in the changed files; no review submissions exist yet. PR remains draft/open pending authenticated workflow smoke test; no merge, production deploy, or database write.
- 2026-10-15: Live HTTP smoke checks via Vercel access returned 200 for the canonical production root, PR #12 preview root, and preview `/insurance` route. The route response contained the application shell only and no server-rendered patient data. This is reachability/SSR-shell evidence only; it does not substitute for authenticated login, UI interaction, or role/branch authorization tests.
- 2026-10-15: Read-only data integrity review found zero active insurance claims, so historical claim-item reconciliation is not yet meaningful. The current `create_insurance_claim` definition checks for negative item amounts but does not enforce that covered + patient amounts equal gross; record this as a DB-side invariant gap to test and patch through a reviewed migration, not a production hotfix.
- 2026-10-15: Read-only pharmacy stock snapshot: all 9 active medicine records have legacy `medicines.stock_quantity` values different from summed remaining non-deleted inventory batches. Eight have zero batch stock; ceftriaxone has legacy 1,994 vs batch remaining 498. This is a reconciliation warning, not proof of corruption because the legacy and batch stock models may be intentionally separate. No quantity changes or database writes performed.
- 2026-10-15: At the time of the 2026-10-15 entry, opened draft PR #13 with an additive SQL patch and contract test. The candidate was later merged as `5229ef8` after PostgreSQL 17 behavioral tests; it remains unapplied to production pending migration-history parity and business-rule gates.
- 2026-10-15: Tightened PR #13 in commit [`c4f3b88`](https://github.com/crauch2088-source/roshan-health-hub/commit/c4f3b884df658985a6109fb39d3a505b2b2f727e): requires active, date-valid insurance; invoice/patient match; allowed service type; non-empty description; JSON-number amounts that are finite, positive/nonnegative as appropriate, max two decimal places, and exact covered + patient = gross reconciliation. Existing permission gate, branch guard, empty search_path, and anon EXECUTE restriction are retained in the replacement definition. CI run [#38761681302](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38761681302) passed security audit, 63 guard tests, typecheck, lint, and build. This is application CI only: it does not execute the SQL contract test or prove the function works in PostgreSQL. PR #13 remains draft/open and unapplied; disposable/staging behavioral tests and migration-history reconciliation remain prerequisites.

## Migration reconciliation update — 2026-10-15
- Added [`docs/MIGRATION_RECONCILIATION.md`](MIGRATION_RECONCILIATION.md) documenting the verified 79-entry production ledger, absence of `supabase/` in the repository, current legacy `db/*.sql` artifact layout, and a safe no-replay adoption plan.
- This is a verified mismatch in repository organization, **not proof that every migration's SQL is missing**. Exact source recovery and content-level parity comparison are still required.
- Read-only query against `supabase_migrations.schema_migrations` confirmed all 79 rows contain non-empty `statements` (one statement per row; approximately 247,724 SQL characters) and all rows have a name. This provides an exact-source recovery path. Do not copy SQL into the public repository until checking hard-coded data/environment assumptions; do not execute the recovered SQL. Repository mapping, clean replay, and live-schema parity remain unverified.
- Broad replay of historical SQL remains blocked until canonical migration history or a reviewed schema-baseline strategy is validated in isolation. Narrow new migrations were applied only after exact target/schema review, integration tests, rollback preparation, and postcondition checks; no historical archive was replayed.
- Next action: continue mapping the recovered SQL source for all 79 applied migration versions against repository candidates, record semantic parity/mismatch and function/privilege/policy evolution, then test the canonical sequence against disposable PostgreSQL 17 and isolated Supabase behavior before any production change.
- Added [`docs/APPLIED_MIGRATION_INVENTORY.md`](APPLIED_MIGRATION_INVENTORY.md) with all 79 exact version/name pairs read from the ledger. Current mapping status across all 79 ledger rows: 5 exact statement/source matches, 31 partial candidate mappings, and 43 unresolved canonical-source mappings. All ledger rows have a documented status, but the 43 unresolved mappings mean the checked-in SQL is not yet a complete reconstruction of production. This is a partial semantic audit, not full source parity; no production writes were made.

## UX, workflow, and clinical-logic redesign — 2026-10-15
- Added [`docs/UX_AND_WORKFLOW_REDESIGN_PLAN.md`](UX_AND_WORKFLOW_REDESIGN_PLAN.md): evidence-informed full-system redesign program covering navigation, screens, dialogs/drawers, automation, clinical workflows, prescribing safeguards, measurement, and phased delivery.
- Added [`docs/UX_AUDIT_REGISTER.md`](UX_AUDIT_REGISTER.md): a separate register item for each discovered route and shared overlay, with provisional risk priorities and acceptance criteria. Items are **Not started** until reviewed; the inventory is not presented as completed UX research.
- Research sources include AHRQ clinical decision support and workflow redesign, ONC 2025 SAFER Guides (including CPOE, patient identity, test follow-up), WHO Medication Without Harm (2024 policy brief), HL7 FHIR MedicationRequest/CDS Hooks, W3C WCAG 2.2 mobile guidance, and GOV.UK form-error patterns. Links and the design implications are recorded in the UX plan.
- Medication decision support will be source-versioned and clinically reviewed; dose calculators must expose inputs/units/calculations/caps and refuse unsupported recommendations. No unverified drug regimens will be auto-populated into production.
- Figma account check indicates the connected seat is **View**; editable Figma work may require an Editor seat. No Figma file was created or changed. Repository planning and research proceeded without assuming write access.
- Next: recover/match the 79 migration SQL sources as already documented, while beginning a code-backed audit of the P0 surfaces (patient identity/context, consultation/prescribing, lab results, pharmacy/inventory, permissions and dialog behavior). No production data or schema was changed by this planning work.

## First code-backed P0 UX/workflow review — 2026-10-15
- Added [`docs/UX_AUDIT_FINDINGS_P0.md`](UX_AUDIT_FINDINGS_P0.md) with source-backed findings from patient chart, patient picker, visits, pharmacy dispensing, lab result handling, and shared dialogs.
- Initial confirmed risk areas: lab result writes/status transitions are split across client requests and some status-update errors are not checked; visit + invoice + invoice-item creation is split across client requests; patient chart history sections have inconsistent explicit limits; pharmacy queue is capped at 200 and periodically refreshes.
- Important positive foundations were also recorded: pharmacy dispensing calls an atomic FEFO-aware database RPC; the patient picker includes MRN/phone disambiguation and a duplicate-patient hint; the shared dialog uses Radix primitives and responsive sizing. Findings explicitly separate confirmed code behavior from risks needing runtime/schema verification.
- Updated the audit register to `Mapped` for the six source surfaces reviewed so far; this does not mean the screens have passed runtime, accessibility, or user-task validation.

- Extended [`docs/UX_AUDIT_FINDINGS_P0.md`](UX_AUDIT_FINDINGS_P0.md) with F-009, a source-backed review of prescription authoring: generic global dose/frequency/duration choices, unitless dose options, missing patient-specific safety context in the tab, a 500-item catalog cap, and separate prescription-header/item writes.
- Added prescription authoring as a distinct P0 audit item in the register. This is a confirmed UI-design gap, not authorization to inject unreviewed dosing rules; clinical regimens require an approved source and named reviewer.

## First implemented prescription UX fix — 2026-10-15
- Draft [PR #15](https://github.com/crauch2088-source/roshan-health-hub/pull/15) is open on `fix/prescription-search-and-reset`.
- It replaces the fixed 500-row medicine catalog fetch with debounced server-side search over medicine name, generic name, brand, and strength; caps each response at 30 matches; adds searching/no-results/error states; closes results after selection; and clears dose/frequency/duration/instructions when switching medicine or adding an item.
- It normalizes recognized dosage-form values and the `oral` route token. This is a focused usability/safety improvement, **not** a clinical dosing engine and not a replacement for patient-specific, source-versioned prescribing support.
- Regression tests were added first for entry reset, regimen reset, search filter construction, short queries, and filter-grammar sanitization; the helper and UI implementation followed. CI run `38659955607` is still in progress at the latest check. PR remains draft, unmerged, and not deployed to production.
- CI is now green on latest head `9dbf499d7982cd85cde44f9416b1974859677e2e` (workflow run [#38660795041](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38660795041)): install/lockfile, dependency/TanStack security checks, guard tests, TypeScript, lint, and production build all passed. Vercel preview is READY at `https://roshan-health-ioginoiz3-roshan45.vercel.app/`. This is preview only; no merge or production deployment.
- Remaining known concerns in the same workflow: patient-specific age/weight/allergy context and medication-specific dosing rules are not yet integrated; prescription header and items are saved in separate requests; full authenticated smoke testing is pending.

- 2026-10-15: Continued PR #15 with a regression test for SQL LIKE wildcard characters in medicine search. The test initially failed on the unprotected behavior; the search helper now replaces user-supplied `%` and `_` wildcard characters before constructing the PostgREST filter. Latest head is `b480a0cab0bdb57c914b56865a48e9cd34ee7f93`; CI run [#38758003036](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38758003036) passed security audit, guard tests (64 total, all passing), TypeScript, lint, and production build. Vercel preview feedback check reports no unresolved feedback. PR #15 remains draft/open pending authenticated smoke tests and full review; no merge, production deployment, or database change.
- 2026-10-15: Follow-up on draft PR #12 after adding a tested claim-save readiness helper. The first run caught three Prettier errors in the helper; formatting was corrected in commit `0e9a2899b1fbb698ac7b42af078da8163b6c5b00`. Latest CI run [#38758668786](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38758668786) completed successfully: dependency/security audit, 60 guard tests, typecheck, lint, and production build all passed. Vercel preview status is success. PR #12 remains draft/open; this is not an authenticated smoke test and does not authorize merge or production deployment.
- 2026-10-15: PR #12's subsequent CI run [#38760288567](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38760288567) passed after adding regression tests for invalid, negative, non-finite, and unreconciled claim amounts. Formatting was fixed in commit [`175216a`](https://github.com/crauch2088-source/roshan-health-hub/commit/175216a4b929b23690f979a7d234899d3e25a71c). The Vercel preview is ready, but the PR remains draft/open and requires authenticated smoke tests and human review. Client validation remains defense-in-depth; database enforcement is handled separately by PR #13.
- 2026-10-15: Code review of PR #15 found prescription header and item rows are inserted in separate requests, risking orphaned pending prescriptions if item insertion fails. Opened [Issue #17](https://github.com/crauch2088-source/roshan-health-hub/issues/17); no records were modified.
- 2026-10-15: Draft PR #22 (`fix/prescription-atomicity`) replaces the two writes with `create_prescription_atomic`, derives the patient and author from the visit/current app user, locks catalog medicine rows during validation, derives catalog name/price server-side, enforces branch and permission checks, and adds disposable PostgreSQL 17 integration tests including injected-failure rollback. CI run [#38772712532](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38772712532) passed both integration and application jobs. SQL remains unapplied to any database.
- 2026-10-15: Follow-up review of PR #22 found medication quantity validation allowed positive fractional values. Commit [af33ba8](https://github.com/crauch2088-source/roshan-health-hub/commit/af33ba87014b4d76be36e84ff99838dac20432be) rejects fractional quantities; an initial integration run exposed a SQL test-block syntax error, fixed by splitting cases into independent `DO` blocks. Latest CI [#38777342323](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38777342323) passed PostgreSQL integration and application CI. No database was modified.
- 2026-10-15: Code review of `usePatientSnapshot` found outstanding balances silently sum at most 1,000 invoices and collapse query errors to zero-looking values. Opened [Issue #18](https://github.com/crauch2088-source/roshan-health-hub/issues/18); no patient or invoice data was modified.
- 2026-10-15: Draft PR #19 replaces the capped patient-invoice read with stable exact-count pagination, adds explicit unavailable states, and tests overpayments and invalid amounts. A follow-up review caught that invalid paid values still risked displaying as zero; the helper now returns `null` for untrustworthy monetary data. CI run [#38771066048](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38771066048) passed security audit, guard tests, typecheck, lint, and build. PR remains draft/open; authenticated smoke testing is still required.
- 2026-10-15: PR #14's isolated PostgreSQL 17 integration suite now also tests rejection of NaN prices and expired stock. The first CI run exposed malformed SQL block delimiters in the added tests; they were corrected, and run [#38770807064](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38770807064) passed the integration job, typecheck, lint, security audit, and build. Follow-up validation changes are queued for another run.
- 2026-10-15: Billing source review found invoice header and item rows are written separately and malformed amounts can be coerced or accepted. Opened [Issue #20](https://github.com/crauch2088-source/roshan-health-hub/issues/20); no financial records were modified.
- 2026-10-15: PR #21 (`fix/invoice-draft-validation`) passed CI run [#38772065614](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38772065614) but was closed as superseded by PR #23, which includes the client-side preflight and the required server-side transaction.
- 2026-10-15: Draft PR #23 (`fix/invoice-atomicity`) adds `create_invoice_atomic`, validates permission and patient branch, validates invoice item and discount inputs, derives the invoice number and totals server-side, and writes the header and items in one transaction. Disposable PostgreSQL 17 integration tests cover totals, invalid/unauthorized/cross-branch inputs, two-decimal precision, unsupported item types, and rollback. Latest CI run [#38774111264](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38774111264) passed both integration and application jobs; Vercel Preview is success. SQL remains unapplied to any database. The client helper and server RPC both enforce two-decimal money precision; review the final UI payload against the RPC contract before any merge.
- 2026-10-15: PR #13's insurance-claim SQL now has a PostgreSQL 17 behavioral integration job. Run [#38777187620](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38777187620) passed the integration and application jobs, covering the SQL contract behavior instead of only checking the function source. SQL remains unapplied to production.
- 2026-10-15: Recovered all 79 production migration ledger statement sets into a quarantine archive on draft [PR #26](https://github.com/crauch2088-source/roshan-health-hub/pull/26); the manifest records source versions, names, ledger MD5 and byte counts. CI [#38778700394](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38778700394) passed. A basic scan found no common private-key/token patterns, but manual follow-up identified an environment-specific admin email and UUID in one one-time identity-linking update. That public archive file was redacted and the branch rebuilt so the active PR branch history contains only the redacted version. A lexical operation scan found no `DROP TABLE`, `DELETE FROM`, or `ALTER TABLE ... DROP COLUMN`; the only `TRUNCATE` keyword is used to revoke a privilege, not truncate data. This does not prove semantic safety or replayability; no recovered SQL was executed and no production schema/data was changed.
- 2026-10-15: Read-only repository security review found secret scanning, push protection, and secret validity checks reported disabled in repository metadata. Current `main` has `.env.example` only, and the exact `.env` path has no GitHub path-history entries despite a cleanup note in a historical commit message. Opened [Issue #25](https://github.com/crauch2088-source/roshan-health-hub/issues/25) to verify history and enable protections where available; no secrets were reproduced and no settings changed. The available connected GitHub actions do not expose a supported setting-change operation for these repository protections, so the issue remains open rather than implying the settings were changed.
- 2026-10-15: Opened draft [PR #19](https://github.com/crauch2088-source/roshan-health-hub/pull/19) for Issue #18. It now uses the existing exact-count paginated read helper with stable invoice-ID ordering, falls back from missing/invalid `net_amount` to `total_amount`, clamps per-invoice overpayment at zero, and renders explicit unavailable/incomplete states instead of presenting query failures as zero. After fixing a missing locale binding found by CI, [run #38762569934](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38762569934) passed security audit, 59 guard tests, typecheck, lint, and build. Vercel Preview is pending verification on the latest commit; authenticated smoke test and human review remain outstanding. No production data was changed.
- 2026-10-15: Read-only migration-ledger integrity step completed. Queried all 79 production ledger rows for version/name, stored statement byte length, and MD5 checksum; validated all 79 version/name pairs against `docs/APPLIED_MIGRATION_INVENTORY.md`, then recorded the checksums in commit [`547e3a6`](https://github.com/crauch2088-source/roshan-health-hub/commit/547e3a65fafe83a76f70701d0f40a3087ebf31bb). These hashes cover the JSON representation of each stored `statements` value, not normalized SQL. This is a source-integrity baseline only: SQL bodies were not exported or executed, repository parity remains unverified, and production was read-only.


## Product logic, interface, and navigation improvement track — 2026-10-15

This is an explicit product-quality workstream, not merely visual polish. Deliver behavior changes through isolated reviewed PRs; preserve authorization and clinical/financial invariants.

### A. Business and workflow logic
- [ ] Map each role's real end-to-end tasks and permissions: reception, GP, dentist, specialist, lab, pharmacy, admin, super admin.
- [ ] Trace workflow transitions and invariants for registration/duplicate detection, queue, visit, consultation, lab orders/results, prescriptions, dispensing, invoices, payments, insurance claims, cashbox, and closeout.
- [x] Reconciled invoice-creation call sites: visits, consultation, laboratory billing, manual billing, and pharmacy dispensing now use the role-aware atomic RPCs from merged PR #23. Five billing migrations are installed and live simulated-auth tests passed; authenticated browser verification remains pending.
- [ ] Reconstruct the final visit/queue allocator from the recovered migration sequence and verify date-keyed concurrency, unique constraints, soft-delete/hard-delete behavior, timezone/date normalization, and whether any UI reserves a queue number in a separate RPC before inserting the visit.
- [ ] Compare effective RLS policies table by table after all applied migrations, accounting for PostgreSQL's permissive policy OR behavior; specifically reconcile `queue.create` client INSERT policy with trigger-generated queue-ticket ownership.
- [x] Added a true two-session cashbox reversal race test using the existing migration in a disposable PostgreSQL 17 service. The test waits until session A is visibly inside the controlled insert delay while holding the original-row lock, then starts session B. Exactly one call succeeded; one reversal row remained, the original was marked reversed, and amounts netted to zero. Full CI passed on head `c7a12408dcd154af65ba0726a59455436d5ea5af` in [run #38887494366](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38887494366).
- [ ] Review test-only draft [PR #36](https://github.com/crauch2088-source/roshan-health-hub/pull/36); it adds this concurrency proof to CI. Keep separate from production rollout until migration reconciliation and isolated Supabase validation are complete.
- [ ] Include `normalize_medicine_names()` and the applied `updated_at` columns in the canonical migration source, or update the UI/schema contract together; medicine creation currently relies on the deployed name-to-generic-name compatibility trigger.
- [x] Resolved the one-primary-invoice-per-visit invariant: default is one itemized primary invoice with consultation/lab/pharmacy lines appended atomically; explicit secondary invoices are supported when deliberately requested. Implemented and smoke-tested in PR #23.
- [ ] Identify duplicated calculations or client-trusted fields; keep authoritative financial, stock, and permission decisions server-side where appropriate.
- [ ] Specify behavior for retries, double-submit, concurrent edits, stale selections, partial network failure, inactive/deleted records, and recoverable rollback.
- [ ] Ensure failed or partial reads never look like zero, success, or an empty clinical history.
- [ ] Validate rules with synthetic fixtures and regression tests; do not use production patient records.

### B. Information architecture and navigation
- [ ] Audit all registered routes against navigation entries, route permissions, titles, breadcrumbs, back behavior, and direct-link access.
- [ ] Keep role-focused navigation consistent; hidden navigation is not an authorization control.
- [ ] Standardize active-route highlighting, nested-route behavior, breadcrumbs, global search/command palette, and return-to-context after save/cancel.
- [ ] Reduce unnecessary clicks in common tasks (patient lookup → queue/visit; visit → diagnosis/prescription/lab; invoice → payment/receipt) without bypassing validation.
- [ ] Check for dead ends, duplicate destinations, missing links, ambiguous labels, unsaved-form loss, and shell-only pages.

### C. Interface and mobile usability
- [ ] Review dashboards for accurate metrics, actionable next steps, and bounded/verified reads.
- [ ] Standardize tables, filters, search, pagination, forms, validation, dialogs, confirmations, and feedback.
- [ ] Test Arabic RTL and English LTR, 320–430px phone widths, tablet/desktop layouts, touch targets, keyboard focus, safe areas, and virtual keyboard behavior.
- [ ] Keep patient identity, branch, visit status, and financial totals clear at the point of action; prevent stale context crossing workflows.
- [ ] Preserve form data after recoverable errors and confirm destructive/irreversible actions.

### Owner decisions required before final billing integration
- **Invoice model — DECIDED 2026-10-15; owner reconfirmed 2026-10-16:** one detailed, itemized invoice per visit is the default. Consultation, each laboratory investigation, dispensed medicines, procedures, and other billable services must appear as distinct line items on that same invoice, with clear quantities, unit prices, line totals, subtotal, discount, payments, and remaining balance to simplify calculation and audit review. Separate invoices are supported only when deliberately selected for an operational reason; a standalone invoice without a visit must also be explicitly selected. Secondary invoices must be clearly distinguished from the primary invoice, and screens must resolve the primary invoice explicitly rather than selecting an arbitrary invoice for the visit. Prevent duplicate billing on retries, preserve payment history, and never silently rewrite a finalized/paid invoice; when appending is unsafe, require an explicit separate invoice or authorized correction flow. Reconcile the existing `uq_invoices_visit_id` index and validate the new primary/secondary discriminator before any database rollout.
- **Permission model:** should clinicians/reception be allowed to create consultation/lab invoices using their workflow permissions, or must all invoice creation require `billing.create`? The recovered migration sequence does restore `EXECUTE` to `authenticated`, but the numbering RPC itself checks `billing.create` and several clinical UI paths still call it directly. Confirm role grants and use role-specific RPCs and server-side validation rather than weakening RLS.

### D. Acceptance and release discipline
- [ ] Build a role × route × workflow × language × viewport acceptance matrix with synthetic users and records.
- [ ] Record each finding with severity, reproduction steps, expected/actual behavior, affected role/route, and regression coverage.
- [ ] Keep behavior fixes separate from visual refactors; run relevant tests, typecheck, lint, build, and review for each PR.
- [ ] Run authenticated preview tests for auth/RLS/branch behavior when a safe test account and isolated environment are available.
- [ ] Do not merge or deploy without explicit approval; the user explicitly authorized this batch's SQL, merges, and deployment on 2026-10-16. Continue to require explicit approval for unrelated or newly destructive changes.

### Initial evidence collected — 2026-10-15
- Read-only review of `src/config/nav.ts`, `src/lib/nav-active.ts`, `src/lib/nav-layout.ts`, `tests/nav-active.test.ts`, `tests/nav-permissions.test.ts`, `src/routes/_authenticated/route.tsx`, and the dashboard found a central navigation source, shared active-route matching, and tests that assert nav permissions equal route gates. These are useful guardrails, not proof of full role-by-role UX acceptance.
- Found a concrete dashboard label mismatch: the upcoming-appointments table displayed `appointment_time` while its column header said “Date”. Focused fix is in [draft PR #27](https://github.com/crauch2088-source/roshan-health-hub/pull/27), adding bilingual “Time/الوقت” and per-panel error states so failed list queries do not look like empty data. CI run [#38785517572](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38785517572) passed. Vercel Preview was blocked by the account's build-rate limit (`upgradeToPro/build-rate-limit`), so preview/browser smoke testing remains outstanding. No production data changed.
- The existing shell/navigation redesign (breadcrumbs, role-aware mobile navigation, command palette, account menu) remains a baseline only. Full role × route × workflow × language × viewport acceptance is still open.
- A code-backed shortcut audit found the dashboard keyboard shortcut omitted `HOME_ITEM` from its permission lookup and therefore did not fail closed. Draft PR [#28](https://github.com/crauch2088-source/roshan-health-hub/pull/28) centralizes permission lookup across Home and module routes, rejects unknown shortcuts, and adds regression tests; CI passed in [run #38792825286](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38792825286). Vercel Preview is blocked by the account build-rate limit, so authenticated preview testing remains outstanding. This was a navigation correctness issue; route gates and RLS remained the security boundary.
- Prescription workflow review found that the consultation tab still loaded only the first 500 medicines client-side, retained dose/frequency/duration when switching/adding medicines, and left a successful draft in place for accidental resubmission. Draft PR [#22](https://github.com/crauch2088-source/roshan-health-hub/pull/22) now includes debounced server-side search, clean regimen resets, safe catalog detachment when a medication name is edited, post-save draft clearing, and regression coverage. CI run [#38787425415](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38787425415) passed PostgreSQL integration, security audit, guard tests, typecheck, lint, and build on the latest head; Vercel Preview remains blocked by the account build-rate limit.
- Invoice workflow review found that a super-admin creating an invoice for a patient in another branch could have the invoice assigned to the super-admin's own branch instead of the patient's branch. Draft PR [#23](https://github.com/crauch2088-source/roshan-health-hub/pull/23) assigns invoices to the patient branch and tests that case. A further test-first review found that the consultation screen could select an arbitrary invoice when a deliberate secondary invoice existed; commit [58e1bd8](https://github.com/crauch2088-source/roshan-health-hub/commit/58e1bd8a0b7169e589b5423015f41af832889085) now filters the link to is_primary=true and includes a regression guard. CI run [#38867761531](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38867761531) passed atomic invoice integration, pharmacy dispense/invoice integration, consolidated visit invoice integration, security audit, guard tests, typecheck, lint, and build. The PR remains draft/unmerged; migration-history reconciliation and authenticated staging/preview smoke tests are still required before merge or database rollout.
- A further high-priority RPC mapping gap is documented for `20260911131456_deep_audit_branch_isolation_rpc_hardening`: the recovered payment RPCs include branch and overpayment checks absent from the candidate function bodies, and the recovered `fn_dispense_prescription` has no matching source in the likely checked-in SQL candidates. Treat this as an unresolved source/effective-behavior mapping issue until the final deployed definitions are traced.
- A high-priority branch-isolation mapping gap is also confirmed: recovered migration `20260911133255_enforce_branch_isolation_rls` creates `private.app_has_branch_access` and dynamically adds branch checks to RLS policies on 13 tables, but no exact helper/loop match was found in likely repository candidates. Equivalent per-table guards may exist elsewhere; verify effective policies before release. See `docs/MIGRATION_RECONCILIATION.md`; no production SQL was run.
- A high-impact concurrency mismatch is now confirmed in the migration ledger: recovered `20260911133229_harden_mrn_invoice_number_concurrency` replaces `next_mrn()` and `next_invoice_number()` with advisory-lock + max-suffix allocation, while the repository baseline still uses `COUNT(*) + 1` without locks. This is recorded in `docs/MIGRATION_RECONCILIATION.md`; verify live constraints and preserve the recovered behavior when canonicalizing. No production SQL was run.
- Further source comparisons confirmed that `20261011080253` hardens supplier-bill validation/branch assignment beyond the repository finance function, and `20261011080524` later restores null-branch compatibility for super-admin only while retaining those validations. `20261011080319` applies empty `search_path` to ten finance/pharmacy `SECURITY DEFINER` functions while the candidate still has `search_path=public` on payment RPCs; `20261011080434` adds branch checks to clinical-child RLS for five tables without an exact helper match in likely candidates. These remain release-blocking source/effective-policy reconciliation items; no SQL was run.
- Later RPC migrations add further guards that the baseline does not represent: `20261011074344` requires `billing.create`/`patients.create` and keeps lock-safe numbering; `20261011074437` requires `insurance.read` plus branch access for coverage calculation; and `20261011075101` hardens pharmacy batch receiving with permission, quantity, expiry, branch, and stock-update checks. The inventory records the unresolved source mappings, and PR #13's coverage patch now preserves the later permission/branch guards with regression coverage.
- A second high-priority privilege mapping gap is recorded for `20260911130812_restrict_security_definer_api_execution_20260911`: the recovered migration revokes `EXECUTE` from all public `SECURITY DEFINER` functions for `PUBLIC`/`anon`/`authenticated`, then grants an explicit 14-RPC allowlist. No equivalent global loop was found in the likely repository candidates. Compare the complete function-signature/grant set before any canonicalization; blind replay could either break access or leave excess access. No SQL was run.
- Security-migration reconciliation also remains incomplete: the recovered `20260911130749_harden_security_and_fk_indexes_20260911` contains a dynamic `SECURITY DEFINER` search-path loop, policy resets, and FK indexes that do not match the combined likely repository candidates statement-for-statement. This is classified as partial mapping—not proof of absent protections—until later/consolidated definitions are traced. See `docs/MIGRATION_RECONCILIATION.md`; no SQL was run.
- Insurance logic audit found a validity gap in the recovered `fn_calculate_insurance_coverage`: it checked policy status/expiry but not the policy start date or active plan/company status, and did not verify that the selected plan belongs to the company recorded on the policy. Draft [PR #13](https://github.com/crauch2088-source/roshan-health-hub/pull/13) now patches both the coverage calculator and claim-creation RPC, with isolated tests for future/expired policies, inactive plans/companies, company-plan mismatch, rule precedence, and permissions. CI run [#38789219521](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38789219521) passed both PostgreSQL integration suites and application checks on the latest coverage patch. Vercel Preview is blocked by the account build-rate limit. One business-rule decision remains open: claim creation validates arithmetic and policy/plan validity but still accepts the caller's covered/patient split; confirm whether manual overrides are intended, otherwise server-side recomputation against the policy rules is needed. Review and migration-history reconciliation remain release gates; nothing was applied to production.


## Billing model decision — confirmed by owner on 2026-10-16 (initially recorded 2026-10-15)

**Confirmed owner decision (2026-10-16):** a visit has one consolidated, fully itemized invoice by default. This is the required default product behavior, not an unresolved question. It should list every billable service as a separate line (consultation, each laboratory test, procedures, dispensed medicines, and other services), with quantity, unit price, line total, subtotal, discount, net total, payments, and outstanding balance visible for easy calculation and review. Multiple invoice documents are supported only as an explicit user choice/operational exception, not as a side effect of a lab or other workflow.

### Required implementation invariants
- A server-side atomic workflow must create the primary invoice or append line items to it; no UI path may independently insert invoice headers and items.
- Recalculate totals from persisted line items on the server. Preserve the payment ledger and prevent totals from falling below amounts already paid.
- If an invoice is finalized/paid or otherwise cannot safely accept new charges, do not silently mutate it. Require a deliberate separate-invoice path or an authorized correction process.
- Model the primary invoice separately from intentional secondary invoices so the current one-active-invoice-per-visit unique index can be replaced safely and legacy invoices remain identifiable.
- Use workflow-specific permission checks for visit, lab, pharmacy, and general billing flows. Do not weaken RLS or grant broad billing permissions merely to make clinical screens work.
- Add integration tests for consultation followed by multiple lab orders, appending to unpaid and partially paid invoices, explicit separate invoices, concurrency/idempotency, cross-branch access, invalid amounts, rollback, and preservation of paid totals.
- Keep proposed SQL under db/ until the 79-migration history/source reconciliation and staging validation are complete; do not apply it to production as part of this implementation pass.

### Current work tracking
- PR #23 (`fix/invoice-atomicity`), current head `a5edda2a79ad393c4b0022912c45a3ccd063749b`, includes consolidated invoice workflows and phase16 idempotency for lab and manual billing. CI run [#38870998242](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38870998242) passed all jobs, and Vercel status is success for the current preview deployment. Vercel fetch returned HTTP 200 for root and direct `/billing`, `/visits`, `/pharmacy`, and `/inventory` paths, each serving the application shell; this verifies reachability only, while authenticated role/branch smoke tests remain outstanding. SQL remains unapplied to production; migration reconciliation and isolated Supabase validation are still release gates.
- Existing index migration db/roshan_phase12_invoice_visit_unique.sql is already applied to production. Any replacement must be a reviewed follow-up migration; do not edit/replay the historical migration or alter the production index during this audit.

- **Read-only production permission/schema check (2026-10-15):** the deployed invoice table has `visit_id` but no primary/secondary discriminator yet; `uq_invoices_visit_id` is live. The deployed permission catalog shows `billing.create` assigned to admin, pharmacist, receptionist, and super_admin; `visits.create` includes doctor/receptionist; `lab.create` includes doctor/lab_tech. Therefore, clinical invoice creation must use narrowly scoped server RPCs authorized by the corresponding workflow permission, not call `next_invoice_number()` or receive broad `billing.create`. Only catalog/schema reads were run; no invoice/payment data or schema was changed.

## Read-only progress update — 2026-10-16 (latest audit)

- [x] Re-checked the live Supabase migration inventory: 88 rows now exist, from `20260818162003` through `20261016183152`. The original 79-row archive remains historical; four earlier tracked and five billing migrations were appended. This count does not establish full historical replayability.
- [x] Checked Supabase development branches: only the default `main` branch exists; there is **no disposable development branch** currently available for isolated validation. Do not create one until its cost/usage implications are known and accepted. No production SQL or data was changed during this check.
- [x] Read-only RBAC query confirms the current `pharmacist` role has `pharmacy.create/read/update` and `billing.create/read/update`; this supports the intended dispensing workflow in the draft, but does not replace authenticated end-to-end testing.
- [x] PR #23 was merged as `a4e53787bed97f9f2d34038641a2a839b12c01ba`; all 11 PR checks and 7 main CI jobs passed. Five billing migrations are applied and the Vercel production deployment is READY. Authenticated browser smoke remains pending.
- [ ] Historical migration replayability remains unresolved. The live ledger now has 88 entries: 79 historical rows plus 9 later tracked migrations. The five billing migrations were validated and applied as a narrow sequence; map remaining historical SQL before replaying or applying unrelated candidate migrations.
- [ ] No disposable Supabase branch exists. Narrow billing migrations were validated through isolated PostgreSQL 17 CI plus rollback-only live-schema/behavior checks; other RLS/finance candidates still require isolated validation, and branch cost must be confirmed before creating one.
- [ ] Continue non-insurance high-risk audit in this order: patient-balance completeness; pharmacy FEFO/stock reconciliation and dispense permissions; cross-branch RPC authorization; queue/visit numbering and deletion/audit history; authenticated clinical workflow smoke tests and privacy/telemetry. Insurance-specific work is paused until the user resumes it.

## Production aggregate integrity snapshot — 2026-10-16

Read-only aggregate SQL checks (no patient names, identifiers, or individual clinical records were returned) found:

- [ ] **Inventory discrepancy requires reconciliation before enforcing batch-only dispensing or changing stock.** The live catalog has 9 active/non-deleted medicine rows with nonzero legacy `stock_quantity`; only 1 non-deleted pharmacy inventory batch exists, and that batch's `branch_id` is NULL and `expiry_date` is before the database's current date (0 branch-assigned batches; all 498 remaining units are unallocated and expired). A fresh read-only query on 2026-10-16 reconfirmed 9 active catalog rows with nonzero legacy stock totaling 4,484, 1 unallocated expired batch totaling 498, and 0 branch-assigned batches. Eight medicine rows have nonzero stock but no matching batch, all 9 catalog rows differ from summed batch quantities, legacy stock totals 4,484 units, and batch quantities total 498 units. Do not overwrite either source or create synthetic batches automatically. First establish whether these are seed/test balances, legacy stock, or actual inventory; then design a documented reconciliation preserving branch, expiry, movement, and audit history.
- [x] Read-only stock-movement aggregation found only 8 rows. One purchase movement of +500 references `pharmacy_inventory` and has a batch ID but no branch; two batch-linked dispense movements sum to −2, consistent with the one current batch having 498 remaining. Separately, 3 purchase rows sum to +525 with no reference table/ID, batch ID, or branch ID, and 2 dispense rows sum to −2 without batch IDs. Further grouping by medicine (still aggregate-only) shows the one batch-linked medicine has legacy `stock_quantity` 1,994, while its non-deleted batch has 498 remaining; its movements show +1,000 purchase and −3 dispense units, including an unreferenced +500 purchase and a dispense without `batch_id`. The other legacy-stock medicines have +25 purchase and −1 dispense units total. These movement sums cannot reconstruct the legacy catalog balances. This explains the batch total only at aggregate level; the 4,484 legacy-stock total and the unallocated 525 purchase units remain unreconciled. Do not assign these movements to branches or synthesize batches automatically.
- [x] The same historical aggregate snapshot found 6 invoices and 6 invoice-item rows; this is superseded by the reset and subsequent billing smoke cleanup, which left invoices and invoice_items at zero.
- [x] No insurance claims were present at the time of the snapshot, so production data could not validate insurance amount behavior; use isolated fixtures and server-side invariant tests instead.
- [x] Added the observed stock discrepancy to [PR #29 review notes](https://github.com/crauch2088-source/roshan-health-hub/pull/29#issuecomment-6211050412). Ensure the proposed atomic receiving/dispensing workflow does not silently force `medicines.stock_quantity` to equal batch totals. Preserve legacy stock handling until the source-of-truth decision and reconciliation procedure are tested.

## Master-plan checklist accounting — 2026-10-16

- Current unweighted checkbox count after this audit: **47 checked / 140 total (~34% of listed checkbox items marked complete)**;
- This is **not** a weighted measure of application functionality: the plan deliberately lists many separate security, migration, and launch gates, and some completed work is summarized in prose rather than represented as checkboxes. Use it as a measure of explicit plan-tracking completion only, not as the project's overall implementation percentage.
- Production readiness remains gated by migration-history reconciliation, isolated Supabase validation, the legacy-stock discrepancy, authenticated role/branch workflows, and unresolved server-side insurance invariants.

## Insurance integrity follow-up — 2026-10-16

- [x] Added a review note to [PR #13](https://github.com/crauch2088-source/roshan-health-hub/pull/13#issuecomment-6211061012): the proposed RPC can accept a balanced claim split whose gross amount is not tied to an actual invoice line. Production currently has zero insurance claim rows, so no existing claim data was changed or used to infer business rules.
- [ ] Do not assume that insurer/patient split overrides are allowed or forbidden. Define whether coverage must always be recomputed server-side from the plan/rules or whether authorized manual overrides are allowed with reason/audit trail. Regardless of that choice, enforce that each claim item references a real eligible charge and cannot inflate the invoice-derived gross amount.
- [ ] Add tests for mismatched invoice line IDs, over-claimed gross amount, duplicate claim item references, coverage-rule mismatch, invalid override actor/reason (if overrides are permitted), and cross-branch attempts.

## Branch ownership risk in legacy pharmacy stock — 2026-10-16

- [x] Added a high-risk review note to [PR #23](https://github.com/crauch2088-source/roshan-health-hub/pull/23#issuecomment-6211071309): its draft dispense RPC can consume unbatched legacy `medicines.stock_quantity` and record the movement against the current branch, but the live `medicines` table has no `branch_id`. The live `pharmacy_inventory` batches are branch-scoped. The aggregate mismatch means ownership of the legacy quantity cannot be inferred safely.
- [ ] Before enabling this workflow, choose and test one safe path: (a) dispense only from batches assigned to the same branch, rejecting insufficient branch stock, or (b) create a reviewed allocation/reconciliation mechanism for legacy stock with explicit branch ownership and audit history. Do not decrement the global legacy balance as if it were branch-specific.
- [ ] Add a PostgreSQL integration case where stock exists only as unallocated legacy quantity and a different branch attempts to dispense it; expected outcome must be a denial with no stock/invoice/prescription changes.

## Targeted safety fixes verified by CI — 2026-10-16

- [x] **PR #23 dispensing safety:** merged and deployed as part of `a4e537`; FEFO branch-scoped stock checks and no legacy-stock fallback are in the live billing RPCs. Authenticated UI smoke remains pending, and phase17 legacy RPC revocation is intentionally deferred.
- [x] **PR #29 receiving safety:** a stock-receive RPC without an explicit target-branch parameter now rejects requests when the acting user has no configured branch, including super-admins, preventing creation of unassigned batches. Added PostgreSQL regression coverage. Full CI passed on [run #38873151138](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38873151138).
- [x] **PR #22 prescription catalog consistency:** prescription creation now requires both `medicines.active` and `medicines.is_active`, matching the dispense path; added a regression case for inconsistent flags. Full CI passed on [run #38873151121](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38873151121).
- [x] Release staging decision: PR #22 and PR #23 are merged after CI and database-level validation; PR #29 and PR #34 remain draft pending their own review/migration gates; phase17 legacy-dispense revocation is deferred until browser smoke; insurance-specific implementation is paused.
- [ ] Do not reconcile the legacy stock discrepancy by copying totals or inventing batches. Establish provenance and branch ownership first, then run a documented adjustment process with an auditable ledger.
- [ ] Insurance claim gross amounts still need an agreed linkage model to invoice/service lines. Current UI permits free-form descriptions and null reference IDs; do not infer the intended split-override policy. Define reference semantics and permitted manual adjustments before changing the RPC contract.

## Migration inventory artifact — 2026-10-16

- [x] Created [`docs/DB_MIGRATION_RECONCILIATION.md`](https://github.com/crauch2088-source/roshan-health-hub/blob/audit/roshan-health-hub-hardening-plan-v2/docs/DB_MIGRATION_RECONCILIATION.md) with the original 79 historical live version/name rows. The current ledger is 88 entries; the report now has a current-status appendix listing the nine later migrations and their repository sources.
- [x] Confirmed that `main` contains 16 top-level SQL files under `db/` after the billing release, including five applied billing migrations and the unapplied phase17 post-deployment revoke. There is still no timestamped `supabase/migrations` directory.
- [ ] Use the inventory to recover exact source mappings for the remaining entries. Do not label a row fully recovered based only on a similar name; preserve the difference between exact basename match, content-confirmed match, partial candidate, and unrecovered source.



## Migration semantic comparison checkpoint — 2026-10-16

- [x] Inspected the recovered migration archive in draft [PR #26](https://github.com/crauch2088-source/roshan-health-hub/pull/26) and compared four recovered SQL candidates against the legacy db/*.sql scripts using whitespace/comment-insensitive SQL text comparison.
- [x] Confirmed the recovered invoice-per-visit migration (20260911120231_roshan_phase12_invoice_visit_unique) is semantically text-equivalent to db/roshan_phase12_invoice_visit_unique.sql after stripping SQL comments and whitespace. This is a content match for that migration only, not proof that the entire migration chain is replayable.
- [x] Confirmed two candidates differ from their recovered migration text: db/roshan_phase2_clinical_workflow.sql includes an additional lab-parameter backfill statement; db/roshan_phase4_finance.sql differs from recovered finance-v2. For the cashbox concurrency candidate, removing the explicit BEGIN/COMMIT wrapper makes the remaining normalized SQL text match the recovered ledger statement set; this supports a content match with a wrapper difference, not a replay-safety conclusion.
- [ ] Continue statement-level comparison of the remaining recovered migrations and legacy SQL scripts. Do not promote archive files into the canonical migration directory or execute them until isolated replay and Supabase-specific validation pass.

- 2026-10-16: Added a focused, read-only content comparison of four recovered migration candidates to the reconciliation inventory. One normalized SQL text match was confirmed; three candidates differed and remain unresolved. No database writes, merges, or deployments occurred.

- [x] **Cashbox migration comparison refined:** the apparent SQL mismatch was isolated to the legacy file's explicit transaction wrapper (`BEGIN`/`COMMIT`); after removing that wrapper, normalized SQL text matches the recovered applied statement set. This does not replace disposable replay testing.

- [x] **Read-only live lab-parameter invariant check (2026-10-16):** Supabase returned 12 undeleted lab tests, zero tests without any parameter, and zero tests without an active parameter. This confirms the current data invariant only; it does not prove the recovered phase-2 migration contained the legacy backfill statement or establish how the invariant was achieved.


### Finance migration live-state findings (read-only, 2026-10-16)
- Compared `db/roshan_phase4_finance.sql`, recovered migration `20260908210824_roshan_phase4_finance_v2`, and current live function/trigger catalogs without writing to production. The source pair is a successive patch vs. a foundational script, not a direct replacement.
- Live financial RPCs checked in this slice (`post_invoice_payment`, `post_expense`, `post_cashbox_entry`, `post_supplier_bill`, `post_supplier_payment`, `reverse_cashbox_entry`) are SECURITY DEFINER with empty `search_path`; authenticated has EXECUTE, anon/PUBLIC do not. This is a narrow grant/config snapshot only.
- Important live-vs-source findings recorded in `docs/DB_MIGRATION_RECONCILIATION.md`: branch-aware/private-helper RPC implementations and the stricter live conflict predicate are later hardening layers; a read-only index catalog check confirms the live `fn_ledger_post` predicate exactly matches `uq_cashbox_source`, so the live pair is consistent; `customer_payment` is explicitly set by recovered follow-up migration `20260911141142`; two audit trigger families both write `audit_logs`, and an aggregate-only last-30-day query found 20 near-identical audit pairs (10 cashbox INSERT, 9 payment INSERT, 1 payment DELETE); and two supplier-payment triggers recompute balances with different overpayment/soft-delete behavior. The live aggregate showed zero non-deleted supplier bills, so this is a structural edge-case risk rather than observed live balance corruption. Reproduce the edge cases in disposable tests before any change; do not alter production or replay the legacy script based on this observation.


## Financial write-path hardening — 2026-10-16

- [x] Completed a read-only live audit of finance-table grants, RPC validation, RLS predicates, and overlapping audit triggers. PR #23 has installed atomic billing RPCs; direct authenticated invoice table writes still exist and PR #33's additional revokes/branch-scoped item reads remain pending.
- [x] Completed the Expenses RPC UI path in merged [PR #41](https://github.com/crauch2088-source/roshan-health-hub/pull/41): the screen calls `post_expense` and rejects non-finite/non-positive amounts; fresh CI passed. Stale PR #30 was closed as superseded. Production deploy and the stacked direct-write revocations in PR #31 remain pending until Vercel quota resets and authenticated smoke tests pass.
- [x] Reviewed stacked draft [PR #31](https://github.com/crauch2088-source/roshan-health-hub/pull/31) for RPC-only finance/insurance writes, permission contracts, branch assignment, overpayment, and idempotency. PR #31 remains draft/unmerged; insurance-specific implementation is paused, and remaining direct-write revokes are separate work.

- [x] Completed finance audit-trigger deduplication: the verified migration was applied as `roshan_phase18_dedupe_finance_audit_triggers_20261016` / `20261016161923`; all five duplicate generic triggers were removed and canonical `trg_finance_audit` triggers remain. Clean replacement [PR #43](https://github.com/crauch2088-source/roshan-health-hub/pull/43) passed PostgreSQL 17 behavior tests plus app CI and merged; stale PRs #32 and #40 were closed as superseded.

## Clinical child-row branch isolation and invoice access — 2026-10-16

- [x] Completed a read-only RLS inventory for `invoice_items`, `prescriptions`, `prescription_items`, and `lab_order_items`. Found that invoice-item SELECT permission lacked a parent-branch predicate, while prescription and lab-order child policies checked permissions but omitted branch checks through the parent records.
- [ ] Review stacked draft [PR #33](https://github.com/crauch2088-source/roshan-health-hub/pull/33). PR #23 is now merged into main; sync/rebase PR #33 before review. Its direct invoice-mutation revokes and invoice-item branch filtering remain unapplied and require their own tests.
- [x] Repaired PR #34's disposable fixture after CI exposed missing policy-table dependencies and missing table grants; expanded tests to cover SELECT/INSERT/UPDATE on medical certificates, patient discounts, and insurance prior authorizations plus DELETE on certificates/discounts, alongside prescription/lab child rows. Full PostgreSQL 17 integration plus guard tests, typecheck, lint, and build passed on head `4af17cc9881c7eae0f06ed12a0bf8ce5d564dc7f` in [run #38885778383](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38885778383).
- [x] Reviewed draft [PR #34](https://github.com/crauch2088-source/roshan-health-hub/pull/34), which scopes branch-sensitive RLS for clinical child rows and related certificate/discount/authorization records. Review found that prescription INSERT/UPDATE/DELETE policies used a branch-only helper and did not enforce patient/visit linkage. Added a regression test (RED on head `91306c1b21aa30bc0fa5c8af5890eb2c2b50a1a6`) and corrected all four prescription write-policy references to `private.app_has_prescription_parent_access`; PostgreSQL 17 integration and full app checks passed on head `372d5c8fbb34a50d6e2e2f1b35ca3be35efa1b9b` in [run #38896060162](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38896060162). Review of the draft code is complete; PR remains unmerged pending migration-history reconciliation and business review of the broader policy changes.


## Finance audit deduplication and insurance claim schema gate — 2026-10-16
- [x] Compared the live `fn_ledger_post` conflict predicate against `pg_indexes`: both use `source_type IS NOT NULL AND source_id IS NOT NULL`, confirming that the live function matches its unique index. The older checked-in candidate remains unsuitable for blind replay.

- [x] Confirmed from the live catalog that five finance tables (`cashbox_transactions`, `expenses`, `payments`, `supplier_bills`, `supplier_payments`) each have both a generic `trg_audit_*` trigger and `trg_finance_audit`. Aggregate-only review found 20 near-identical audit pairs over 30 days, concentrated in cashbox and payments; no matching pairs were observed for the other overlapping tables in that window.
- [x] Added a PostgreSQL 17 regression fixture and observed the intended RED result in a temporary duplicate PR: a single payment INSERT created two audit rows. Then found the existing, more complete canonical draft PR #32, which already tests INSERT/UPDATE/DELETE on all five finance tables plus a non-finance control table; its integration and full CI suite passed on head `a626104e616a5d19857db4b819099be55aad4e6c`. Closed duplicate PR #35 without merging or deploying. A later independently created duplicate, PR #37, also reproduced the behavior in PostgreSQL 17 but was closed in favor of the more complete PR #32; PR #37's PostgreSQL integration passed, while lint failed on its intermediate head. 
- [ ] Insurance claim schema semantics remain an owner/business-rule gate: live `insurance_claim_items.reference_id` is nullable UUID without a foreign key, and `service_type` is free text. A fresh aggregate-only snapshot on 2026-10-16 found zero insurance plans, zero coverage rules, zero patient-insurance rows, zero claims/items, and only six invoice lines (four consultation, two laboratory). There is currently no configured plan/rule dataset or historic claim-item population to infer the reference model from. The schema alone does not establish whether a reference should target an invoice item, service catalog item, or another entity. Do not invent a target or silently reject current legacy data; insurance workflow remains unconfigured until the owner defines linkage and coverage/override rules.


### Privileged-role database guard review — 2026-10-16
- [x] Read-only live catalog check confirmed that the three prepared protection triggers for `users`, `roles`, and `role_permissions` are absent in production. The current RLS policy set permits generic user creation/update and `admin.full` role maintenance without a database-level `role_id = super_admin` invariant. There are currently zero active users assigned the `admin` role, but this remains a structural escalation risk if that role is activated or assigned.
- [x] Extended draft [PR #38](https://github.com/crauch2088-source/roshan-health-hub/pull/38) from a test-only guard check into a tested hardening fix. The new PostgreSQL 17 regression reproduced that `auth.uid() IS NULL` lets an anonymous JWT bypass the prepared role guard; the old behavior failed in run [#38896579035](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38896579035). The guard now trusts only a `service_role` JWT or a direct trusted DB session with no JWT role claim (`postgres`/`supabase_admin`); anonymous JWTs are denied even in a fixture that grants them direct table DML. Full PostgreSQL 17 integration, security audit, guard tests, typecheck, lint, and build passed on head `523f7a0f9cc1359d9ed162eede9e75dd388a5d31` in [run #38897148980](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38897148980). At the time of that audit the change was draft and unapplied; it was superseded on 2026-10-16 by merge `cf42e6bf97dafe47b71cdff37578f42eb3a2ac52` and tracked production migration `20261016170816`.
- [ ] Historical migration-sequence parity remains unresolved. The role guard was applied as a new tracked Supabase migration after PostgreSQL 17 integration tests, exact live-schema review, rollback correction, and rollback-only live behavior checks. Continue full history reconciliation and isolated Supabase validation before applying the separate PR #22/#34/#13 candidates; do not replay recovered historical SQL.


## Production operations snapshot — 2026-10-16

- [x] Rechecked Vercel scope through the connected account: the Roshan team has one linked Vercel project, `roshan-health-hub`, connected to `crauch2088-source/roshan-health-hub`. The latest deployment marked `production` is READY and points to `main` commit `a64f804679aeaae7299b034176f2265ac1806db0`; recent PR previews remain separate and do not change production.
- [x] Checked the current 24-hour runtime-error aggregate: Vercel reported no runtime error groups. The older missing `VITE_SUPABASE_PUBLISHABLE_KEY` cluster is timestamped 2026-10-14, and the latest selected 24-hour window contained no runtime errors; do not describe that historical cluster as a current outage. A 30-minute production error-log query returned no entries. Read Vercel environment-variable metadata without decrypting values and confirmed `VITE_SUPABASE_PUBLISHABLE_KEY` is configured for both production and preview. This is an observability/configuration snapshot, not an authenticated clinical smoke test.
- [ ] Vercel preview builds are still blocked by the Hobby build-rate limit for multiple draft PRs. Continue using GitHub PostgreSQL 17 integration/guard jobs and source-level checks while rate-limited; do not change plan or create a second Vercel project to work around this.
- [ ] Keep production at the currently verified main deployment until reviewed changes are approved; none of the current draft hardening PRs has been merged by this work session.


## Prescription workflow cross-PR consolidation — 2026-10-16

- [x] Compared the overlapping prescription-search PR #15 with atomic prescription PR #22 at source level. Ported the remaining search-safety and catalog-form normalization gaps into PR #22: remove SQL LIKE `%`/`_` wildcard characters and PostgREST filter grammar from user terms; avoid querying the catalog for empty/one-character searches; normalize supported catalog dosage forms to the select's canonical lowercase values and the route to `oral`; unknown dosage forms remain unselected rather than being misrepresented. Added regression cases first; CI confirmed the missing helper (RED), then the helper/UI assertions and formatting were corrected. Latest head `e9b85929357360006cff31d690ea6658a928c7c6` passed 68 guard tests, PostgreSQL 17 atomic prescription integration, security audit, typecheck, lint, and build in [run #38899424448](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38899424448). PR #15 was closed as superseded after a note was added; PR #22 remains open/draft/unmerged. No production SQL, merge, or deployment occurred. The current catalog has 9 active medicines and all 9 have blank dosage_form values, so this normalization primarily prevents future inconsistent values rather than changing existing catalog entries.


## Branch assignment and finance-ledger data readiness — read-only — 2026-10-16

- [x] Closed the narrower pharmacy batch-tab PR #14 as superseded by PR #29, after recording the reason in its conversation. PR #29 remains open/draft/unmerged; no production changes were made.
- [x] Ran an aggregate-only live Supabase check without selecting patient names, MRNs, invoice IDs, or other row-level identifiers. The database has 2 non-deleted branches, both marked active in both flags and both labeled as the main branch (English `ROSHAN Main Branch` / `ROS-MAIN`; Arabic `الفرع الرئيسي` / `MAIN`). Branch-level aggregates show the English branch has 1 active user, 1 patient, 1 cashbox entry, and zero visits/invoices/inventory batches; the Arabic branch has zero counts in those categories. Among 6 active users, the doctor, lab-tech, pharmacist, and receptionist accounts have no branch; one super-admin has a branch and one does not. There are 6 active branchless invoices totaling 57,000, all linked to patients whose branch is also null; 5 are linked to branchless visits. There are 10 active branchless payments totaling 57,000, and each has exactly one matching payment-ledger row with the same amount. These records may be synthetic/prelaunch data; this query does not establish their real-world ownership.
- [x] Followed the finance aggregate into `cashbox_transactions`: there are 12 non-deleted branchless entries with signed total 7,000.01, including one legacy expense of -50,000 and 11 payment-ledger rows totaling 57,000.01. Exactly one `source_type='payment'` ledger row has no matching `payments` row: amount 0.01 on 2026-09-17. No row identifiers or descriptions were retrieved. This is an orphan-ledger finding to reconcile, not a basis for automatic deletion or adjustment.
- [x] **Prelaunch data gate resolved 2026-10-16:** user confirmed all patient/clinical/financial records were disposable manually entered test data. All operational patient/clinical/financial rows and public audit logs were cleared; six auth users and six app users remain. ROS-MAIN is the sole active branch; unopened MAIN is inactive; four non-super-admin staff accounts were assigned to ROS-MAIN; one global super-admin remains branchless. No patient or financial transaction rows were retained.


### Finance hardening follow-up evidence — 2026-10-16
- PR #32's general CI and PostgreSQL audit-dedup behavioral job passed (run `38878206233`); PR #31's general CI, RPC-only finance integration, and two-session idempotency job passed (run `38893892959`). Both PRs remain draft/unmerged; no production migration or deployment was performed.
- Live catalog confirms both generic and finance audit triggers are attached to all five targeted finance tables. Supplier-bill invariant checks are currently inconclusive on live data because there are zero supplier bills and zero supplier payments; isolated integration tests are required.


### Insurance workflow evidence and unresolved business semantics — 2026-10-16
- PR #12 (invoice required for claim creation) and PR #13 (claim amount invariants) are merged. PR #13's isolated PostgreSQL 17 integration passed after explicitly revoking PUBLIC/anon execution and granting authenticated execution on the claim RPC. PR #13 SQL remains unapplied to production; PR #22 and #34 remain draft.
- Read-only production aggregate query found zero active insurance claims and zero claim items, so production data cannot confirm behavior for invoice linkage, service references, or covered/patient amount splits. Keep the insurance semantics decision gate open rather than treating zero observed violations as proof.


### Patient registration and private helper privileges — 2026-10-16
- Replaced stale PR #39 with merged [PR #44](https://github.com/crauch2088-source/roshan-health-hub/pull/44). Its fresh rerun passed all four CI jobs; Phase 21A (`create_patient_atomic`) is applied and verified in Supabase, while Phase 21B remains pending until the new UI is deployed and smoke-tested.
- PR #34 now adds an explicit least-privilege grant boundary for `private.app_has_branch_access(uuid)` plus an integration assertion. The latest CI run `38903566507` passed both general verification and clinical child branch-isolation integration.
- Read-only ACL review also identified four other private helpers with anon EXECUTE ACLs, while anon has no schema USAGE. Schedule a separate dependency-aware sweep rather than treating them as externally reachable or revoking them without checking policy/trigger callers.


### Stacked PR sequencing and current CI evidence — 2026-10-16
- PR #23 must precede PR #33 because #33 removes direct invoice/invoice-item mutation privileges after the atomic invoice UI/RPC paths are in place. PR #30 must precede PR #31 because #31 revokes direct finance-table writes and #30 routes the Expenses screen through `post_expense`. Do not promote #31/#33 independently of their client-path dependencies.
- Finance audit dedup is now applied and tracked in merged PR #43. PR #34 remains open with green branch-isolation integration CI. Patient registration is merged in PR #44; Phase 21A is applied, but Phase 21B privilege revocation awaits production UI deployment. Do not merge/apply PR #31 or #33 independently of their client-path dependencies.
- Vercel deployment limits are separate from CI: PR-level CI passed and mainline CI passed on `eb83cd21b80ce587da41b74b9715806ab4828db0`, but no newer production deployment exists. Finance audit dedup and patient RPC Phase 21A are applied; do not apply privilege-revocation Phase 21B before the new UI is live.


### Finance audit duplication remediation — proposed, not released (2026-10-16)
- Created draft PR #40: https://github.com/crauch2088-source/roshan-health-hub/pull/40. It proposes dropping only the older generic `trg_audit_*` trigger from `payments`, `expenses`, `supplier_payments`, and `cashbox_transactions`, retaining the newer `trg_finance_audit` trigger.
- Added a focused PostgreSQL 17 integration workflow. Its run #38904042089 passed: the test exercises INSERT, UPDATE, DELETE, confirms one audit row per operation, and verifies the migration is idempotent on a disposable database.
- General CI run #38904041803 has passed install, dependency audit, patched TanStack checks, guard tests, and typecheck; lint was still running at last observation and build had not started. Do not claim full CI until refreshed.
- Production audit inspection was read-only. No migration was applied to production; this PR remains draft pending review of user attribution and audit-retention expectations.
- Separate read-only insurance aggregate found no active insurance claims or claim items currently present (six active invoices and six invoice items). This does not resolve the policy question of whether claims must reference exact invoice lines or server-recalculate coverage; keep insurance financial integrity open pending explicit business-rule design.

- Follow-up aggregate-only audit comparison found all 20 near-identical pairs had matching `user_id` values between the two trigger-generated rows (3 pairs had both user IDs null; none differed). This lowers observed attribution-divergence concern but does not replace review of noninteractive/service-role paths.

- Anti-duplication check: PR #40 was created while following the live audit finding, then immediately closed as redundant after discovering the existing, broader PR #32. PR #32 is the canonical proposed fix: it covers all five finance tables, retains generic auditing on a non-finance control table, and its PostgreSQL 17 integration + full CI passed. Do not merge PR #40.


## Connected-tool handoff refresh — 2026-10-16

Read-only refresh performed against the current GitHub refs and connected Supabase migration ledger. No PR was merged, no deployment was triggered by this work, and no production SQL was executed.

- Current plan blob SHA: `95ba4135f70bdec8f3ad22f8b627806763b49c9e`. Counting every literal Markdown checkbox token in this file yields 47 checked and 93 unchecked (140 total; 33.57%). This is a document-wide checklist count, not a weighted implementation or launch-readiness score; the plan contains historical follow-up notes, so phase-local counts should not be inferred from this raw total.
- Current `docs/DB_MIGRATION_RECONCILIATION.md` was fetched from the same branch (blob `329916f329924536f43d343baf79a499e0b606ca`). It records 79 applied migration rows, 10 committed legacy `db/*.sql` files on main, four exact basename matches, and unresolved semantic/replay parity. The connected Supabase migration listing independently returned 79 entries, ending at `20261014164131_roshan_cashbox_reversal_concurrency`.
- PR #24 (this plan branch) is OPEN/DRAFT, head `fa7f2421b8cf543f62d7c13787bfe08ee5cfc1af`; CI run `38904423841` completed successfully.
- Latest relevant draft PR heads and CI evidence: #12 `175216a4b929b23690f979a7d234899d3e25a71c` / run `38760288567` SUCCESS; #13 `e1ef268c519398e97e78c8beec96dc613e141340` / `38789219521` SUCCESS; #22 `e9b85929357360006cff31d690ea6658a928c7c6` / `38899424448` SUCCESS; #23 `14e0b167a9b80c989184a60f35a2b8ab449df62e` / `38872711903` SUCCESS; #29 `28704de2044a029fb916f3b2c93dec20c71e4730` / `38873102682` SUCCESS; #33 `863dae0f482a06882f6b3740e8cdde673e869c9c` / `38880644006` SUCCESS; #34 `f5e7db64d947ff1bd5d71e509ce38b2e283c812f` / `38903566507` SUCCESS; #26 `7c3286d4843f656cc73ba028be494ab3a932747a` / `38778700394` SUCCESS; #31 `e8d54fa7849596408c3788e9e806eb41731d77ec` / `38893892959` SUCCESS; #32 `a626104e616a5d19857db4b819099be55aad4e6c` / `38878206233` SUCCESS; #36 `c7a12408dcd154af65ba0726a59455436d5ea5af` / `38887494366` SUCCESS; #38 `523f7a0f9cc1359d9ed162eede9e75dd388a5d31` / `38897148980` SUCCESS; #39 `8fa3ae58ffc8964ce5e4397e4a34a3c2618b3a1a` / `38903131578` SUCCESS. These are branch CI results only and do not authorize merge or deployment.
- PRs #12, #13, #22, #23, #24, #26, #27, #28, #29, #31, #32, #33, #34, #36, #38, and #39 are currently OPEN/DRAFT; #35, #37, and #40 are CLOSED without merge. PR #33 is based on #23. PR #31 is based on `fix/expenses-atomic-rpc`. Do not treat dependent PRs as independently releasable without reviewing their base and migration order.
- PR #34's current migration `db/roshan_phase20_clinical_child_branch_isolation.sql` now covers prescriptions, prescription items, lab orders/items, medical certificates, patient discounts, and insurance prior authorizations; its current PostgreSQL 17 fixture includes cross-branch SELECT/INSERT/UPDATE/DELETE assertions for the expanded tables and same-branch positive controls. Latest CI passed, but this remains a disposable-fixture result: it does not prove the migration works against the exact live schema, that all policy names/permissions match production, or that every application workflow retains intended access. Keep it unapplied until migration parity and live-schema dependency review are complete.
- Insurance semantics remain unresolved: live aggregate queries found no active claims/items, so current production rows cannot validate the meaning of `reference_id` or whether manual covered/patient splits are legitimate. Successful CI for #12/#13 is not business-policy approval.
- No authenticated browser session was available during this refresh, so login, role-gate, cross-branch user journeys, and protected-route behavior were not re-tested. CI success is not a substitute for authenticated smoke tests.


## Live lab-order branch-context check — 2026-10-16

Read-only aggregate queries against the connected production database found 9 non-deleted `lab_orders` rows and all 9 have `branch_id IS NULL`. Of those, only 1 has a non-null patient branch that could be a fallback; 8 have neither an order branch nor a patient/visit branch fallback. No row was observed with a non-null order branch that disagreed with its patient or visit branch.

This is a data-quality and authorization-behavior concern for PR #34: the parent `lab_orders_*` policies check `app_has_branch_access(lab_orders.branch_id)`, which fails closed for a NULL branch for ordinary branch users, while the proposed child helper derives access from `COALESCE(lo.branch_id, v.branch_id, p.branch_id)`. The one fallback-present row can therefore behave differently between parent and child policies; eight rows have no branch fallback at all. Do not backfill or alter production data as part of this audit. A review note was added to PR #34 asking for disposable PostgreSQL regression coverage for both branchless cases and an explicit decision about preserving fail-closed behavior versus an approved repair. The live schema/data check did not read patient-identifying fields.

Other aggregate results during the same read-only pass: `patient_discounts` has zero rows, `medical_certificates` has zero rows, and `insurance_prior_authorizations` has zero rows. These empty tables cannot validate intended edge-case behavior; the `patient_discounts.patient_id` column is nullable and `partner_id` is present, so partner-only discount semantics still need confirmation before treating the proposed patient-only branch helper as fully validated.


## Follow-up security regression — patient-branch helper grant — 2026-10-16

During the PR #34 review, a read-only production catalog check found that `private.app_has_patient_branch(uuid)` was SECURITY DEFINER with an empty `search_path` but still executable by `anon`. The proposed child-table RLS migration called this helper directly and initially revoked anonymous execution only from `private.app_has_branch_access(uuid)`.

A disposable PostgreSQL 17 regression was added; it failed on head `69945084c67a088c9f7e793daa150866c129398d` with `anonymous role must not execute private patient-branch helper`. The migration was corrected to revoke PUBLIC/anon and grant authenticated execution for `private.app_has_patient_branch(uuid)`. Latest PR #34 head `0e18974ebfc588cbf605b62cdc5d4169f93fcca7` passed both PostgreSQL 17 integration and full install/audit/role-guard/typecheck/lint/build in CI run [38906930251](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38906930251). The change remains in an open draft PR; no production permissions or SQL were changed.


### Invoice write-path parity audit — 2026-10-16
- [x] The three invoice-creation RPCs from PR #33 were absent at the time of the original audit; PR #23 has since installed the core consultation/lab/manual billing RPCs. PR #33's remaining scope is direct-write revocation and branch-aware invoice-item reads.
- [x] Read-only ACL check confirmed authenticated still has direct INSERT/UPDATE/DELETE on invoices and invoice_items. PR #23 installed atomic RPCs but did not yet revoke direct table writes; PR #33 remains the separate candidate for that hardening.
- [x] Compared live invoice and invoice-item RLS: invoice SELECT checks branch access, while invoice-item SELECT still needs parent-invoice branch filtering. PR #33 proposes the parent filter; keep it draft until independently tested.
- [x] Historical aggregate integrity snapshot found 6 invoices and 6 invoice items with no orphaned items; this snapshot is superseded by the user-authorized reset, which left invoices and invoice_items at zero.
- [x] Historical RPC audit confirmed next_invoice_number() and post_invoice_payment(...) were authenticated-only SECURITY DEFINER/RPC paths with empty search_path; PR #23 has since added the missing atomic invoice-creation RPCs. Historical migration replayability and other direct-write paths remain separate work.


### Patient registration atomicity audit — 2026-10-16
- [x] Read-only catalog comparison confirmed the proposed atomic patient RPC preserves the live RMC MRN prefix and advisory-lock key.
- [x] Aggregate production check recorded 10 patient rows: 5 RMC MRNs, 1 TEST-prefixed MRN, and 4 NULL MRNs; no identifying fields were retrieved and no data was modified.
- [x] Reviewed PR #39's server-side permission, active-user, required-branch, and server-derived audit attribution checks.
- [x] Reviewed disposable PostgreSQL coverage for invalid input, permission denial, missing branch, rollback, and two-session MRN allocation concurrency.
- [x] Confirmed full CI on the refreshed patient-registration candidate passed all four jobs (atomic registration/MRN concurrency, cashbox concurrency, finance audit behavior, and install/audit/typecheck/lint/build); merged PR #44 as `36903ddcf1fb27ba35eb1237f594c006b5529dc2`. Phase 21A is applied; Phase 21B remains pending deployment.


## Verified follow-up batch — 2026-10-16
- [x] Confirmed the latest master-plan documentation commit's full GitHub Actions job completed successfully: run [38908548869](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38908548869), including dependency/security checks, role-guard tests, typecheck, lint, and production build.
- [x] Cross-checked the connected Supabase migration ledger: 88 rows now exist, from `20260818162003` through `20261016183152`; the original 79-row inventory is a historical snapshot, not the current count.
- [x] Rechecked PR #23's current head and CI association: it remains OPEN/DRAFT, based on `main`, with CI run [38872711903](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38872711903) successful. It is not merged or released.
- [x] Rechecked PR #33's dependency: it was based on PR #23's former `fix/invoice-atomicity` branch; PR #23 is now merged, so PR #33 needs sync/rebase and separate review before any rollout.
- [x] Repeated the read-only private-helper ACL audit: five SECURITY DEFINER helpers have effective anon EXECUTE according to PostgreSQL privilege checks, while anon has no USAGE on schema `private`. Treat as least-privilege debt, not proof of a current PostgREST route; map policy/trigger dependencies before proposing revocations.

These checks are repository/metadata verification, not application feature completion. No production SQL, data, grants, merges, or deployments were changed.

- [x] Mapped live dependencies before considering any helper permission change: branch-access helper → 50 policies/13 tables; claim helper → 4 policies/2 tables; invoice helper → 3 policies; patient helper → 3 policies; role-sync helper → one trigger. Broad changes are explicitly blocked pending isolated-context regression tests.


## Execution batch — 20 items — 2026-10-16

## Completed work and verified evidence

1. Re-read the master plan on `main` and checked current branch/PR state before making changes.
2. Reviewed PR #19's implementation and regression tests for the patient snapshot outstanding-balance calculation.
3. Verified the invoice query no longer uses the former 1,000-row cap and uses `useAllRows` with an exact server count and stable `id` ordering.
4. Verified the calculation falls back from invalid/missing `net_amount` to `total_amount`, and returns unknown instead of inventing a balance when monetary fields are invalid.
5. Verified overpayments do not display as negative debt and query/incomplete-page errors render an explicit unavailable state.
6. Verified PR #19 CI run [38771066048](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38771066048) passed the security audit, guard tests, typecheck, lint, and build.
7. Verified PR #19's Vercel preview had a Ready/success status before merge.
8. Squash-merged PR #19, **patient snapshot balance integrity**, as commit [b4f214f](https://github.com/crauch2088-source/roshan-health-hub/commit/b4f214faa29650b2ca0d75230a3bd665d08aebb9). No schema or patient/invoice data was changed by this PR.
9. Reviewed PR #22 CI run [38899424448](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38899424448): application checks and PostgreSQL 17 atomic-prescription integration both passed.
10. Reviewed PR #23 CI run [38872711903](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38872711903): application checks, consolidated visit invoice, atomic invoice, and pharmacy-dispense/invoice integration jobs passed.
11. Reviewed PR #29 CI run [38873102682](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38873102682): application checks and PostgreSQL 17 pharmacy batch-receiving integration passed.
12. Reviewed PR #30 CI run [38876630369](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38876630369): application security/guard/typecheck/lint/build job passed.
13. Reviewed PR #32 CI run [38878206233](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38878206233): application checks and PostgreSQL 17 finance-audit-trigger deduplication integration passed.
14. Reviewed PR #34 CI run [38906930251](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38906930251): application checks and clinical child-table cross-branch integration passed.
15. Reviewed PR #38 CI run [38897148980](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38897148980): application checks and privileged-role-guard integration passed.
16. Confirmed PR #31 is based on PR #30's `fix/expenses-atomic-rpc` branch; it must not be integrated before its prerequisite is reconciled. PR #33 similarly depends on PR #23's `fix/invoice-atomicity` branch.
17. Reviewed the current migration-recovery gate: PR #26 is documentation/quarantine work only. Recovered SQL remains unexecuted; semantic parity and clean replay remain unresolved.
18. In PR #39, corrected patient registration so the form no longer silently defaults missing gender to male; saving is blocked until gender is explicitly selected, with a regression guard added.
19. In PR #39's proposed SQL, added explicit revocation of direct `authenticated` INSERT on `public.patients` and execution of legacy `public.next_mrn()`, so the new atomic registration RPC cannot be bypassed through those paths.
20. Added PostgreSQL integration assertions and fixture setup for those revoked privileges. Latest PR #39 head is [55c6bb8](https://github.com/crauch2088-source/roshan-health-hub/commit/55c6bb808a583421ce9cc44695db3a8efcf32856). **CI for this new head has not yet appeared in the workflow-run lookup; this item is implemented but not yet CI-verified.** The PR remains draft and the proposed SQL has not been applied.



## Release gates still open

- PR #12 is merged as `e6f664d`; its production UI deployment and authenticated insurance-claim smoke test remain pending.
- PR #13 remains blocked by staging/Supabase validation and migration-history reconciliation.
- Open SQL/security candidates #13, #22, #23, #29, #31, #33, and #34 still need their stated live-schema, migration-parity, and business-rule gates; PostgreSQL fixtures alone do not prove compatibility with production. PR #38 is now merged and its narrow guard migration is applied.
- The connected Supabase migration ledger still has 79 applied entries, while canonical repository migration-history parity remains unresolved. No production SQL was run in this batch.
- PR #39 was superseded by PR #44; Phase 21B patient privilege revocation still awaits a deployed and authenticated registration smoke test.
- No production SQL was applied in this batch. The only merge was PR #19, a UI/query correctness change without schema changes.


## Execution batch 2 — 20 additional items — 2026-10-16

## 20 items completed

1. Re-read the canonical `docs/MASTER_PLAN.md` from `main` before starting this batch.
2. Recounted the plan's explicit checkbox items: 156 total.
3. Recounted completed checkboxes: 63.
4. Recalculated checklist completion as 63/156 = **40.4%**; audit-only work is not counted as implementation completion.
5. Queried the connected Supabase migration ledger; it reports 79 applied migrations.
6. Queried the live public schema table inventory; it reports 56 public tables.
7. Verified that all 56 listed public tables currently have RLS enabled.
8. Counted 33 public SECURITY DEFINER functions.
9. Verified that all 33 public SECURITY DEFINER functions have a function-level `search_path` configuration. This is a configuration check, not a substitute for reviewing each function's actual value and logic.
10. Verified that the `anon` role cannot directly INSERT into `public.patients`.
11. Found that `authenticated` can currently INSERT directly into `public.patients`; the proposed PR #39 revocation has not been applied to production.
12. Found that `authenticated` can currently EXECUTE `public.next_mrn()`; the proposed PR #39 revocation has not been applied to production.
13. Confirmed that `public.create_patient_atomic(text,text,date,text,text)` does not yet exist in production.
14. Read the current production `public.next_mrn()` definition without modifying it.
15. Confirmed that the live allocator uses the transaction advisory-lock key `hashtext('roshan:mrn')`.
16. Compared PR #39's candidate atomic allocator and confirmed it uses the same advisory-lock key, so the two code paths coordinate on the same lock if deployed.
17. Reviewed the candidate SQL fixture and found invalid dollar-quote syntax around its stub `next_mrn()` function.
18. Corrected the fixture to use valid `$$ ... $$` dollar quoting.
19. Added an integration regression test asserting that a blank gender is rejected by the atomic patient-registration RPC.
20. Committed those two test corrections to PR #39 as [90bc780](https://github.com/crauch2088-source/roshan-health-hub/commit/90bc780cc38d66227ae6b8a8a2cab268c6ca8f0e) and verified its Vercel preview reached READY: [preview deployment](https://vercel.com/roshan45/roshan-health-hub/HmemGD1Zy5DYKRZZ8AGFJR31otW3).



## Important status and safety boundary

- PR #39 remains draft/open. The preview's READY state is a frontend build/deployment signal, not proof that the PostgreSQL integration workflow passed.
- The live database still has direct authenticated patient INSERT and authenticated execution of `next_mrn()`. This is a verified least-privilege gap to close through a reviewed, reconciled migration—not by an ad hoc production SQL command.
- The production database still does not contain the atomic patient-registration RPC. No SQL, grants, patient data, or other database state was changed in this batch.
- Migration-history parity remains unresolved. Do not merge or apply the candidate migration until the repository migration sequence, isolated PostgreSQL/Supabase integration tests, rollback, and branch authorization behavior are reviewed.
- The master-plan checklist percentage remains **40.4%** (63/156). This batch contains substantial audit and test-preparation work, but those tasks are deliberately not reclassified as completed production features.


## Updated execution authorization and working mode — 2026-10-16

The user explicitly authorizes direct project execution using Composio, GitHub, Supabase, Vercel, and other available connected tools; current web research where useful; applying SQL required by the project; and merging any change judged ready. The user states the stored patient/financial data is test-only and disposable, including permission to delete it if a specific task requires it. Do not ask again for routine in-scope merge/SQL approval.

Execution rules: maximize concrete, verifiable progress in batches; use parallel workstreams for independent tasks; keep this file as the single source of truth; record each material code/SQL/doc change, CI evidence, deployment state, and updated checklist percentage. Continue other useful work when a task is blocked. Do not inflate completion based on audits. Do not perform broad destructive operations merely because test data is disposable: first establish the exact target and necessity, prefer tracked/reversible migrations, and verify postconditions. For database changes, use the best available isolated validation; if unavailable, choose narrow idempotent changes and capture a rollback. Merges remain authorized when the relevant code, dependencies, CI, and data/schema assumptions are checked.

## External guidance consulted — 2026-10-16
- Supabase database migrations: https://supabase.com/docs/guides/deployment/database-migrations — keep schema changes in versioned migration files; avoid direct remote schema edits that bypass migration history.
- Supabase branching: https://supabase.com/docs/guides/deployment/branching — branches are isolated; Git-connected branches apply repository migrations while dashboard branches derive from project migration history.
- PostgreSQL 17 CREATE FUNCTION security: https://www.postgresql.org/docs/17/sql-createfunction.html — SECURITY DEFINER routines require a trusted search_path and selective EXECUTE grants.



## Execution batch C — 2026-10-16

### Verified changes
- Recorded the user's standing authorization for direct in-scope execution, Composio-first workflows, SQL, and merges, while retaining scoped-change, rollback, and verification safeguards.
- Merged PR #26: archived the 79 applied migration statements and manifest under `docs/recovered-migrations/`. These remain quarantined documentation, not executable migrations.
- Merged PR #41 after fresh CI: expense creation now uses the existing `post_expense` RPC; the UI rejects non-finite and non-positive amounts. The old stale/conflicted PR #30 was closed as superseded.
- Applied and verified finance audit trigger deduplication in Supabase as migration `roshan_phase18_dedupe_finance_audit_triggers_20261016` / version `20261016161923`. Removed only the five duplicate generic audit triggers; verified each finance table retained `trg_finance_audit`; no rows were deleted or updated. PR #43 passed CI and was merged to track the migration and tests.
- Applied Phase 21A of patient registration as `roshan_phase21_patient_registration_atomicity_20261016` / version `20261016162410`. The `SECURITY DEFINER` RPC uses an empty `search_path`, and authenticated can execute it. Existing direct INSERT and `next_mrn()` privileges remain unchanged for compatibility.
- Split patient registration rollout into Phase 21A (RPC install) and Phase 21B (legacy privilege revocation). PR #44 contains the staged migrations, PostgreSQL 17 integration/concurrency tests, and current guard-test updates. After the first workflow was cancelled during a PR refresh, the full rerun passed all four jobs (atomic registration/MRN concurrency, cashbox concurrency, finance audit behavior, and install/audit/typecheck/lint/build). PR #44 was then merged as commit `36903ddcf1fb27ba35eb1237f594c006b5529dc2`. Do not apply Phase 21B until the updated UI is deployed and smoke-tested.

### Deployment limitation
- The latest verified production deployment is still on commit `9f6b2c881247b570cc75e1f61ed13a2337183b86`, before PRs #41, #43, and #44 merged. Vercel deployment creation returned HTTP 402: the team's daily API deployment quota (100/day) is exhausted, resetting approximately 2026-10-17 16:24 UTC. No alternate account or bypass was attempted. Once quota resets, deploy current `main`, verify the app, then apply Phase 21B.
- Supabase migration history now contains 81 entries. The broader historical migration parity/replay audit remains open; archived SQL has not been replayed.

### Checklist accounting
- Main-plan checklist: **64/156 = 41.0%**. One existing checklist item for the Expenses RPC UI was marked complete after PR #41 merged and passed fresh CI. Finance audit and patient RPC work are recorded, but they do not independently close more checklist items while production UI deployment and Phase 21B remain pending.


## Execution batch D — 2026-10-16

### Production deployment recovered and verified
- Deployed current `main` commit `3166f0bef5b734dad541516fb37fa003accfed2f` to the canonical Vercel project `roshan-health-hub` after the previous daily API quota window had elapsed. Deployment [2Usy7342GX3XFarGVrqs64sGFFWk](https://vercel.com/roshan45/roshan-health-hub/2Usy7342GX3XFarGVrqs64sGFFWk) reached `READY`, with the canonical alias `https://roshan-health-hub.vercel.app`. This deployment includes the already-merged PR #41, #43, and #44 code.
- Verified current main CI run [#38932545934](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38932545934): all four jobs succeeded — finance audit trigger deduplication, atomic patient registration/MRN concurrency, cashbox reversal two-session concurrency, and install/audit/typecheck/lint/build.
- Anonymous HTTP smoke checks returned 200 for `/`, `/auth`, `/setup`, `/dashboard`, `/patients`, `/insurance`, `/pharmacy`, and `/queue`. These prove public route-shell reachability only; they do not prove successful login, authenticated mutations, role enforcement, or branch isolation. The nonexistent `/login` path returned 404 and was not treated as a product route.
- Read-only production database review verified the 16 inspected SECURITY DEFINER RPCs have empty function-level `search_path`, no EXECUTE for `anon` or `PUBLIC`, and EXECUTE for `authenticated`; the reviewed functions contain application permission checks, but this is not a substitute for adversarial cross-branch testing.
- No new database migration or privilege change was applied in this batch. Phase 21B remains gated on authenticated smoke testing of the deployed patient-registration path; historical migration parity is still unresolved.

### Checklist accounting
- Updated the existing reproducible-CI checklist item after the current main SHA passed all four required jobs: **65/156 = 41.7%**.
- Security advisor warnings remain for `pg_trgm` in `public`, authenticated access to 16 SECURITY DEFINER functions (review each as an intentional RPC surface), and disabled leaked-password protection. No blind function revocations or auth configuration changes were made.


## Execution batch E — 2026-10-16 (late)

### Production and security work completed
- Merged PR #12, `fix(insurance): require invoice for claim creation`, as `e6f664d6b3a99a1925871280dbfa7b1f528090c5`. Focused insurance-claim validation tests and all four main CI jobs passed. The UI change has not yet reached production because Vercel's deployment API quota is exhausted; authenticated insurance workflow smoke testing remains open.
- Merged PR #38, `fix(security): guard privileged role mutations`, as `cf42e6bf97dafe47b71cdff37578f42eb3a2ac52`. Post-merge main CI run [#38937191630](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38937191630) passed all four jobs. The PostgreSQL 17 privileged-role guard integration and app checks were green on the merged candidate.
- Applied the guard through the tracked Supabase migration workflow as `roshan_security_privileged_role_guard_20261016`, ledger version `20261016170816`. Migration history now contains 82 entries. The three BEFORE-row triggers are present on `public.users`, `public.roles`, and `public.role_permissions`; five private SECURITY DEFINER helpers have empty `search_path` and no EXECUTE for `anon`, `authenticated`, or `PUBLIC`. Bootstrap function EXECUTE remained revoked as before.
- Verified that the database still has exactly one `super_admin` role and two users assigned to it. Four live behavioral assertions ran inside explicit transactions that were rolled back: anonymous JWT cannot assign the `super_admin` role; an authenticated non-super-admin cannot assign it; a real super-admin remains recognized and can update their own row; and an ordinary user can update their own non-super-admin row. No persistent test user or row change was retained.
- Corrected the guard migration's rollback notes to include the new trusted-context helper before merge.

### Current open PRs and CI
- PR #22 is refreshed to current main at head `4008bdccdc807453c87bf6f11186420de4b9fb63`. Its dedicated PostgreSQL 17 integration checks passed on the refreshed head; the latest application CI was still running at the last check. Keep it draft until migration-history reconciliation and authenticated clinical workflow review are complete.
- PR #34 is refreshed to current main at head `ec83e94a33e9c299ecf6ea32c1886e51c2da482f`. Its dedicated PostgreSQL 17 branch-isolation integration passed on the refreshed head; application CI was queued/not yet visible at the last check. Keep it draft because live-schema compatibility, branchless parent-row behavior, and migration-history parity remain open.
- PR #38 is merged and applied. PR #12 is merged but not yet deployed. PR #13 remains blocked by the unresolved insurance invoice-line/reference business model.

### Deployment quota and rollout gate
- Latest verified production deployment remains `3166f0bef5b734dad541516fb37fa003accfed2f` at [the canonical Vercel project](https://vercel.com/roshan45/roshan-health-hub/2Usy7342GX3XFarGVrqs64sGFFWk). It includes PR #41, #43, and #44, but predates PR #12 and #38.
- A production deployment attempt for latest main `e6f664d` was rejected with HTTP 402, `api-deployments-free-per-day`, `retryAfter=86400`. The mapped Vercel CLI fallback was checked but the CLI is not installed in the available cloud shell. No alternate account or quota bypass was attempted. Earliest reasonable retry is approximately 2026-10-17 17:03 UTC / 19:03 Sudan local time.
- Do not apply patient Phase 21B until the new registration UI is deployed and authenticated smoke-tested. Do not apply PR #22, #34, or #13 SQL solely because fixture CI is green; their migration-history/live-schema/business-rule gates remain open.

### Checklist accounting
- Checklist remains **65/156 = 41.7%**. No additional checklist item is marked complete here: PR #12 still needs deployment and authenticated workflow verification, and the broader role-guard migration-parity gate remains open even though the narrow migration was applied and behaviorally verified.


## Execution batch F — user-authorized test-data reset and reprioritization — 2026-10-16

### User clarification and scope
- The user confirmed that the clinic has one operational branch; the second branch has not opened, and all previously stored patient/clinical/financial records were manually entered test fixtures, not real patient or financial data.
- The user explicitly authorized deleting these test records while preserving user accounts, requested that insurance-related plan work be temporarily deferred, and directed continued progress on other plan tracks.
- Insurance code/schema were not removed and insurance-specific checklist items were not marked complete; implementation work on insurance is paused by user request.

### Live database reset completed and verified
- Cleared transactional/test rows from appointments, patient records and their clinical child records, visits, vitals, diagnoses, notes, laboratory orders/items/results, prescriptions/items, invoices/items, payments, expenses, cashbox transactions, queue tickets, follow-ups, stock movements, supplier bills/payments, patient discounts, certificates, procedure orders/results, insurance transactions, corporate/partner test records, and the application audit log. Explicit TRUNCATE with RESTART IDENTITY and CASCADE was executed inside one PostgreSQL transaction block; only named operational tables and their FK-dependent rows were targeted.
- Verified zero rows in public.patients, appointments, visits, vitals, diagnoses, clinical_notes, lab_orders, lab_order_items, lab_results, prescriptions, prescription_items, invoices, invoice_items, payments, expenses, cashbox_transactions, queue_tickets, followups, stock_movements, and audit_logs.
- Verified user accounts were preserved: 6 rows in auth.users, 6 in public.users, and 5 in public.profiles.
- Preserved authorization/configuration/reference data: 16 roles, 107 permissions, 491 role-permission links, 11 departments, 13 services, 12 lab tests, 18 lab parameters, 9 medicines, 24 procedures, and 8 system settings.
- Verified there is now exactly 1 active branch: ROSHAN Main Branch (ROS-MAIN). The unopened الفرع الرئيسي (MAIN) row was retained for referential safety but marked inactive (active=false, is_active=false).
- Assigned the four branchless non-super-admin staff accounts to ROS-MAIN. The one global super-admin account remains branchless by design; the other super-admin remains assigned to the operational branch. No user account was deleted.
- Verified storage.objects contains 0 objects, so no uploaded test files needed removal.
- The prior branch-data readiness report is superseded for current counts; see the updated snapshot in docs/BRANCH_DATA_READINESS_2026-10-16.md.

### Non-insurance implementation path
- Rechecked the atomic prescription UI/RPC candidate, PR #22, at head 6eb0d63f92465ee4bec2084daef217cc2fd3ec1b; latest CI reports 9 check runs, including successful finance-audit, cashbox-concurrency, PostgreSQL integration, security, typecheck, lint, and build jobs. PR #22 was merged into main as commit 18c377dd480791332e4c4369891310587c30036f after all 9 PR checks passed; the four main CI jobs on the merge commit also passed. The merged UI is not yet present in the latest observed production deployment.
- The production RPC is already installed under Supabase migration ledger version 20261016172209; PR #22 is now merged but not yet deployed; its PR body reflects that the RPC is already installed. The latest observed Vercel production deployment is still SHA 9e032c5b6844c7db8fc14e23513eab37de384627, which predates the merge.
- PR #34 remains deferred: it covers branch-aware RLS for clinical child tables but also includes an insurance-prior-authorization policy. Do not merge/apply it while insurance work is paused and migration/live-schema review remains open.
- Current security advisor snapshot: 17 authenticated-callable SECURITY DEFINER notices (review each RPC individually; these are warnings, not proof of vulnerability), plus pg_trgm in public. Performance advisor reports 123 unused-index notices; no indexes were dropped.
- The checklist remains based on implemented/verified plan items only. The data reset and audit work do not count as feature completion. PR #22 is merged but its production UI smoke gate is still open, so keep the numerator unchanged unless an existing checklist item genuinely meets its exit criteria.

### Remaining gates
1. Reconcile the live 83-entry Supabase migration ledger with repository SQL artifacts and establish a repeatable migration source of truth.
2. Correct PR #22 description to reflect the already-installed RPC, complete source review, then merge when the migration/release gates are satisfied.
3. After Vercel's deployment quota resets, deploy the intended main SHA and run authenticated registration/consultation/prescription smoke tests.
4. Continue non-insurance security review and patient/invoice atomicity work; keep insurance implementation paused until the user resumes it.


### Checklist accounting after batch F
The current checklist is 65/156 = 41.7%. The data reset and audit work do not count as feature completion. Keep the numerator unchanged unless an existing checklist item genuinely meets its exit criteria.


### Follow-up verification — prescription RPC smoke test — 2026-10-16
- Exercised public.create_prescription_atomic inside one PostgreSQL DO statement using an assigned doctor account and transaction-local authenticated JWT claims.
- The smoke test inserted a synthetic patient and visit, called the live RPC with one active catalog medicine, and asserted one prescription item was created with the server-derived catalog price.
- The same statement cleaned up the generated prescription, queue ticket, visit, patient, and audit rows before completing. Final independent counts confirmed zero patients, visits, queue tickets, prescriptions, prescription items, and audit logs; all six auth users and all six public user rows remain.
- The initial fixture was corrected after two setup/cleanup issues (MRN column length and a queue-ticket FK); those failures were atomic and left no records. The final run passed. This is simulated-auth database-level validation only; authenticated browser/UI testing remains pending.


## Execution batch G — prescription merge and billing live-schema validation — 2026-10-16

### Prescription workflow merged
- PR #22 was merged into main with squash commit 18c377dd480791332e4c4369891310587c30036f after all 9 PR checks passed. Main CI on the merge commit passed all 4 jobs.
- The live create_prescription_atomic RPC was exercised under transaction-local authenticated JWT claims for an assigned doctor. It created one prescription item and used the catalog price; the synthetic patient, visit, prescription, queue ticket, and audit rows were cleaned up in the same atomic statement. Independent postconditions confirmed zero patients, visits, prescriptions, prescription_items, queue_tickets, and audit_logs.
- The billing merge is now deployed: Vercel production deployment is READY at SHA a4e53787bed97f9f2d34038641a2a839b12c01ba and is aliased to roshan-health-hub.vercel.app. Main CI passed all 7 jobs.

### Itemized invoice and billing candidate advanced safely
- PR #23 (consolidated visit invoice, atomic lab billing, pharmacy dispensing invoice, and billing idempotency) had a stale base and merge conflicts in only .github/workflows/ci.yml and package.json. Both were reconciled by preserving all current main jobs and combining the main and invoice test suites; the branch now includes a merge commit with main and keeps all 26 intended changed files.
- All 12 CI checks on the resolved PR #23 head 45f4aaf4e2945eec5091d548c34ad1f9890ed004 passed. PR #23 was merged as a4e53787bed97f9f2d34038641a2a839b12c01ba; five billing SQL migrations are now installed in Supabase. The post-deployment legacy RPC revoke remains intentionally unapplied.
- Ran a rollback-only live-schema dry run of all 35 statements across the five billing SQL files, followed by simulated-auth smoke tests using an assigned doctor and receptionist. The test created a primary consultation invoice, appended a lab line to the same invoice, verified an idempotent lab-order retry did not duplicate the order/lines, and created an explicit secondary invoice. The transaction's sentinel exception rolled back all DDL and test rows. Postconditions verified the is_primary column, billing RPCs, and idempotency table were not persisted and all patient/visit/lab/invoice/audit tables remained empty.
- Release hazard resolved through staged compatibility: phase14 now leaves public.fn_dispense_prescription(uuid) callable for the current UI; the new phase17 migration revokes it only after the new UI is deployed and authenticated browser smoke tests pass.
- Historical migration reproducibility remains separate: live ledger has 83 entries (79 historical statements archived and 4 later tracked SQL changes). The rollback-only live-schema check and isolated PostgreSQL 17 integration tests validate this narrow billing change, but the recovered 79-entry archive is not a clean from-scratch baseline.
- Insurance implementation remains paused at user request. Insurance-related checklist items are neither marked complete nor removed.

### Current release sequence
1. Completed: split legacy dispense RPC revocation into phase17 and add CI regression tests for the compatibility window.
2. Completed: applied five billing migrations in order (ledger versions 20261016183123–20261016183152) while preserving the legacy RPC.
3. Completed: merged PR #23 as a4e53787bed97f9f2d34038641a2a839b12c01ba; all 7 main CI jobs passed and Vercel production deployment is READY.
4. Pending: authenticated browser/UI tests for consultation, lab order, consolidated invoice, explicit secondary invoice, pharmacy dispense, and retry/idempotency. Apply phase17 only after those tests pass.
5. Checklist remains 74/156 = 47.4%; no new feature checkbox is counted complete until its rollout and verification gates pass.


## Execution batch H — billing release merged and deployed — 2026-10-16

### Mainline and deployment
- PR #23 merged as commit a4e53787bed97f9f2d34038641a2a839b12c01ba.
- Main CI on that merge commit passed all 7 jobs: pharmacy dispense/invoice integration, consolidated visit invoice integration, cashbox concurrency, patient registration/MRN concurrency, finance audit deduplication, atomic invoice integration, and install/audit/typecheck/lint/build.
- Vercel production deployment for the merge commit reached READY and is aliased to https://roshan-health-hub.vercel.app. This confirms deployment readiness, not authenticated UI correctness.

### Five billing migrations applied and verified
- 20261016183123 roshan_phase8_atomic_invoice
- 20261016183130 roshan_phase13_consolidated_visit_invoice
- 20261016183136 roshan_phase14_dispense_invoice_atomic_compat
- 20261016183145 roshan_phase15_manual_invoice_consolidation
- 20261016183152 roshan_phase16_billing_idempotency
- The database-level simulated-auth smoke passed after the migrations were applied: consultation and lab lines consolidated into one primary invoice, lab retry returned the same order without duplicate lines, and an explicit secondary invoice was created with idempotent retry.
- Test rows were cleaned before completion. Postconditions: auth.users=6, public.users=6, patients=0, visits=0, queue_tickets=0, lab_orders=0, lab_order_items=0, invoices=0, invoice_items=0, private.billing_rpc_idempotency=0, public.audit_logs=0, auth.audit_log_entries=0.
- The current legacy dispense RPC remains callable so the previously deployed UI remains compatible. New billing RPCs are authenticated-only; anon execution is denied; the non-idempotent manual-invoice overload is denied to authenticated.

### Deferred post-deployment step
- Do not apply db/roshan_phase17_revoke_legacy_dispense_rpc.sql yet. Browser automation is not connected and no user credentials were provided, so authenticated UI smoke tests are pending.
- After authenticated browser tests pass for consultation, lab order, consolidated invoice, separate invoice, pharmacy dispense, and idempotent retries, apply phase17 and verify the legacy RPC is no longer executable.
- Insurance implementation remains paused at user request.
- Checklist remains 65/156 = 41.7%; keep the numerator unchanged until authenticated UI verification completes.


## Plugin and integration operating map (2026-10-16)
- Durable detailed map: [docs/PLUGIN_TOOLING_MAP.md](./PLUGIN_TOOLING_MAP.md). Consult it before each phase and whenever the task changes; update it when a connector, permission, tool capability, or project workflow changes.
- Use direct first-party connectors for Supabase, Vercel, PostHog, and Figma when they provide the needed operation; use Composio for cross-app orchestration, GitHub writes when the native GitHub connector returns 403, and broad connector discovery.
- Before any Composio workflow, search for tools, review the recommended plan and complete input schemas, verify the target app/account is ACTIVE, then batch only independent operations. Never guess tool slugs, IDs, or project targets.
- Route current library/API questions through Context7 and official docs; use current web research for guideline/security decisions; use Product Design/Figma for UX discovery only when the connection/permissions allow it. Figma MCP has previously been view-only/rate-limited, so do not block code-based design work on it.
- Prioritize connected capabilities: GitHub (repo, CI, issues/PRs, code/security scans); Supabase (schema/migrations/RLS/advisors/logs/functions); Vercel (canonical project, deploys, domains, env-key inventory, logs); PostHog (errors/funnels/feature flags only after privacy controls); Context7 (current library docs); Superpowers/engineering skills (TDD, debugging, review); Product Design/Figma (screen audits and design tokens); Composio (multi-app batch execution); Lovable/Replit (only for targeted comparison/prototype, never create a parallel source of truth).
- Before real clinic traffic: no session replay or analytics containing PHI, patient identifiers, clinical text, invoice/payment details, auth tokens, URLs/query strings, or request/response bodies. Default to no capture or mask-all; use synthetic test data and verify capture configuration first. PostHog's current connected project was previously empty and must not be enabled for clinic data without an explicit privacy review.
- Browser automation is a current blocker for authenticated production smoke tests. Request a browser workflow integration only when ready to test the real UI; never ask the user to paste credentials into chat. See the tooling map for suggested optional integrations and exact triggers.


## Integration review follow-up — live checks (2026-10-16)
- [ ] Investigate current Supabase security advisor: 21 functions are flagged as callable by `authenticated` users while `SECURITY DEFINER`. This is not automatically a vulnerability: inspect all current function bodies, grants, `search_path`, internal permission checks, branch/tenant checks, and negative authorization tests before changing grants or function security.
- [ ] Enable Supabase Auth leaked-password protection after confirming the setting's impact and documenting the change.
- [ ] Review the `pg_trgm` extension placement warning; assess dependency impact and migration/rollback path before moving it.
- [ ] Performance advisor currently lists 100 unused-index findings. Do not drop them without query/workload evidence; measure query plans and preserve indexes used by branch scoping, uniqueness, foreign keys, and high-frequency search.
- [x] Vercel inventory reconfirmed one linked project in team `roshan45`: `roshan-health-hub` linked to `crauch2088-source/roshan-health-hub`.


## Repository cross-check from integration review (2026-10-16)
- [ ] Open draft PR #34, [branch-scope prescription/lab child rows](https://github.com/crauch2088-source/roshan-health-hub/pull/34), has reported passing PostgreSQL 17 integration + guard/typecheck/lint/build checks on its latest head, but remains unapplied to production. Preserve the migration-history reconciliation and business-review gates; do not merge solely because CI is green.
- [ ] Keep open security issue #25 active: secret scanning/push protection are reported disabled and historical environment-file exposure is still unverified.
- [ ] Re-triage existing finance/clinical data integrity issues before launch, including invoice amount validation/atomicity (#20), complete patient balance aggregation (#18), and insurance claim invariants (#16). Re-check issue/PR state before acting; these notes are snapshots, not assertions that each remains unchanged.
- The documentation-only integration-map commit reports Vercel status pending; do not interpret that alone as a failed app build or change production configuration for a docs-only commit.



### Plugin / integration review update — 2026-10-16
- [x] Created `docs/PLUGIN_TOOLING_MAP.md` and linked it from this plan; it is the durable trigger map for connected and optional tools.
- [x] Firecrawl connection confirmed active during follow-up. Official docs confirm search, scrape, crawl/map, parse, and interactive page workflows; use it for targeted official-doc research, cross-source implementation reviews, and biomedical literature research when relevant. Do not send patient data to it.
- [ ] TinyFish remains the next optional connection for authenticated browser smoke tests. Firecrawl's Interact can perform dynamic browser tasks, but full signed-in app QA should use a controlled synthetic test account and must not be represented as completed until actually run.
- [ ] A CI status lookup for documentation commit `64175c353838bbcfacea6945c5653a58b5098656` returned Vercel `failure` with target URL indicating `build-rate-limit`. This is a hosting/build quota signal, not evidence of a TypeScript or test failure. Recheck the latest run before changing code or deploying.
- [ ] Updated Supabase security advisor snapshot (2026-10-16 19:56 UTC): 21 authenticated-callable SECURITY DEFINER findings, leaked-password protection disabled, `pg_trgm` in `public`; performance advisor returned 100 unused-index findings. These are current advisor counts and do not mean 21 proven vulnerabilities. Function access must be validated one-by-one; Supabase docs require pinned/empty `search_path`, schema-qualified names, narrow EXECUTE grants, and authorization checks.
- [ ] Open release-sensitive work discovered during review: [PR #34](https://github.com/crauch2088-source/roshan-health-hub/pull/34) clinical child-row branch isolation (draft; regression tests pass on its reported head, but migration/history review remains), [PR #33](https://github.com/crauch2088-source/roshan-health-hub/pull/33) invoice RPC-only writes and branch isolation (draft, based on another branch), and [PR #31](https://github.com/crauch2088-source/roshan-health-hub/pull/31) finance/insurance direct-write restrictions (draft). Do not merge stacked PRs out of order or apply their SQL to production before migration history and cross-branch behavior are reconciled.
- [ ] Priority follow-up defects also surfaced: [Issue #18](https://github.com/crauch2088-source/roshan-health-hub/issues/18) states patient-picker outstanding balance uses a 1,000-invoice cap and may silently display an incomplete total; [Issue #20](https://github.com/crauch2088-source/roshan-health-hub/issues/20) records earlier non-atomic manual invoice creation and numeric validation risks; [Issue #25](https://github.com/crauch2088-source/roshan-health-hub/issues/25) tracks historical secret exposure / secret-scanning availability. Verify current code and issue/PR relationships before implementation, since issues can be superseded.


## Authenticated browser smoke test — TinyFish — 2026-10-16

- [x] Authenticated, read-only browser smoke test completed against the canonical production URL `https://roshan-health-hub.vercel.app` using the `Roshan Health Hub QA` browser profile. Run report: https://agent.tinyfish.ai/runs/d7d5a041-d267-45ed-b147-373086c66da0
- [x] Reported session identity: General Manager (`المدير العام`). Dashboard rendered, Arabic RTL shell/navigation and breadcrumb/header appeared intact, and the browser agent reported no visible login redirect, permission error, blank page, broken image, layout failure, or runtime error.
- [x] The agent reported opening/rendering 23 routes: `/dashboard`, `/patients`, `/visits`, `/queue`, `/clinic`, `/appointments`, `/followups`, `/certificates`, `/pharmacy`, `/inventory`, `/lab`, `/lab-catalog`, `/billing`, `/finance`, `/accounting`, `/expenses`, `/partners`, `/reports`, `/analytics`, `/insurance`, `/users`, `/audit`, and `/settings`. Dashboard tables were empty, consistent with the current synthetic/test-data reset. Settings displayed the expected center name, Arabic name, SDG currency, zero tax, invoice footer, and 90-day pharmacy-expiry threshold.
- [x] Test was explicitly read-only: no Add/Edit/Delete/Submit/Save actions were activated and no records were mutated.
- [ ] Scope limitation: this was a browser-agent visual/navigation smoke test, not a full Playwright/console capture, independent role/branch authorization test, or clinical/financial end-to-end transaction test. “No console errors observed visually” is not equivalent to instrumented console verification.
- [ ] Next: use this working browser profile for targeted synthetic-data workflows (registration → queue → visit; prescription; lab; consolidated invoice and secondary invoice; pharmacy dispense and retry/idempotency) with explicit cleanup/postcondition checks. Do not run destructive operations or real patient workflows. Keep phase17 legacy-dispense RPC revocation blocked until the new pharmacy UI and retries are verified.
- [ ] Reconcile the TinyFish profile registry: the successful run loaded the authenticated session even though `list_profiles` reported no `signed_in_sites`. Re-check profile state later; this metadata mismatch does not invalidate the completed smoke report, but should not be silently described as a confirmed persistent site entry.
- [ ] The previous statements that browser automation was not connected / credentials were not supplied are superseded by this successful run. Browser automation is now available for further authorized QA.


## Authenticated patient registration and module-route smoke tests — 2026-10-16

- [x] TinyFish authenticated UI smoke test created exactly one synthetic patient via the production UI using `create_patient_atomic`: `QA TINYFISH ROSHAN 20261016 BATCH01`, MRN `RMC000001`, UUID `e4d03d21-224e-4c27-9f18-0fa1fc5feb2b`. UI showed a “Saved” toast and the patient appeared in the list with the expected MRN. No phone, DOB, or national ID was supplied.
- [x] Before registration, read-only SQL verified patients, visits, appointments, queue tickets, invoices, and audit_logs were all zero; one active branch was present. The exact patient had zero dependent appointments, attachments, certificates, follow-ups, invoices, lab orders, medical certificates, discounts, insurance rows, prescriptions, procedure orders, queue tickets, and visits.
- [x] Guarded cleanup then checked the exact UUID + full name + MRN, refused to proceed if any dependent rows existed, deleted exactly that one synthetic patient, and removed only audit rows for `table_name='patients'` and that exact `record_id`. Postcondition query confirmed the synthetic patient absent and global patients, visits, invoices, audit_logs all returned to zero. No pre-existing rows were changed.
- [x] Read-only TinyFish follow-up inspected `/visits`, `/queue`, `/lab`, `/billing`, `/pharmacy`, and `/patients`. All six routes authenticated, rendered their expected empty states and zero-valued metrics, and sidebar navigation worked. Patient registration modal opened and was canceled; full name is required and Save is disabled until it is entered. No visit, lab order, invoice, payment, dispense, or stock mutation was attempted.
- [x] Run evidence: registration https://agent.tinyfish.ai/runs/7f496a5f-f247-4dd9-af7f-81a2a565460d; read-only module audit https://agent.tinyfish.ai/runs/abe5ee2f-49bc-4617-b31a-d58e5c84a0cc; earlier 23-route shell smoke https://agent.tinyfish.ai/runs/d7d5a041-d267-45ed-b147-373086c66da0.
- [ ] Scope limits: these are browser-level smoke checks, not full clinical/financial transaction E2E, instrumented console logs, independent role/branch negative authorization tests, or mobile RTL/LTR viewport matrix. Keep the production legacy dispense RPC revoke blocked until new UI pharmacy and retry/idempotency tests pass.
- [ ] Product issue observed: the patient list has no visible edit/delete/archive action, despite patient rows having soft-delete metadata. Do not add hard-delete controls. Review role permissions and implement a permission-gated, audited soft-delete/archive workflow only after defining safeguards for records with clinical/financial dependents; meanwhile use guarded exact-ID cleanup only for isolated synthetic test fixtures.
- [ ] The browser profile metadata still does not record `roshan-health-hub.vercel.app` under `signed_in_sites`, although these runs did load the authenticated app. Reconcile profile persistence before relying on long-running repeat automation.


## Follow-up QA batch and issue triage — 2026-10-16

- [x] A second synthetic patient-registration attempt was started for the reception→visit→queue workflow. The UI saved `QA TINYFISH VISIT 20261016 BATCH02` with MRN `RMC000001` and UUID `aa0c142d-ba3f-482c-a883-453ed230cf89`, but the browser automation failed while opening the New Visit form. Independent DB inspection showed zero visits, queue tickets, appointments, invoices, lab orders, or prescriptions for that patient.
- [x] Guarded SQL cleanup matched the exact synthetic patient UUID/name/MRN, asserted there were no dependent records, deleted exactly one patient, and removed only that patient's audit rows. Final independent counts: patients=0, visits=0, queue_tickets=0, appointments=0, lab_orders=0, prescriptions=0, invoices=0, invoice_items=0, payments=0, audit_logs=0. No real or pre-existing records were changed.
- [x] Closed stale [Issue #17](https://github.com/crauch2088-source/roshan-health-hub/issues/17) after verifying atomic prescription RPC usage, installed SQL, and passing CI/database smoke evidence.
- [x] Closed stale [Issue #20](https://github.com/crauch2088-source/roshan-health-hub/issues/20) after verifying invoice UI now uses server-side atomic RPC + client preflight validation, with installed billing migrations and passing integration/main CI.
- [x] Closed the obsolete Composio pipeline test issue [#1](https://github.com/crauch2088-source/roshan-health-hub/issues/1); active tooling routing is now maintained in `docs/PLUGIN_TOOLING_MAP.md`.
- [ ] Keep [Issue #18](https://github.com/crauch2088-source/roshan-health-hub/issues/18) open: source currently uses exact paginated invoice reads, total_amount fallback, and explicit unavailable states, but add/verify focused regression coverage for >1,000 invoices and query-failure behavior before closing it.
- [ ] The reception→visit→queue browser test remains incomplete because TinyFish failed mid-run. Do not retry the same run blindly; continue via an independent path, and recheck the empty-state baseline before a fresh bounded run.


## Final triage correction — 2026-10-16

- [x] Closed [Issue #18](https://github.com/crauch2088-source/roshan-health-hub/issues/18) after a fresh main-source review confirmed complete range pagination and exact-count gating in `usePatientSnapshot`, `net_amount` → `total_amount` fallback, explicit unavailable states, and regression tests for >1,000 rows, query failure, early termination, and invalid monetary data.
- [x] Main CI passed for the documentation/tooling map update in run [#38964357807](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38964357807). This run validates repository checks for that commit, not a new production deployment.
- [ ] Reception→visit→queue remains unverified end-to-end: TinyFish failed after the second synthetic patient saved but before a visit was created. The exact patient and its audit rows were removed; live database counts were independently verified back to zero. Continue with a new, diagnosed browser attempt rather than assuming the failed run completed.


## Phase 21B applied — patient write-path hardening verified — 2026-10-16

- [x] Preflight confirmed the latest READY production deployment for the canonical project is on main and aliases `roshan-health-hub.vercel.app`; production UI smoke tests had already succeeded on the atomic registration form.
- [x] Applied Supabase migration `roshan_phase21_patient_registration_privileges_20261016` from `db/roshan_phase21_patient_registration_privileges.sql`. It revokes direct `INSERT` on `public.patients` from `authenticated` and revokes all EXECUTE on legacy `public.next_mrn()` from `PUBLIC`, `anon`, and `authenticated`.
- [x] Post-migration privilege verification: `authenticated_patient_insert=false`; `authenticated_next_mrn=false`; `anon_next_mrn=false`; `service_role_next_mrn=true`; `authenticated_create_patient_atomic=true`; `anon_create_patient_atomic=false`.
- [x] Post-migration browser smoke test successfully registered one synthetic patient via the current UI and displayed “Saved” with MRN `RMC000001`. Test run: https://agent.tinyfish.ai/runs/643f8bd1-d227-4fc8-b96b-fa6098819ebf. The exact synthetic patient `QA TINYFISH PHASE21B POSTMIGRATION 20261016` (UUID `d6d0b9dc-84bb-4d29-a1c2-5538a3cdd1d4`) had no dependent rows; guarded cleanup deleted only that exact patient and its patient audit rows.
- [x] Final postconditions confirmed patients=0, visits=0, queue_tickets=0, invoices=0, payments=0, audit_logs=0; registration RPC remains executable by `authenticated` and not `anon`.
- [ ] Keep broader role/branch adversarial authorization testing open. This change closes the direct-write bypass for patient registration but does not prove all other SECURITY DEFINER RPCs and branch policies safe.


## Supabase SECURITY DEFINER inventory after Phase 21B — 2026-10-16

- [x] Read-only catalog inventory counted 42 `SECURITY DEFINER` functions in `public`; 20 currently have EXECUTE for `authenticated`, and zero public functions have EXECUTE for `anon`.
- [x] All 20 authenticated-callable public SECURITY DEFINER functions have an empty/pinned `search_path`; static body scan found authorization/scope markers in each definition. This is a triage signal only—not a substitute for negative tests of every argument, branch, patient/visit relation, and financial invariant.
- [x] `anon` has EXECUTE ACLs on five functions in the `private` schema, but read-only schema privilege check confirms `anon` has no USAGE on `private`, so those functions are not reachable through normal schema access. Keep least-privilege review open rather than claiming these ACLs are ideal.
- [ ] Still open: function-by-function adversarial authorization testing, branch isolation for cross-entity IDs, the Auth leaked-password protection setting, `pg_trgm` extension placement, and migration replay parity.
- [ ] Vercel runtime-error cluster lookup returned 403 for the connected account. No retries were made; request logs/error clusters remain unavailable through that specific connector operation.

## Phase 22 — clinic-local visit/queue date regression — 2026-10-16

- [x] Confirmed production defect with the authenticated synthetic smoke test: the UI encoded clinic midnight as UTC 2026-10-15 22:00:00+00, while the visit trigger derived queue_date using UTC and assigned 2026-10-15. The visits page filters on the clinic's current date, so the saved visit was hidden from that date's list.
- [x] Added a source fix to send the intended clinic-local queue_date explicitly with the visit, while retaining visit_date as a timestamp.
- [x] Added a tracked migration that changes both private.ensure_visit_queue() and private.create_queue_ticket() to derive fallback dates in Africa/Khartoum, preserving the empty search_path security posture.
- [x] Added a PostgreSQL 17 integration regression covering the UTC rollover boundary, exactly-one queue ticket, and explicit queue-date preservation; added it to CI plus a source guard test.
- [x] Applied migration `roshan_phase22_clinic_local_queue_date_20261016` to the verified Supabase production project after PostgreSQL 17 regression CI passed. Live catalog verification confirms both trigger functions now use `AT TIME ZONE 'Africa/Khartoum'` and retain an empty `search_path`. The CI regression validates midnight rollover and exactly one queue ticket.
- [x] The current production alias is READY on deployment SHA `1d23c39d15b3cd9399c81169830086694bcafc6`, and a read-only smoke confirmed the login page renders. After the Phase 23 migration, an authenticated synthetic visit → queue test succeeded with the expected clinic-local date and exactly one queue ticket. The code-relevant Phase 22 fix is present in the deployed source; no new frontend code change was needed for Phase 23. Patient-level archive remains a separate UX/safety task.

## Phase 23 — legacy queue allocator collision found by authenticated UI test (2026-10-16)

- [x] Authenticated TinyFish run [1801a025-212a-4c3c-b49c-f1be3ce88fd0](https://agent.tinyfish.ai/runs/1801a025-212a-4c3c-b49c-f1be3ce88fd0) reproduced the production failure: one synthetic patient was registered, but the single New Visit submit hit `visits_visit_number_day_key`.
- [x] Read-only live inspection found seven soft-deleted visits numbered 1–7 with clinic-local `visit_date` corresponding to 2026-10-16 but stale `queue_date` set to 2026-10-15. The allocator only considered `queue_date`, so it selected visit number 1 again and collided with the unique index on `(visit_date, visit_number)`.
- [x] Fixed by extending the allocator to reserve numbers from either the stored `queue_date` or `(visit_date AT TIME ZONE 'Africa/Khartoum')::date`. Added PostgreSQL 17 regression coverage with the live unique index and seven legacy soft-deleted rows.
- [x] PR #46 [merged](https://github.com/crauch2088-source/roshan-health-hub/pull/46) as `0c86c7294613f9130cdd2a2fae7681f015cbbb0a`. CI run [#38972671208](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38972671208) passed, including the PostgreSQL 17 clinic queue regression, guard tests, security audit, typecheck, lint, and build. Related privileged-role, prescription, insurance-claim, and CodeQL checks also passed; CodeQL reported no new alerts.
- [x] Applied tracked migration `roshan_phase23_legacy_queue_allocator_20261016` to Supabase production; ledger version is `20261016215806`. Live catalog verification confirms the allocator includes both date paths and keeps `search_path = ''`.
- [x] Authenticated retry run [1b8a5a29-9e77-461f-921c-e3864c36f43d](https://agent.tinyfish.ai/runs/1b8a5a29-9e77-461f-921c-e3864c36f43d) succeeded once: synthetic visit UUID `8a75ab3d-2989-4764-9d42-7dc302e9b73f`, queue number `Q8`, clinic-local `queue_date = 2026-10-16`, and exactly one ticket dated 2026-10-16. No error toast occurred.
- [x] Guarded cleanup removed only the exact synthetic patient, visit, queue ticket, and related audit rows after confirming there were no appointments, clinical notes, diagnoses, labs, prescriptions, invoices, payments, procedures, attachments, or vitals linked to the test visit. Follow-up SQL confirmed all four exact-ID counts are zero. The seven older soft-deleted visit rows were left untouched.
- [ ] Follow up on the New Visit selectors: the browser displayed no department/doctor choices, while a live catalog count showed 11 active departments and one active doctor-role user. Investigate authenticated API/RLS/query errors and the role filter before launch; the visit was allowed to save without selecting either.
- [ ] Continue broader clinical UAT, cross-branch negative authorization tests, and historical migration-source/replay parity review.


## Phase 24 — permission-safe visit-form options (in progress, 2026-10-16)

- Read-only production checks confirm 11 departments satisfy the active/not-deleted filters and an active clinical doctor exists. The UI's direct queries are subject to mismatched RLS: department SELECT requires `admin.full`, while reception has `visits.create`; staff-directory SELECT requires `users.read`. Do not broaden direct SELECT on `public.users`, because it contains contact/account fields.
- Proposed fix uses `public.get_visit_form_options()`, a narrowly shaped SECURITY DEFINER RPC gated by `visits.create`, returning only active departments and minimal active clinical-staff identifiers/names within the caller's branch. It explicitly revokes PUBLIC/anon execution and grants authenticated execution.
- Added PostgreSQL 17 integration coverage for permission denial, active/deleted filtering, clinical-role filtering, cross-branch and branchless staff exclusion, minimal returned fields, and anon/authenticated EXECUTE privileges. Added a UI guard test and CI job.
- [x] PR #47 merged as `3206729326c30559579296a26b49a9306c399e38` after all CI jobs passed. Migration `roshan_phase24_visit_form_options_20261016` applied to production. Simulated authenticated receptionist verification returned 11 departments and one same-branch doctor, no email/phone fields; `anon` EXECUTE is false and `authenticated` EXECUTE is true. Authenticated browser UI verification remains pending because Vercel production deploys are rate-limited. This phase is independent of Phase 23 queue-number repair.

## Phase 25 — self-profile bootstrap under RLS (merged; migration applied, 2026-10-16)

- Production RLS inspection confirmed the receptionist role has `visits.create` and `visits.read`, but not `users.read` or `admin.full`; direct `users` profile reads and `role_permissions` reads returned zero rows under the authenticated receptionist JWT.
- [x] PR #48 merged as `65461aea4a31e19e9b2adf9377374e43bb8b860a` after all CI jobs passed, including the PostgreSQL 17 self-profile regression suite, typecheck, lint, and build.
- [x] Migration `roshan_phase25_current_app_profile_20261016` applied to production. `public.get_my_app_profile()` returns only the caller's non-deleted profile and that user's permission codes; inactive accounts receive no permission codes. Function configuration has an empty `search_path`; anon EXECUTE is false and authenticated EXECUTE is true.
- [x] Simulated authenticated receptionist verification after applying the migration returned role `receptionist`, active status, 20 assigned permission codes including `visits.create`, while direct RLS-protected reads still returned zero rows. The verification used a rolled-back, read-only transaction and changed no account data.
- Remaining deployment gate: Vercel production deployment is blocked by the team's build-rate limit. The latest READY production deployment is still on the earlier commit, so the browser-level receptionist/doctor/super-admin login and visit-creation smoke test remains pending until a new build can deploy. Do not describe the UI fix as production-live until that smoke test passes.


## Execution batch I — 40 clinical UI/workflow items delivered to main — 2026-10-17

**Result:** all 40 implementation deliverables from the clinical UX workstream have been merged into `main` in commit [`f08ad543`](https://github.com/crauch2088-source/roshan-health-hub/commit/f08ad543cefa8e94aff4500d6361d71f4aa3060f) via [PR #49](https://github.com/crauch2088-source/roshan-health-hub/pull/49). This records implementation delivery only; it does not mark the application production-ready.

### Completed deliverables (40/40)

**Design system and navigation (1–12)**
1. Refreshed semantic teal/ink color tokens while preserving light/dark token structure.
2. Increased shared corner-radius treatment for the clinical workspace.
3. Added a subtle, low-contrast clinical canvas background.
4. Added reusable surface, patient-context, field-label and tab styling.
5. Added restrained page-enter motion with a reduced-motion override.
6. Improved shell spacing and working-canvas width.
7. Clarified global-header hierarchy and surface treatment.
8. Refined desktop navigation rail contrast, active state and target height.
9. Refined mobile bottom-navigation surface and safe-area padding.
10. Added source-level responsive/safe-area regression guards.
11. Added source-level keyboard tab, selected-state and visible-focus regression guards.
12. Added regression guards for dark semantic tokens, reduced motion and print styling.

**Consultation workflow (13–22)**
13. Made consultation tabs bilingual.
14. Added semantic tablist/tab/tabpanel roles and selected state.
15. Added arrow/Home/End keyboard navigation.
16. Improved the patient-context banner.
17. Made visit number more prominent.
18. Improved MRN, age/sex, department and doctor information hierarchy.
19. Preserved LTR rendering for MRNs in RTL screens.
20. Added unsaved-note confirmation on tab change and browser navigation/unload.
21. Added a collapsed optional local-only clinical review checklist that does not block emergency care.
22. Added automated consultation regression coverage for tabs, unsaved-note warnings and the optional checklist.

**Laboratory workflow (23–36)**
23. Debounced catalogue search.
24. Sanitized search input before composing PostgREST filters.
25. Added an explicit catalogue-loading state.
26. Added a clear catalogue-error state and no-submit explanation.
27. Improved search/category controls and category counts.
28. Exposed selection state using accessible `aria-pressed`.
29. Added selected-test subtotal estimation.
30. Improved selected-test summary and desktop sticky placement.
31. Added bilingual accessible names to removal controls.
32. Added a clinical-justification reminder for urgent priority.
33. Disabled submission for unresolved patient or catalogue error.
34. Preserved idempotency key and atomic order-plus-invoice RPC.
35. Added a bilingual five-stage worklist indicator from persisted status.
36. Added abnormal-result acknowledgement and blocked verification while edits are unsaved; critical-value escalation remains intentionally unimplemented until governed thresholds/policy exist.

**Prescription safety and correctness (37–40)**
37. Added pure validation for empty prescriptions, missing medication/dose/frequency/duration and invalid quantity.
38. Enforced prescription completeness before calling the existing atomic RPC.
39. Added bilingual clinician-entered dosing safety text; the system does not infer doses.
40. Added pediatric age/weight warnings distinguishing missing weight from unreadable/unavailable weight; no automatic dose calculation was added.

### Verification and release boundary

- PR #49 head `712f0968ae15dfe333a575482da27de0fa5e7496` passed all 10 application CI jobs and the PostgreSQL 17 integration job in [run #39010816932](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39010816932) and [run #39010816947](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39010816947).
- Authenticated, read-only preview smoke test: [TinyFish run #55bf12a1](https://agent.tinyfish.ai/runs/55bf12a1-5cef-42f5-9a5f-093d79d6b794). The app shell loaded, 23 navigation sections were reachable, RTL/LTR switching and search overlay worked, and dashboard/patient/visit/appointment/pharmacy/lab/billing pages rendered expected empty states. No records were created, edited, deleted, or submitted.
- Code-scanning open-alert query returned zero open alerts for the reviewed branch; this does not prove the absence of all security issues.
- Post-merge main CI completed successfully: CodeQL [#39012087070](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39012087070) and all 10 application jobs in [#39012087462](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39012087462) passed. The follow-up master-plan documentation commit `761b6eaf72a2ba387de2de1179fa350bae538878` also passed all 10 application jobs in run [#39012155869](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39012155869).
- Vercel automatically started a production-target build for merge SHA `f08ad543`; it was explicitly canceled before completion because release gates remain open. Latest previously verified READY production deployment is still `1d23c39d15b3cd9399c81169830086694bcafc6`. No production release of this redesign is claimed.
- Remaining gates: clinician approval of pediatric wording; actual phone screenshots for RTL/LTR and light/dark/print; live keyboard/screen-reader review; full synthetic-data end-to-end workflows; and migration-history parity plus the broader authorization/security review.
- The current live DB contains 93 applied migration records. Read-only aggregate verification found 56/56 public tables with RLS, 44 public SECURITY DEFINER functions, zero anon EXECUTE on those functions, 22 authenticated-callable SECURITY DEFINER functions, and function-level `search_path` configuration on all 44. Supabase advisors still report `pg_trgm` in `public`, the authenticated SECURITY DEFINER warning, and disabled leaked-password protection.
- Read-only operational counts at the same checkpoint: one soft-deleted patient, seven soft-deleted visits, zero queue tickets, zero invoices, zero payments, and 16 audit rows. These rows were not changed.
- Current raw master-document checkbox count before this append was 120 checked / 230 total, but historical execution logs duplicate checklist items, so that raw ratio is not a reliable weighted product-readiness metric. Do not count this 40-item batch as 40 additional production-ready checklist gates.


## Latest runtime verification correction — 2026-10-17

- Authenticated read-only production smoke run [d84bd3b6-1896-4c55-b712-32587b5d6806](https://agent.tinyfish.ai/runs/d84bd3b6-1896-4c55-b712-32587b5d6806) initially opened the deployed app as an authenticated General Manager. Dashboard, Patients, Visits, Queue, Pharmacy, Lab and Billing routes loaded; metrics/empty states showed zeros/no records. The browser session then ended around the language-toggle interaction, redirecting to `/auth`; the run could not reauthenticate. This timing alone does **not** prove that language switching caused logout.
- A focused follow-up on the preview [eb010868-8414-473c-a9f8-b9f7ed8a8d9d](https://agent.tinyfish.ai/runs/eb010868-8414-473c-a9f8-b9f7ed8a8d9d) found the profile signed out, but confirmed the language toggle itself switched Arabic RTL to English LTR without redirecting or signing out. Therefore record the production logout as an **unconfirmed session-expiry/reproduction issue**, not a confirmed language-toggle defect.
- The saved browser profile currently has no site sign-in recorded for the production or preview domains. A secure setup session for the canonical production URL has been created; user must sign in and save the profile before authenticated production E2E can continue. No credentials were requested or exposed in chat.
- Current main source head after the plan update is `761b6eaf72a2ba387de2de1179fa350bae538878`. CI for the code merge and plan documentation is green. Production-target builds for `f08ad543` and `761b6eaf` were explicitly canceled before completion because clinical wording review, actual device/accessibility QA, and full synthetic-data E2E remain release gates. Latest previously verified READY production SHA remains `1d23c39d15b3cd9399c81169830086694bcafc6`.
- Read-only RLS policy inspection surfaced child-table policies on `invoice_items`, `lab_order_items`, and `prescription_items` whose visible expressions check permission but do not themselves show a parent-branch predicate. The existing draft PR #34 targets related clinical child-row isolation but is coupled to an insurance prior-authorization policy and has unresolved migration parity. Treat this as a high-priority follow-up for focused parent-branch authorization tests; do not merge the combined PR or apply its migration until split/reviewed and isolated CI passes.


## Execution batch II — 50 parent-branch authorization regression checks — 2026-10-17

**Verified runtime QA:** Authenticated read-only production browser run [ef4ba3bc](https://agent.tinyfish.ai/runs/ef4ba3bc-7a56-4444-aef1-f76e3be29147) confirmed a valid General Manager session, all 23 sidebar routes, Arabic RTL and English LTR layout, session persistence after language switching, and no observed console/HTTP errors. It performed no writes. Production data pages showed zero active rows. This verifies the currently deployed version, not the pending UI redesign or the source-only SQL in the security PRs.

**Source-only security work delivered for review:**
- [PR #50 — invoice item branch isolation](https://github.com/crauch2088-source/roshan-health-hub/pull/50): focused invoice_items policy patch plus PostgreSQL 17 fixture. The dedicated integration workflow passed; full application CI run [#39014063654](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39014063654) passed all 10 jobs. The Vercel preview check passed. The PR remains draft because it is a proposed SQL change and must not be confused with production application.
- [PR #51 — 54 parent-branch authorization regressions](https://github.com/crauch2088-source/roshan-health-hub/pull/51): scoped policies for certificates, medical_certificates, patient_discounts, procedure_orders, and procedure_results; added private.app_has_procedure_order_branch_access with pinned empty search_path and restricted grants. The dedicated PostgreSQL 17 test passed on [run #39014128392](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39014128392); full app CI [#39014128414](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39014128414) passed all 10 jobs; Vercel preview check passed. The first fixture attempt failed because the disposable test role lacked USAGE on the private schema; this was fixed in the fixture and the rerun passed.
- These changes are deliberately **not applied to the live Supabase database**. Migration-history/replay parity and broader adversarial authorization review remain mandatory. The broader draft PR #34 still includes insurance/certificate/discount scope and is not merged; do not apply its migration as-is.
- Live policy inventory also confirms missing explicit parent-branch predicates on followups and queue_tickets; queue delete remains super-admin-only. Track these as next focused work, and keep the existing queue-date/atomic workflows intact.

### The 54 regression checks in PR #51

1. certificates SELECT shows only the current branch's row.
2. Cross-branch certificate UPDATE affects zero rows.
3. Same-branch certificate UPDATE succeeds.
4. Cross-branch certificate INSERT is rejected.
5. Same-branch certificate INSERT succeeds.
6. Cross-branch certificate DELETE affects zero rows.
7. Same-branch certificate DELETE succeeds.
8. Rejected certificate INSERT leaves no row.
9. medical_certificates SELECT shows only the current branch's row.
10. Cross-branch medical-certificate UPDATE affects zero rows.
11. Same-branch medical-certificate UPDATE succeeds.
12. Cross-branch medical-certificate INSERT is rejected.
13. Same-branch medical-certificate INSERT succeeds.
14. Cross-branch medical-certificate DELETE affects zero rows.
15. Same-branch medical-certificate DELETE succeeds.
16. Rejected medical-certificate INSERT leaves no row.
17. patient_discounts SELECT shows only the current branch's row.
18. Cross-branch patient-discount UPDATE affects zero rows.
19. Same-branch patient-discount UPDATE succeeds.
20. Cross-branch patient-discount INSERT is rejected.
21. Same-branch patient-discount INSERT succeeds.
22. Cross-branch patient-discount DELETE affects zero rows.
23. Same-branch patient-discount DELETE succeeds.
24. Rejected patient-discount INSERT leaves no row.
25. procedure_orders SELECT shows only the current branch's row.
26. Cross-branch procedure-order UPDATE affects zero rows.
27. Same-branch procedure-order UPDATE succeeds.
28. Cross-branch procedure-order INSERT is rejected.
29. Same-branch procedure-order INSERT succeeds.
30. Cross-branch procedure-order DELETE affects zero rows.
31. Same-branch procedure-order DELETE succeeds.
32. Rejected procedure-order INSERT leaves no row.
33. procedure_results SELECT derives access from the parent procedure order.
34. Cross-branch procedure-result UPDATE affects zero rows.
35. Same-branch procedure-result UPDATE succeeds.
36. Cross-branch procedure-result INSERT is rejected.
37. Same-branch procedure-result INSERT succeeds.
38. Cross-branch procedure-result DELETE affects zero rows.
39. Same-branch procedure-result DELETE succeeds.
40. Rejected procedure-result INSERT leaves no row.
41. Missing patient IDs fail closed in the patient-branch helper.
42. A tuple with no patient and no visit fails closed.
43. A nonexistent procedure-order ID fails closed.
44. A certificate cannot combine a current-branch patient with a foreign-branch visit.
45. A procedure order cannot combine a current-branch patient with a foreign-branch visit.
46. A rejected mixed-branch certificate leaves no row.
47. A rejected mixed-branch procedure order leaves no row.
48. The foreign-branch certificate remains unchanged after attempted writes.
49. The foreign-branch medical certificate remains unchanged after attempted writes.
50. The foreign-branch procedure result remains unchanged after attempted writes.
51. A certificate with same-branch patient and visit IDs is rejected if the visit belongs to a different patient.
52. A procedure order with same-branch patient and visit IDs is rejected if the visit belongs to a different patient.
53. A rejected mismatched certificate leaves no row behind.
54. A rejected mismatched procedure order leaves no row behind.

### Additional invoice-item checks in PR #50

- Invoice-item SELECT is parent-invoice branch scoped.
- Cross-branch INSERT is rejected; same-branch INSERT succeeds.
- Cross-branch UPDATE and DELETE affect zero rows; same-branch UPDATE and DELETE succeed.
- The invoice-branch helper denies nonexistent invoice IDs and is not directly executable by anon.
- The dedicated PostgreSQL 17 workflow passed, and the normal app CI passed all 10 jobs.

### Release gates remain open

- [ ] Reconcile the historic migration ledger against canonical, replayable source migrations before applying any of these proposed policy changes.
- [x] Add isolated negative/positive tests for followups and queue_tickets; preserve the queue delete super-admin-only invariant. PR #52 now covers cross-branch reads/writes, mixed-branch and same-branch mismatched patient/visit links, branchless-parent fail-closed behavior, helper grants, and the super-admin-only queue delete invariant. Dedicated PostgreSQL 17 run [#39016952455](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39016952455) and all 10 application CI jobs [#39016952459](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39016952459) passed. The SQL remains source-only and unapplied.
- [ ] Complete broader cross-branch testing of every authenticated SECURITY DEFINER RPC and direct table policy.
- [ ] Complete clinician review of pediatric safety wording, actual-phone RTL/LTR/light/dark/print screenshots, keyboard/screen-reader review, and synthetic-data end-to-end clinical workflows.
- [ ] Keep production on the previously verified READY deployment until all release gates pass; successful preview and CI are not a production release.


## Execution continuation — follow-up RLS and RPC review — 2026-10-17

- Live read-only policy inventory reconfirmed that the production policies for `invoice_items`, `lab_order_items`, `prescription_items`, `certificates`, `medical_certificates`, `patient_discounts`, `procedure_orders`, `procedure_results`, `followups`, and `queue_tickets` still visibly enforce app permissions without a parent-branch predicate. These remain real production authorization gaps until a reviewed migration is applied; repository PRs alone do not change the live database.
- PR #52 was strengthened with `private.app_has_patient_visit_branch_access(uuid, uuid)`, which composes the existing branch helper with a patient/visit linkage check. It has a pinned empty `search_path`, denies PUBLIC/anon execution, grants authenticated execution for RLS, and tests mismatched patient/visit links even when both IDs belong to the same branch. Dedicated PostgreSQL 17 and full CI are green as above.
- The production function inventory found 22 authenticated-callable public SECURITY DEFINER functions; all observed definitions had an empty `search_path`, and none of the sampled functions was executable by `anon`. Reviewed overloads of `create_billing_invoice_atomic` and `create_lab_order_with_invoice_atomic` showed that legacy signatures without idempotency request IDs are not executable by authenticated callers; only the newer idempotent overloads are granted. This is a bounded inspection, not a complete adversarial RPC audit.
- Supabase Security Advisor still reports three warning classes: `pg_trgm` in `public`, 22 authenticated-callable SECURITY DEFINER functions, and leaked-password protection disabled. Do not blindly revoke authenticated RPC execution: those functions are current application write paths. Enable leaked-password protection after validating the correct Auth settings path and checking for user-facing impact; do not claim this setting is enabled.
- Vercel team/project inspection currently returns 403 for scope `team_roshan45` with an explicit instruction to grant/re-authorize team access. The current connector cannot verify latest production deployment metadata until this access is restored. Do not substitute a guessed project/team or change deployment settings without access.
- PR #50 (invoice items), PR #51 (certificates/discounts/procedure child rows), PR #52 (followups/queue) and PR #34 (broader clinical child rows with insurance coupling) remain source-only candidates. No candidate RLS SQL was applied to production. The canonical migration sequence and content-level parity for the 93 live migration ledger entries remain unresolved.
- Immediate next steps: (1) recover Vercel team access; (2) reconcile the complete live migration ledger with source definitions and an ordered replay plan; (3) split PR #34's insurance-specific policies from clinical child-row isolation and remove redundant overlapping policy candidates; (4) run a complete role × operation × branch authorization matrix against a disposable PostgreSQL fixture; (5) only then package reviewed changes into canonical timestamped migrations with rollback notes.


## Continuation verification addendum — 2026-10-17

- PR #53 now isolates prescription and lab-order child-row RLS from the insurance-coupled PR #34. Its PostgreSQL 17 integration passed [run #39017468423](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39017468423), prescription atomicity integration passed [#39017468484](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39017468484), and full application CI passed all 10 jobs [#39017468422](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39017468422). The PR remains draft/source-only because migration parity is still a release gate.
- PR #52 now tests same-branch patient/visit mismatch in addition to cross-branch authorization. PostgreSQL 17 run [#39016952455](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39016952455) and full CI [#39016952459](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39016952459) passed.
- Migration reconciliation was advanced in [`docs/DB_MIGRATION_RECONCILIATION.md`](DB_MIGRATION_RECONCILIATION.md): read-only fingerprints and source comparisons now cover fourteen recent entries through Phase 25. Executable source matches were observed for the listed candidates, with comment-only or trailing-newline differences documented where applicable. The older historical sequence remains unreconciled; do not replay it or apply the RLS candidates.
- Main documentation CI for the prior reconciliation update passed all 10 application jobs in [run #39017386467](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39017386467); CodeQL [#39017386850](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39017386850) passed.
- Vercel access is still blocked by 403 scope authorization for `team_roshan45`; the connector explicitly requires team access to be re-granted. No deployment settings or live DB policies were changed.


## Execution continuation — finance-only security split — 2026-10-17

- [PR #53 — prescription/lab child-row isolation](https://github.com/crauch2088-source/roshan-health-hub/pull/53) has a dedicated PostgreSQL 17 integration pass and all 10 application CI jobs passing. It is separate from insurance prior-authorization work and remains draft/source-only pending the migration replay gate.
- [PR #54 — finance RPC-only writes, isolated from insurance](https://github.com/crauch2088-source/roshan-health-hub/pull/54) was created from main. It covers cashbox transactions, expenses, payments, supplier bills and supplier payments only; it does not revoke DML or change policies on insurance tables. Dedicated PostgreSQL 17 run [#39017930879](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39017930879) passed, and full CI [#39017930924](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39017930924) passed all 10 jobs. It also proposes retiring authenticated execution of the legacy add_cashbox_entry RPC after a default-branch source search found the active UI uses post_cashbox_entry instead. This is still a source-only candidate, not a live database change.
- Migration reconciliation now includes source comparisons/fingerprints for 14 recent applied entries through Phase 25, including Phase 7 prescription atomicity, Phase 8/13–16 billing functions, the privileged-role guard, and Phases 21–25. The 79-row historical baseline and remaining earlier ledger entries still require complete source mapping and disposable clean replay; do not treat this partial progress as a release gate closure.
- Current main documentation commits through de28027ac8798e025f22f68a122b132ebf1b6029 record the audit. Vercel team access remains 403 for team_roshan45, so latest deployment metadata cannot be verified or changed through the current connector.


## Context continuity documentation update — 2026-10-17

- Replaced the outdated, prompt-like root `README.md` with a durable context entrypoint: project purpose and stack, verified implementation/security status, merged vs source-only work, exact open release gates, operating rules, and a prioritized handoff checklist. The README directs future sessions to read this file first, then the master plan, migration reconciliation, and plugin/tooling map, and to re-verify live state before acting.
- Preserved the former root README as [`docs/ORIGINAL_PRODUCT_BRIEF.md`](ORIGINAL_PRODUCT_BRIEF.md) for traceability. Credential-like patterns were screened/redacted in the archived text; a post-write scan found no JWT-shaped token, `sb_secret` value, or PostgreSQL connection URI.
- Atomic documentation commit [`039a426797f8cfbbad0080200690ab1761abd22a`](https://github.com/crauch2088-source/roshan-health-hub/commit/039a426797f8cfbbad0080200690ab1761abd22a) changed only `README.md` and `docs/ORIGINAL_PRODUCT_BRIEF.md`; both files were re-read from GitHub and their content/ends verified. No app code, live SQL, or deployment settings changed.
- CI for that docs commit: all 10 application jobs passed in [run #39018590529](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39018590529); CodeQL [run #39018590577](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39018590577) remained in progress at the last poll. Re-check it in the next session.
- GitHub branch lookup reported `main` unprotected with no required status checks at this snapshot. Treat this as a governance hardening task; do not change repository protection blindly without checking current project workflow requirements.
- Continue with the priorities in the root README: reauthorize Vercel team scope, reconcile all live migration ledger entries and stale inventory header, establish a clean disposable replay, complete the role/operation/branch authorization matrix, and only then review/merge/apply the SQL candidates.


## No-cost security-test continuation — 2026-10-17

- User explicitly declined all paid services. Do not create Supabase branches/projects or incur usage charges. Continue isolated PostgreSQL 17 integration through GitHub Actions runners for this public repository.
- Updated PR #50: added parent-changing `invoice_id` UPDATE denial and strict original-row postconditions. PostgreSQL 17 integration and CI passed at `ba5f742a05bb912ec169a056e9c29a0b08967f64`.
- Updated PR #51: added certificate/procedure-order parent reassignment, patient-discount cross-branch reparenting, authenticated helper EXECUTE assertions, and branch-B row postconditions. Parent-branch integration passed at `70eb7a38e66f448c0a4f5cb2a28d3c1d30207c52`; recheck general CI before any merge.
- Updated PR #52: added follow-up/queue parent-changing UPDATE cases; queue/follow-up integration and CI passed at `2fdb444743603ad383e4c774cc35060f3aea21e7`. Queue DELETE is intentionally super-admin-only; a non-super-admin denial does not independently prove branch-specific DELETE semantics.
- Updated PR #53: added prescription-item and lab-order-item parent reassignment tests; corrected the lab FK column to `order_id` after CI caught the mismatch. PostgreSQL 17 integration and CI passed at `8187d1d95e2b6d485163a8805947abee71ad086e`.
- PR #54 finance-only RPC integration and CI passed on `f002a7944bc219fbca305901434d9ccbd42ed8a9`; exhaustive role × RPC and full-chain replay remain gates.
- No PR merged and no production SQL/policies/grants/data changed. Full migration replay remains blocked by the missing trustworthy pre-migration baseline and the intentionally redacted one-time identity link. Do not guess a baseline.
- Detailed findings and check links: [SECURITY_PR_REVIEW.md](SECURITY_PR_REVIEW.md).


## No-cost source parity gate — 2026-10-17

- User explicitly disallows any paid service usage. Do not create Supabase branches/projects or incur charges. Focused PostgreSQL 17 tests use free GitHub Actions runners for this public repository.
- Added `scripts/verify-migration-source-parity.py` and wired it into `.github/workflows/ci.yml`. The verifier reads repository files only and makes no database connection. Its isolated simulation passed: **93 mappings, 92 normalized source hashes verified, one intentionally redacted placeholder**. The dedicated workflow passed; on main commit `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`, all 13 checks were successful, including CodeQL for Python and JavaScript/TypeScript.
- PR #54 gained authenticated/anon EXECUTE assertions for all six finance write/reversal RPCs. Its dedicated finance integration passed on `d0d818a9988216cdfc52723d7e9ffae7402a50d1`; general CI was still in progress at last poll. Re-query before merge.
- Regression updates: #50 parent-changing invoice-item UPDATE; #51 certificate/procedure/discount parent changes plus helper-grant and fixture postconditions; #52 follow-up/queue parent changes; #53 prescription/lab child parent changes. Dedicated PostgreSQL 17 suites passed on their latest noted test heads; PR #51's full CI passed on `70eb7a38e66f448c0a4f5cb2a28d3c1d30207c52`.
- All PRs #50–#54 remain open/draft and unmerged. No production SQL, grants, policies, or rows were changed.
- The 93-entry source comparison remains a text-level parity check, not a clean-chain replay or semantic proof. Full replay is blocked by absence of a reviewed pre-migration baseline and one intentionally redacted environment-specific identity-link migration. Do not invent the baseline or run replay against production.
- Evidence and limitations: [security review](SECURITY_PR_REVIEW.md), [source parity manifest](recovered-migrations/source-parity-report.json), [migration reconciliation](DB_MIGRATION_RECONCILIATION.md).


## Latest no-cost regression results — 2026-10-17

- PR #51 added a NULL-patient/branch-B-visit insert denial for `procedure_orders`; the dedicated parent-branch integration and all PR checks passed on `4af41b893b12427b15577f2312b13e4d92785c20`.
- PR #52 added equivalent NULL-patient/branch-B-visit denial tests for both `followups` and `queue_tickets`, including postconditions that no denied row remains; all PR checks passed on `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`.
- PR #54's complete CI and expanded finance RPC privilege integration passed on `d0d818a9988216cdfc52723d7e9ffae7402a50d1`.
- Main docs/CI commit `696e422d959b308c5087339af74b541d941fa205` passed all 13 checks: application CI/integration checks, source-parity verifier, and both CodeQL language analyses. Vercel still reports the build-rate-limit check failure for newer docs commits; latest READY deployment checked is earlier docs-only SHA `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`. Do not force deployment.
- All PRs #50–#54 remain open/draft and unmerged. No paid resources or production SQL/policy/grant/data changes were made. Full-chain replay remains a release gate: no reviewed pre-migration baseline, plus one intentionally redacted environment-specific identity-link migration.


## Final no-cost security regression pass — 2026-10-17

- All five security PR heads are still open/draft/unmerged, and every workflow on each latest head is green: #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64`; #51 `4af41b893b12427b15577f2312b13e4d92785c20`; #52 `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`; #53 `8187d1d95e2b6d485163a8805947abee71ad086e`; #54 `670185193a0400634fe49f7e2e004b4223611ce3`.
- #51/#52 now include negative insert tests where `patient_id IS NULL` but `visit_id` points to branch B; they assert the row is rejected and leaves no residue. #54 verifies grants/denials for all six finance write/reversal RPCs and checks each exists as SECURITY DEFINER with a fixed `search_path`.
- Main commit `1c996bcc906e0739b5c693f2fe3968acdc72b9c6` passed all 13 checks (application CI/integration, source-parity job, and both CodeQL language analyses). This doc-only update requires fresh CI/CodeQL verification before considering its SHA fully green.
- Vercel's latest status remains the build-rate-limit check failure; latest READY deployment checked is earlier documentation-only SHA `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`. No attempt was made to bypass rate limits or force deployment.
- No paid resources, production SQL, policies, grants, or rows were changed. Full-chain replay remains a release gate because the trustworthy pre-migration baseline is absent and one identity-link migration is intentionally redacted. Continue with free GitHub Actions fixtures and source-level recovery only; do not invent a baseline.


## Replay-safe redacted migration policy validation — 2026-10-17

- Added `docs/recovered-migrations/replay-safe/20260818191254_fix_patients_rls_and_admin_link.sql`: derived from the stored migration with exactly one environment-specific identity UPDATE omitted; the four patient RLS policies are preserved. The original public source remains intentionally redacted and the replay-safe variant is not a canonical deployment migration.
- Added `db/tests/redacted_migration_policy_replay_fixture.sql` and `db/tests/redacted_migration_policy_replay_integration.sql`; GitHub Actions PostgreSQL 17 applies the synthetic fixture, runs the policy repair, verifies policy names/commands/permission predicates, tests SELECT/INSERT/UPDATE/DELETE, and asserts the synthetic app user remains unlinked.
- Main commit `ed1218e35121d9de08845fcc943fb8a3252717a6` passed all 14 checks, including the new isolated replay job, source-parity verifier, application CI, and both CodeQL analyses.
- Full-chain replay remains blocked by the missing trustworthy pre-migration baseline. Do not claim all 93 migrations replay cleanly and do not use production as a test target. No paid Supabase branch/project was created.


## Final verification after replay-safe migration checks — 2026-10-17

- Latest main SHA `ddf7d3b5b72d18bbfd13598472ce4db480c09bca` passed all **15/15** checks: application CI, source-parity manifest plus replay-safe variant validation, isolated PostgreSQL 17 patient-policy replay test, and both CodeQL language analyses.
- The source-parity verifier now enforces that the replay-safe redacted-migration variant contains no email/identity UUID and no identity UPDATE, while preserving all four patient RLS policies.
- PRs #50–#54 remain open/draft/unmerged; latest head checks are all green. No paid resources or production SQL/grant/policy/data mutations were performed.
- Full 93-migration replay is still blocked by the absence of a reviewed pre-migration baseline. Vercel's current-main status points to a build-rate-limit failure; do not force deployment. Last READY deployment inspected is earlier docs-only SHA `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`.


## Live continuation verification — 2026-10-17 10:30 UTC

This entry supersedes earlier status snapshots where they conflict. Live sources queried: GitHub repository/commits/check runs/PRs, Vercel production deployments, Supabase project/migration history and advisors.

### Verified current baseline
- Latest `main` observed: `2143f63624993a7d8f9bfbf71c251d129fe0b691`. GitHub check-run endpoint returned **14/14 success** on that exact SHA.
- Latest READY production deployment observed for Vercel project `roshan-health-hub`: SHA `ddf7d3b5b72d18bbfd13598472ce4db480c09bca`. This is behind main; no claim that the latest main commit is deployed. Do not force a new deployment during the provider build-rate-limit condition.
- Supabase `jewzonxplxhogqrnhosl`: `ACTIVE_HEALTHY`, PostgreSQL 17.6, eu-west-1; 93 applied migrations, latest `20261016222009_roshan_phase25_current_app_profile_20261016`.
- Live Security Advisor at 2026-10-17 10:29 UTC: 22 authenticated-callable public SECURITY DEFINER warnings, one public-schema `pg_trgm` warning, and leaked-password protection warning. Performance Advisor: 90 unused-index findings. Triage individually; do not blanket-revoke RPCs or drop indexes.
- PR #50–#54 remain open/draft/unmerged. Current heads: #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64`; #51 `4af41b893b12427b15577f2312b13e4d92785c20`; #52 `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`; #53 `8187d1d95e2b6d485163a8805947abee71ad086e`; #54 `670185193a0400634fe49f7e2e004b4223611ce3`. The current PR list returned base SHAs that differ across the five drafts and predate the observed main SHA; treat this as a stale-base/dependency signal and refresh each PR's base and CI before merge decisions.
- No Supabase SQL, policy/grant change, production data mutation, paid resource creation, or forced deployment was performed.

### Current hard blockers and execution order
1. Keep the clean-replay release gate closed: 92/93 normalized source matches; the one unmatched source is the intentionally redacted identity-link migration; a reviewed trustworthy pre-migration baseline and full ordered replay proof remain absent.
2. Inspect each security PR's exact diff, changed-file overlap, commit ancestry, and live CI against current main. Rebase/update bases only when the resulting diff is understood; do not merge drafts automatically.
3. Continue free isolated PostgreSQL 17 adversarial tests (role × operation × branch, parent reassignment, malformed/null linkage, direct finance DML denial, RPC authorization and retry/idempotency). Keep synthetic fixtures only.
4. Review advisor findings one by one; no production privilege changes until each function's callers and authorization contract are established.
5. Continue app/UX acceptance after the security/replay gates, then verify production SHA and smoke-test the canonical domain.

### Cost and environment guardrails
- Do not create a Supabase development branch/project without explicit agreement to the quoted nonzero recurring cost (last quote: US$0.01344/hour).
- The replay-safe redacted-migration SQL is an isolated test artifact, not a canonical deployment migration.
- CI success is not production deployment evidence. Use exact SHA equality plus READY/alias checks for release verification.


## Finance RPC NULL-direction finding and verified fix — 2026-10-17 10:37 UTC

### Source finding
Review of PR #54 found a SQL three-valued-logic edge case in `public.post_cashbox_entry`: `IF _direction NOT IN ('deposit','withdrawal')` is not true for a NULL input, allowing NULL to reach the CASE expression and be treated as a withdrawal. This was a defect in a draft migration, not a production database finding.

### Change and test evidence
- Regression assertion committed first: `ed1c14b218d2dab8c7dc7e862f273e3e990a9e42`.
- Validation fixed in `53483d87bb30f3bbc6fe4e95f4e266d1f763b96f`: reject NULL explicitly.
- Added `workflow_dispatch` to the finance integration workflow on branch head `c15d69ab96b3ba7be8c45212bee3511130bd0bcd`; registered the isolated workflow on main in `e4b1a6d0cea31d3e6e3976451a331bd586811ff6` without bringing candidate SQL onto main.
- PostgreSQL 17 finance integration passed: [run #39025549230](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025549230). Main CI passed on `e4b1a6d`; CodeQL was still in progress at the last check.
- PR #54 remains open/draft; the fix is not deployed or applied to Supabase.

### Next
1. Verify fresh CI/CodeQL for the documentation commit and verify its Vercel state without forcing a deployment.
2. Continue reviewing draft SQL for NULL validation, idempotency, branch ownership, and direct-write permission gaps.
3. Preserve the full migration replay gate and do not merge #50–#54 until the base/replay gates are resolved.


## Live status refresh — 2026-10-17 10:45 UTC

- Current main documentation commit checked: `147e1b2e978bb4a0ee65da92117a5448f1a03863`; GitHub reports 14 check runs and the associated main workflow run concluded successfully. See [main CI run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025657739) and [CodeQL run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025657774).
- All five security draft integration workflows have a successful result on their latest observed branch head:
  - PR #50 invoice-item branch isolation, SHA `ba5f742a05bb912ec169a056e9c29a0b08967f64`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39021158326).
  - PR #51 parent-branch isolation, SHA `4af41b893b12427b15577f2312b13e4d92785c20`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39022406414).
  - PR #52 queue/follow-up isolation, SHA `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39022409722).
  - PR #53 prescription/lab child isolation, SHA `8187d1d95e2b6d485163a8805947abee71ad086e`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39021361272).
  - PR #54 finance RPC-only writes, SHA `c15d69ab96b3ba7be8c45212bee3511130bd0bcd`: [manual PostgreSQL 17 run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025549230).
- These are isolated SQL fixture/integration passes, not evidence of applying candidate migrations to Supabase or of full historical migration replay. Keep all five PRs as drafts until branch ancestry, complete migration-source parity, grants/policies, and the reviewed baseline are reconciled.
- The five PR API snapshots report different base SHAs; do not assume their diffs are based on the same current main or merge them in a batch. Refresh base/head comparisons immediately before any integration decision.
- Vercel's latest listed READY production deployment remains SHA `4b4b871b6637bb85703336d3c6f47e4e3f3f0c1f`, behind current main. Do not force deployment while the build-rate-limit failure remains unresolved.
- No Supabase writes, production migration, PR merge, or paid-resource creation was performed during this refresh.
