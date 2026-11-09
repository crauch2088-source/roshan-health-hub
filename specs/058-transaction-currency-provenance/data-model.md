# Data Model: Single-Currency SDG Provenance

## Currency invariant
Roshan supports one currency only: ISO 4217 SDG. It is a permanent product invariant.

## Included records

| Table | Meaning | Currency rule |
|---|---|---|
| invoices | Posted patient/corporate invoice | Persist SDG |
| payments | Posted settlement against invoice | Persist SDG |
| cashbox_transactions | Payment, expense, supplier and reversal ledger rows | Persist SDG |
| expenses | Posted operating expense | Persist SDG |
| supplier_bills | Posted supplier obligation | Persist SDG |
| supplier_payments | Posted supplier settlement | Persist SDG |
| pharmacy_inventory | Received inventory batch with purchase/selling prices | Persist SDG |

## Inherited/global values

- invoice_items inherit the parent invoice currency; no conflicting independent code is assigned.
- Current medicine, lab-test, procedure and service catalogue prices are expressed in SDG.
- Clinical order line prices are not independent ledger settlements; final posted amounts are captured on invoices.
- Cashbox aggregate views inherit the currency of source ledger rows; no cross-currency totals exist.

## Deferred scope

- Insurance claim headers, items, payments, plans and coverage rules are deferred.
- Employee salary/payroll is deferred until a payroll transaction workflow exists.
- No FX rate, conversion, or multi-currency fields are introduced.

## Column semantics

Each included table receives currency_code text:
- DEFAULT 'SDG' for new records.
- CHECK (currency_code IS NULL OR currency_code = 'SDG').
- Existing rows remain NULL after the additive migration.
- A private trigger rejects explicit NULL on new rows, rejects non-SDG values, and prevents a populated code from being changed or cleared.
- A legacy NULL can only be assigned SDG through an explicit, separately reviewed reconciliation.
