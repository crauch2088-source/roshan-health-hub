# Feature Specification: Source-aware financial reversal

**Status:** Implemented and verified in isolated QA; production application pending backup/restore gate  
**Related phases:** 54, 54B, 54C  
**Source of truth:** `docs/MASTER_PLAN.md`

## Problem statement

A generic cashbox reversal must not reverse a source-linked payment without updating the authoritative payment and invoice state. Otherwise the cashbox ledger, payment record and invoice balance can disagree. Branchless or cross-branch financial rows must fail closed, including for super-admins.

## User stories

- As an authorized finance operator, I can reverse an invoice payment with a mandatory reason and receive one atomic, auditable reversal.
- As a finance operator, I cannot use the generic cashbox reversal endpoint for invoice, supplier or insurance payment sources.
- As a receptionist with billing and payment read permissions, I can verify whether a payment receipt is active, voided or inconsistent without receiving broad cashbox read access.
- As an administrator, I cannot bypass missing branch attribution for a financial reversal.

## Functional requirements

- **FR-001:** Invoice payment reversal requires `cashbox.update` or super-admin status and a non-empty reason.
- **FR-002:** The RPC locks invoice, payment and original cashbox entry in a consistent order.
- **FR-003:** Payment, invoice and original cashbox entry must exist, be branch-bound and share the same branch.
- **FR-004:** Original ledger amount must match the payment amount; an already reversed/deleted payment or ledger row is rejected.
- **FR-005:** Reversal creates one linked negative cashbox row, marks the original row reversed, soft-deletes the payment with actor attribution, and relies on the existing payment trigger to recompute invoice paid/outstanding totals.
- **FR-006:** Generic reversal rejects source types `payment`, `supplier_payment` and `insurance_claim_payment`; dedicated workflows are required for the latter two.
- **FR-007:** Generic reversal rejects branchless cashbox entries, including for super-admins.
- **FR-008:** Receipt status RPC is bounded to 200 payment IDs, requires both `payments.read` and `billing.read`, and enforces branch access to both invoice and payment.
- **FR-009:** Receipt status is consistent only when invoice/payment/ledger branches and amounts match and the reversal row is present and correctly linked/valued when reversed.
- **FR-010:** Receipt status RPC is SECURITY DEFINER with empty `search_path`, executable by authenticated users only; it returns no patient-identifying data.
- **FR-011:** No table/data migration or production mutation is required for this feature.

## Acceptance criteria

- A successful invoice-payment reversal changes the payment to deleted/reversed, marks the original cashbox entry reversed, creates exactly one reversal row and recomputes invoice totals.
- A duplicate reversal fails without additional ledger rows or balance changes.
- Generic reversal still works for ordinary non-payment cashbox entries.
- Generic reversal fails for invoice, supplier and insurance payment source rows.
- Cross-branch and branchless reversals fail, even under super-admin bypass.
- Active and voided receipt statuses are distinguishable; branchless, amount-mismatched or reversal-row-mismatched receipts are marked inconsistent.
- A user lacking either `payments.read` or `billing.read` cannot call the receipt-status RPC.
- Anonymous execution is denied.

## Out of scope

Dedicated supplier-payment and insurance-claim-payment reversal workflows; historical data backfill; production application before backup/restore evidence.
