# Roshan Health Hub — Neon Autonomous QA Completion, Full-Workflow Closure & Independent Deep Review Mandate

**Created:** 2026-11-22  
**Execution owner:** Neon (primary autonomous engineering executor)  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Current task PR:** [#296 — QA Operational Blockers](https://github.com/crauch2088-source/roshan-health-hub/pull/296)  
**Current task branch:** `fix/qa-operational-blockers-20261121`  
**Current task head at mandate creation:** `b11d35952c013f3c2c110875f30bbc85657ce06c`  
**Current main at mandate creation:** `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`  
**Status:** EXECUTE CONTINUOUSLY TO THE MAXIMUM SAFE COMPLETION — NOT A PLANNING-ONLY TASK.

---

## 0. Binding instruction: one continuous autonomous campaign

You are the primary executor. The owner has explicitly asked for one comprehensive execution cycle, not a sequence of short sessions and not a plan that returns after the first fix.

Proceed without routine approval requests for repository inspection, reading documentation, diagnosing, editing code, writing tests, creating feature branches, committing, updating existing PRs, creating logically necessary PRs, running tests, inspecting QA, or continuing to the next independent task. Do not stop after fixing the first CI error. Do not ask the owner to say “continue”. Keep working until:
- every safe, autonomous task in this mandate has been completed and independently reviewed;
- all work that is blocked by unavailable credentials, physical access, owner-only settings, or clinical approval has been isolated and documented precisely;
- the complete QA journey has been exercised as far as the environment permits;
- the final deep review has been performed after implementation, not before it;
- the repository checkpoint and final report are committed and linked from the relevant PR(s).

A written plan, a list of recommendations, or a report without implementation is not completion. A green unit test is not operational acceptance. A preview deployment is not a Production release. A merged PR is not proof that the clinic can safely operate.

### Explicitly narrowed safety envelope for this campaign

This task-specific mandate deliberately uses a stricter release boundary than any broader standing project authorization:

1. **Production Supabase is strictly READ-ONLY.** No INSERT, UPDATE, DELETE, RPC writes, DDL/DML, migrations, grants/revokes, role/account changes, Auth changes, secrets/configuration changes, storage mutations, or destructive actions against Production.
2. **Production Vercel is strictly READ-ONLY.** Do not deploy, promote, rollback, change aliases, environment variables, project settings, domains, or production configuration.
3. Do not merge PR #296 or any other code PR into `main` under this mandate. Do not change `main` directly. Keep implementation in isolated feature branches and PRs. The owner will decide any subsequent merge/release action separately.
4. QA mutations are permitted only after positively identifying the QA project by exact Supabase project reference and confirming the target before every write. Use synthetic records only. Never copy real patient, clinical, financial, or staff data into QA.
5. Do not use Production as a test environment, even for “harmless” smoke tests. No production patient creation, visit creation, pharmacy transaction, lab order, invoice, or test account.
6. Do not weaken authentication, RLS, branch isolation, role checks, audit protections, test assertions, or security controls to obtain green CI.
7. Do not delete synthetic QA patients or transactions created in previous acceptance runs unless a documented test cleanup mechanism proves the records are disposable and the action is explicitly safe. Prefer isolated, uniquely named synthetic records and idempotent fixtures.
8. Do not activate clinical protocols or make clinical policy decisions. Clinical decision-support work may be implemented only against verified evidence and must remain clinician-review/activation gated.
9. No paid services, upgrades, quota bypasses, or new recurring costs. Protect free Vercel build quota and existing connected-service limits.
10. Never expose secrets, access tokens, password values, backup keys, service-role keys, or PHI in commits, PR comments, logs, reports, screenshots, or this conversation.

If any action conflicts with these boundaries, do not perform that action. Continue independent work that remains safe.

---

## 1. Mandatory Composio-first operating procedure

The owner specifically requires you to use **Composio MCP**. It is not optional and must be used as the primary service-integration layer for GitHub, Supabase, Vercel, and browser workflows where supported.

At the beginning of this campaign:

1. Call Composio tool discovery for the concrete work required: GitHub repository/PR/branch/checks/files; Supabase project identity, read-only SQL, schema, migration history, QA migration application if needed; Vercel QA deployments and metadata; and authorized browser interaction for QA acceptance.
2. Confirm GitHub, Supabase, and Vercel connections are ACTIVE. The latest discovery snapshot on 2026-11-22 showed:
   - GitHub: one active account, `github_ticket-waled`.
   - Supabase: two active accounts; account selection is required. **Do not guess which account maps to QA or Production.**
   - Vercel: three active accounts; account selection is required. Resolve the correct Roshan project/team/account before acting.
3. Use exact tool slugs returned by Composio discovery only. Retrieve full schemas for every tool whose result includes `schemaRef`. Never invent tool names or argument keys.
4. Use `COMPOSIO_MULTI_EXECUTE_TOOL` for independent calls where appropriate. Do not batch dependent actions whose arguments require earlier outputs. Pass the correct explicit account alias/ID for every ambiguous toolkit.
5. For Supabase, verify the project reference before any query. Map:
   - QA: `hopfohcnrtbiqjkgeukz`
   - Production: `jewzonxplxhogqrnhosl`
   If account mapping is uncertain, use only safe project identity/read-only discovery until resolved. Never infer a project from an account alias alone.
6. Use `SUPABASE_RUN_READ_ONLY_QUERY` for all Production diagnostics. For QA, use read-only queries for diagnosis and the authorized QA migration action only when a reviewed migration is actually required. The generic beta SQL action is capable of writes even if the caller describes a query as read-only; do not use it casually.
7. Use Composio Vercel actions to inspect deployments, branch, environment target, status, deployment URL, and checks. Do not deploy Production. A Vercel status check marked “success” only proves a deployment operation completed; it does not by itself prove the correct preview URL or that the preview contains the PR head.
8. Use Composio browser/Computer Use if available for authenticated QA journeys. Respect SSO and access controls. Do not bypass login or fabricate credentials. If browser automation cannot resize viewports, record that limitation and use another supported authorized method if available.
9. If a Composio tool is missing or fails, search for the correct action again and inspect its schema. Do not silently switch to an unrelated account, a generic API proxy, or an unsafe manual workaround. Record any true capability limitation and continue all independent tasks.
10. Keep an action ledger: tool/action, account selected (non-secret alias/ID only), exact target project/ref, read/write classification, timestamp, result, and evidence link. Never include credential values.

**Required:** Use Composio for the work; do not merely mention it in the final report.

---

## 2. Reconcile live repository state before touching implementation

The following snapshot is verified as of 2026-11-22 and must be rechecked at execution time. It is not permission to assume that later state is unchanged.

### 2.1 Current Git baseline

- `main`: `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.
- `main` parent: `f046e41f7c67ccb3d7f3ad63fcd00729bb756e74`.
- PR #296 base: `main` at `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.
- PR #296 head: `b11d35952c013f3c2c110875f30bbc85657ce06c`.
- PR #296 branch: `fix/qa-operational-blockers-20261121`.
- PR #296 is OPEN, DRAFT, and NOT MERGED.
- The branch is based directly on the recorded main SHA; recheck whether main has advanced before updating it. Never force-push, rebase published history, amend a published commit, or overwrite concurrent work.
- The GitHub branch API reported `main` as **unprotected** and the PR branch as unprotected at the time of inspection. Treat this as a serious governance finding. Recheck current rulesets and branch protection. Do not bypass protection or assume a successful status check compensates for absent protection. Record owner-only settings actions precisely.

### 2.2 PR #296 exact CI findings

The exact head had 30 check runs:
- 27 success
- 1 skipped
- 2 failures

The two failing jobs were:
- `Install, audit, typecheck, lint, build` — job `136801414490`
- `Insurance claim validation regression` — job `136801414344`

**Important correction:** the insurance-claim test itself ran 7/7 successfully. That workflow then ran the same TypeScript check and failed there. Do not misdiagnose this as a failing insurance business-rule test.

Both failed jobs expose the same TypeScript defects on the PR head:
- `src/lib/i18n.tsx(580,3): TS1117 — duplicate property name in an object literal`
- `src/routes/_authenticated/accounting.tsx(174,26)`, `(175,26)`, `(176,26)`, `(177,26)`, `(181,23)`, `(185,29)`, `(186,29)`, `(187,29)`: `TS2304 — Cannot find name 't'`

The 341-test guard suite completed with 341/341 passing before typecheck failed. This does not override the typecheck failure. The CI failure logs were inspected directly.

The Vercel GitHub status for the PR head was marked successful, but this does **not** establish that the tested QA Preview is built from PR #296. Resolve the exact Vercel deployment ID, commit SHA, branch, target (Preview, never Production), and URL before browser acceptance.

### 2.3 PR #296 work reported and evidence classification

The PR contains a consolidated QA blocker fix:
- P0 branch RLS access for the SECURITY INVOKER visit attribution trigger.
- P1 calendar-safe month range in expenses.
- P1 patient duplicate detection, address field, and patient-registration RPC extension.
- P2 localized pharmacy error messages and required expiry date.
- P2 Arabic/English i18n and role labels.
- QA-only SQL patch and regression tests.

A QA report dated 2026-11-21 states that Reception created a visit and queue ticket Q1; GP completed a synthetic note, diagnosis J06.9, vitals and a prescription; pharmacy refused to dispense a free-text prescription item under the Phase 57/57B guard; and audit entries were recorded. Treat this as **reported prior QA evidence** until you re-open the exact deployment and verify it yourself. Do not relabel old screenshots or report statements as newly verified.

### 2.4 Newly discovered QA lab-catalog blocker

The prior QA browser run found:
- QA `lab_tests` catalogue had zero rows.
- Adding a synthetic test failed with schema-cache error: `Could not find the 'normal_max' column of 'lab_tests' in the schema cache`.
- The frontend `/lab-catalog` code on the tested preview attempted to send `normal_min` / `normal_max`.
- The prior preview was an older QA deployment from branch `qa/isolated-acceptance-20261023`, commit `d8f494be773ab766bf6781d4a8297a4d581153e7`, not proven to include PR #296.

This is a new concrete blocker. Diagnose the authoritative table definition, current main code, all historical/forward migrations, QA migration ledger, generated types, and the exact deployment commit. Determine whether:
- the frontend is ahead of the QA schema;
- a required migration was omitted or not applied;
- the UI is writing obsolete/wrong field names;
- a baseline/schema contract is stale;
- or multiple of these are true.

Do not add columns blindly, do not mutate the migration ledger, do not patch the schema cache manually, and do not weaken schema-contract tests. Choose the smallest forward-only, documented, QA-tested correction that preserves historical records and is compatible with the canonical migration sequence.

---

## 3. Source-of-truth and mandatory reading

Before implementation, read the current versions of:
- `docs/MASTER_PLAN.md` — authoritative roadmap and task status.
- `AGENTS.md` — execution, quota, Git and safety policy.
- `.specify/memory/constitution.md` — durable project principles and delegated governance.
- `docs/PARALLEL_ENGINEERING_CONTINUATION.md`.
- `docs/parallel-reports/TEMPLATE.md`.
- `docs/AUTONOMOUS_ENGINEERING_COMPLETION_MANDATE_2026-11-21.md`.
- `docs/AUTONOMOUS_COMPLETION_PLAN_2026-11-20.md`, if still present.
- `docs/ROSHAN_CHECKPOINT_AND_EXACT_PATCHES_2026-11-21.md`, if still present.
- the latest relevant QA, security, migration reconciliation, pharmacy, inventory, finance, and release reports.
- current PR #296 diff, discussion, checks, and all changed files.
- current open PRs/issues and their actual head/base commits.

Some historical paths in older mandates may have moved or been renamed. If a path returns 404, locate the canonical current file using repository tree/search; do not silently treat a missing document as proof that its requirements are obsolete.

Read the relevant Spec Kit specification/plan/tasks before implementing a substantial feature. Load and follow the installed Test-Driven Development skill before changing behavior. Keep specs, tests, code and documentation aligned.

### Repository policy constraints to preserve

- One atomic commit per logical implementation bundle; include code, tests and relevant docs together.
- Avoid many per-file commits and repeated push/CI cycles.
- One CI run per coherent completed stage. After a failure, fix the root cause and rerun only the required workflows/jobs where supported.
- Documentation-only, SQL-only and script-only changes must skip frontend builds when the existing workflow policy supports it.
- Always respect free Vercel quota. No unnecessary Preview deployment for a documentation-only change.
- Use batched read-only Supabase diagnostics where practical.
- Do not reopen completed historical phases without a concrete code change, new evidence, or regression.
- Never rewrite published history or force-push.
- Do not merge to `main` in this campaign.

---

## 4. Stage A — Fix PR #296 and perform a security-quality review of every change

Work first on the existing PR #296 branch unless live state proves that it has been superseded. Preserve the branch and PR. If main advanced, reconcile it safely using normal ancestry-aware operations; do not blindly rebase or overwrite.

### A1. Fix the confirmed TypeScript failures

1. Inspect the full `dict` object in `src/lib/i18n.tsx`; identify both occurrences of the duplicate key reported at line 580. Preserve the correct Arabic and English translations and remove only the duplicate declaration. Check for further duplicate keys across the dictionary.
2. Inspect `AccountingPageInner` and the component hierarchy in `src/routes/_authenticated/accounting.tsx`. The file already imports/uses `useLang`; the compiler says `t` is not defined at eight locations. Determine whether the hook destructuring is absent in the relevant component, scoped in a parent, or accidentally removed. Add the correct translation function in the correct component scope; do not replace translated calls with hardcoded text.
3. Inspect all remaining errors after the two fixes. Run `npm run typecheck`, `npm run lint`, `npm run build`, and the exact insurance test. Confirm the insurance test is still 7/7.
4. Review the seven moderate npm audit findings. Classify direct/transitive, reachable/unreachable, fixable/breaking. Do not run a broad `npm audit fix` that changes the lockfile indiscriminately. Make only safe, justified updates if in scope; otherwise document exact packages and risk.
5. Run the new QA blocker regression test and full `test:guard`; preserve the 341+ existing tests and add any missing regression coverage.
6. Ensure CI reports all required workflows on the final exact SHA. A skipped canonical PG17 baseline/authenticated acceptance workflow must remain explicitly identified and either be enabled with the correct QA/CI setup or recorded as a real gate; it is not a pass.

### A2. Branch RLS and visit attribution — P0

Independently review the policy and trigger rather than accepting the happy-path visit result alone.

- Inspect `public.branches` RLS policies, `private.app_has_branch_access(uuid)`, `public.app_has_perm(text)`, the user's branch assignment, active/deleted flags, and `private.phase47_visit_branch_attribution()`.
- Confirm the trigger remains SECURITY INVOKER if that is the intentional contract. Do not switch to SECURITY DEFINER to hide an RLS problem.
- Prove that an authenticated Reception/GP user can SELECT only the branch or branches they are authorized to access.
- Prove that the same user cannot read, assign, create visits in, or infer protected data from another branch merely by supplying a known UUID.
- Test active, inactive, deleted, unassigned, one-authorized-branch, multiple-authorized-branches, and no-authorized-branch cases.
- Test reception visit creation, GP visit start/save, direct RPC/API calls, queue ticket branch binding, visit/queue read isolation, and failure rollback.
- Inspect policy permissiveness: no older permissive policy may accidentally widen access; verify effective policy composition, not just the new policy text.
- Test admin and super_admin according to the actual role/permission contract, without granting roles broad access to make the tests pass.
- Confirm no branch is auto-created or silently activated. If exactly one authorized active branch exists, the UI may default to it; if multiple exist, require explicit selection; if none exist, return a clear localized actionable error.
- Ensure error handling never swallows visit-creation failures or reports success without a persisted visit.
- Verify audit records include actor, branch, target, action and timestamp, with no sensitive clinical payload leakage.

### A3. Patient registration, duplicate detection and idempotency — P1

Review both the browser and authoritative database contract.

- Determine whether duplicate detection currently depends on the currently loaded `list.rows` page. If so, it is not a reliable system-wide duplicate check.
- Implement a server-authoritative lookup/check or a safe atomic registration workflow that considers all records in the authorized branch, with appropriate privacy and access restrictions.
- Normalize Sudanese phone formats consistently (country code +249, leading 0, 00249, Arabic-Indic digits, whitespace and punctuation). Do not assume phone number uniqueness.
- Normalize names conservatively for comparison (Arabic whitespace/diacritics and equivalent forms only where safe); never rewrite the stored legal/clinical name.
- Preserve the distinction between a confirmed duplicate and a possible match (shared family phone, common names, namesakes, incomplete identifiers).
- A possible match should warn and permit a justified override; a confirmed match should guide the user to the existing chart and require a deliberate, audited override only where policy allows.
- If override is allowed, record who overrode, when, which candidate was considered, the reason, and the resulting new patient. A checkbox alone is not sufficient evidence of an audited override. Avoid leaking another branch's patient existence to an unauthorized user.
- Do not create a unique constraint on name or phone alone.
- Add durable idempotency/double-submit protection so retries and concurrent clicks cannot create multiple MRNs/patient rows.
- Review `create_patient_atomic` signature replacement and all existing callers. Preserve backwards compatibility for five-argument callers; check PostgREST overload resolution, function ACL, SECURITY DEFINER search_path, branch resolution and explicit authenticated grants.
- Confirm the optional `_address` is saved correctly and is not silently omitted or overwritten by an update path.
- Test duplicate and near-duplicate pairs, Arabic/English name variants, shared family phones, same name/different people, same phone/different people, different branches, concurrent duplicate submissions, retry after timeout, and explicit override audit.
- Ensure patient search, edit, pagination and registration remain consistent and mobile-usable.

### A4. Expenses date-range correction — P1

- Review `monthDateRange()` and all callers, timezone semantics and date column type.
- Use a half-open interval `[monthStart, nextMonthStart)` with correctly constructed calendar dates; no `YYYY-MM-31` or locale-dependent parsing.
- Test all 12 months, leap/non-leap February, 30-day months, December-to-January rollover, timezone boundaries, empty months, and records exactly at both boundaries.
- Confirm date filtering and displayed month totals reconcile with database values.
- Verify no regression in expenses create/edit/delete permission boundaries, audit events, branch filtering, or financial reporting.

### A5. Pharmacy localized errors and expiry requirements — P2

- Map known RPC/constraint codes to safe, actionable Arabic and English messages. Do not expose raw backend internals to end users.
- Unknown errors should produce a generic localized message and a correlation/reference identifier where supported, while the technical detail remains in PHI-safe logs.
- Ensure `expiry_date` is visibly required and server-side required. UI required markers alone are not validation.
- Verify `medicine_stock_is_rpc_managed` cannot be bypassed by direct table writes; preserve the approved atomic RPC-only stock mutation boundary.
- Test missing expiry, malformed expiry, expired batch, negative/zero quantity, insufficient stock, duplicate request, stale stock, unauthorized actor, wrong branch and failed atomic transaction.
- Confirm no stock or invoice mutation occurs on a rejected dispense.

### A6. Arabic/English i18n and accessibility — P2

- Audit the full translation dictionary for duplicate keys, missing keys, untranslated labels, incorrect language leakage, mixed-script labels and raw snake_case keys.
- Audit `accounting.tsx`, `app-shell.tsx`, `dashboard.tsx`, `inventory.tsx`, `billing.tsx`, `reports.tsx`, `lab-catalog.tsx`, `expenses.tsx`, and every route touched by the fixes.
- Localize all role names from canonical role codes. Do not expose legacy role codes as UI labels.
- Verify date, currency (SDG), number, decimal, percentage, and plural formatting in both languages.
- Check RTL mirroring of navigation, breadcrumbs, cards, tables, dialogs, icons, form controls and error messages; do not mirror directional icons incorrectly.
- Check accessible names, field labels, required state, keyboard focus, focus return from dialogs, error announcements, contrast and target size.
- Add dictionary coverage tests and rendered component tests where source-contract tests alone would be insufficient.

### A7. PR #296 release-quality decision

Keep PR #296 Draft until:
- all TypeScript/lint/build errors are resolved;
- all required CI checks pass on the exact head;
- changed SQL is replayed on disposable PostgreSQL 17 and QA only where required;
- branch RLS negative cases pass;
- duplicate-registration safety is server-authoritative and audited;
- all frontend fixes are live on the correct QA Preview and manually re-accepted;
- no unresolved Critical/High security or data-integrity defect remains.

Do not mark the PR Ready or merge it merely because a subset of tests passes.

---

## 5. Stage B — Fix the lab schema/catalogue blocker and complete the full clinical loop

This is the next critical end-to-end objective after A.

### B1. Reconcile `lab_tests` schema

1. Inspect the current QA schema using read-only catalog queries: columns, types, defaults, nullability, constraints, indexes, RLS, grants, triggers and relevant views/functions.
2. Inspect Production schema read-only only for comparison; do not mutate it. Compare QA, Production, main migration source, canonical baseline, generated types and frontend payload contract. Record differences by source and timestamp.
3. Inspect migration history in both environments without altering the ledger. Identify the exact migration expected to introduce/rename reference-range fields and whether it was applied.
4. Inspect all callers of `lab_tests`, including `src/routes/_authenticated/lab-catalog.tsx`, lab order entry, result entry, reports and generated DB types. Identify whether the intended columns are `normal_min`/`normal_max`, alternate names, or typed JSON/range fields.
5. Select a single canonical schema contract. Avoid adding duplicate synonymous columns merely to silence PostgREST.
6. If a forward migration is necessary, create it in the repo, add PG17 replay tests and migration-parity checks, verify backward compatibility, then apply to QA only after exact project identity is confirmed.
7. Refresh or wait for the schema cache only through supported Supabase mechanisms. Never manually modify internal schema cache tables.
8. Seed one synthetic QA lab test only after the schema is aligned; include realistic but clearly synthetic name, units, price and reference range. Do not present synthetic reference ranges as clinical standards.
9. Test create, edit, activate/deactivate, search, selection, permission denial, validation and persistence after reload.

### B2. Laboratory workflow E2E

Complete the entire synthetic journey:
- GP orders a catalogue-linked test for the synthetic patient/visit.
- Reception/admin billing state is correct according to existing billing design.
- Lab technician sees only authorized branch orders.
- Lab staff receives/collects sample and records the required sample metadata.
- Lab result entry supports numeric, text/coded, zero, abnormal, critical, pending and corrected results as the current schema permits.
- Result save is atomic and idempotent; repeated submission does not duplicate invoices or results.
- Lab doctor/reviewer workflow is exercised if the actual product role model supports it. Do not invent role codes.
- Verification uses the approved `verify_lab_order(uuid)` or canonical RPC, not direct client table writes.
- Unverified results cannot be represented as verified; correction/revision history is preserved.
- GP can see the authorized result in the correct patient/visit context.
- Audit records preserve actor, action, branch, timestamps and state transitions without logging unnecessary PHI.
- Negative tests: wrong branch, unauthorized role, missing sample, malformed result, duplicate request, stale update, cancelled visit, failed invoice, result verification by unauthorized user, and partial failure/rollback.

Record the exact test ID, order ID, visit ID and result status in the QA-only report using synthetic IDs only.

---

## 6. Stage C — Complete catalogue-linked pharmacy dispense, stock ledger and finance integrity

The previous QA run correctly refused a free-text prescription item. Do not weaken the Phase 57/57B fail-closed guard. Resolve the data/workflow issue correctly.

### C1. Medicine catalogue identity

- Inspect current medicine catalogue identity fields, uniqueness rules, brand/generic identity, strength, dosage form, route, concentration, pack size, unit conversion and active status.
- Link the synthetic prescribed item to the active catalogue medicine `QA Test Paracetamol 500mg` using the supported prescription workflow or an authorized correction/selection process.
- Do not silently convert free text to a medicine catalogue identity based only on a matching name.
- Preserve the prescriber's original text and the canonical catalogue identity separately where the data model supports both.
- Verify pharmacist correction/reconciliation workflow and prescriber approval rules from the current issue/PR and database contract. Do not allow a pharmacist to alter a clinical instruction without the required prescriber authorization.
- If the correction workflow is not implemented, implement it as a separate scoped PR with auditable request, approval/rejection, actor, reason, old/new identity and immutable history.

### C2. Atomic dispense and stock movement

- Use the authorized atomic pharmacy dispense RPC. Never decrement stock through direct frontend table updates.
- Starting from the QA test batch with 10 units, a successful dispense of 2 units must produce exactly 8 saleable units, one dispense record, one appropriate invoice/effect, and one audit event set according to the existing design.
- Same idempotency key and same canonical payload must return the original result without additional effects.
- Same key with changed payload, actor or branch must fail explicitly.
- Concurrent duplicate requests must produce exactly one dispense/stock/invoice effect.
- Test insufficient stock, expired batch, wrong branch, inactive medicine, unlinked/free-text item, unauthorized role, missing required prescription fields, cancelled visit, already dispensed item, repeated click, network retry and rollback.
- Validate batch selection/expiry rules and ensure FIFO/FEFO behavior only if it is the documented product policy.
- Verify inventory ledger and on-hand quantity reconcile after dispense.
- Verify invoice lines, visit, patient, branch, payment state and audit history all point to the correct entities. No duplicate or orphan invoices.
- Test cancellation before handover and post-handover return/quarantine only under the existing approved Phase 62 contract; do not return potentially contaminated/expired goods to saleable stock.
- Preserve the 10 → 8 expected test evidence, but use a fresh isolated batch if the prior batch has already been consumed. Never assume its current stock from the old report.

### C3. Finance, billing and accounting

- Review atomic visit billing, invoice/payment idempotency, cashbox, receipts, supplier payments, expenses, insurance claims and compensation flows.
- Validate arithmetic at exact decimal precision and currency SDG; avoid floating-point rounding drift.
- Reconcile invoice gross, discounts, insurance-covered amount, patient amount, payments, refunds/compensations and outstanding balance.
- Ensure no duplicate invoice/payment/receipt under retry or concurrent submission.
- Ensure reversals/compensations are append-only and reference canonical source invoice/payment identifiers.
- Test multiple visits for one patient so payments/claims/compensations never attach to the wrong visit.
- Validate expenses month filtering and cashbox/report totals after A4.
- Verify role restrictions at both UI and RPC/database layer.
- Run the insurance claim regression (its business test was already 7/7 on the observed PR head) plus typecheck/lint/build and relevant PG17 integration.

---

## 7. Stage D — Full QA role and route acceptance

Do not create role aliases or privileges merely to fill a test matrix. First reconcile the canonical `public.roles`, permission catalogue, `public.users`, Auth identities, UI route guards, RPC authorization and legacy role mapping.

Previously reported active QA accounts:
- `admin`
- `doctor`
- `lab_tech`
- `pharmacist`
- `receptionist`

Previously reported missing role accounts:
- `super_admin`
- `dentist`
- `specialist`
- `lab_doctor`
- `lab_assistant`

The prior report says `super_admin` is canonical, while `dentist`, `specialist`, `lab_doctor`, and `lab_assistant` exist only as legacy role codes. Recheck the live QA model. Do not infer that the role model supports all nine as separate active roles.

### D1. Role matrix

For every supported canonical role, build a table of:
- canonical role code and display label;
- linked Auth identity (redacted identifier only);
- active/deleted status;
- branch assignment;
- allowed screens;
- allowed actions;
- denied actions;
- direct URL/API/RPC denial evidence;
- branch-isolation evidence.

At minimum, verify Reception, GP/Doctor, Lab Technician, Pharmacist and Admin. Verify Super Admin only if a safe synthetic QA account can be created using supported Auth Admin UI/API and without granting unintended powers. Verify Dentist, Specialist, Lab Doctor and Lab Assistant only if they are genuine supported roles or modules; otherwise document the canonical equivalent and the exact missing implementation/owner decision.

Never:
- edit `auth.users.encrypted_password` directly;
- manipulate Supabase Auth internals through SQL;
- use a weak QA password in Production;
- assign super_admin just to get a route to load;
- grant all permissions to a test account;
- create role records that do not match the product's permission model.

### D2. Authenticated route inventory

Read `docs/MASTER_PLAN.md` and current router tree. Derive the complete authenticated route list from source, not old report counts. Verify every route:
- loads for authorized role;
- is hidden or denied for unauthorized role;
- enforces direct URL navigation;
- scopes queries and writes to authorized branch;
- handles empty/loading/error states;
- supports Arabic RTL and English LTR;
- has no raw translation keys or unhandled console/runtime errors.

Prior project plan references roughly 22 authenticated screens; previous reports referenced 27/30 routes. Reconcile the exact current count and avoid duplicate route aliases. Cover, where present:
dashboard, patients, visits, queue, clinic, lab, lab catalogue, pharmacy, inventory, billing, accounting, finance, expenses, reports/analytics, users, roles/permissions, audit, settings/branches, appointments, follow-ups, certificates, suppliers/partners/insurance, printing and any other current authenticated route.

Do not claim route coverage based only on a route file existing. Record actual role-based browser results.

---

## 8. Stage E — Security, privacy, data integrity and database deep review

Perform a fresh independent security review of the actual current candidate and the relevant live QA schema. Do not assume prior PR reviews cover these new changes.

### E1. RLS and branch isolation

- Enumerate all public tables/views and RLS-enabled status.
- Identify tables with RLS disabled, missing policies, overly permissive policies, and policies that depend on helper functions.
- Inspect effective grants and function EXECUTE ACLs, including PUBLIC/anon/authenticated inheritance.
- Verify branch isolation for patients, visits, queue, notes, diagnoses, vitals, prescriptions, prescription items, lab orders/results, inventory batches/ledger, invoices, payments, expenses, audit and storage objects.
- Include both direct PostgREST table access and RPC access.
- Verify policies are not widened by older permissive policies.
- Test branch A vs branch B with two synthetic identities and assert cross-branch SELECT/INSERT/UPDATE/DELETE denial as appropriate.
- Do not weaken existing RLS for convenience.

### E2. RPC and function posture

For each changed or critical RPC/function:
- signature and overloads;
- SECURITY INVOKER vs SECURITY DEFINER rationale;
- fixed safe `search_path` for SECURITY DEFINER;
- explicit owner and EXECUTE grants;
- canonical role and permission checks;
- authenticated user binding;
- branch context binding;
- validation and error semantics;
- transaction/rollback behavior;
- idempotency/concurrency behavior;
- audit events;
- data returned (minimum necessary).

Review in particular:
- `private.phase47_visit_branch_attribution()`
- `private.app_has_branch_access(uuid)`
- `public.create_patient_atomic(...)`
- visit creation and visit billing RPCs;
- lab order creation and `verify_lab_order(uuid)`;
- atomic pharmacy dispense;
- inventory ledger RPCs;
- payment/receipt/claim/compensation RPCs;
- all new helper functions introduced by this campaign.

### E3. Critical existing open workstreams

Reconcile the current state of these previously identified work items and issues. Do not duplicate work already merged or superseded:
- pharmacy dispense role boundary / PR #250;
- private helper EXECUTE ACL / PR #260 and Issue #218;
- backup/restore rehearsal / Issue #199;
- main branch protection / Issue #253;
- pharmacy cancellation/return / PR #293;
- inventory ledger controls / PR #294;
- medicine identity / PR #210;
- pediatric prescribing safety / PR #292;
- WHO ICD-10 2019 / PR #291;
- finance receipt/payment/printing PRs;
- PHI-safe telemetry and security hardening PRs;
- the current open QA operational blocker PR #296.

The latest open-PR search surfaced many parallel implementation and report PRs, including several apparently overlapping Window 02/04/05/06/07/08 reports, CI routing work, finance receipt/payment, saved-prescription printing, pharmacy corrections, medicine identity, inventory ledger, security hardening and documentation. Re-fetch the live set and classify each:
- canonical implementation;
- duplicate/superseded implementation;
- dependent PR;
- independent work;
- report-only evidence;
- stale/unneeded;
- blocked by owner.
Do not close or merge PRs merely to reduce the count. Preserve unique fixes and evidence. Avoid starting duplicate implementation.

### E4. PHI-safe telemetry and audit

- Inspect logs, error boundaries, analytics/telemetry, client-side console output, audit tables and export functions.
- Ensure patient names, phone numbers, national IDs, diagnoses, notes, prescriptions, lab results, tokens and credentials are not emitted into telemetry or exception traces.
- Preserve audit append-only behavior. Confirm ordinary roles cannot update/delete audit records.
- Ensure audit captures actor, branch, action, target type/ID, timestamp and safe metadata without duplicating clinical content.
- Test unauthorized audit access and tamper attempts in QA.
- Review CSV/PDF exports and printing for accidental cross-branch data leakage.

### E5. Data migration and schema integrity

- Reconcile QA and Production schema/migration ledgers read-only, but do not attempt to force them into parity by editing migration history.
- Distinguish missing migration, failed migration, drift, intentional environment difference and stale generated type.
- Review constraints, foreign keys, indexes, triggers, function signatures, grants, RLS and views for all changed entities.
- Use disposable PostgreSQL 17 for baseline + forward migration replay. Verify transaction behavior and rollback on failure.
- Add regression coverage for any real schema mismatch.
- Do not edit canonical baseline merely to make a new test pass unless the historical provenance demonstrates the baseline is wrong.
- Avoid destructive/irreversible QA migration operations; create a recovery plan before applying any QA DDL.

---

## 9. Stage F — Responsive UI, Arabic/English and accessibility acceptance

The prior managed browser could not resize viewports. This means mobile acceptance is **unverified**, not failed and not passed.

1. Identify whether Composio browser tooling supports viewport emulation, device scale, responsive mode, or mobile browser sessions. Use supported methods.
2. Test at 320, 360, 375, 390 and 430 CSS pixels, in both Arabic RTL and English LTR.
3. If remote browser viewport emulation is unavailable, use an authorized alternative browser/device automation path. Do not invent screenshots or claim tests you could not execute.
4. Prioritize complete user journeys on mobile:
   - sign in;
   - patient registration/search;
   - visit creation and queue;
   - GP consultation and diagnosis;
   - prescription;
   - pharmacy receiving and dispensing;
   - lab order/result;
   - billing/payment;
   - inventory and expenses;
   - reports and audit.
5. Check horizontal overflow, clipped dialogs, keyboard overlap, sticky headers, table scrolling, touch target size, focus order, validation errors and navigation.
6. Verify Arabic RTL and English LTR on each critical screen; check mixed Arabic/English labels, dates, numbers, currency, icons and form alignment.
7. Check WCAG 2.2 AA essentials: semantic headings, accessible names, labels, required state, keyboard operation, visible focus, focus management, contrast, error identification/announcement and target sizes.
8. If a physical Android check is still required, record one concise owner action with exact URL, exact test path and expected result. Do not ask the owner for multiple rounds of repetitive screenshots.

---

## 10. Stage G — Operational workflows beyond the immediate blocker

Use `MASTER_PLAN.md` to select additional unfinished, high-value work that can be completed safely without expanding into a redesign. Complete as much as possible after Stages A–F. Prioritize operational continuity, data integrity and security over cosmetic changes.

Review and, where current code/evidence shows a real gap, implement and test:
- patient search, duplicate safety, patient history and address persistence;
- appointments and follow-up reminders;
- clinic queue lifecycle, waiting/in-progress/completed/cancelled states;
- clinical notes, diagnoses, vitals and medical certificates;
- lab catalogue, order, sample, result, review, verification and correction;
- medicine catalogue, prescription linkage, dispense, handover, cancellation, return and quarantine;
- inventory receipt, batch expiry, adjustments, write-off, ledger reconciliation and price history;
- invoices, payments, receipts, cashbox, supplier balances, expenses, insurance claims and reports;
- audit and role/branch settings;
- PDF/print workflows for prescriptions, receipts, invoices, lab results and certificates;
- backup/restore documentation and the existing backup automation.

Do not add features merely because they appear in a list. Verify they are in scope in the current roadmap, identify dependencies, and implement only when the current architecture supports them safely.

### G1. Printing

- Verify actual print layouts for Arabic and English, A4 and thermal/receipt if supported.
- Ensure print views use saved authorized data, not unsaved or fabricated client state.
- Avoid leaking hidden patient fields or another branch's data.
- Test browser print/PDF output, page breaks, signatures/stamps placeholders, and narrow receipt layout.
- Physical printer pairing/paper output may remain owner-only; report the exact device check required.

### G2. Backup and restore

- Inspect Issue #199 and current workflow state, without exposing secrets.
- Diagnose exact backup-runner failure and determine whether the cause is missing/expired credential, Drive permission, encryption/decryption, database dump or retention logic.
- Do not retrieve or print secret values. Never place backup secrets in repository files or logs.
- Run only QA/disposable backup and restore rehearsal under the strict boundary. Do not restore over Production.
- Verify artifact integrity, encryption, decryption in a controlled authorized environment, schema/data restore, migration compatibility and recovery time evidence.
- If a missing owner-only secret or Drive authorization prevents completion, produce exact one-time owner steps and continue unrelated work.

---

## 11. Stage H — Final comprehensive review (mandatory second pass after implementation)

After all code changes and QA work are complete, stop feature development and perform a fresh, independent review pass over the complete resulting candidate. This is a required separate stage; do not reuse the implementation checklist as if it were a review.

### H1. Fresh-state reset

- Re-fetch main, all active branches, all PRs/issues, exact candidate heads, latest CI, Vercel Preview deployment and QA database schema/migration state.
- Re-read the final diff from base to head, not only the files you remember editing.
- Review every changed file, SQL object, generated type, workflow file, test, documentation change and dependency update.
- Review the complete PR conversation and unresolved review threads.
- Verify no unexpected file, secret, PHI, environment file, generated artifact, or unrelated change was included.
- Confirm Production remained unchanged using read-only evidence and no Production Vercel deployment/config event occurred.

### H2. Independent code review checklist

For every changed code path, ask:
- Does the code do exactly what the requirement says?
- Can the user reach the intended path in the actual UI?
- Does the server enforce the same rule as the UI?
- Are authorization and branch checks performed at the authoritative layer?
- Can concurrent requests, retries, stale data or network failure create duplicates or partial state?
- Are amounts, quantities, dates, timezones and units exact?
- Are failures surfaced clearly without leaking backend details or PHI?
- Are previous records and audit history preserved?
- Is the migration forward-safe, ordered, compatible and represented in the canonical baseline/tests?
- Are Arabic RTL and English LTR correct?
- Are mobile, keyboard and screen-reader behaviors acceptable?
- Do tests prove the negative cases and not merely source-string presence?
- Is there any silent catch, optimistic false success, swallowed error, unhandled promise or hidden fallback?
- Did the change introduce a permission expansion, new dependency, cost, deployment trigger or build quota use?
- Are docs and roadmap statuses truthful?

### H3. Required validation on the exact final head

Run only the relevant full suite after targeted checks:
- `npm ci` or the repository's supported clean install;
- `npm run typecheck`;
- `npm run lint`;
- `npm run build`;
- `npm run test:guard`;
- all changed-feature tests;
- insurance claim validation test;
- PostgreSQL 17 baseline replay and forward migration tests;
- clinical E2E acceptance tests where the required isolated environment is configured;
- branch/RLS/ACL tests;
- pharmacy atomic dispense and invoice integration;
- inventory ledger/return/reconciliation tests;
- patient registration/duplicate/idempotency tests;
- lab catalogue/order/result verification tests;
- accessibility/i18n tests;
- secret/PHI scanning and dependency audit.

Use the repository's actual scripts and workflow names; do not invent scripts. Do not run redundant CI if the exact SHA already has a successful result and no relevant files changed. If CI fails, inspect logs, fix the root cause, and rerun only the necessary jobs where possible. A skipped required test is not a pass.

### H4. Defect severity and stop rules

Classify findings:
- **Critical:** plausible patient harm, unauthorized clinical/financial action, cross-branch/PHI exposure, destructive data loss, incorrect stock/payment mutation.
- **High:** major workflow blocker, exploitable authorization gap, incorrect persisted clinical/financial data, unreliable audit or backup/restore.
- **Medium:** degraded but recoverable workflow, inconsistent localization, non-critical data/report discrepancy.
- **Low:** cosmetic or minor usability issue.
- **Owner gate:** cannot be resolved without owner credentials, physical access, clinical sign-off or a policy decision.

Do not call the campaign accepted while any Critical/High issue remains unresolved. If an issue is not autonomously fixable, document the evidence, containment, impact, and exact owner action. Continue unrelated work.

---

## 12. Git and delivery model

- Continue PR #296 for defects within its QA operational-blocker scope. Do not add unrelated feature work to it.
- Create separate PRs only for genuinely independent logical changes (for example, lab schema alignment, pharmacy correction workflow, backup tooling, or unrelated security fixes).
- Keep each logical implementation bundle atomic: code + tests + docs + migration/baseline updates as applicable.
- Do not create a PR for a report-only change unless project policy or the user specifically needs it; update the relevant existing branch/report when appropriate.
- Do not close, merge, or delete other open PRs merely because they are old. Reconcile their content and preserve unique work.
- Do not use force push, rebase published commits, amend published commits, or change main directly.
- Before updating an existing branch, verify its latest SHA and use expected-SHA/lease semantics where supported. If the branch moved concurrently, stop that write and reconcile.
- Ensure documentation-only commits skip frontend builds if workflow policy supports it.
- Use draft PRs while acceptance is incomplete. Mark ready only after all required evidence and review gates pass.
- No merge to main, no Production migration, and no Production deployment under this mandate.

---

## 13. Required repository documentation updates

Do not create competing roadmaps. Update the authoritative existing files where appropriate and create one final campaign report.

1. Update `docs/MASTER_PLAN.md` with current, evidence-backed status for each completed or blocked item. Distinguish:
   - planned;
   - implemented;
   - automated-test verified;
   - PG17 verified;
   - QA browser verified;
   - security reviewed;
   - clinically evidence-checked;
   - clinically reviewed;
   - approved for activation;
   - operationally accepted;
   - owner-blocked.
2. Update `AGENTS.md` only if a durable operational instruction genuinely needs correction. Do not duplicate this entire campaign mandate into AGENTS.
3. Update the current Roshan checkpoint / autonomous completion plan with exact branches, SHAs, PRs, CI run IDs, environments, work completed and next action.
4. Preserve historical reports. Do not overwrite previous dated reports or alter old evidence to imply it was collected now.
5. Create the final report:
   `docs/parallel-reports/NEON_QA_COMPLETION_AND_DEEP_REVIEW_REPORT_2026-11-22.md`
6. Follow `docs/parallel-reports/TEMPLATE.md` where applicable. Include exact links and citations to GitHub commits, PRs, CI jobs, Vercel deployments, QA evidence and source files.
7. Add a concise summary comment to PR #296 linking this mandate and the final report. Link other relevant PRs/issues where their work was completed.
8. Commit documentation together with the related implementation bundle whenever practical; avoid a report-only commit if it can be included in the final logical implementation commit.

### Final report must contain

- Verified date/time and exact main/candidate SHAs.
- PR/issue inventory and canonical/superseded classification.
- Workstream-by-workstream implementation status and exact files/SQL objects changed.
- All tests, commands, versions, exact commit SHA, CI run IDs, pass/fail/skipped counts and links.
- Lab schema mismatch root cause and exact schema contract correction.
- Branch RLS positive and negative evidence.
- Patient duplicate detection server-side, override audit and concurrency evidence.
- End-to-end journey from Reception → GP → Lab → Pharmacy → Billing/Finance → Audit.
- Pharmacy stock before/after, invoice count and idempotency evidence.
- QA role matrix and actual supported roles.
- Route coverage and responsive/RTL/LTR/WCAG results.
- Security review: RLS, grants, function ACLs, RPC authorization, PHI telemetry, audit integrity and branch isolation.
- Migration history/schema parity findings, with Production read-only.
- Vercel Preview deployment URL, exact commit, branch, environment target and browser test evidence.
- Backup/restore status and any owner-only secret/permission blocker.
- Exact list of unresolved Critical/High/Medium/Low issues and owner actions.
- Engineering completion percentage and operational acceptance percentage, each with a transparent denominator/rubric and evidence. Do not reuse old 79.5% / 29% or any historical estimate without recalculating from current work.
- ETA only if supported by observed throughput and remaining dependencies; otherwise state that it is not reliably estimable.
- Explicit statement: Production Supabase and Production Vercel remained untouched.

---

## 14. Definition of done — do not stop early

The campaign is exhausted only when all the following are true or have a precise, evidence-backed owner gate:

### Engineering
- [ ] PR #296 TypeScript duplicate key and undefined translation function defects fixed.
- [ ] Typecheck, lint, build, guard suite and all relevant CI checks green on exact final head.
- [ ] Insurance claim regression confirmed 7/7 or improved with new coverage.
- [ ] Lab catalogue schema contract reconciled and QA synthetic test can be created/edited.
- [ ] Full lab order → sample → result → verification → GP visibility journey tested.
- [ ] Catalogue-linked prescription can be dispensed through the approved RPC.
- [ ] Pharmacy stock, invoice and audit effects are atomic, idempotent and branch-safe.
- [ ] Patient duplicate detection is server-authoritative, safe under pagination/concurrency, and override is audited.
- [ ] Visit branch access has both positive and negative RLS evidence.
- [ ] Expenses month ranges pass every calendar edge case.
- [ ] Pharmacy errors and expiry requirements are localized and enforced server-side.
- [ ] Arabic/English translation audit has no known raw keys or language leaks in covered routes.
- [ ] Canonical role and route matrix has been reconciled and tested.
- [ ] Relevant security, migration and PG17 regression suites pass.
- [ ] Full final deep review is complete and all Critical/High issues are resolved or precisely owner-gated.
- [ ] Final report and roadmap/checkpoint are updated in the repository.

### Operational acceptance
- [ ] Reception → GP → Lab → Pharmacy → Billing/Finance → Audit flow is completed on the correct QA Preview.
- [ ] Role authorization and branch isolation are tested at both UI and server/database layers.
- [ ] No duplicate patient, visit, invoice, payment, lab order, dispense or stock mutation occurs under retries/concurrency.
- [ ] Responsive mobile, Arabic RTL and English LTR are tested or precisely marked owner/device blocked.
- [ ] Physical printer and staff acceptance are not falsely claimed.
- [ ] Clinical decision-support protocols remain unactivated until formal clinical review.
- [ ] Backup and restore evidence is complete or owner-blocked with exact steps.

### Release boundary
- [ ] No merge to main.
- [ ] No Production Supabase writes or migrations.
- [ ] No Production Vercel deployment, promotion, rollback or configuration change.
- [ ] No secrets or PHI disclosed.

---

## 15. Execution order and continuation behavior

Execute continuously in this order, but do not wait on a blocked item before doing independent work:

1. Revalidate live repository, PR #296, all open PRs/issues, CI and Composio connections.
2. Fix the exact CI TypeScript failures and inspect the full PR #296 diff.
3. Complete the PR #296 regression/security review and update its draft PR.
4. Resolve the QA lab schema contract and complete lab E2E.
5. Complete catalogue-linked pharmacy dispense and financial/inventory reconciliation.
6. Complete patient duplicate/override/idempotency and branch RLS negative cases.
7. Complete route/role, localization, mobile and accessibility acceptance.
8. Reconcile open security/pharmacy/inventory/finance/backup/branch-protection work without duplicating existing PRs.
9. Complete the independent final deep review.
10. Update roadmap/checkpoint, write the final report, commit and link evidence.
11. Recheck all final states after documentation commits. Ensure the report does not claim a result from an earlier SHA as if it applied to the final SHA.

If the owner later says only “أكمل” or “Continue”, resume from the final report/checkpoint's exact Next Action after verifying live repository state. Do not repeat completed tasks.

**Start now. Use Composio. Fix and verify; do not merely plan. Continue until the maximum safe autonomous work is completed, then perform the full independent review and report.**
