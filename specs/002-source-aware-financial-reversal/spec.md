# Feature Specification: Source-aware financial reversal

**Feature Branch**: `002-source-aware-financial-reversal`  
**Created**: 2026-11-03  
**Status**: Implemented and verified in isolated QA; production application pending backup/restore gate  
**Input**: `docs/MASTER_PLAN.md` — Phase 54, Phase 54B and Phase 54C.

## User Scenarios & Testing

### User Story 1 — Reverse an invoice payment safely (Priority: P1)

An authorized finance operator reverses a saved invoice payment with a mandatory reason. The payment, cashbox ledger and invoice balance remain consistent as one atomic operation.

**Why this priority**: Financial ledger integrity and auditability are critical; a generic cashbox reversal must not leave the source payment active.

**Independent Test**: Use synthetic invoice/payment/cashbox fixtures in PostgreSQL 17 and verify the payment state, reversal row, original ledger state and invoice balance.

**Acceptance Scenarios**:

1. **Given** a posted invoice payment with a matching branch-bound ledger entry, **When** an authorized operator reverses it with a reason, **Then** exactly one linked reversal row is created and the invoice balance is recomputed.
2. **Given** an already reversed or deleted payment, **When** the operator repeats the reversal, **Then** the RPC rejects it without adding another ledger row.
3. **Given** a supplier or insurance payment source, **When** the generic cashbox reversal RPC is called, **Then** it rejects the request and requires a dedicated source workflow.

### User Story 2 — Verify receipt status without broad cashbox access (Priority: P1)

A receptionist with billing and payment read permissions checks whether a saved payment receipt is active, voided or inconsistent without receiving `cashbox.read`.

**Why this priority**: Receipt printing must reflect posted ledger state without expanding reception permissions.

**Independent Test**: Call the bounded receipt-status RPC with synthetic active, reversed, branchless and mismatched records under users with different branch/permission settings.

**Acceptance Scenarios**:

1. **Given** an active, branch-consistent payment, **When** an authorized reader checks its status, **Then** the RPC reports a matching, non-reversed ledger.
2. **Given** a reversed payment with a matching reversal row, **When** an authorized reader checks its status, **Then** the RPC reports the reversal reason and timestamp.
3. **Given** a branchless, cross-branch or amount-mismatched record, **When** its status is checked, **Then** it is marked inconsistent and must not be printed as a valid receipt.
4. **Given** a user missing either `payments.read` or `billing.read`, **When** the RPC is called, **Then** access is denied.

### User Story 3 — Preserve ordinary cashbox corrections (Priority: P2)

An authorized finance operator can still reverse a non-payment cashbox correction through the generic workflow.

**Why this priority**: Source-aware protections must not break legitimate expense/income correction workflows.

**Independent Test**: Reverse a synthetic non-payment cashbox row and verify the original/reversal relationship and reason.

**Acceptance Scenarios**:

1. **Given** a branch-bound non-payment cashbox entry, **When** an authorized operator reverses it, **Then** the generic reversal succeeds.
2. **Given** a branchless cashbox entry, **When** any operator including a super-admin attempts reversal, **Then** the operation is rejected.

### Edge Cases

- Duplicate reversal requests and concurrent invoice payment activity.
- Payment, invoice or cashbox row has no branch binding.
- Payment amount differs from its original ledger amount.
- Reversal flag exists without a matching reversal row, or vice versa.
- Cross-branch payment/invoice/ledger association.
- Empty or oversized payment-ID array.
- Receipt reprint after soft deletion/reversal.
- Supplier and insurance payment source types passed to the generic reversal RPC.

## Requirements

### Functional Requirements

- **FR-001**: Invoice payment reversal MUST require `cashbox.update` or super-admin status and a non-empty reason.
- **FR-002**: The RPC MUST lock invoice, payment and original cashbox entry in a consistent order.
- **FR-003**: Invoice, payment and original ledger entry MUST exist, be branch-bound and share the same branch.
- **FR-004**: Original ledger amount MUST match the payment amount; already-reversed or deleted payment/ledger states MUST be rejected.
- **FR-005**: Reversal MUST create one linked negative cashbox row, mark the original row reversed, soft-delete the payment with actor attribution and allow the existing payment trigger to recompute invoice totals.
- **FR-006**: Generic cashbox reversal MUST reject `payment`, `supplier_payment` and `insurance_claim_payment` source types.
- **FR-007**: Generic reversal MUST reject branchless cashbox entries, including for super-admins.
- **FR-008**: Receipt status MUST be bounded to 200 IDs, require both `payments.read` and `billing.read`, and enforce branch access to the invoice and payment.
- **FR-009**: Receipt status MUST be consistent only when invoice/payment/ledger branch IDs and amounts match and the reversal row is present and correctly linked/valued when reversed.
- **FR-010**: The receipt-status RPC MUST be SECURITY DEFINER with an empty `search_path`, executable by authenticated users only, and return no patient-identifying data.
- **FR-011**: The feature MUST NOT add tables/columns or backfill business data; only forward-only function/ACL migrations are used.

### Key Entities

- **Invoice**: Saved financial document, branch attribution and current balance.
- **Payment**: Posted payment linked to an invoice, branch and actor.
- **Cashbox transaction**: Immutable source ledger row and linked reversal row.
- **Receipt status**: Minimal read model describing ledger existence, consistency and reversal state.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A successful reversal creates exactly one reversal row and recomputes the invoice balance.
- **SC-002**: Duplicate, branchless and cross-branch reversals are rejected with no side effects.
- **SC-003**: Generic reversal remains functional for ordinary non-payment entries and rejects payment-source entries.
- **SC-004**: Active and reversed receipts are distinguished correctly; inconsistent receipts are never represented as valid.
- **SC-005**: A user lacking either required read permission and all anonymous users are denied receipt-status execution.
- **SC-006**: PostgreSQL 17 integration tests pass for all cases above.

## Assumptions

- Existing payment and cashbox ledger rows remain authoritative.
- Existing payment triggers remain responsible for invoice paid/outstanding totals.
- Supplier and insurance payment reversal workflows remain out of scope until their own source-specific invariants are designed.
- Production application requires encrypted backup and isolated restore evidence.
