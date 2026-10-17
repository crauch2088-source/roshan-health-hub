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
