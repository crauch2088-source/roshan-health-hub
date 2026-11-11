# Feature Specification: Transaction Currency Provenance

**Feature Branch**: `058-transaction-currency-provenance`

**Created**: 2026-11-09

**Status**: Draft — owner policy decided; implementation and release gates remain open

**Input**: Resolve the historical receipt-currency integrity issue identified during review of PR #181. A printed receipt must show the currency that applied when the transaction was posted, not whatever currency is currently selected in mutable application settings.

## User Scenarios & Testing

### User Story 1 — Reprint a historical receipt faithfully (Priority: P1)

A cashier with the required permissions opens a previously posted payment and prints or reprints its receipt. The receipt must use the currency stored with the transaction and must not change if the current application display setting is edited later.

**Why this priority**: A currency label is part of the amount's meaning. Relabelling an old amount can create a materially false financial document.

**Independent Test**: Create a synthetic QA invoice and payment with a known currency, change a test-only display preference, reload the saved payment, and verify that the receipt still displays the original currency. No Production records are used.

**Acceptance Scenarios**:

1. **Given** a posted payment with a persisted currency code, **When** the receipt is opened, **Then** the receipt displays that exact code.
2. **Given** a posted payment whose currency is SDG, **When** the current settings display currency changes in a test fixture, **Then** reprinting still displays SDG.
3. **Given** a payment with no trustworthy currency provenance, **When** a receipt is requested, **Then** official printing is blocked and the missing currency is identified; no fallback is inferred.

### User Story 2 — Capture currency at the authoritative write boundary (Priority: P1)

When an invoice or payment is posted, the system records the applicable currency in the same transaction as the monetary record. The payment must use the invoice's currency, and its corresponding cashbox ledger row must agree.

**Why this priority**: Historical fidelity cannot be repaired reliably in the UI. Currency provenance belongs in the authoritative database write path.

**Independent Test**: In disposable PostgreSQL 17, post an invoice and payment through the existing atomic RPCs and assert matching immutable currency codes across invoice, payment, and generated cashbox ledger entries.

**Acceptance Scenarios**:

1. **Given** the fixed SDG currency, **When** an invoice is created, **Then** its currency code is saved atomically with the invoice.
2. **Given** an invoice with a saved currency, **When** a payment is posted, **Then** the payment copies the invoice's persisted SDG provenance rather than reading a newer display setting.
3. **Given** a payment ledger row, **When** the payment is reversed, **Then** the reversal retains the original currency code and amount sign semantics.
4. **Given** a request with a missing or non-SDG currency, **When** a monetary write is attempted, **Then** the RPC fails closed without creating partial invoice, payment, or ledger state.

### User Story 3 — Enforce permanent SDG-only operation (Priority: P1)

Roshan operates exclusively in Sudanese pounds (SDG). Administrators cannot select, switch, or add another currency. Every monetary record is denominated in SDG.

**Why this priority**: This reflects the clinic's actual operating model and avoids unnecessary multi-currency and FX complexity. Persisted SDG provenance prevents historical receipts from being relabelled by a mutable setting.

**Independent Test**: In disposable PostgreSQL 17, attempt to change the clinic currency and post a non-SDG monetary record; both must fail without partial writes. Reprint a posted SDG receipt after changing a test-only display preference and verify it remains SDG.

**Acceptance Scenarios**:

1. **Given** the clinic currency is SDG, **When** an administrator attempts to change it, **Then** the database rejects the change.
2. **Given** an invoice, payment, cashbox entry, or reversal is posted, **When** its provenance is inspected, **Then** its stored currency code is SDG.
3. **Given** a request attempts to submit a non-SDG currency, **When** a monetary write is attempted, **Then** the RPC rejects it and creates no partial financial or ledger state.
4. **Given** an old receipt is reprinted, **When** a display preference changes, **Then** the receipt still displays SDG.

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

- **FR-001**: System MUST persist the fixed ISO 4217 code `SDG` with every invoice covered by this feature.
- **FR-002**: System MUST persist `SDG` with every payment and MUST reject a payment whose currency is not SDG or does not match its invoice.
- **FR-003**: System MUST persist `SDG` on every cashbox ledger entry, including payment and reversal entries.
- **FR-004**: Receipt rendering MUST use saved transaction currency provenance and MUST NOT derive a historical receipt's currency from the current `system_settings.currency` value.
- **FR-005**: Reversal entries MUST retain the original transaction currency.
- **FR-006**: Monetary writes MUST remain atomic and use the existing authorized RPC/write boundary; browser clients MUST NOT gain direct financial-table write privileges.
- **FR-007**: A receipt with missing, invalid, or contradictory currency provenance MUST fail closed and MUST NOT print an inferred currency.
- **FR-008**: Historical rows MUST NOT be backfilled from a mutable setting unless a separately reviewed evidence record proves the correct currency for every affected row.
- **FR-009**: The system MUST enforce SDG as the only permitted currency at authorized database write boundaries and reject attempts to configure or post another currency.
- **FR-010**: The system MUST NOT implement FX rates, FX gains/losses, currency conversion, or multi-currency reporting.
- **FR-011**: The feature MUST preserve idempotency, branch isolation, exact decimal precision, audit attribution, and existing reversal semantics.
- **FR-012**: No FX rates, FX gains/losses, cross-currency settlement, currency switching, or multi-currency support are in scope.

### Owner Policy — Decided

The owner has explicitly selected **single-currency SDG-only operation**. Roshan will use Sudanese pounds (`SDG`) permanently. There is no anticipated business requirement to change the clinic's currency, and no multi-currency or FX capability should be built. Enforce this policy in the authoritative database/write boundary, not only in UI settings. Persist `SDG` on financial records and ledger entries so receipts and reports remain historically self-describing. Any future reversal would require a separate, exceptional, owner-authorized migration and accounting-reconciliation project, not a routine setting.

- Every monetary write must be denominated in SDG.
- Attempts to configure or post another currency must fail closed.
- The current settings value is not historical transaction provenance.
- No FX rates, conversion, cross-currency settlement, or multi-currency reporting are in scope.

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
- The owner policy is now decided; these facts do not authorize a migration or Production change.
