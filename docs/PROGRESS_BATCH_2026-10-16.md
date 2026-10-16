# Roshan Health Hub — Execution Batch Report
**Date:** 2026-10-16  
**Scope:** 20 concrete execution/review items from the master plan. This report distinguishes completed code/CI work from release gates that remain open.

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

- PR #12 remains draft pending human review and authenticated insurance-claim smoke test.
- PR #13 remains blocked by staging/Supabase validation and migration-history reconciliation.
- PRs #22, #23, #29, #30, #31, #32, #33, #34, #38, and #39 contain proposed SQL or security-sensitive changes. Passing PostgreSQL fixtures are useful evidence, but do not prove compatibility with the current live Supabase schema.
- The connected Supabase migration ledger still has 79 applied entries, while canonical repository migration-history parity remains unresolved. No production SQL was run in this batch.
- PR #39 requires its latest CI run to pass, then isolated schema/authorization validation and the existing branch-assignment/data-readiness gate before it can be considered merge-ready.
- No production SQL was applied in this batch. The only merge was PR #19, a UI/query correctness change without schema changes.
