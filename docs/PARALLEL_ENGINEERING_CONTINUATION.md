# Parallel Engineering Continuation Protocol

**Repository:** `crauch2088-source/roshan-health-hub`  
**Created:** 2026-11-16  
**Purpose:** Let each of the ten parallel engineering conversations resume safely when the owner says only **"Continue" / "أكمل"**, without re-explaining the project, repeating completed work, or widening the assigned scope.

This document is an execution handoff, not a release approval. `docs/MASTER_PLAN.md`, `AGENTS.md`, `.specify/memory/constitution.md`, current source, live GitHub state, and the exact task/issue remain authoritative.

---

## 1. Standing instruction for every window

Each window must receive the bootstrap prompt in §2 once. After that, the owner may simply write **"أكمل"**. On every continuation:

1. Re-read this document, especially the window's latest round entry in §4, and re-read the original task prompt and relevant issue/PR.
2. Verify the current repository state from GitHub. Do not assume the previously reported SHA, PR head, CI result, issue state, or migration state is still current.
3. Resume from the recorded **Next action**. Do not restart completed investigation or recreate an existing branch, commit, test, PR, issue, or review comment.
4. If the task has already been implemented, merged, superseded, or invalidated by newer mainline work, prove that from current source/history and switch to the smallest missing verification or regression test. Do not create duplicate implementation.
5. Make real progress in the assigned scope: inspect → reproduce → fix/design → test → document → deliver. A report or plan alone is not implementation when an implementation task remains feasible.
6. Use test-first development for behavior changes. Use disposable PostgreSQL 17 for SQL/RLS/ACL/transaction behavior. Run focused tests first and one coherent exact-head CI pass after the complete change.
7. Keep one logical task in one branch and one atomic commit, including tests and documentation. Respect the repository quota rules: no redundant CI, no unnecessary Vercel build/deployment, no paid service.
8. Preserve all higher-priority safety gates. No real patient/clinical/financial data in prompts, fixtures, logs, or external services. Use synthetic data only in disposable/QA test environments.
9. Do not merge, close issues/PRs, apply hosted migrations, change live ACL/RLS, write business data, or promote deployments unless the original task and current release gates explicitly authorize that exact action. A green CI is not clinical or staff acceptance.
10. Report only evidence actually obtained. Distinguish **passed / failed / skipped / blocked / not run**. Finish each response with: (a) work completed, (b) exact branch/commit/PR, (c) tests and exact result, (d) unresolved risks, and (e) one precise next action.

### Stop conditions

Stop and report a blocker rather than guessing if the target branch/head is ambiguous, the original scope conflicts with newer mainline contracts, a required credential/owner decision is missing, a destructive action is proposed, a clinical-policy decision is needed, or the safe recovery path is unknown. Do not silently broaden scope to make a task appear complete.

---

## 2. One-time bootstrap prompt — paste once into each existing window

> Adopt `docs/PARALLEL_ENGINEERING_CONTINUATION.md` as the standing continuation protocol for this repository. Your window identity and original task scope remain unchanged. Read §4 for your window number, latest findings, and next action. From now on, when I say only **"أكمل"**, re-check current GitHub/source state and continue the next unfinished action in your assigned window; do not ask me to repeat the prompt or context. Do not redo completed work, create duplicate PRs, or expand into another window's scope. Follow AGENTS.md, the Spec Kit Constitution, docs/MASTER_PLAN.md, the original task's safety limits, and all release gates. Make implementation progress where the task requires it, test it, document evidence, and report exact status. **Mandatory isolated report:** publish your report using `docs/parallel-reports/TEMPLATE.md` to `docs/parallel-reports/round-01/window-XX.md` (replace XX with your window number). Edit only your own report file; never combine reports or overwrite another window's file. Commit it with your task PR, or use a separate docs-only report PR for review-only work. Include the exact file path and commit/PR link in your chat response. For every later round, create a new `round-NN` file and preserve prior reports. Never claim an unperformed action succeeded.

Once this bootstrap has been sent to a conversation, the owner should not need to paste the full original task again.

---

## 3. Cross-window coordination rules

- **Window ownership is strict.** A window may identify a dependency in another window, but must not edit that other window's files or take over its task. Record the dependency and notify the owner.
- **Shared files are serialized.** `docs/MASTER_PLAN.md`, `AGENTS.md`, migration manifests, package manifests/lockfiles, shared workflows, and common fixtures are not to be edited casually by parallel windows. Propose one consolidated owner/coordinator change after the relevant work is complete.
- **No false completion by arithmetic.** A review marked 100% means that review was performed; it does not mean the underlying defect is fixed. A feature already present on main is not new work delivered by the current session.
- **Exact-head evidence only.** CI from a predecessor commit does not validate a later PR head. Recheck the exact current head before calling a candidate verified.
- **No implicit environment promotion.** A SQL file in a PR is not an applied migration. QA validation is not Production validation. Production readiness requires provenance/reconciliation, recovery evidence, least-privilege review, exact-head checks, and applicable human acceptance.
- **No premature closure.** Keep Draft/HOLD/Request Changes while material findings remain. Do not close a superseded PR or issue until its replacement is accepted and the owner-approved closure condition is met.
- **Consolidate at round end.** The coordinator updates §4 with actual outcomes, evidence, dependencies, and next actions. The ten windows then continue from that handoff.

---

## 4. Round 01 handoff — 2026-11-16

**Baseline supplied for this round:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`  
**Important:** This is the round's requested baseline, not a permanent assumption. Every continuation must verify current `main` and exact PR heads.

### Window 01 — Clinical prescription completeness and printing / PR #258

**Established findings**
- #258 is the current candidate for saved-prescription printing and Phase 63; #179 is an older divergent line and must not be merged over the rebased candidate.
- Phase 63 trigger has a confirmed review concern: the `NEW.deleted_at IS NOT NULL` early return may permit an active row to be soft-deleted while clinical fields are simultaneously made invalid.
- Printing uses saved records and status allowlisting; physical Android/A4/thermal acceptance and authenticated role acceptance remain unproven.

**Next action**
1. Recheck current #258 head and review-thread state.
2. Fix the active-to-deleted transition without weakening historical already-deleted rows; reject or preserve protected clinical payload changes on the transition.
3. Add a PostgreSQL 17 regression test for simultaneous soft-delete + invalid dose/frequency/quantity, plus ordinary soft-delete and already-deleted-row cases.
4. Decide and document whether MRN or another stable patient identifier is mandatory for official output; do not invent a clinical/identity policy.
5. Re-run focused print/Phase 63 tests and exact-head CI. Keep Draft until independent clinical/security review and real-device acceptance are complete.
6. Treat #179 as superseded only after #258 is accepted; do not close it prematurely.

**Hard boundary:** No clinical dose inference, no live migration, no physical-print acceptance claim without physical testing.

### Window 02 — Phase 61C security / PR #250

**Established findings**
- #250's core wrapper design enforces pharmacist role plus both `pharmacy.update` and `billing.create`, with private unchecked implementation and fixed empty search paths.
- QA and Production have not received Phase 61C. Production also lacks Phase 61B according to the round's evidence.
- Existing hosted dispense RPCs therefore remain a release blocker; the candidate PR is not itself a production fix.
- Additional gaps: explicit Doctor denial on the atomic entry point, concurrent idempotency/same-prescription/last-stock tests, authenticated PostgREST role-switch acceptance, and independent price-update authorization review.

**Next action**
1. Recheck current #250 head, Phase 61B/61C migration dependencies, and live read-only state only if the original task authorizes it.
2. Add missing disposable PostgreSQL 17 concurrency and explicit Doctor-denial tests; verify no idempotency row is created on denied requests.
3. Independently trace the medicine price mutation path and define a separate scoped follow-up; do not silently fold it into #250.
4. Reconcile Production migration provenance before any environment rollout. Keep #250 Draft/HOLD until exact-head CI and independent security review pass.

**Hard boundary:** Do not apply Phase 61B/61C to QA or Production from this continuation prompt. No hosted ACL changes.

### Window 03 — Medicine catalogue identity / pack attestation / PR #210

**Established findings**
- Phase 60 improves identity-field separation and restricts identity-column writes; append-only pack-attestation records have good integrity properties.
- The attestation proves a pharmacist's recorded review of stored identity, not independent physical, barcode, manufacturer, or regulatory verification.
- Product identity, commercial pack identity, base dispensing unit, and conversion ratios are not yet a complete model.
- Duplicate identity handling, normalization, historical prescription display, and post-stock identity correction need evidence.
- Latest PR head/CI must be rechecked; the report's cited commit was not proven to be the current head.

**Next action**
1. Recheck latest #210 head and current catalogue schema/call sites.
2. Add a narrowly scoped duplicate-detection/identity policy that distinguishes equivalent products from different manufacturers and does not use a naïve uniqueness key.
3. Test historical prescription/receipt rendering after a medicine display-name change, and test identity changes after batches/stock exist.
4. Document attestation semantics accurately in UI and API.
5. Keep Pack Identity and Pack-to-Unit Conversion as a separate specification/workstream with PostgreSQL invariants; do not invent conversion rules or mix the entire feature into #210.
6. Re-run exact-head CI and independent SQL review before recommending merge.

**Hard boundary:** Do not represent attestation as barcode/physical/regulatory validation. Do not alter existing stock, batch, price, or prescription history.

### Window 04 — Financial receipt integrity / PR #181

**Established findings**
- The receipt is sourced from persisted payment data and validates invoice/payment/ledger provenance, branch, currency, and reversal linkage.
- High-priority issue: the UI does not pass the RPC's `_idempotency_key`; retries after a lost response may duplicate a payment.
- Other open decisions include immutable receipt identity, historical cashier attribution, permission parity, Bankak reference requirements, and payment-ledger reconciliation.
- The reported PR base diverged from the requested baseline and must be reconciled before integration.

**Next action**
1. Recheck #181 head/base and current payment RPC signature.
2. Implement a stable per-attempt idempotency key that survives retries but changes for a genuinely new payment; test lost-response/retry behavior on disposable PostgreSQL 17.
3. Reconcile displayed balance with active payment ledger totals and test exact decimal/overpayment/reversal cases.
4. Resolve `payments.read` versus `billing.read` permission expectations with role-matrix tests.
5. Define whether payment UUID + cashbox ledger is the canonical immutable receipt identity; preserve actor attribution and method-specific Bankak reference validation.
6. Keep Draft until exact-head tests and finance/security review pass.

**Hard boundary:** No live financial writes; no real payment or patient data in tests.

### Window 05 — CI workflow routing / PR #256

**Established findings**
- Narrow path filters are preferable to broad `db/**` or `tests/**` triggers.
- The prescription atomicity workflow omitted source files consumed by its test, including `src/lib/prescription-draft.ts` and `PrescriptionTab.tsx`.
- `package.json` is an execution dependency for Node module mode in some workflows and is missing from relevant filters.
- Existing tests validate duplicated path lists, not the real workflow dependency graph.
- Branch protection/required-check behavior must be reconciled because path-skipped checks can leave required contexts pending.

**Next action**
1. Recheck #256 current head and workflow files.
2. Add the missing source and package manifest paths to the appropriate narrow filters.
3. Improve tests to parse the actual YAML and verify the workflow's consumed files/commands, manual dispatch, and push/pull-request routing.
4. Verify path-filtered jobs cannot silently omit required aggregate PR status; coordinate the always-running aggregate gate/branch protection design with the release owner rather than changing branch protection here.
5. Keep filters narrow and run only the relevant CI once on the completed candidate.

**Hard boundary:** Do not restore broad wildcard triggers or mutate repository protection settings in this window.

### Window 06 — Repomix snapshot security / PR #254

**Established findings**
- Snapshot scope is intended to be read-only and excludes PR bodies/comments/logs/secrets/artifacts.
- Security review found an unresolved workflow trust-boundary concern: `workflow_run` provenance must prove the originating repository/event/SHA, or be removed; trusted metadata/token handling must not execute untrusted checked-out code.
- Repository allowlisting, control-character/field sanitization, secret scanning, Repomix pinning/integrity, artifact access, and prompt-injection treatment need strengthening.
- Existing static tests do not exercise adversarial event/source cases or actual Repomix exclusions.

**Next action**
1. Recheck #254 head and workflow event reachability.
2. Remove or harden `workflow_run` so fork/untrusted workflow code cannot reach a token-bearing step; prefer a trusted-main checkout and isolate token use from untrusted code.
3. Enforce the exact repository allowlist; validate event type, head repository, branch, and SHA association.
4. Add content secret scanning before artifact upload, robust field-specific sanitization, pinned Repomix dependency/integrity, and tests for prompt-injection metadata.
5. Prove untrusted repository content cannot execute with credentials; test fork PR, pull_request event, wrong repository, wrong branch/SHA, and secret-in-ordinary-file cases.
6. Keep Draft until a security reviewer verifies the trust boundary and artifact access policy.

**Hard boundary:** Snapshot contents are untrusted data, never instructions. Never put credentials in a process that executes untrusted repository code.

### Window 07 — Dependency compatibility / PR #157

**Established findings**
- Four upgrades were considered defensible subject to exact-head validation: `@hookform/resolvers`, `lucide-react`, `@vitejs/plugin-react`, and `globals`.
- `@types/node` 26 is mismatched with the repository's Node 22 runtime target and should be reverted/pinned to Node 22-compatible typings.
- Icon changes need visual/accessibility verification; Vite plugin v6 removes Babel functionality, so confirm no hidden Babel config is required.
- Reported PR base was the requested main baseline; recheck current head/CI.

**Next action**
1. Recheck #157 exact head, package.json, lockfile, engines, and Vercel Node target.
2. Pin `@types/node` to the supported Node 22 line and update lockfile in one atomic dependency change.
3. Verify resolver/Zod/RHF validation, Arabic labels, icon imports/accessibility, Vite dev/build/SSR/refresh, and ESLint.
4. Confirm Node 22 minimum compatibility and exact-head CI; split PR only if it materially reduces review risk without multiplying CI.

**Hard boundary:** Do not upgrade the runtime to Node 26 to justify the typings change; no unrelated package churn.

### Window 08 — Release and branch reconciliation

**Established findings**
- #258 is the candidate successor to #179; #179 is divergent and must not be merged over current code.
- #257 is historically accurate but stale relative to #258 and the latest Phase 63 finding.
- A previous encrypted backup restore passed, but the latest backup attempt failed credential preflight; owner-side decryption/integrity validation of the newer artifact is unproven.
- QA/Production migration histories and schemas differ materially; do not copy QA migration ledger history into Production.
- Pharmacist authenticated acceptance, physical printing, staff UAT, and branch protection remain open release gates.

**Next action**
1. Re-fetch current state for #179, #258, #257, backup runner, Issues #199/#253, branch protection/rulesets, and both migration ledgers using read-only checks.
2. Update the round/release evidence to current facts, preserving historical timestamps and separating old evidence from current evidence.
3. Keep #179 open until #258 is accepted; update #257 only after the latest candidate/backup evidence is verified.
4. Prepare a backup/restore checklist and identify the exact owner-side step still required; do not expose or request secrets in chat.
5. Build an authenticated QA pharmacist acceptance and physical-print checklist using synthetic data; do not claim acceptance until a human performs it.
6. Keep Production NO-GO while any P0 gate remains unresolved.

**Hard boundary:** No backup secret mutation, no production migration, no branch protection mutation, and no issue/PR closure from this window without explicit task authorization and verified gates.

### Window 09 — Pharmacist-to-prescriber correction workflow / Issue #217

**Established findings**
- The backend workflow already exists on main through the Phase 61/61B implementation; creating another backend PR would duplicate functionality.
- Existing PostgreSQL 17 tests cover request/resolution roles, responsible prescriber, wrong branch, duplicate/concurrent resolution, audit, and no new stock/invoice rows.
- Current no-side-effect assertions rely too much on row counts and may miss UPDATEs to existing stock or finance rows.

**Next action**
1. Recheck Issue #217 and the current Phase 61/61B SQL/tests on main.
2. Strengthen disposable PostgreSQL 17 tests by snapshotting and comparing actual values (not only counts) for `medicines.stock_quantity`, `pharmacy_inventory`, `stock_movements`, `invoices`, `invoice_items`, `payments`, and `cashbox_transactions`.
3. Include both accepted and rejected correction paths and assert no unintended inventory/financial mutation.
4. Ensure Phase 57/57B completeness gates remain independent and cannot be bypassed by correction resolution.
5. If the issue is already closed or equivalent tests have landed, prove it and report no duplicate PR.

**Hard boundary:** Do not recreate the backend, change dispensing/billing behavior, or apply hosted migrations.

### Window 10 — Phase 55 private helper ACL regression / Issue #218 / PR #260

**Established findings**
- Existing Phase 55 tests cover effective EXECUTE denial for the target roles, SECURITY DEFINER callers, and the role-sync trigger.
- New PR #260 adds a real PostgreSQL 17 regression for four insurance RLS policy paths that directly call `private.app_has_claim_branch(uuid)`.
- The test fails with permission denied after Phase 55 revokes authenticated EXECUTE. This is a demonstrated functional regression, not a reason to grant EXECUTE back to authenticated.
- A safe, branch-scoped SECURITY DEFINER wrapper or equivalent RLS design is needed.

**Next action**
1. Recheck #260 and Issue #218 current head, tests, and review state.
2. Trace all direct policy and function call sites of `app_has_claim_branch(uuid)`, including all insurance SELECT/INSERT/UPDATE/DELETE policies and delegated SECURITY DEFINER callers.
3. Design the narrowest authenticated-callable wrapper that derives actor identity from `auth.uid()`, validates branch access internally, fixes `search_path`, and cannot be used as an arbitrary branch-membership oracle.
4. Add PostgreSQL 17 positive/negative tests for all four current policy paths, direct denial of the underlying helper, cross-branch isolation, SECURITY DEFINER callers, trigger behavior, and unchanged ACLs for unrelated public functions.
5. Keep #260 Draft until the regression is green and an independent security review approves the wrapper and RLS semantics.

**Hard boundary:** Never GRANT authenticated direct EXECUTE on the underlying helper merely to make the regression green. No hosted ACL/migration changes.

---

## 5. Round closeout template

At the end of every ten-window round, append a new dated subsection using this structure. Preserve prior round records; do not rewrite history.

- **Round baseline:** exact main SHA at round start.
- **Window status:** for each window, current branch/PR/issue, exact head SHA, state, tests, findings, and whether work is implemented or review-only.
- **Accepted findings:** only findings independently verified against current source/tests.
- **Unresolved blockers:** severity, affected paths, evidence, dependency, and owner decision if any.
- **Cross-window dependencies:** explicit ordering; identify one owner window per change.
- **Next action per window:** one concrete, executable step; avoid vague "continue investigation".
- **Release gates:** migration parity, backup/restore, exact-head CI, independent review, authenticated role acceptance, physical print, staff UAT, and branch protection as applicable.
- **Readiness:** report engineering readiness separately from operational acceptance; change percentages only when new evidence justifies it.
- **No-change declaration:** explicitly list any environment, migration, ACL, deployment, or business-data actions not performed.

**Round closeout is not a merge/release authorization.** The owner/coordinator must reconcile conflicting reports and current mainline evidence before authorizing the next action.


## 6. Mandatory isolated report delivery — one file per window

**Every window must publish its report as a separate Markdown file in the repository.** A report written only in chat is not a delivered round artifact. Do not put ten windows' reports into one shared file, and do not edit another window's report.

### Round 01 report destinations

Each window owns exactly one path:

| Window | Required report file |
|---|---|
| 01 | `docs/parallel-reports/round-01/window-01.md` |
| 02 | `docs/parallel-reports/round-01/window-02.md` |
| 03 | `docs/parallel-reports/round-01/window-03.md` |
| 04 | `docs/parallel-reports/round-01/window-04.md` |
| 05 | `docs/parallel-reports/round-01/window-05.md` |
| 06 | `docs/parallel-reports/round-01/window-06.md` |
| 07 | `docs/parallel-reports/round-01/window-07.md` |
| 08 | `docs/parallel-reports/round-01/window-08.md` |
| 09 | `docs/parallel-reports/round-01/window-09.md` |
| 10 | `docs/parallel-reports/round-01/window-10.md` |

For later rounds, use the same convention: `docs/parallel-reports/round-NN/window-NN.md`, where the final number is the window number (01–10). Never overwrite a prior round's report. Create a new round directory/file.

### Report delivery rules

1. At the end of each meaningful work session, update **only your own report file** with incremental evidence. At the end of the round, ensure it is a complete final report.
2. Commit the report on the same task branch/PR as the work it documents where possible. For review-only windows, use a dedicated docs-only report branch/PR if there is no safe existing task branch. Do not push report commits to `main` directly.
3. Keep report changes isolated: one window's report file per commit is preferred; never combine another window's report or modify the shared continuation protocol without coordinator approval.
4. Report source facts with exact repository paths, commit SHAs, PR/Issue numbers, workflow run IDs/links, and test commands/results. Mark every item **verified**, **reported but not rechecked**, **not run**, or **blocked**.
5. Include findings with severity, reproduction/evidence, impact, proposed fix, test required, and owner/dependency. Separate defects in current main, candidate-branch defects, and environment-only risks.
6. State explicitly whether code/tests were changed, whether a branch/commit/PR was created, and whether any hosted QA/Production, migration, ACL, deployment, or business data was touched. Default is no hosted changes.
7. Do not paste credentials, tokens, private patient information, real clinical records, or financial identifiers into reports. Synthetic test data only.
8. A report file is evidence and handoff, not approval. Do not mark a PR approved, an issue closed, a migration applied, or a release gate passed unless the corresponding action/evidence exists.
9. In the chat response, provide the report file path and GitHub link, the exact commit/PR containing it, a short summary, and the next action. If the file could not be committed, say so plainly and provide the complete report in chat without pretending repository delivery occurred.
10. The coordinator reviews the ten isolated files, resolves contradictions against current mainline/source evidence, and then writes the consolidated round closeout in §5 or a separate coordinator-owned round summary. Individual windows must not edit that summary.

### Required report structure

Use the template at `docs/parallel-reports/TEMPLATE.md`. At minimum every report must contain: window identity and original task; round/baseline; scope and exclusions; current verified repository state; work actually performed; findings ranked by severity; tests with exact pass/fail/skip/not-run status; changed files and exact commit/PR; risks/dependencies; actions explicitly not performed; verdict; and one concrete next action.

### Add this instruction to every window's one-time bootstrap

> **Report delivery is mandatory:** publish your work in your own isolated file under `docs/parallel-reports/round-01/window-XX.md` (replace XX with your window number). Use `docs/parallel-reports/TEMPLATE.md`. Do not edit another window's report or write the combined report. Commit the report with your task PR, or create a separate docs-only report PR if your window is review-only. Include the exact report path and commit/PR link in your chat response. For each later round, create a new round-NN file and preserve all previous reports.


---

## 7. Round 01 report delivery audit — 2026-11-16

Coordinator recheck against the currently open GitHub pull requests. **These are candidate artifacts on PR branches, not files merged into `main`.** A PR existing does not mean its report is accepted.

| Window | Report delivery evidence | Status |
|---|---|---|
| 01 | PR #258 contains the prescription implementation and supporting docs, but its changed-file list has no `docs/parallel-reports/round-01/window-01.md`. | **MISSING** — publish the isolated report; do not substitute implementation docs. |
| 02 | PR #262 adds `docs/parallel-reports/round-01/window-02-phase-61c-security-review.md`. | **PATH NON-COMPLIANT** — preserve the existing file and add/correct the canonical `window-02.md` path using the template. |
| 03 | PR #263 adds `docs/parallel-reports/round-01/window-03.md`. | **DELIVERED ON PR** — review pending. |
| 04 | PR #267 adds `docs/parallel-reports/round-01/window-04.md`. | **DELIVERED ON PR** — review pending. |
| 05 | PR #265 adds `docs/parallel-reports/round-01/window-05.md`. | **DELIVERED ON PR** — review pending. |
| 06 | PR #264 adds `docs/parallel-reports/round-01/window-06.md`. | **DELIVERED ON PR** — review pending. |
| 07 | PR #268 adds `docs/parallel-reports/round-01/window-07.md`. | **DELIVERED ON PR** — review pending. |
| 08 | PR #266 adds `docs/parallel-reports/round-01/window-08.md`. | **DELIVERED ON PR** — review pending. |
| 09 | PR #269 adds `docs/parallel-reports/round-01/window-09.md` alongside its test-hardening change. | **DELIVERED ON PR** — independent review comment recorded; PR remains Draft pending human UAT. |
| 10 | PR #260 currently changes only `db/tests/phase55_clinical_parent_guard_assertions.sql`; no isolated report is present in its changed-file list. | **MISSING** — publish the isolated report; keep the failing regression visible and do not weaken the ACL to make it green. |

### Coordinator next actions

1. Windows 01 and 10 must publish their missing reports to their exact reserved paths.
2. Window 02 must add the canonical `window-02.md` report path without deleting its already-published detailed file.
3. The coordinator must review every report against current source, exact PR heads, CI, and environment evidence before any PR is merged.
4. No report PR is a release approval. Keep the Production decision **NO-GO** while the Phase 55 RLS/ACL defect, Phase 63 soft-delete bypass, Phase 61C deployment/security gates, backup verification, and required pharmacist/staff acceptance remain unresolved.

