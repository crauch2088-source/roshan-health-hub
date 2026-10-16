# Roshan Health Hub — Execution Batch Log (2026-10-16)

This is a verified work log, not a claim that 20 application features were shipped. It records 20 completed repository/CI/database-audit actions. No production SQL, grants, or patient/billing data were modified in this batch.

## Safe repository changes

- [x] Merged [PR #28](https://github.com/crauch2088-source/roshan-health-hub/pull/28): shortcut permission lookup now includes Home and fails closed for unknown destinations.
- [x] Merged [PR #27](https://github.com/crauch2088-source/roshan-health-hub/pull/27): corrected the upcoming-appointment time label and made dashboard panels distinguish query failures from empty results.
- [x] Merged [PR #24](https://github.com/crauch2088-source/roshan-health-hub/pull/24): made the refreshed master plan and migration reconciliation inventory canonical on `main`.
- [x] Merged [PR #36](https://github.com/crauch2088-source/roshan-health-hub/pull/36): added deterministic two-session cashbox-reversal concurrency testing to CI.
- [x] Verified post-merge CI run [38913449838](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38913449838) succeeded on main commit [`4d05d951`](https://github.com/crauch2088-source/roshan-health-hub/commit/4d05d95135c6ffbdeb69fa4bde81ff6475541f27).
- [x] Verified the main CI job completed dependency install, TanStack version enforcement, security audit, role-guard tests, typecheck, lint, and build successfully.
- [x] Verified the separate PostgreSQL 17 cashbox race job passed on main: exactly one competing reversal succeeded and the original plus reversal netted to zero.

## Read-only production database checks

- [x] Rechecked the Supabase applied-migration ledger: 79 recorded entries.
- [x] Verified the ledger range runs from `20260818162003` through `20261014164131`; count/range is not proof of SQL-source parity.
- [x] Inspected the live migration-ledger columns: `version`, `statements`, `name`, `created_by`, `idempotency_key`, and `rollback`.
- [x] Confirmed duplicate generic and finance-specific audit triggers are still attached to all five finance tables targeted by PR #32; cleanup is not applied.
- [x] Confirmed the generic audit trigger on `patients` remains separate and should be preserved by finance-trigger cleanup.
- [x] Confirmed ledger/payment-related triggers coexist with audit triggers on expenses, payments, and supplier payments.
- [x] Confirmed the production `post_expense(...)` SECURITY DEFINER RPC exists.
- [x] Confirmed the production `fn_receive_pharmacy_batch(...)` SECURITY DEFINER RPC exists.
- [x] Confirmed the production `create_insurance_claim(...)` SECURITY DEFINER RPC exists.
- [x] Confirmed the production `reverse_cashbox_entry(...)` SECURITY DEFINER RPC exists.
- [x] Confirmed the proposed invoice-creation RPCs from PR #33 are absent in production; PR #23 must precede #33.
- [x] Confirmed the proposed atomic patient-registration RPC from PR #39 and atomic prescription RPC from PR #22 are absent in production.
- [x] Confirmed production role/permission tables currently have audit/role-text synchronization triggers, but not the proposed privileged-role guard triggers from PR #38.
- [x] Reconfirmed the recorded branch-context issue: 6 production invoices and 6 invoice items are branchless, with no orphaned invoice items.
- [x] Reconfirmed the recorded lab-order branch-context issue: all 9 non-deleted lab orders have NULL `branch_id`, and 8 lack a patient/visit branch fallback.

## Remaining release gates

- PR #19 is ready for review but its merge was blocked by the execution safety layer; it has not been merged.
- PR #32's finance-trigger migration, PR #34's clinical branch-isolation migration, PR #38's privileged-role guard migration, and the patient/prescription/invoice migrations remain unapplied.
- Do not backfill branchless invoices/lab orders without a documented data-classification decision.
- Do not apply production migrations until migration-source reconciliation and isolated-schema validation are complete. The Supabase development-branch creation flow requires explicit cost confirmation, so no billable branch was created.
- Supabase Security Advisor currently reports: leaked-password protection disabled, `pg_trgm` installed in `public`, and 15 SECURITY DEFINER functions executable by authenticated users. These require function-by-function intent review; the advisor findings alone do not prove a vulnerability.
