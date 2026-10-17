# Security PR review — 2026-10-17

This document records a bounded source-level review of PRs #50–#54. It is not a production exploit report. No SQL from these proposals was applied to production and none of the PRs was merged during this review.

## Cross-cutting gate

All five PRs remain open/draft. Their dedicated PostgreSQL 17 integration tests and PR descriptions report passing runs, but the full 93-entry migration history is not yet replayable from a reviewed pre-migration baseline. The one historical identity-link migration is intentionally redacted in public source. Do not merge until the replay gate and relevant findings below are resolved.

## Findings

### PR #50 — blocked_by_full_replay_gate

- **Severity:** medium
- **Files:** `db/tests/invoice_item_branch_isolation_integration.sql`
- **Finding:** Resolved on the PR head: added a parent-changing UPDATE against a visible branch-A item and strengthened postconditions to require the branch-B row to remain present with its original invoice_id/description. The dedicated PostgreSQL 17 integration workflow and CI both pass on commit `ba5f742a05bb912ec169a056e9c29a0b08967f64`. The PR remains unmerged pending the separate clean-replay gate.
- **Required change:** Completed and verified by PostgreSQL 17 integration and CI on the PR head; see the test commit and passing workflow above.

### PR #51 — changes_required_before_merge

- **Severity:** high
- **Files:** `db/roshan_parent_branch_isolation.sql`
- **Finding:** app_has_patient_visit_branch_access uses `_visit_id IS NULL OR _patient_id IS NULL OR EXISTS(patient/visit match)`. Live information_schema confirms patient_id is nullable on patient_discounts and procedure_orders. A row with NULL patient_id and a valid visit can therefore bypass the patient-to-visit consistency assertion (while still needing branch access). This is a parent-link integrity gap, not evidence of cross-branch access by itself.
- **Required change:** Do not classify this as a demonstrated cross-branch access bypass: the helper still verifies branch access through the supplied visit. Treat it as a data-integrity contract decision. Confirm whether visit-only child rows are valid in this schema; if not, add an explicit constraint or reject the shape. Parent-reassignment tests have been added. Do not add NULL-linkage denial tests until the intended nullable-row contract is settled.

### PR #51 — changes_required_before_merge

- **Severity:** medium
- **Files:** `db/tests/parent_branch_isolation_integration.sql`
- **Finding:** Follow-up commit adds parent-changing UPDATE checks for certificates, patient discounts and procedure orders; checks authenticated EXECUTE grants for patient/attachment helpers; and asserts branch-B discount and procedure rows remain present with their original parent/value. The dedicated parent-branch integration passed on commit `cc8f81c7de84eef1ac9fe56e2cafe562f1c38498`; after the final discount fixture correction, the same integration is green on `70eb7a38e66f448c0a4f5cb2a28d3c1d30207c52` while general CI finishes.
- **Required change:** Assert fixture existence/value before and after denied writes; assert authenticated EXECUTE and anon denial for every helper modified.

### PR #52 — changes_required_before_merge

- **Severity:** high
- **Files:** `db/roshan_queue_followup_branch_isolation.sql; db/tests/queue_followup_branch_isolation_integration.sql`
- **Finding:** Nullable patient_id/visit_id can leave the child-to-parent integrity contract ambiguous, but the visit branch check still applies when a visit is supplied; this is not established cross-branch read access. The queue DELETE policy is deliberately super-admin-only, so a non-super-admin's zero-row result proves that role restriction, not an independent branch-specific DELETE rule. Preserve this as an explicit authorization design note rather than a release-blocking defect unless policy intent changes.
- **Required change:** Resolved test gap: added UPDATE attempts that reassign a visible follow-up or queue ticket to a same-branch visit belonging to a different patient. PostgreSQL 17 queue/follow-up integration and CI pass on commit `2fdb444743603ad383e4c774cc35060f3aea21e7`. Do not test denial of cross-branch DELETE for super-admin unless product policy explicitly says super-admin is branch-restricted; the current helper deliberately grants super-admin global access.

### PR #52 — changes_required_before_merge

- **Severity:** medium
- **Files:** `db/tests/queue_followup_branch_isolation_integration.sql`
- **Finding:** Resolved on the PR head: added parent-changing UPDATE tests for both follow-ups and queue tickets, and the dedicated PostgreSQL 17 integration workflow passes. The separate clean-replay gate remains open.
- **Required change:** Completed for the visible parent rows in PR #52 and #53; the dedicated PostgreSQL 17 workflows pass on the latest test commits.

### PR #53 — blocked_by_full_replay_gate

- **Severity:** medium
- **Files:** `db/tests/prescription_lab_child_branch_isolation_integration.sql`
- **Finding:** Resolved on the PR head: added parent reassignment tests for prescription items and lab-order items. An initial run correctly exposed a mistaken column name in the new lab test; it was corrected to the schema's `order_id`, and the dedicated PostgreSQL 17 integration plus CI pass on commit `8187d1d95e2b6d485163a8805947abee71ad086e`. The PR remains unmerged pending the full-chain replay gate.
- **Required change:** Add parent reassignment UPDATE tests for prescription items and lab order items, including mismatched patient/visit links.

### PR #54 — blocked_by_full_replay_gate

- **Severity:** medium
- **Files:** `db/roshan_phase27_finance_rpc_only_writes.sql; db/tests/finance_only_rpc_writes_integration.sql`
- **Finding:** The proposal is scoped to cashbox transactions, expenses, payments, supplier bills, and supplier payments and routes writes through validated RPCs. The source review did not establish a clean-chain replay or full role × operation matrix for all five tables and all exposed RPCs.
- **Required change:** Keep source-only until clean replay is proven; retain direct INSERT/UPDATE/DELETE/TRUNCATE denial assertions for every table, and allowed/denied-role plus retry/idempotency/branch tests for every RPC.

## Live schema evidence

A read-only query of `information_schema.columns` on 2026-10-17 confirmed `patient_id` and `visit_id` are nullable for `followups`, `queue_tickets`, `patient_discounts`, and `procedure_orders`; `prescriptions.patient_id` and `lab_orders.patient_id` are NOT NULL. A read-only function-definition query confirmed the existing `private.app_has_attachment_branch_access(uuid,uuid)` permits a NULL patient ID with a non-NULL visit when the visit branch is accessible; the PR #51/#52 wrapper then skips the patient/visit equality check when either argument is NULL. This is an integrity gap to close or explicitly constrain, not proof that cross-branch reads are allowed.

## No-cost next sequence

1. Do not create a Supabase branch or any paid resource. Use the existing public-repository GitHub Actions runners and PostgreSQL 17 service for isolated migration-specific fixtures; these test runs have already succeeded for PRs #50, #52 and #53, and the updated #51 integration is green while general CI finishes.
2. Keep the historical migration replay gate open until a trustworthy pre-migration baseline and safe treatment of the redacted one-time identity link are available. The 92/93 text-match result is not a full replay proof. Do not synthesize a guessed baseline or run replay against production.
3. Finish the final CI check on PR #51; re-query all PR heads/checks after any further edits. PRs #50–#54 remain open/draft and unmerged.
4. Continue expanding focused role × operation tests and review stacked-PR dependencies. Merge only after source review, relevant PostgreSQL 17 checks, full application CI, and a defensible clean-replay path pass.


## Live authorization-surface baseline — 2026-10-17

Read-only inspection of the connected production project found:

- All 56/56 public base tables have RLS enabled, and none of those tables is missing all RLS policies. This is only a configuration baseline; it does not prove each policy is correct.
- `anon` has no `USAGE` on schema `private`, while `authenticated` does. A few private `SECURITY DEFINER` helpers show `anon EXECUTE` ACLs, but the missing schema `USAGE` blocks direct schema access; review these as defense-in-depth cleanup candidates, not a demonstrated exposed endpoint.
- Security Advisor currently reports 22 public `SECURITY DEFINER` functions callable by `authenticated`, one `pg_trgm` extension-in-public-schema warning, and disabled leaked-password protection. Review each RPC's authorization, branch checks, grants, and fixed `search_path`; do not revoke all RPCs wholesale.
- Performance Advisor reports 90 unused-index findings. Do not drop indexes based on this signal alone.
- The live grants inventory still shows `authenticated` DML grants on many public objects. RLS remains the row filter, but this makes the full role × object × operation matrix and PR #54's focused finance revocations important. No production grants or policies were changed by this audit.

## No-cost verification update — 2026-10-17

- No paid Supabase branch/project was created. Isolated PostgreSQL 17 tests run on GitHub Actions public-repository runners.
- Latest observed passing test heads: #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64`; #52 `2fdb444743603ad383e4c774cc35060f3aea21e7`; #53 `8187d1d95e2b6d485163a8805947abee71ad086e`. #51 parent-branch integration passed on `70eb7a38e66f448c0a4f5cb2a28d3c1d30207c52`; general CI was still in progress at the time of this note. #54 existing finance-only RPC integration and CI passed on `f002a7944bc219fbca305901434d9ccbd42ed8a9`.
- No production SQL, grants, policies, or rows were modified.


## No-cost verification and latest regression work — 2026-10-17

- No paid Supabase resources were created. Focused PostgreSQL 17 regression tests use GitHub Actions runners; the new source-parity verifier checks repository files only.
- Main commit `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c` passed all 13 checks, including the new migration source parity job and both CodeQL language analyses. The verifier checked all 93 manifest mappings: 92 normalized hashes match and one redacted file is correctly marked non-executable.
- PR #54 now checks authenticated EXECUTE and anon denial for all six finance write/reversal RPCs. The focused finance integration passed on `d0d818a9988216cdfc52723d7e9ffae7402a50d1`; general CI was still in progress at last poll.
- PRs #50–#53 now exercise parent-changing UPDATE paths. Latest noted PostgreSQL 17 integration suites passed; #51 full CI passed on `70eb7a38e66f448c0a4f5cb2a28d3c1d30207c52`. These are focused fixture tests, not proof of the entire historical migration chain.
- Keep every PR #50–#54 open/draft until a trustworthy pre-migration baseline and safe replay handling for the redacted one-time identity-link migration are available. Do not guess the baseline or touch production for replay.


## Latest regression evidence — 2026-10-17

- PR #51: NULL `patient_id` plus a branch-B visit is rejected for `procedure_orders`; all checks passed on `4af41b893b12427b15577f2312b13e4d92785c20`.
- PR #52: equivalent NULL-patient branch-B insert attempts for `followups` and `queue_tickets` are rejected and leave no rows; all checks passed on `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`.
- PR #54: all six finance write/reversal RPC grant assertions are included; finance integration and complete PR CI passed on `d0d818a9988216cdfc52723d7e9ffae7402a50d1`.
- Main commit `696e422d959b308c5087339af74b541d941fa205` passed all 13 checks, including the source-parity job and CodeQL for Python and JavaScript/TypeScript. Newer Vercel checks still point to the build-rate-limit page; the last READY deployment inspected is on earlier documentation-only commit `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`. No deployment was forced.
- These isolated fixtures strengthen specific RLS/RPC behaviors but do not establish full historical migration replay. Keep PRs #50–#54 unmerged until the replay baseline and remaining review gates are resolved.


## Final no-cost test evidence — 2026-10-17

- All latest test heads for PRs #50–#54 have passing dedicated PostgreSQL 17 integration workflows and full PR CI: #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64`; #51 `4af41b893b12427b15577f2312b13e4d92785c20`; #52 `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`; #53 `8187d1d95e2b6d485163a8805947abee71ad086e`; #54 `670185193a0400634fe49f7e2e004b4223611ce3`.
- #51/#52 now explicitly prove a NULL patient identifier does not allow insertion of a child row pointing to a visit in another branch. #54 validates all six finance RPC grant boundaries, anon denial, SECURITY DEFINER, and fixed search_path; its focused integration and complete CI passed.
- Main commit `1c996bcc906e0739b5c693f2fe3968acdc72b9c6` passed all 13 checks including source parity and both CodeQL analyses. This documentation-only commit will require its own fresh check run.
- Vercel check remains blocked by the provider's build-rate-limit response. Last READY deployment inspected is an earlier docs-only SHA; no forced deploy or bypass was attempted.
- These are isolated test fixtures, not proof of full migration replay. No paid resource or production database change was used. Keep PRs open/draft until the reviewed baseline and redacted migration replay gate are resolved.


## Replay-safe redacted migration policy validation — 2026-10-17

- The previously redacted migration has now been split into a public, replay-only variant that removes the environment-specific identity mapping while preserving the four patient RLS policy changes. The source remains redacted; the replay variant is explicitly not a canonical deployment migration.
- The isolated PostgreSQL 17 workflow verifies stale-policy removal, four authenticated policies and their operation/permission predicates, successful fixture SELECT/INSERT/UPDATE/DELETE, and no Auth-to-app-user identity assignment. The workflow passed on main commit `ed1218e35121d9de08845fcc943fb8a3252717a6`.
- All 14 checks on that main commit passed, including the replay-safe policy job, source-parity check, application CI and both CodeQL language analyses.
- This validates only the policy portion of one redacted migration. Full replay remains blocked until a reviewed pre-migration baseline exists; PRs #50–#54 remain open/draft and unmerged pending that release gate.


## Final verification after replay-safe migration checks — 2026-10-17

- The final main SHA `ddf7d3b5b72d18bbfd13598472ce4db480c09bca` passed 15/15 checks, including the new replay-safe policy integration, source-parity checks that reject identity literals/UPDATEs in the replay variant, and both CodeQL analyses.
- All PRs #50–#54 remain open/draft/unmerged and their latest test heads have passing focused PostgreSQL 17 integration and full CI.
- No paid resources or production database mutations were used. Full-chain replay remains gated on a trustworthy pre-migration baseline. Vercel's current-main check still points to the build-rate-limit page; no deployment was forced.


## Live recheck — 2026-10-17 10:30 UTC

- Live PR inventory confirms #50–#54 are all still open drafts; none has been merged. Latest heads are #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64`, #51 `4af41b893b12427b15577f2312b13e4d92785c20`, #52 `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`, #53 `8187d1d95e2b6d485163a8805947abee71ad086e`, #54 `670185193a0400634fe49f7e2e004b4223611ce3`.
- The PR listing returned base SHAs that vary across the drafts and are older than the observed current main `2143f63624993a7d8f9bfbf71c251d129fe0b691`. Before merge, refresh the actual base refs, compare each branch's merge-base/diff to main, check for duplicate/stale commits, and rerun the required CI on the final head. Do not interpret the returned state alone as mergeability proof.
- Current main SHA `2143f63624993a7d8f9bfbf71c251d129fe0b691`: GitHub check-run endpoint reports 14/14 successful.
- Current Supabase Advisor (observed 2026-10-17 10:29 UTC): 22 authenticated-callable public SECURITY DEFINER findings, one `pg_trgm` public-schema warning, and leaked-password protection warning; Performance Advisor reports 90 unused-index findings. This is a triage queue, not authorization to revoke all RPCs or remove indexes.
- Current production deployment listing: READY SHA `ddf7d3b5b72d18bbfd13598472ce4db480c09bca`, behind main. No forced deployment and no live database mutation.
- The clean-replay blocker remains unchanged: no reviewed pre-migration baseline and one intentionally redacted identity-link migration. PRs remain source-only until that gate is satisfied.


## PR #54 follow-up — NULL direction validation (2026-10-17)

- **Finding:** The draft `post_cashbox_entry` used `IF _direction NOT IN ('deposit','withdrawal')`, which does not reject NULL in PL/pgSQL's three-valued logic. A NULL direction could fall through the guard and be classified as withdrawal by the CASE expression.
- **Regression first:** Added the NULL-direction assertion in commit `ed1c14b218d2dab8c7dc7e862f273e3e990a9e42`.
- **Fix:** Explicit NULL check added in `53483d87bb30f3bbc6fe4e95f4e266d1f763b96f`.
- **CI wiring:** Added `workflow_dispatch` to the draft branch workflow (`c15d69ab96b3ba7be8c45212bee3511130bd0bcd)); registered the same isolated PostgreSQL 17 workflow on main (`e4b1a6d0cea31d3e6e3976451a331bd586811ff6`). The main change is workflow-only; no finance SQL was added to main.
- **Evidence:** PostgreSQL 17 finance RPC-only integration passed on the current draft branch head in [run #39025549230](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025549230). Main CI passed on `e4b1a6d`; CodeQL was in progress at the last check.
- **Scope:** PR #54 remains draft and source-only. No production SQL or grants changed. Full clean replay remains a hard merge gate.


## Live security draft and CI snapshot — 2026-10-17 10:45 UTC

All five focused draft integration workflows have successful latest observed runs: #50 `ba5f742a` ([run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39021158326)); #51 `4af41b89` ([run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39022406414)); #52 `4b72a876` ([run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39022409722)); #53 `8187d1d9` ([run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39021361272)); #54 `c15d69ab` ([PostgreSQL 17 run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025549230)). Main commit `147e1b2e978bb4a0ee65da92117a5448f1a03863` has 14 check runs and its associated workflow concluded successfully ([CI](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025657739), [CodeQL](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025657774)).

These results validate only their respective isolated fixtures/workflows. They do not close the missing trusted migration baseline/full 93-entry replay gate. PR base snapshots differ; refresh ancestry and diff against current main before integrating. The latest listed READY Vercel deployment is still SHA `4b4b871b6637bb85703336d3c6f47e4e3f3f0c1f`, behind main. No production SQL was applied and no PR was merged.


## PR ancestry and integration gate — 2026-10-17 10:47 UTC

A live compare against current `main` reports all five security drafts as diverged. They are 42–49 commits behind current main, with merge bases `43afd071` (#50–#52), `710f1232` (#53), and `de28027a` (#54). Candidate files are additive in the compare output, but that does not prove correct migration order or replay compatibility. Keep PRs as drafts; do not batch-rebase or merge without reviewing source parity and migration dependencies. Their successful PostgreSQL jobs remain isolated fixture-level tests, not production schema replay.


## PR #51 regression test coverage update — 2026-10-17

The parent-branch test suite previously duplicated a certificate `visit_id` reassignment assertion. Commit [`19e91bc`](https://github.com/crauch2088-source/roshan-health-hub/commit/19e91bc38af9f16c2a6d46f8af6249742812ba84) replaces the duplicate with a `patient_id` reassignment check and adds an INSERT check for same-branch but inconsistent patient/visit parents. Dedicated PostgreSQL 17 integration passed in [run #39026202054](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39026202054). The broader PR workflow was still in progress at last check; no SQL migration was applied.


## Live verification refresh — 2026-10-17 10:56 UTC
- `main` SHA `5cf7eea2037314f7e90bf2f654e05a4d3840e667`: all 14 checks passed; the newest Vercel production deployment is READY on the same SHA and has the canonical `roshan-health-hub.vercel.app` alias.
- PR #51 head `19e91bc38af9f16c2a6d46f8af6249742812ba84` has passing dedicated PostgreSQL 17 integration and PR-wide CI, including source-parity and replay-safe policy fixture jobs. This is not proof of full-chain replay.
- Read-only live catalog counts: 44 public + 25 private SECURITY DEFINER functions. Of these, 22 public functions are authenticated-callable and zero public functions are anon-callable; anon lacks USAGE on `private` despite five private EXECUTE grants. No blanket grant changes recommended from counts alone.
- No production SQL or grants changed. Keep PRs #50–#54 as drafts until clean replay baseline, nullable-link contract, ancestry, and final authorization matrices are resolved.


## Execution batch — 2026-10-17 (verified follow-up)
### New regression coverage and status
- PR #51 (`b2cd795af0ffa0d4de93ccdfe721bfa94257ee9f`): 20/20 checks passed. Removed duplicate procedure-order visit reassignment assertions; now tests patient reassignment against a different visit and rejects a same-branch mismatched patient/visit INSERT.
- PR #52 (`c8060592284355ed1c934120be7cfe0ae7c650c1`): 20/20 checks passed. Added patient reassignment regression checks for followups and queue tickets.
- PR #53 (`91c6f33d0873c533040a911de1599065aa995acf`): 20/20 checks passed. Replaced duplicate lab-order cross-branch reassignment coverage with a same-branch mismatched-parent reassignment case.
- PR #54 (`9ad29bbc5f21d980279e916e8f4a9d5d140dffa4`): 21/21 checks passed. Added a fixture regression for the explicitly documented super-admin/no-branch supplier-bill compatibility path. Read-only live aggregate confirms that this account state exists; this finding does not justify changing the established behavior without a product decision.
- PR #50 remains at previously checked head `ba5f742a05bb912ec169a056e9c29a0b08967f64`; no new code was added to it in this batch.
- Main migration-inventory documentation commit `b03b3c07f33266b55c60a27c7b7e5a3e154c708e` passed all 14 checks. Vercel remains READY on older SHA `5cf7eea2037314f7e90bf2f654e05a4d3840e667`; current docs-only SHA is not confirmed deployed.
### Decision gates unchanged
- All five security PRs remain open/draft and unmerged because their bases/ancestry are not reconciled with current `main` and full-chain replay is not proven.
- No production SQL, policy, grant, or data mutation; no paid resource created.
- Keep the redacted identity mapping private. The 92/93 normalized source comparison is text-level evidence only; it is not semantic proof or a clean replay.
