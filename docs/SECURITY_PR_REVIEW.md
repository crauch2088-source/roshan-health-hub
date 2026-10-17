# Security PR review — 2026-10-17

This document records a bounded source-level review of PRs #50–#54. It is not a production exploit report. No SQL from these proposals was applied to production and none of the PRs was merged during this review.

## Cross-cutting gate

All five PRs remain open/draft. Their dedicated PostgreSQL 17 integration tests and PR descriptions report passing runs, but the full 93-entry migration history is not yet replayable from a reviewed pre-migration baseline. The one historical identity-link migration is intentionally redacted in public source. Do not merge until the replay gate and relevant findings below are resolved.

## Findings

### PR #50 — blocked_by_full_replay_gate

- **Severity:** medium
- **Files:** `db/tests/invoice_item_branch_isolation_integration.sql`
- **Finding:** The test verifies a cross-branch UPDATE against an already hidden branch-B invoice item and a cross-branch INSERT, but does not attempt to update a visible branch-A item by changing its invoice_id to a branch-B invoice. The policy has a WITH CHECK predicate; exercise that path explicitly.
- **Required change:** Add parent-changing UPDATE rejection and assert the original invoice_id remains unchanged.

### PR #51 — changes_required_before_merge

- **Severity:** high
- **Files:** `db/roshan_parent_branch_isolation.sql`
- **Finding:** app_has_patient_visit_branch_access uses `_visit_id IS NULL OR _patient_id IS NULL OR EXISTS(patient/visit match)`. Live information_schema confirms patient_id is nullable on patient_discounts and procedure_orders. A row with NULL patient_id and a valid visit can therefore bypass the patient-to-visit consistency assertion (while still needing branch access). This is a parent-link integrity gap, not evidence of cross-branch access by itself.
- **Required change:** Fail closed when a visit is supplied without a patient ID, or explicitly define/document the supported visit-only shape and enforce it consistently; add NULL-patient + valid-visit negative tests.

### PR #51 — changes_required_before_merge

- **Severity:** medium
- **Files:** `db/tests/parent_branch_isolation_integration.sql`
- **Finding:** Cross-branch UPDATE/DELETE attempts target branch-B patient_discounts and procedure_orders rows, but post-operation assertions do not confirm those exact rows still exist with original values. Helper EXECUTE assertions also omit authenticated grants for app_has_patient_branch and app_has_attachment_branch_access.
- **Required change:** Assert fixture existence/value before and after denied writes; assert authenticated EXECUTE and anon denial for every helper modified.

### PR #52 — changes_required_before_merge

- **Severity:** high
- **Files:** `db/roshan_queue_followup_branch_isolation.sql; db/tests/queue_followup_branch_isolation_integration.sql`
- **Finding:** The same nullable patient/visit helper pattern bypasses linkage consistency when one ID is NULL. Live schema confirms patient_id and visit_id are nullable on followups and queue_tickets. Also, the cross-branch queue DELETE test uses a non-super-admin, so a zero-row result may be caused by the super-admin-only delete invariant rather than the branch predicate.
- **Required change:** Add NULL-patient + valid-visit mismatch tests and run the cross-branch delete case as a super-admin assigned to branch A, proving a branch-B ticket is still not deleted.

### PR #52 — changes_required_before_merge

- **Severity:** medium
- **Files:** `db/tests/queue_followup_branch_isolation_integration.sql`
- **Finding:** The integration test covers mismatched patient/visit on INSERT but does not attempt UPDATE of a visible row to a branch-B visit or a same-branch visit belonging to a different patient; the WITH CHECK linkage invariant could regress undetected.
- **Required change:** Add parent-changing UPDATE tests and assert parent references remain unchanged.

### PR #53 — blocked_by_full_replay_gate

- **Severity:** medium
- **Files:** `db/tests/prescription_lab_child_branch_isolation_integration.sql`
- **Finding:** Tests cover cross-branch row UPDATE and same-branch UPDATE but do not attempt changing a visible prescription/lab child row to a different parent (the policy WITH CHECK path). Live schema has prescriptions.patient_id and lab_orders.patient_id NOT NULL, reducing the nullable-parent concern seen in PRs #51/#52.
- **Required change:** Add parent reassignment UPDATE tests for prescription items and lab order items, including mismatched patient/visit links.

### PR #54 — blocked_by_full_replay_gate

- **Severity:** medium
- **Files:** `db/roshan_phase27_finance_rpc_only_writes.sql; db/tests/finance_only_rpc_writes_integration.sql`
- **Finding:** The proposal is scoped to cashbox transactions, expenses, payments, supplier bills, and supplier payments and routes writes through validated RPCs. The source review did not establish a clean-chain replay or full role × operation matrix for all five tables and all exposed RPCs.
- **Required change:** Keep source-only until clean replay is proven; retain direct INSERT/UPDATE/DELETE/TRUNCATE denial assertions for every table, and allowed/denied-role plus retry/idempotency/branch tests for every RPC.

## Live schema evidence

A read-only query of `information_schema.columns` on 2026-10-17 confirmed `patient_id` and `visit_id` are nullable for `followups`, `queue_tickets`, `patient_discounts`, and `procedure_orders`; `prescriptions.patient_id` and `lab_orders.patient_id` are NOT NULL. A read-only function-definition query confirmed the existing `private.app_has_attachment_branch_access(uuid,uuid)` permits a NULL patient ID with a non-NULL visit when the visit branch is accessible; the PR #51/#52 wrapper then skips the patient/visit equality check when either argument is NULL. This is an integrity gap to close or explicitly constrain, not proof that cross-branch reads are allowed.

## Safe next sequence

1. Obtain approval for the quoted disposable Supabase branch cost (US$0.01344/hour), or use an already-authorized zero-cost isolated PostgreSQL environment if one is available.
2. Recover/synthesize the reviewed pre-migration baseline and create a replay-only variant for the redacted one-time identity link that does not publish or replay environment-specific identity literals.
3. Add the listed regression assertions on the relevant PR branches; re-run dedicated PostgreSQL 17 integration and full CI.
4. Re-evaluate stacked PR bases/dependencies and merge only after clean replay and authorization gates pass.



## Live authorization-surface baseline — 2026-10-17

Read-only inspection of the connected production project found:

- All 56/56 public base tables have RLS enabled, and none of those tables is missing all RLS policies. This is only a configuration baseline; it does not prove each policy is correct.
- `anon` has no `USAGE` on schema `private`, while `authenticated` does. A few private `SECURITY DEFINER` helpers show `anon EXECUTE` ACLs, but the missing schema `USAGE` blocks direct schema access; review these as defense-in-depth cleanup candidates, not a demonstrated exposed endpoint.
- Security Advisor currently reports 22 public `SECURITY DEFINER` functions callable by `authenticated`, one `pg_trgm` extension-in-public-schema warning, and disabled leaked-password protection. Review each RPC's authorization, branch checks, grants, and fixed `search_path`; do not revoke all RPCs wholesale.
- Performance Advisor reports 90 unused-index findings. Do not drop indexes based on this signal alone.
- The live grants inventory still shows `authenticated` DML grants on many public objects. RLS remains the row filter, but this makes the full role × object × operation matrix and PR #54's focused finance revocations important. No production grants or policies were changed by this audit.
