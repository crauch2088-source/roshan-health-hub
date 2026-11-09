# Feature Specification: Transaction Currency Provenance

**Feature Branch**: `058-transaction-currency-provenance`

**Created**: 2026-11-09

**Status**: Draft — owner policy decision required before implementation

**Input**: Resolve the historical receipt-currency integrity issue identified during review of PR #181. A printed receipt must show the currency that applied when the transaction was posted, not whatever currency is currently selected in mutable application settings.

## User Scenarios & Testing

### User Story 1 — Reprint a historical receipt faithfully (Priority: P1)

A cashier with the required permissions opens a previously posted payment and prints or reprints its receipt. The receipt must use the currency stored with the transaction and must not change if the current application display setting is edited later.

**Why this priority**: A currency label is part of the amount's meaning. Relabelling an old amount can create a materially false financial document.

**Independent Test**: Create a synthetic QA invoice and payment with a known currency, change the current display setting in a disposable test fixture, reload the saved payment, and verify that the receipt still displays the original currency. No Production records are used.

**Acceptance Scenarios**:

1. **Given** a posted payment with a persisted currency code, **When** the receipt is opened, **Then** the receipt displays that exact code.
2. **Given** a posted payment whose currency is SDG, **When** the current settings display currency changes in a test fixture, **Then** reprinting still displays SDG.
3. **Given** a payment with no trustworthy currency provenance, **When** a receipt is requested, **Then** official printing is blocked and the missing currency is identified; no fallback is inferred.

### User Story 2 — Capture currency at the authoritative write boundary (Priority: P1)

When an invoice or payment is posted, the system records the applicable currency in the same transaction as the monetary record. The payment must use the invoice's currency, and its corresponding cashbox ledger row must agree.

**Why this priority**: Historical fidelity cannot be repaired reliably in the UI. Currency provenance belongs in the authoritative database write path.

**Independent Test**: In disposable PostgreSQL 17, post an invoice and payment through the existing atomic RPCs and assert matching immutable currency codes across invoice, payment, and generated cashbox ledger entries.

**Acceptance Scenarios**:

1. **Given** a valid configured currency, **When** an invoice is created, **Then** its currency code is saved atomically with the invoice.
2. **Given** an invoice with a saved currency, **When** a payment is posted, **Then** the payment copies the invoice currency rather than reading a newer display setting.
3. **Given** a payment ledger row, **When** the payment is reversed, **Then** the reversal retains the original currency code and amount sign semantics.
4. **Given** a request with a missing or unsupported currency, **When** a monetary write is attempted, **Then** the RPC fails closed without creating partial invoice, payment, or ledger state.

### User Story 3 — Change the clinic currency without corrupting existing records (Priority: P2)

An administrator changes the clinic currency only under an explicitly approved policy. Historical invoices, payments, cashbox entries, supplier balances, expenses, and catalogue prices must never be silently relabelled.

**Why this priority**: Currency configuration affects every displayed monetary value, not only receipts.

**Independent Test**: Use synthetic QA data to verify the approved policy's behavior when an administrator attempts a currency change after monetary records exist.

**Acceptance Scenarios**:

1. **Given** the clinic has no monetary records, **When** an administrator selects the initial currency, **Then** the setting is validated and stored.
2. **Given** monetary records exist, **When** an administrator attempts to change the clinic currency, **Then** the system follows the owner-approved single-currency lock or explicitly supported multi-currency workflow.
3. **Given** reports contain records in more than one currency, **When** totals are calculated, **Then** values are grouped by currency unless a separately specified and auditable FX conversion is used.

## Edge Cases

- Legacy invoice/payment/cashbox rows with NULL currency provenance.
- Reversed, soft-deleted, partially paid, or duplicated payments.
- A payment linked to an invoice whose currency differs from the configured current currency.
- A settings change racing with invoice creation or payment posting.
- A retry with the same idempotency key after a settings change.
- A currency code that is not a supported ISO 4217 code.
- Decimal precision differences between currencies.
- Reports that combine amounts from different currencies.
- Manual cashbox entries and other monetary modules that do not originate from invoices.

## Requirements

### Functional Requirements

- **FR-001**: System MUST persist a validated ISO 4217 currency code with every invoice covered by this feature.
- **FR-002**: System MUST persist the invoice currency with every payment and MUST reject a payment whose currency does not match its invoice.
- **FR-003**: System MUST persist the same currency code on the cashbox ledger entry generated from a payment.
- **FR-004**: Receipt rendering MUST use saved transaction currency provenance and MUST NOT derive a historical receipt's currency from the current `system_settings.currency` value.
- **FR-005**: Reversal entries MUST retain the original transaction currency.
- **FR-006**: Monetary writes MUST remain atomic and use the existing authorized RPC/write boundary; browser clients MUST NOT gain direct financial-table write privileges.
- **FR-007**: A receipt with missing, invalid, or contradictory currency provenance MUST fail closed and MUST NOT print an inferred currency.
- **FR-008**: Historical rows MUST NOT be backfilled from a mutable setting unless a separately reviewed evidence record proves the correct currency for every affected row.
- **FR-009**: The system MUST prevent silent currency changes from relabelling catalogue prices, balances, invoices, payments, expenses, supplier records, or cashbox entries.
- **FR-010**: Reports MUST NOT sum amounts across currencies without explicit, auditable conversion rules.
- **FR-011**: The feature MUST preserve idempotency, branch isolation, exact decimal precision, audit attribution, and existing reversal semantics.
- **FR-012**: No FX rates, FX gains/losses, or cross-currency settlement are included in the initial release unless separately specified and approved.

### Owner Decision Required

Choose one operating policy before implementation:

- **Recommended initial policy**: one clinic currency (currently Production is configured as SDG), immutable after the first monetary record; persist the currency code on financial source and ledger records so historical documents remain self-describing.
- **Alternative**: multi-currency transactions; each monetary record carries its own currency and all balances/reports are currency-partitioned. FX conversion requires a separate specification.

This feature does not assume the owner has selected either policy.

## Key Entities

- **Clinic currency configuration**: the validated currency used for new monetary operations under the approved operating policy.
- **Invoice**: the financial obligation and its immutable currency.
- **Payment**: a settlement against one invoice, carrying the same currency as that invoice.
- **Cashbox transaction**: the financial ledger event generated from a payment or reversal, carrying the source currency.
- **Receipt**: a read-only document derived from one saved payment, invoice, and verified ledger state.

## Success Criteria

- **SC-001**: 100% of newly posted invoices, payments, and associated cashbox ledger rows in the covered flow have a valid matching currency code.
- **SC-002**: A settings change cannot alter the currency shown on any previously posted receipt.
- **SC-003**: A payment with missing or mismatched currency is rejected with no partial financial or ledger mutation.
- **SC-004**: Reversal and idempotent retry tests preserve currency and amount fidelity.
- **SC-005**: No Production migration or release occurs before disposable PostgreSQL 17 tests, source-parity review, authenticated QA role/branch acceptance, and owner approval.

## Verified Baseline and Assumptions

- Production currently has `system_settings.currency = SDG`; QA currently has no currency setting row.
- Read-only counts on 2026-11-09 found zero rows in `invoices`, `payments`, and `cashbox_transactions` in both environments. No row values were read.
- The current `invoices`, `payments`, and `cashbox_transactions` tables have no currency-code column.
- PR #181 currently passes a mutable `currencyValue` into the receipt model builder.
- Phase54C receipt-integrity RPC exists in QA only; Production migration head remains earlier.
- These facts do not establish a policy decision or authorize a migration.
