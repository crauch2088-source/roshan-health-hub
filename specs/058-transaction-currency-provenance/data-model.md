# Data Model: Transaction Currency Provenance

## Currency Code

- **Representation**: ISO 4217 three-letter code (for example, `SDG`).
- **Validation**: Must equal the literal uppercase code `SDG`; no currency registry or selector is needed.
- **Immutability**: Currency is immutable after the monetary record is posted. Corrections use an audited reversal/reissue workflow, never an in-place currency relabel.

## Entities

### Clinic Currency Configuration

Represents the clinic's approved operating currency.

- Current Production setting: `system_settings.currency = SDG`.
- QA currently has no currency setting row.
- The setting is display/configuration metadata only. All posted monetary records persist `SDG`; historical receipts read the persisted record, never the setting.
- Owner policy is decided: `SDG` is the permanent clinic currency; no multi-currency or FX. Database enforcement must reject changes away from SDG.

### Invoice

Proposed attribute:

- `currency_code`: non-null, CHECK-constrained literal `SDG`, assigned at invoice creation.

Invariant:

- All invoice item amounts and totals inherit the invoice currency.
- Currency cannot be changed after invoice posting.

### Payment

Proposed attribute:

- `currency_code`: non-null literal `SDG`, copied from the locked parent invoice during payment posting.

Invariants:

- Payment currency must equal invoice currency.
- Client input cannot override the invoice currency.
- Idempotency payload comparison includes the effective currency or verifies it from the locked invoice.
- Reversal does not mutate the original payment currency.

### Cashbox Transaction

Proposed attribute:

- `currency_code`: non-null literal `SDG`, inherited from its source payment or reversal.
- Manual cashbox entries are assigned `SDG` internally at posting time.

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
