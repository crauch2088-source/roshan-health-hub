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
- [ ] Insurance RPC gap from source review: `create_insurance_claim` does not currently enforce invoice-to-insured-patient matching or full item amount reconciliation server-side. Tracked in [Issue #16](https://github.com/crauch2088-source/roshan-health-hub/issues/16). PR #12 client-side validation is defense-in-depth only; database-side remediation must be tested in disposable/staging Supabase before production.
- [ ] Review RLS policies/grants for identity, patient, clinical, lab, pharmacy, inventory, finance, and insurance tables.
- [ ] Fix prescription header/items non-atomic save: source review found two separate client inserts that can leave a pending header without items on second-step failure. Tracked in [Issue #17](https://github.com/crauch2088-source/roshan-health-hub/issues/17).
- [ ] Review draft PR #22 for atomic prescription creation. Latest CI run [#38772712532](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38772712532) passed the PostgreSQL 17 integration job, security audit, guard tests, typecheck, lint, and build. Migration-history reconciliation and authenticated preview smoke tests remain prerequisites before merge/deployment.
- [ ] Fix patient snapshot outstanding balance completeness/error states: source review found a 1,000-invoice cap, missing `total_amount` fallback, and query errors that render like zero values. Tracked in [Issue #18](https://github.com/crauch2088-source/roshan-health-hub/issues/18).
- [ ] Fix invoice header/items non-atomic writes and server-side amount validation. Tracked in [Issue #20](https://github.com/crauch2088-source/roshan-health-hub/issues/20).
- [ ] Review draft PR #23 for atomic invoice creation and server-side financial invariants. Latest CI run [#38772767477](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38772767477) passed the PostgreSQL 17 integration job, security audit, guard tests, typecheck, lint, and build. The narrower PR #21 is closed as superseded. Migration-history parity and authenticated preview smoke tests remain prerequisites before merge/deployment.
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
- 2026-10-15: Tightened PR #13 in commit [`c4f3b88`](https://github.com/crauch2088-source/roshan-health-hub/commit/c4f3b884df658985a6109fb39d3a505b2b2f727e): requires active, date-valid insurance; invoice/patient match; allowed service type; non-empty description; JSON-number amounts that are finite, positive/nonnegative as appropriate, max two decimal places, and exact covered + patient = gross reconciliation. Existing permission gate, branch guard, empty search_path, and anon EXECUTE restriction are retained in the replacement definition. CI run [#38761681302](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38761681302) passed security audit, 63 guard tests, typecheck, lint, and build. This is application CI only: it does not execute the SQL contract test or prove the function works in PostgreSQL. PR #13 remains draft/open and unapplied; disposable/staging behavioral tests and migration-history reconciliation remain prerequisites.

## Migration reconciliation update — 2026-10-15
- Added [`docs/MIGRATION_RECONCILIATION.md`](MIGRATION_RECONCILIATION.md) documenting the verified 79-entry production ledger, absence of `supabase/` in the repository, current legacy `db/*.sql` artifact layout, and a safe no-replay adoption plan.
- This is a verified mismatch in repository organization, **not proof that every migration's SQL is missing**. Exact source recovery and content-level parity comparison are still required.
- Read-only query against `supabase_migrations.schema_migrations` confirmed all 79 rows contain non-empty `statements` (one statement per row; approximately 247,724 SQL characters) and all rows have a name. This provides an exact-source recovery path. Do not copy SQL into the public repository until checking hard-coded data/environment assumptions; do not execute the recovered SQL. Repository mapping, clean replay, and live-schema parity remain unverified.
- Production DDL remains frozen for PR #13 and PR #14 until canonical migration history or a reviewed schema-baseline strategy is validated in isolation. No production database writes, resets, merges, or production deploys occurred in this step.
- Next action: retrieve the exact SQL source for all 79 applied migration versions, record source/checksum/parity status, and test the resulting canonical sequence against a disposable PostgreSQL 17 environment plus isolated Supabase behavior before any production change.
- Added [`docs/APPLIED_MIGRATION_INVENTORY.md`](APPLIED_MIGRATION_INVENTORY.md) with all 79 exact version/name pairs read from the live ledger. Repository-source mapping and content parity remain explicitly unverified; no production writes were made.

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
- 2026-10-15: Code review of `usePatientSnapshot` found outstanding balances silently sum at most 1,000 invoices and collapse query errors to zero-looking values. Opened [Issue #18](https://github.com/crauch2088-source/roshan-health-hub/issues/18); no patient or invoice data was modified.
- 2026-10-15: Draft PR #19 replaces the capped patient-invoice read with stable exact-count pagination, adds explicit unavailable states, and tests overpayments and invalid amounts. A follow-up review caught that invalid paid values still risked displaying as zero; the helper now returns `null` for untrustworthy monetary data. CI run [#38771066048](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38771066048) passed security audit, guard tests, typecheck, lint, and build. PR remains draft/open; authenticated smoke testing is still required.
- 2026-10-15: PR #14's isolated PostgreSQL 17 integration suite now also tests rejection of NaN prices and expired stock. The first CI run exposed malformed SQL block delimiters in the added tests; they were corrected, and run [#38770807064](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38770807064) passed the integration job, typecheck, lint, security audit, and build. Follow-up validation changes are queued for another run.
- 2026-10-15: Billing source review found invoice header and item rows are written separately and malformed amounts can be coerced or accepted. Opened [Issue #20](https://github.com/crauch2088-source/roshan-health-hub/issues/20); no financial records were modified.
- 2026-10-15: PR #21 (`fix/invoice-draft-validation`) passed CI run [#38772065614](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38772065614) but was closed as superseded by PR #23, which includes the client-side preflight and the required server-side transaction.
- 2026-10-15: Draft PR #23 (`fix/invoice-atomicity`) adds `create_invoice_atomic`, validates permission and patient branch, validates invoice item and discount inputs, derives the invoice number and totals server-side, and writes the header and items in one transaction. Disposable PostgreSQL 17 integration tests cover totals, invalid/unauthorized/cross-branch inputs, and rollback. CI run [#38772767477](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38772767477) passed both integration and application jobs. SQL remains unapplied to any database.
- 2026-10-15: Opened draft [PR #19](https://github.com/crauch2088-source/roshan-health-hub/pull/19) for Issue #18. It now uses the existing exact-count paginated read helper with stable invoice-ID ordering, falls back from missing/invalid `net_amount` to `total_amount`, clamps per-invoice overpayment at zero, and renders explicit unavailable/incomplete states instead of presenting query failures as zero. After fixing a missing locale binding found by CI, [run #38762569934](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38762569934) passed security audit, 59 guard tests, typecheck, lint, and build. Vercel Preview is pending verification on the latest commit; authenticated smoke test and human review remain outstanding. No production data was changed.
- 2026-10-15: Read-only migration-ledger integrity step completed. Queried all 79 production ledger rows for version/name, stored statement byte length, and MD5 checksum; validated all 79 version/name pairs against `docs/APPLIED_MIGRATION_INVENTORY.md`, then recorded the checksums in commit [`547e3a6`](https://github.com/crauch2088-source/roshan-health-hub/commit/547e3a65fafe83a76f70701d0f40a3087ebf31bb). These hashes cover the JSON representation of each stored `statements` value, not normalized SQL. This is a source-integrity baseline only: SQL bodies were not exported or executed, repository parity remains unverified, and production was read-only.
