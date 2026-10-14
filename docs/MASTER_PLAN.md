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
- Open PR search surfaced #9 (audit-plan docs) and #5 (SSR logging/redaction); refresh their true state, head SHA, checks, and review threads before action.
- Branches seen: `main`, `audit/roshan-health-hub-hardening-plan`, `feat/nav-consistency-ux-pass`, `feat/responsive-shell-lab-ui`, `feat/shell-redesign`, `fix/cashbox-reversal-concurrency`, `fix/ssr-error-logging-redaction`, `fix/ssr-log-object-redaction`, `fix/vercel-node22-runtime`, `pr8-visual-artifacts`.
- Main `package.json` declares Node `22.x` and has `test:guard`, `typecheck`, `lint`, and `build` scripts.
- Vercel team `roshan45` has two linked projects, `roshan-health-hub` and `roshan-health-hub-hjfy`, both linked to the same repo. Prior audit found Vercel Node 24.x vs package.json Node 22.x; identify canonical domain/project and align runtime.
- Connected Supabase project `jewzonxplxhogqrnhosl` is named “Project Name: Roshan Production”, ACTIVE_HEALTHY, PostgreSQL 17.6, region eu-west-1. Migrations extend through `20261014164131_roshan_cashbox_reversal_concurrency`.
- Supabase security advisor reports `pg_trgm` in `public` and 15 SECURITY DEFINER functions executable by `authenticated`. Review each function’s ACL, internal authorization, branch isolation, input validation, and fixed search_path; do not blanket-revoke intended RPCs.
- Performance advisor reports many unused indexes; do not drop based on this signal alone. Schema inventory includes both `medicines` and `medicines_2`; verify usage before changing. No database writes/deployments were performed during this inspection.
- GitHub native file update returned 403 “Resource not accessible by integration”; use the active Composio GitHub connection for repo writes.

## Phases and exit criteria

### 0. Baseline and ownership — CURRENT
- [ ] Refresh main SHA, PR states/heads/reviews/CI, branches, and changed files.
- [ ] Identify canonical Vercel project, production domain, Git branch mapping, current deployment SHA, build logs, and runtime health.
- [ ] Verify PostHog connection/project; if unavailable, record it and continue without assuming telemetry exists.
- [ ] Record Supabase migration head, RLS/policy inventory, advisor findings, and confirm environment before writes.
**Exit:** dated baseline with canonical repo/branch/database/deployment and explicit unknowns.

### 1. Security, privacy, and repository hygiene
- [ ] Audit current files/history for exposed credentials; report paths/types, never values. Rotate/revoke any real exposed credential before history rewriting.
- [ ] Verify secret scanning, dependency alerts, and code scanning availability.
- [ ] Review every callable SECURITY DEFINER RPC for least privilege, branch context, fixed search_path, validation, and safe errors.
- [ ] Review RLS policies/grants for identity, patient, clinical, lab, pharmacy, inventory, finance, and insurance tables.
- [ ] Add automated unauthenticated, wrong-role, cross-branch, and forbidden-write tests.
**Exit:** no unresolved critical/high-risk access-control issue; repeatable checks and evidence.

### 2. Runtime and CI reproducibility
- [ ] Align Node version in package.json, CI, lockfile, and Vercel.
- [ ] Run guard tests, typecheck, lint, production build, and dependency/security checks on a frozen candidate SHA.
- [ ] Verify SSR log redaction with synthetic tokens, cookies, UUIDs, emails, and query strings.
- [ ] Resolve lint/format debt narrowly; avoid unrelated sweeping rewrites.
**Exit:** reproducible green checks and documented deployment target.

### 3. Database and migrations
- [ ] Compare repo migrations to deployed migration history; investigate schema drift and compatibility columns.
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
1. Refresh PR #9 and #5 status/checks and inspect current main CI.
2. Verify merged PRs #8/#10/#11 against current main SHA and run checks.
3. Resolve Vercel canonical project/domain and Node 22/24 mismatch.
4. Review the 15 SECURITY DEFINER findings individually; do not blanket-revoke.
5. Audit secret history safely and determine whether credential rotation is required.
6. Update this plan with evidence/checkmarks as work completes.

## Change log
- 2026-10-15: Initialized from connected-tool inspection. No database writes, destructive changes, merges, or deployments performed.
