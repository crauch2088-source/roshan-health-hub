# Roshan Health Hub — Master Plan to Production

**Single source of truth:** keep this plan updated until launch. Snapshot date: 2026-10-16. Repository: https://github.com/crauch2088-source/roshan-health-hub

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
- Vercel is now consolidated to one project: `roshan-health-hub` (`prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`), linked to `crauch2088-source/roshan-health-hub`, canonical verified domain `roshan-health-hub.vercel.app`, Node `22.x`. Duplicate project `roshan-health-hub-hjfy` was deleted via the connected Vercel account and verified absent; its project-specific `*.vercel.app` domain is retired. The retained production deployment is READY on `main` SHA `a64f804679aeaae7299b034176f2265ac1806db0`; a newer docs-branch deployment is preview-only and is not production.
- Connected Supabase project `jewzonxplxhogqrnhosl` is named “Project Name: Roshan Production”, ACTIVE_HEALTHY, PostgreSQL 17.6, region eu-west-1. Migrations extend through `20261014164131_roshan_cashbox_reversal_concurrency`.
- Supabase security advisor reports `pg_trgm` in `public`, 15 SECURITY DEFINER functions executable by `authenticated`, and leaked-password protection disabled. Read-only review found all 56 public tables have RLS enabled; no table grants `anon` SELECT/INSERT in the sampled inventory; no `anon` EXECUTE privilege on public SECURITY DEFINER functions; the 15 callable authenticated functions each contain an app permission check and have `search_path` set to empty. Branch checks are present in the branch-sensitive RPCs inspected. The two `stock_movements` policies target `public` but both enforce app permission and branch access, and neither is unconditional. Review the [Supabase leaked-password protection guidance](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection); the Auth setting was not changed. This is a positive initial review, not yet a full adversarial authorization test.
- Current Supabase target `jewzonxplxhogqrnhosl` is `Roshan Production`, `ACTIVE_HEALTHY`, PostgreSQL 17.6, region `eu-west-1`. The live migration ledger now has 88 entries through `20261016183152_roshan_phase16_billing_idempotency`; the original 79-row inventory is historical and full replay parity remains unresolved. All 56 public tables have RLS enabled. The performance advisor snapshot reported 127 unused-index findings on 2026-10-16; do not drop indexes based on this signal alone. Schema inventory includes both `medicines` and `medicines_2`; verify usage before changing.
- GitHub native file update returned 403 “Resource not accessible by integration”; use the active Composio GitHub connection for repo writes.

## Phases and exit criteria

### 0. Baseline and ownership — IN PROGRESS
- [x] Confirmed `main` SHA `a64f804679aeaae7299b034176f2265ac1806db0` and successful GitHub Actions CI run #38649354331: install/lockfile, dependency security audit, patched TanStack versions, guard tests, typecheck, lint, and build passed.
- [x] Confirmed PR #5 was superseded by redaction code already present in `main`; closed it without merging. PR #9 remains a draft/open plan PR; its CI passed, but its base is stale.
- [x] Consolidated Vercel to the single project `roshan-health-hub`; removed duplicate `roshan-health-hub-hjfy`; verified only one matching project remains. Both projects’ Node setting had been aligned to `22.x` before deletion. Canonical verified domain is `roshan-health-hub.vercel.app`.
- [ ] Perform authenticated live smoke tests for login, role gates, patient lookup, queue, and server-rendered routes. Vercel production deployment for billing merge SHA `a4e53787bed97f9f2d34038641a2a839b12c01ba` is READY; browser/login tests remain pending because no browser automation connection is active and no credentials were supplied.
- [x] Verified PostHog `Default project` is connected but has no events; privacy configuration needs review before any clinic telemetry is enabled.
- [x] Confirmed Supabase target `jewzonxplxhogqrnhosl` is healthy on PostgreSQL 17.6 and 56/56 public tables have RLS enabled. Live migration ledger has 88 entries, latest `20261016183152_roshan_phase16_billing_idempotency`; 79 historical rows remain in the original inventory plus 9 later tracked migrations. [ ] Reconcile historical SQL artifacts/replayability; do not replay recovered SQL without source and rollback validation.
**Exit:** pending authenticated runtime smoke tests, privacy review, and migration-history parity.

### 1. Security, privacy, and repository hygiene
- [ ] Audit current files/history for exposed credentials; report paths/types, never values. Rotate/revoke any real exposed credential before history rewriting.
- [x] Read-only scan of current main for common Supabase/service-role/access-token/database-URL patterns found no hard-coded credential assignment. `src/lib/supabase-admin.ts` reads `SUPABASE_SECRET_KEY` / legacy `SUPABASE_SERVICE_ROLE_KEY` only from `process.env`; `.npmrc` contains only the public npm registry, and root environment files are `.env.example` only. This does not inspect every historical commit or prove the absence of all secret formats; history exposure remains unverified.
- [ ] Verify secret scanning, dependency alerts, and code scanning availability.
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

## Immediate next actions
1. After the Vercel deployment quota permits the next production release, run an authenticated smoke test for the merged PR #12 insurance claim workflow; client validation remains defense-in-depth.
2. Run authenticated runtime smoke tests on `https://roshan-health-hub.vercel.app` and confirm role/branch gates.
3. Reconcile the 79 applied Supabase migrations against repository artifacts; source SQL has now been recovered to quarantine in draft [PR #26](https://github.com/crauch2088-source/roshan-health-hub/pull/26), with ledger checksums and a basic secret-pattern scan. Next: semantic diff against `db/*.sql`, review data/destructive assumptions, then clean PostgreSQL 17 replay and Supabase-specific validation. Do not move the recovered files into the canonical migration directory or execute them yet.
4. PR #13 is merged as `5229ef8`, which adds tested DB-side insurance claim amount invariants and policy-validity checks. Its SQL is still not applied to production; The final ACL fix passed dedicated PostgreSQL 17 integration on head [`8be7e13`](https://github.com/crauch2088-source/roshan-health-hub/commit/8be7e134862fb4cdad3172b1f888bbc237295bf0); the main application/security/concurrency suite passed on its immediately preceding code-equivalent head, and mainline CI passed after merge, covering amount splits/precision, active insurance, invoice/patient matching, branch isolation, authorization, and rollback. Vercel Preview remains blocked by the account build-rate limit. This fixture does not replace full Supabase staging validation; migration parity and authenticated smoke tests remain required. Continue adversarial tests for all 15 authenticated-callable SECURITY DEFINER RPCs.
5. Classify pharmacy inventory reconciliation before changing quantities: current read-only snapshot shows all 9 active medicine rows have `stock_quantity` different from the sum of non-deleted batch `quantity_remaining` (8 have no remaining batch quantity; ceftriaxone has 1,994 legacy vs 498 batch units). This may reflect intentionally separate legacy/batch stock, so do not auto-sync; trace dispense/receive semantics and UI source-of-truth first.
6. Safely scan Git history for credentials without printing values; determine whether rotation is required.
7. Review PostHog privacy settings before enabling any telemetry.
8. Refresh PR #9 against current `main` and keep it draft until its contents and CI are current.

- Historical: PR #14 was an earlier draft of batch receiving. Its old CI/preview evidence is not evidence for the current implementation; PR #14 remains open only for historical comparison and should not be merged.
- Current pharmacy-receive work is in [draft PR #29](https://github.com/crauch2088-source/roshan-health-hub/pull/29), head `e06afc57938ddad2bc27ca51fe4d4da7caa44295`; CI run [#38795032633](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38795032633) passed PostgreSQL 17 behavior/rollback tests, security audit, guard tests, typecheck, lint, and build. The current proposal uses `pharmacy.update`, routes both quick-receive and batch-tab receipts through the atomic RPC, rejects invalid/expired batch data, removes direct browser INSERT on `stock_movements`, and keeps newly created medicine stock at zero until a batch is received. SQL remains unapplied; PR #29 is still draft pending review and migration-source reconciliation. Vercel Preview is blocked by the account build-rate limit, so authenticated browser smoke testing remains outstanding. Existing legacy-vs-batch stock differences remain untouched and require separate review.


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
