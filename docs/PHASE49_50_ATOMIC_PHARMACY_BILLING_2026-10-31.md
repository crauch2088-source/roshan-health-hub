# Phase 49-50 — Pharmacy and clinical billing hardening

**Status:** Draft candidate for review. Not applied to QA or production.  
**Base:** Phase 48 Storage entity/branch binding (PR #148).

## Phase 49 — pharmacy, stock ledger and request idempotency

- Retains the existing FEFO dispense-and-invoice transaction as the single stock mutation path, but hardens branch ownership: even a super-admin consumes stock only from the patient's branch; patient and visit branches must match.
- Refuses null/unknown expiry and expired batches. FEFO selects the earliest valid expiry, then oldest receipt.
- Adds a private request-key table. Same actor, prescription and invoice choice replay the original per-batch result; reusing a key for another actor, prescription or payload is rejected.
- Exposes atomic_pharmacy_dispense to authenticated users only. It checks pharmacy.update and the currently deployed billing.create permission contract.
- Revokes the older dispense-only RPC because it could mutate stock without invoice coupling.
- Makes stock_movements read-only to browser clients, with permission-checked branch-scoped SELECT; writes stay in audited atomic definer RPCs.
- Pharmacy UI retains the request UUID after a network failure; changing invoice mode invalidates that key.

## Phase 50 — clinical completion and billing

- Adds complete_clinical_visit_and_bill.
- Locks visit and patient, checks active rows, exact patient/visit branch agreement, visits.update, and rejects cancelled visits or invalid consultation fees.
- Adds the consultation fee to the primary invoice before changing visit state.
- Completes visit and active queue tickets using one server timestamp. Retry does not rewrite the visit and repairs queue timestamps.
- Preserves complete_visit_atomic as a compatibility wrapper for existing UI callers.
- Billing failure rolls back visit and queue state.

## Audit aggregate

The read-only aggregate groups by day, table, action and actor, returning counts only. It does not expose audit_logs.old_data or new_data. Branch filtering excludes legacy rows without an explicit branch id rather than guessing.

## Verification and release boundary

A disposable PostgreSQL 17 workflow replays the canonical v112 baseline and Phases 34/46/47/48/49/50. It tests FEFO expiry exclusion, idempotent retry, duplicate rejection, invoice reconciliation, and visit/queue timestamp alignment.

This does not replace browser/staff UAT. The candidate is not applied to QA or production. Production remains blocked on exact-head review/CI, manual backup and restore rehearsal, and authenticated staff acceptance. The current pharmacist role has billing.create; this candidate preserves that permission contract. Least-privilege pharmacy billing requires a separate coordinated change to the invoice helper and role matrix. The invoice-coupled legacy RPC remains callable temporarily for compatibility and needs a later cutover revocation after UI acceptance.


### Additional inventory invariants

- Medicine catalogue creation no longer accepts initial stock, batch number or medicine-level expiry. New medicines start at zero; stock is added through the batch receipt RPC only.
- Positive-quantity pharmacy batches require a known expiry at database level. Legacy NULL-expiry rows remain stored but cannot be dispensed until reconciled.
- Browser clients have SELECT-only access to pharmacy_inventory and stock_movements. Direct authenticated changes to medicines.stock_quantity are rejected; atomic receive/dispense RPCs maintain the aggregate.
- Stock movement branch attribution for no-visit super-admin dispensing is anchored to the patient's branch, not a nullable user branch.


### Stock-entry source-of-truth correction

The medicine master form no longer accepts an initial stock count, batch number or medicine-level expiry. New medicine records start at zero stock; every positive stock quantity must enter through the atomic batch receipt RPC. The database rejects positive-quantity batches without an expiry and rejects direct authenticated edits to medicines.stock_quantity. Existing legacy NULL-expiry batches are retained for reconciliation, but the dispense RPC excludes them.


The dashboard now exposes a separate unknown-expiry batch panel instead of silently treating those rows as healthy or conflating them with expired stock. Batch receipt requires an expiry date in the UI, and the database trigger enforces the same invariant.


The combined PG17 critical-path replay follows the canonical Phase 48 fixture order: v112 baseline, Storage/Realtime fixture, Phase 34, Phase 48, then Phases 49 and 50. Phase 46 and 47 remain covered by their own isolated fixture workflows and are intentionally not replayed into this baseline test.


### Queue role boundary

The queue screen now uses queue.update for operational call/start actions, allowing reception to move tickets without writing clinical visit status. Completion and cancellation remain gated by visits.update; completion uses the billing-aware atomic visit RPC. This avoids granting clinical write authority to reception merely to operate the queue.
