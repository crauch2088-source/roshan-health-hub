# Roshan Health Hub — Master Plan to Production

**Single source of truth:** keep this plan updated until launch. Snapshot date: 2026-10-15. Repository: https://github.com/crauch2088-source/roshan-health-hub

## Operating rules
- Execute work directly with connected tools. Request any missing integration/permission explicitly.
- If a specific step repeatedly fails despite reasonable diagnosis, stop looping, ask the user to use Claude for that step, then resume the remaining plan.
- User authorizes changes to disposable test data/schemas; nevertheless verify environment and scope before destructive actions.
- Never expose or commit secrets, credentials, tokens, or real patient data.
- Production database changes, merges, and deployments require reviewed changes, tests, rollback readiness, and explicit release approval.
- Treat security advisor warnings as leads, not proof of exploitability. Preserve indexes unless workload evidence supports removal.

## Verified starting point
- Recent repository commits indicate PR #10 (SSR log redaction) and #11 (cashbox reversal concurrency) merged; merge commits include `533dcb5` and `4ae13ef`.
- PR #8 (shell redesign, page patterns, dashboard data accuracy) subsequently merged at `a64f804679aeaae7299b034176f2265ac1806db0`. Merge conflict resolution in `3667bafd` combined `test:guard` lists.
- PR #9 remains OPEN + DRAFT on `audit/roshan-health-hub-hardening-plan`, head `29a07b4b6327452a4f1eb24e7859cb3d42e402b0`; its CI passed, but its base SHA is stale (`209f5a0`) and it should remain a review-only plan PR until refreshed. PR #5 was CLOSED as superseded: current `main` already contains SSR redaction in `src/lib/redact.ts`, `src/lib/error-capture.ts`, and `tests/ssr-log-redaction.test.ts`.
- Branches seen: `main`, `audit/roshan-health-hub-hardening-plan`, `feat/nav-consistency-ux-pass`, `feat/responsive-shell-lab-ui`, `feat/shell-redesign`, `fix/cashbox-reversal-concurrency`, `fix/ssr-error-logging-redaction`, `fix/ssr-log-object-redaction`, `fix/vercel-node22-runtime`, `pr8-visual-artifacts`.
- Main `package.json` declares Node `22.x` and has `test:guard`, `typecheck`, `lint`, and `build` scripts.
- Vercel is now consolidated to one project: `roshan-health-hub` (`prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`), linked to `crauch2088-source/roshan-health-hub`, canonical verified domain `roshan-health-hub.vercel.app`, Node `22.x`. Duplicate project `roshan-health-hub-hjfy` was deleted via the connected Vercel account and verified absent; its project-specific `*.vercel.app` domain is retired. The retained production deployment is READY on `main` SHA `a64f804679aeaae7299b034176f2265ac1806db0`; a newer docs-branch deployment is preview-only and is not production.
- Connected Supabase project `jewzonxplxhogqrnhosl` is named “Project Name: Roshan Production”, ACTIVE_HEALTHY, PostgreSQL 17.6, region eu-west-1. Migrations extend through `20261014164131_roshan_cashbox_reversal_concurrency`.
- Supabase security advisor reports `pg_trgm` in `public` and 15 SECURITY DEFINER functions executable by `authenticated`. Read-only review found all 56 public tables have RLS enabled; no table grants `anon` SELECT/INSERT in the sampled inventory; no `anon` EXECUTE privilege on public SECURITY DEFINER functions; the 15 callable authenticated functions each contain an app permission check and have `search_path` set to empty. Branch checks are present in the branch-sensitive RPCs inspected. The two `stock_movements` policies target `public` but both enforce app permission and branch access, and neither is unconditional. This is a positive initial review, not yet a full adversarial authorization test.
- Supabase reports 79 applied migrations through `20261014164131_roshan_cashbox_reversal_concurrency`. The repository currently has a small set of legacy `db/*.sql` scripts and no timestamped `supabase/migrations` directory in the `main` tree; full migration-history parity is unresolved and is a significant reproducibility risk. Performance advisor reports 131 unused-index findings; do not drop indexes based on this signal alone. Schema inventory includes both `medicines` and `medicines_2`; verify usage before changing. No database writes or production deployments were performed during this inspection.
- GitHub native file update returned 403 “Resource not accessible by integration”; use the active Composio GitHub connection for repo writes.

## Phases and exit criteria

### 0. Baseline and ownership — IN PROGRESS
- [x] Confirmed `main` SHA `a64f804679aeaae7299b034176f2265ac1806db0` and successful GitHub Actions CI run #38649354331: install/lockfile, dependency security audit, patched TanStack versions, guard tests, typecheck, lint, and build passed.
- [x] Confirmed PR #5 was superseded by redaction code already present in `main`; closed it without merging. PR #9 remains a draft/open plan PR; its CI passed, but its base is stale.
- [x] Consolidated Vercel to the single project `roshan-health-hub`; removed duplicate `roshan-health-hub-hjfy`; verified only one matching project remains. Both projects’ Node setting had been aligned to `22.x` before deletion. Canonical verified domain is `roshan-health-hub.vercel.app`.
- [ ] Perform authenticated live smoke tests for login, role gates, patient lookup, queue, and server-rendered routes. Public HTTP smoke check completed on 2026-10-15: canonical production root and PR #12 preview root returned HTTP 200; direct `/insurance` on preview also returned HTTP 200 and returned the app shell only, with no patient data in server-rendered HTML. This verifies deployment reachability/SSR shell only, not login, authenticated behavior, or role/branch gates; those remain pending an authenticated browser session.
- [x] Verified PostHog `Default project` is connected but has no events; privacy configuration needs review before any clinic telemetry is enabled.
- [x] Confirmed Supabase target `jewzonxplxhogqrnhosl` is `Roshan Production`, `ACTIVE_HEALTHY`, PostgreSQL 17.6, region `eu-west-1`, migration head `20261014164131_roshan_cashbox_reversal_concurrency`; 56/56 public tables have RLS enabled. [ ] Reconcile 79 applied migrations with repository SQL artifacts; do not write to production while parity is unresolved.
**Exit:** pending authenticated runtime smoke tests, privacy review, and migration-history parity.

### 1. Security, privacy, and repository hygiene
- [ ] Audit current files/history for exposed credentials; report paths/types, never values. Rotate/revoke any real exposed credential before history rewriting.
- [ ] Verify secret scanning, dependency alerts, and code scanning availability.
- [x] Initial read-only review of all 15 authenticated-callable SECURITY DEFINER RPCs: no anon EXECUTE, empty `search_path`, and internal permission checks observed. [ ] Finish function-by-function adversarial tests for cross-branch IDs, invalid financial inputs, and branchless super-admin inventory/cashbox paths.
- [ ] Review RLS policies/grants for identity, patient, clinical, lab, pharmacy, inventory, finance, and insurance tables.
- [ ] Add automated unauthenticated, wrong-role, cross-branch, and forbidden-write tests.
**Exit:** no unresolved critical/high-risk access-control issue; repeatable checks and evidence.

### 2. Runtime and CI reproducibility
- [x] Align Node version in package.json, CI, lockfile, and the retained Vercel project at `22.x`.
- [ ] Run guard tests, typecheck, lint, production build, and dependency/security checks on a frozen candidate SHA.
- [ ] Verify SSR log redaction with synthetic tokens, cookies, UUIDs, emails, and query strings.
- [ ] Resolve lint/format debt narrowly; avoid unrelated sweeping rewrites.
**Exit:** reproducible green checks and documented deployment target.

### 3. Database and migrations
- [ ] Compare the 79 applied database migrations to repo `db/*.sql` artifacts; there is no timestamped `supabase/migrations` directory on `main`, so migration replay/parity is not yet reproducible.
- [ ] Determine whether `medicines` / `medicines_2` are active/legacy before any change.
- [ ] Verify FK/unique constraints, soft-delete behavior, audit relationships, pagination, and indexes.
- [ ] Test candidate migrations on a confirmed disposable dev branch/database; demonstrate backup/restore and rollback.
**Exit:** reviewed schema map, migration parity, recoverability; no unexplained drift.

### 4. Clinical workflows
- [ ] Test registration → duplicate detection/MRN → branch assignment → queue → visit.
- [ ] Test consultation, vitals, ICD-10 diagnosis, notes, prescriptions, referrals, follow-up.
- [ ] Test lab order → sample → processing → result entry/verification → clinician visibility.
- [ ] Test role-specific edit permissions, audit history, retries, double-submit, and network failure.
**Exit:** synthetic end-to-end clinical workflow matrix passes.

### 5. Pharmacy, inventory, and finance
- [ ] Test receiving batches, expiry, FEFO dispensing, stock movements/returns, and expired/negative stock prevention.
- [ ] Test concurrency/idempotency for dispensing, invoices, payments, cashbox entries/reversals, supplier bills/payments, and expenses.
- [ ] Insurance claims UI/RPC mismatch found and patched in draft PR #12: UI previously sent `invoiceId: null` while the database RPC requires a valid invoice. The draft now requires an invoice belonging to the selected patient, resets stale claim items when the insurance/invoice selection changes, and validates required fields before RPC. CI is green on head `a2cd2dd752d5577506674284db239865d1fc5459`; Vercel preview is READY. Still needs human review and an authenticated smoke test; not merged/deployed.
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
- [ ] Obtain explicit approval before production migrations, merge, or deploy.
- [ ] Deploy in a controlled window; smoke-test auth/roles, patient, queue, visit, lab, pharmacy, payment, and reports using approved test workflow.
- [ ] Monitor redacted logs and errors; roll back if critical acceptance checks fail.
**Exit:** release report with deployed SHA, smoke-test evidence, monitoring status, and remaining non-blocking issues.

### 10. Stabilization
- [ ] Monitor first day/week for errors, performance, integrity, and user blockers.
- [ ] Fix critical issues via isolated changes and regression tests; verify backups and privacy-safe analytics.
**Exit:** stable service and agreed maintenance cadence.

## Immediate next actions
1. Review PR #12 (insurance claim invoice-link fix), run an authenticated smoke test on its preview, and merge only after review.
2. Run authenticated runtime smoke tests on `https://roshan-health-hub.vercel.app` and confirm role/branch gates.
3. Reconcile the 79 applied Supabase migrations against repository artifacts; establish a canonical migration workflow before any DDL changes.
4. Review draft PR #13, which adds a DB-side invariant for insurance claim amount splits and a SQL contract test. The patch has not been applied to production; first establish a canonical migration workflow and run behavioral tests on disposable/staging Supabase. Continue adversarial tests for all 15 authenticated-callable SECURITY DEFINER RPCs, especially invalid inputs and cross-branch resource IDs.
5. Classify pharmacy inventory reconciliation before changing quantities: current read-only snapshot shows all 9 active medicine rows have `stock_quantity` different from the sum of non-deleted batch `quantity_remaining` (8 have no remaining batch quantity; ceftriaxone has 1,994 legacy vs 498 batch units). This may reflect intentionally separate legacy/batch stock, so do not auto-sync; trace dispense/receive semantics and UI source-of-truth first.
6. Safely scan Git history for credentials without printing values; determine whether rotation is required.
7. Review PostHog privacy settings before enabling any telemetry.
8. Refresh PR #9 against current `main` and keep it draft until its contents and CI are current.

- 2026-10-15: Added draft PR #14 for atomic pharmacy batch receiving. The batch-receipt UI now calls a single RPC instead of separate client-side inserts/updates; the SQL validates `pharmacy.create`, configured branch, positive whole-unit quantity, non-negative prices, and date ordering, locks the medicine row, then writes batch, aggregate stock, and movement in one transaction. Added static regression guards to `test:guard`. SQL remains under `db/` (not applied), because migration-history parity is still unresolved. CI run #38656903437 was still in progress at the time of this entry; no database changes, merges, or production deployments were made.

- 2026-10-15: Confirmed both connected Supabase accounts expose only the same project, `jewzonxplxhogqrnhosl` (PostgreSQL 17.6, ACTIVE_HEALTHY); no separate staging project is available. Do not create a production-derived database branch for tests until its data-copy semantics and PostgreSQL engine compatibility are confirmed. PR #14 CI first failed only on one Prettier formatting error in the new test; that line was fixed in commit `17ed43a18f34ddb7db9cc5866f6d78aea8580ad8`. Latest CI run #38657039335 had passed security audit, guard tests, typecheck, and lint; build was still running at the last check. No database writes or deployments.

- 2026-10-15: PR #14 CI is now green on `17ed43a18f34ddb7db9cc5866f6d78aea8580ad8`: install, dependency/security audit, guard tests (including the new atomic-receipt contract checks), TypeScript typecheck, ESLint, and production build all succeeded. Vercel preview deployment `roshan-health-9vidoqg8x-roshan45.vercel.app` is READY; HTTP GET of its root and `/inventory` returned 200. These are unauthenticated route/reachability checks only; the RPC is not installed in any database and authenticated receiving has not been behaviorally tested. PR #14 remains draft and must not be merged/deployed until a compatible isolated database is available and the SQL is tested.

- 2026-10-15: Extended PR #14 with an isolated PostgreSQL 17 CI integration job using a disposable service and fixture schema. Real SQL execution passed for a successful batch receipt, fractional-quantity rejection, permission rejection, missing-branch rejection, execute grants (authenticated allowed / anon denied), and an injected stock-movement failure proving the batch insert and aggregate increment roll back together. The normal CI job also passed install, security audit, guard tests, typecheck, lint, and build on `433933ece98978340a5b209a0a66e123f4c73924` (run #38657310413). This verifies the RPC against PostgreSQL 17 with a controlled fixture; it does not replace testing against Supabase's full production schema. PR #14 remains draft, SQL is not applied to production, and no production data was changed.

## Change log
- 2026-10-15: Initialized from connected-tool inspection. No database writes, destructive changes, merges, or deployments performed.
- 2026-10-15: Vercel consolidation completed via Composio: deleted duplicate `roshan-health-hub-hjfy`, verified only `roshan-health-hub` remains, and retained canonical domain `roshan-health-hub.vercel.app`.
- 2026-10-15: Closed PR #5 as superseded after confirming the redaction implementation and tests are already in `main`; no merge occurred.
- 2026-10-15: Read-only Supabase audit: 56/56 public tables have RLS enabled; no anon SELECT/INSERT grants in the reviewed inventory and no anon EXECUTE on public SECURITY DEFINER functions. All 15 authenticated-callable SECURITY DEFINER functions inspected have empty `search_path` and app-level permission checks. Migration head is `20261014164131_roshan_cashbox_reversal_concurrency` (79 migrations); repository migration parity remains unresolved. No Supabase writes.
- 2026-10-15: Confirmed insurance claim UI sent `invoiceId: null` despite the database RPC requiring an invoice. Added regression tests first (red on missing helper), then implemented invoice picker + validation in PR #12. CI run #38655085321 passed install, security audit, guard tests, typecheck, lint, and build on `a2cd2dd752d5577506674284db239865d1fc5459`; Vercel preview is READY. Static review found no blocking defect in the changed files; no review submissions exist yet. PR remains draft/open pending authenticated workflow smoke test; no merge, production deploy, or database write.
- 2026-10-15: Live HTTP smoke checks via Vercel access returned 200 for the canonical production root, PR #12 preview root, and preview `/insurance` route. The route response contained the application shell only and no server-rendered patient data. This is reachability/SSR-shell evidence only; it does not substitute for authenticated login, UI interaction, or role/branch authorization tests.
- 2026-10-15: Read-only data integrity review found zero active insurance claims, so historical claim-item reconciliation is not yet meaningful. The current `create_insurance_claim` definition checks for negative item amounts but does not enforce that covered + patient amounts equal gross; record this as a DB-side invariant gap to test and patch through a reviewed migration, not a production hotfix.
- 2026-10-15: Read-only pharmacy stock snapshot: all 9 active medicine records have legacy `medicines.stock_quantity` values different from summed remaining non-deleted inventory batches. Eight have zero batch stock; ceftriaxone has legacy 1,994 vs batch remaining 498. This is a reconciliation warning, not proof of corruption because the legacy and batch stock models may be intentionally separate. No quantity changes or database writes performed.
- 2026-10-15: Opened draft PR #13 (`fix/db: enforce insurance claim amount invariants`) with an additive SQL patch and contract test. It validates nonnegative amounts, covered/patient portions not exceeding gross, and covered + patient equaling gross within 0.01. PR remains untested against a disposable/staging database and unapplied to production; migration workflow parity is a prerequisite.

## Migration reconciliation update — 2026-10-15
- Added [`docs/MIGRATION_RECONCILIATION.md`](MIGRATION_RECONCILIATION.md) documenting the verified 79-entry production ledger, absence of `supabase/` in the repository, current legacy `db/*.sql` artifact layout, and a safe no-replay adoption plan.
- This is a verified mismatch in repository organization, **not proof that every migration's SQL is missing**. Exact source recovery and content-level parity comparison are still required.
- Production DDL remains frozen for PR #13 and PR #14 until canonical migration history or a reviewed schema-baseline strategy is validated in isolation. No production database writes, resets, merges, or production deploys occurred in this step.
- Next action: retrieve the exact SQL source for all 79 applied migration versions, record source/checksum/parity status, and test the resulting canonical sequence against a disposable PostgreSQL 17 environment plus isolated Supabase behavior before any production change.
- Added [`docs/APPLIED_MIGRATION_INVENTORY.md`](APPLIED_MIGRATION_INVENTORY.md) with all 79 exact version/name pairs read from the live ledger. Repository-source mapping and content parity remain explicitly unverified; no production writes were made.
