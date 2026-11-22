# Roshan Health Hub — Owner-Gated QA Acceptance & Release-Gate Closure Mandate

**Created:** 2026-11-22  
**Executor:** Neon (primary autonomous engineering executor)  
**Repository:** `crauch2088-source/roshan-health-hub`  
**PR:** [#296](https://github.com/crauch2088-source/roshan-health-hub/pull/296)  
**Branch:** `fix/qa-operational-blockers-20261121`  
**Starting head (must re-verify):** `a12589d61496571b0fc1b3b0377455b4f4b4ca52`  
**Base SHA previously observed:** `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`

## 0. Binding objective

Execute one continuous closure campaign. Reconcile the previous report with live evidence, fix the QA Preview deployment issue, complete all safe automated acceptance work, investigate and safely address the reported 18 SECURITY DEFINER/search_path findings in QA only, prepare the remaining owner-only steps, perform a fresh independent review after changes, and commit a final report. Do not start unrelated features, duplicate completed work, or stop after writing a plan. Do not ask the owner to say “continue”.

Read first:
- `docs/NEON_AUTONOMOUS_QA_COMPLETION_AND_DEEP_REVIEW_MANDATE_2026-11-22.md`
- `docs/parallel-reports/NEON_QA_COMPLETION_AND_DEEP_REVIEW_REPORT_2026-11-22.md`
- `docs/parallel-reports/TEMPLATE.md`
- `docs/MASTER_PLAN.md`

## 1. Mandatory Composio procedure

The owner explicitly requires **Composio MCP** as the primary integration layer for GitHub, Supabase, Vercel, and supported browser workflows.

- Start with Composio discovery for every required workflow. Use only exact returned tool slugs. Retrieve complete schemas for schemaRef tools.
- Confirm ACTIVE connections and explicitly select the correct account when multiple accounts exist.
- Verify exact identities before actions:
  - QA Supabase: `hopfohcnrtbiqjkgeukz`
  - Production Supabase: `jewzonxplxhogqrnhosl`
  - Vercel project: `prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`
  - Vercel team: `team_GxMH4eyATlCfJMG8SJXzDcAg`
- Never infer which Supabase or Vercel account is QA/Production from ordering or alias. Verify returned project references.
- Keep an action ledger: time, action/tool, exact target, read/write classification, outcome, evidence URL. Never log secrets or PHI.
- Batch only independent read calls. Never parallelize dependent writes.

## 2. Safety boundaries — absolute

**Production Supabase and Production Vercel are READ-ONLY.** No writes, migrations, grants/revokes, RLS changes, Auth/role changes, storage writes, secrets/config changes, deploys, promotions, rollbacks, aliases, domains, or environment changes.

QA only, synthetic records only, after verifying exact QA project and target. Preserve previous synthetic evidence. Do not weaken RLS, branch isolation, authentication, permissions, audit, tests, or security controls. No real patient/staff/clinical/financial data. No new paid services or quota bypass. Never expose credentials, tokens, private backup keys, or PHI. Do not activate clinical protocols. Do not merge PR #296 or any PR to main, do not modify main, close the PR, mark it ready, or approve release. No force-push or history rewrite. Keep PR #296 Draft and unmerged.

If an action crosses these boundaries, do not perform it; document the precise blocker and continue independent safe work.

## 3. Reconcile live state before work

Fetch current PR #296, branch head, base SHA, current main SHA, commits, changed files, reviews/comments, and all check runs. Do not assume the previous report remains current.

Verify exact-head CI for the full SHA `a12589d61496571b0fc1b3b0377455b4f4b4ca52` and any newer head. Enumerate all workflow runs and check runs; classify PASS/FAIL/SKIP/CANCELLED/PENDING/NOT RUN. A skipped check is not a pass.

**Reconcile the prior count discrepancy:** the report says 8/8 workflows passed, while a subsequent live Composio listing exposed seven workflow runs on the exact SHA. Inspect run `45035537910` (described as PR #296) and establish whether it is a distinct workflow, a deployment/check, or another event. Do not report 8/8 unless eight distinct applicable workflows on the exact SHA are proven.

Re-read the previous report and current `MASTER_PLAN.md`. Label claims current verified, historical verified, owner-reported, inferred, or not rechecked. Verify all referenced files and migrations exist at the current branch head. Record main/head divergence.

## 4. P0 — complete or owner-gate the QA pharmacy dispense

The previous report says a catalogue-linked synthetic prescription for `QA Test Paracetamol 500mg`, quantity 2, expected total 300 SDG, with prior stock 10, is pending in `/pharmacy`. A managed-browser confirmation policy blocked the final Dispense click.

1. Inspect QA only. Locate the existing pending synthetic prescription; do not create a duplicate if it remains valid.
2. Verify it is linked to the canonical medicine, correct quantity/price, correct patient synthetic identity, correct branch, and authorized pharmacist role.
3. Use Composio/browser if the authorized QA UI can be completed without bypassing takeover.
4. If `requires_user_takeover: true`, stop at that boundary. Do not bypass it with direct RPC, hidden API, privileged SQL, impersonation, or browser-policy evasion. Leave the owner a direct QA URL and exact action.
5. After the owner performs the UI click, verify from QA: stock 10→8 (or explain a changed baseline); one dispense only; one matching invoice line; correct total; correct status transitions; audit actor/action; retry idempotency; no double billing; free-text rejection without stock movement.
6. Until evidence exists, mark dispensing **OWNER REQUIRED / NOT COMPLETED**. Do not claim success.

## 5. P0 — diagnose and recover the exact QA Preview

The previous exact-head Vercel lookup for branch `fix/qa-operational-blockers-20261121`, SHA `a12589d61496571b0fc1b3b0377455b4f4b4ca52`, returned deployment `dpl_3fRGCogi9SgNANyuEm88v1MMb17p` in **CANCELED** state, with reason: “The deployment was canceled because the Ignored Build Step command returned exit code 0.”

The project ignore command observed was:

```sh
git diff --quiet HEAD^ HEAD -- src/ public/ index.html package.json package-lock.json vercel.json vite.config.ts tsconfig*.json
```

This is not a build failure. It likely means the last commit did not touch configured application paths. Prove the actual situation:

1. Inspect deployments for exact branch/head and preceding application-code commits. Find newest READY Preview and its full Git SHA.
2. Inspect Vercel deployment metadata/events and compare the runtime source tree at that Preview SHA with the PR head. Establish whether all app-code fixes from PR #296 are already present in a READY preview even if the final test/docs-only commit was skipped.
3. Inspect the ignore command and commit diff. Do not change project settings just to force a build.
4. If a READY Preview contains identical runtime source/config to the current PR head, document its actual deployment SHA and use it for QA UI acceptance only with that caveat.
5. Otherwise, use a supported Vercel QA Preview deployment action only if it targets this exact project/team/branch and cannot affect Production. Verify target=preview, full SHA, URL, READY state, and successful build/checks.
6. Do not use Production alias/deployment as QA. Do not consume repeated build quota. If no safe deployment route exists, document exact owner-only Vercel action required.
7. Verify the actual preview serves the expected application and test routes: `/login`, `/dashboard`, `/patients`, `/visits`, `/clinic`, `/lab`, `/lab-catalog`, `/pharmacy`, `/inventory`, `/expenses`, `/billing`, `/audit`.

## 6. Android responsive, RTL and LTR acceptance

The previous report says the managed browser could not resize viewports. Do not mark mobile passed based on desktop screenshots.

- Discover whether an authorized browser/viewport tool can test 320, 360, 390, and 430 CSS-pixel widths.
- Test Arabic RTL and English LTR separately, on login, navigation, dashboard, patient registration/search/dialogs, visit/GP, lab, pharmacy, inventory, expenses, billing/receipt, and audit.
- Check horizontal overflow, clipped content, modal sizing, keyboard overlap, table behavior, touch targets, focus, icon order, and untranslated strings.
- Distinguish viewport emulation from physical Android/Honor-device acceptance.
- If automation is unavailable, create a precise owner-operated phone checklist with URLs, steps, expected results, and pass/fail fields. Mark physical mobile acceptance owner-required; never claim it passed.

## 7. Security finding — reported 18 SECURITY DEFINER functions

The prior report listed these functions as having mutable search_path in QA and Production:
`audit_row_change`; `bootstrap_super_admin` (two overloads); `create_staff_user`; `current_role_name`; `fn_cashbox_immutable`; `fn_finance_audit`; `fn_ledger_from_expense`; `fn_ledger_from_payment`; `fn_ledger_from_supplier_payment`; `fn_ledger_post`; `fn_recompute_invoice_paid`; `fn_recompute_supplier_bill`; `get_current_user_profile`; `record_cashbox_expense`; `record_cashbox_payment`; `record_cashbox_supplier_payment`; `sync_supplier_bill_payment`.

Do not assume the list/count is still correct. Re-enumerate exact function signatures/overloads, owner, language, SECURITY DEFINER flag, proconfig/search_path, ACL, and dependencies in both environments using read-only catalog queries.

For each function:
- Read its definition and identify every unqualified object reference, extension dependency, temp-schema dependency, and trigger/RPC caller.
- Do not blindly set `search_path = ''` unless all non-catalog objects are explicitly schema-qualified and behavior is preserved.
- Create a dedicated isolated migration only if justified. Pin exact signatures; do not use wildcard/dynamic SQL that could alter unintended overloads.
- Add PG17 replay, function config, ACL invariance, behavior regression, and malicious shadow-schema tests.
- Preserve intended owners, EXECUTE grants, PUBLIC/anon/authenticated permissions, RLS assumptions, and trigger context unless a separately reviewed change is required.
- Apply and test in QA only. Production is catalog-read-only; do not apply this migration there.
- Leave any unsafe-to-change function untouched and document why.
- Produce a before/after table for each signature, search_path, owner, ACL, and test result.

This is targeted remediation, not a claim of complete security certification.

## 8. Backup and restore owner gate

Re-fetch latest backup-runner source SHA, workflow run, artifact metadata/digest, encrypted copy metadata (if authorized connector access exists), and runner-side PG17 restore evidence. Check whether artifact scope is database-only; do not call it a complete Supabase control-plane/storage/secrets backup.

Owner-side local decryption is reported unverified. Never request, read, upload, print, or store the owner's private age identity/key. Prepare a concise offline procedure for the owner to verify digest, decrypt locally, restore into a disposable isolated PostgreSQL 17 target, and report success/failure. Do not send private key material to Neon, ChatGPT, GitHub, Supabase, or Vercel. Mark this gate owner-required until independent evidence is supplied.

## 9. Roles, routes, and operational regression

Reconcile live canonical roles and legacy mappings. Prior report saw five active QA roles (`admin`, `doctor`, `lab_tech`, `pharmacist`, `receptionist`) and reported `super_admin`, `dentist`, `specialist`, `lab_doctor`, `lab_assistant` missing as QA identities/canonical roles. Verify current state; do not invent roles/accounts or grant privileges to complete a checklist. Do not directly edit `auth.users.encrypted_password`. Use only supported QA Auth flows if required and authorized.

Test allowed and denied routes/actions for every existing QA role, including cross-branch access. Verify fail-closed behavior and no data leakage.

Re-run focused synthetic workflow tests only where evidence is missing or stale:
- Reception: patient create/search/edit, duplicate detection/override, address persistence, active branch, queue ticket.
- GP: queue call, visit, note, diagnosis, vitals, lab order, catalogue-linked prescription.
- Lab: order receive, result entry/save/verification, invalid and unauthorized transitions.
- Pharmacy: catalogue-linked dispense, stock/invoice/audit atomicity, retries, insufficient stock, expired batch, free-text rejection, wrong branch, unauthorized role.
- Finance: invoice totals, payment/receipt idempotency, no duplicate charge, SDG formatting.
- Expenses: month-end boundaries, leap year, 30/31-day months, half-open ranges and timezone boundaries.
- Audit: expected events, no secrets/PHI, no false success on denied actions.
- Clinical: no protocol activation; clinician approval remains explicit.

Do not generate duplicate test transactions when existing synthetic records can be reused.

## 10. Open PR / issue reconciliation

Re-fetch current state; previous report references #296, #250, #210, #258 (possibly superseding #179), #181/#280, #260/#218, #290–#295, #199, #253, and related finance, inventory, ICD-10, pediatric safety, telemetry and backup work. For each relevant item record state, draft/ready, base/head SHA, CI, dependency, duplicate/superseded status, and whether it blocks this campaign. Do not merge, close, retarget, or rewrite any PR. Do not duplicate existing work. Use the owning branch when appropriate; create a separate narrow PR only for genuinely separate required changes.

## 11. Independent review after implementation

After all changes, perform a fresh review from the final branch head:
- inspect full diff of all new commits;
- review SQL/migrations, RLS, branch isolation, SECURITY DEFINER/search_path, ACL, RPC atomicity, stock/ledger/invoice invariants, idempotency, audit and PHI exposure;
- review route guards, error handling, i18n, RTL/LTR, responsive behavior and accessibility;
- run applicable unit/integration/guard/typecheck/lint/build/PG17 tests on exact final SHA;
- enumerate completed, skipped, pending and failed checks separately;
- re-fetch Preview and prove branch, full SHA, preview target, URL, READY state and runtime source parity;
- confirm Production remained read-only and no merge/main change occurred;
- classify findings with severity, evidence, impact, correction, owner, and whether they block QA acceptance or Production.

## 12. Documentation and final report

- Add a dated concise checkpoint to `docs/MASTER_PLAN.md`; append only, preserve historical entries.
- Never overwrite the previous campaign report.
- Create `docs/parallel-reports/NEON_OWNER_GATED_QA_CLOSURE_REPORT_2026-11-22.md` using `docs/parallel-reports/TEMPLATE.md`. Identify the correct window/round from repo instructions; do not guess. If no window applies, say so.
- Include exact branch/head/base/main SHAs, commits, PR links, exact CI run IDs, Preview deployment ID/URL/SHA, QA project reference, migration evidence, test results, action ledger summary, and explicit actions not performed.
- Separate: implemented, automated-test verified, live QA verified, independently reviewed, owner-required, blocked/not tested.
- Recalculate Engineering RC and Operational Acceptance only if the current rubric/evidence support it. Show weights/calculation. Documentation-only work earns no implementation credit. Otherwise label previous 69.8% / 28.0% as historical and current score unassessed.
- Production decision stays **NO-GO** until all mandatory gates are independently approved.

The final report must explicitly answer:
1. Exact final PR head and current main SHA; PR #296 state/draft/merge status.
2. Exact QA Preview URL, deployment ID, target, state and Git SHA—or precise owner blocker.
3. Exact-head CI list with PASS/FAIL/SKIP/PENDING/NOT RUN and resolution of the 7-vs-8 workflow discrepancy.
4. Pharmacy dispense result and stock/invoice/audit/idempotency evidence—or explicit owner click outstanding.
5. Mobile viewport and physical Android status, distinguishing emulation from device acceptance.
6. Current exact state of all 18 reported function signatures in QA and Production; QA migration/tests if performed; explicit confirmation Production unchanged.
7. Backup artifact evidence and owner-side decryption status.
8. Roles/routes tested and unsupported roles/permissions.
9. Relevant PR/issue reconciliation.
10. Independent review scope and exact evidence.
11. Owner/clinical/physical actions still required.
12. Evidence-weighted scores or reason current scores cannot be calculated.
13. Production GO/NO-GO and exact blockers.

## 13. Definition of done and execution

Do not claim full closure unless live repository/CI/Vercel/QA state is reconciled; a source-verified QA Preview is ready or its precise owner blocker documented; all safe automated acceptance work is done; pharmacy dispense is verified or explicitly owner-gated; the 18-function finding is re-enumerated and safely remediated/tested in QA or precisely blocked; mobile and backup owner gates are honest; roles and related PRs are reconciled; independent review occurs after implementation; exact-head CI/PG17 evidence is complete; MASTER_PLAN and a new template-based report are committed and linked from PR #296.

**Start now. Continue through every safe section. Do not return a plan-only or progress-only response. Do not ask the owner to say “continue”. Leave PR #296 Draft and unmerged. Production remains strictly read-only.**
