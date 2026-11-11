# Data Model: Transaction Currency Provenance

## Currency Code

- **Representation**: ISO 4217 three-letter code (for example, `SDG`).
- **Validation**: Must match the supported currency registry and be uppercase.
- **Immutability**: Currency is immutable after the monetary record is posted. Corrections use an audited reversal/reissue workflow, never an in-place currency relabel.

## Entities

### Clinic Currency Configuration

Represents the clinic's approved operating currency.

- Current Production setting: `system_settings.currency = SDG`.
- QA currently has no currency setting row.
- The setting is configuration for new operations, not the source of truth for historical records.
- Whether the setting is immutable after the first monetary record or supports multi-currency is an owner decision.

### Invoice

Proposed attribute:

- `currency_code`: non-null ISO 4217 code captured at invoice creation.

Invariant:

- All invoice item amounts and totals inherit the invoice currency.
- Currency cannot be changed after invoice posting.

### Payment

Proposed attribute:

- `currency_code`: non-null ISO 4217 code copied from the locked parent invoice during payment posting.

Invariants:

- Payment currency must equal invoice currency.
- Client input cannot override the invoice currency.
- Idempotency payload comparison includes the effective currency or verifies it from the locked invoice.
- Reversal does not mutate the original payment currency.

### Cashbox Transaction

Proposed attribute:

- `currency_code`: non-null ISO 4217 code inherited from its source payment or reversal.
- Manual cashbox entries use the approved clinic currency at posting time.

Invariants:

- A payment ledger row must match its payment currency.
- A reversal ledger row must match the original ledger currency.
- No ledger row may be created with an unknown or mismatched currency.

### Receipt

Read-only projection:

- Payment ID, invoice identity, patient identity, amount, currency code, method, received timestamp, cashier, current balance, and ledger/reversal status.
- Currency must come from persisted payment/invoice data and be checked against the ledger source.
- Missing or contradictory currency makes the receipt incomplete and non-printable.

## Relationships

- One invoice has zero or more payments.
- Each payment belongs to one invoice.
- A payment may have one original cashbox ledger entry and zero or one reversal entry.
- The receipt represents one saved payment and its parent invoice plus verified ledger state.

## Scope Boundary

This proposed model covers invoice/payment/cashbox receipt provenance. It does not silently solve currency semantics for expenses, supplier bills/payments, insurance, pharmacy purchase prices, or lab/service catalogues. Those must be inventoried and included before any global currency-setting lock or multi-currency reporting is implemented.


## Superseding single-SDG model — 2026-11-09

Roshan supports SDG only. The first persisted-provenance scope is invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, and pharmacy_inventory batches. Each receives nullable currency_code with DEFAULT 'SDG' for new rows. A private trigger rejects explicit NULL/non-SDG inserts and prevents changing or clearing a populated code.

Existing rows remain NULL until an explicitly reviewed evidence-backed reconciliation assigns SDG. Invoice line items inherit invoice currency; master catalogue prices use global SDG. Insurance tables and payroll are deferred. No FX or multi-currency semantics are introduced.
