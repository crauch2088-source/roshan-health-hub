# Phase 58 — Single SDG Currency Provenance

**Owner decision:** Roshan is permanently SDG-only. No future currency switch, multi-currency, FX conversion, or cross-currency settlement is supported.

## Read-only schema inventory (Production and QA)

The following seven tables have monetary source/ledger meaning and currently lack a currency-code column in both environments:

- invoices
- payments
- cashbox_transactions
- expenses
- supplier_bills
- supplier_payments
- pharmacy_inventory (received batch purchase/selling price)

Insurance claims, claim items, claim payments, and insurance coverage are deferred per the owner's earlier scope decision. Employee salary/payroll is deferred until an actual payroll transaction workflow exists. Medicine/lab/service/procedure master prices remain expressed in SDG under the global product invariant. Invoice line items inherit their parent invoice currency.

## Financial function source comparison

Read-only pg_get_functiondef fingerprints were compared across Production and QA. Invoice creation/payment, expense posting, supplier bill/payment posting, and standard ledger triggers match. Pharmacy dispensing and cashbox reversal differ; invoice-payment reversal is QA-only. This candidate intentionally does not replace any existing financial RPC, because doing so before the live source/migration provenance is reconciled could overwrite environment-specific security and branch logic.

## Candidate database behavior

The migration adds nullable currency_code columns with DEFAULT 'SDG' for new rows on the seven approved tables. Existing rows stay NULL. A private trigger:
- rejects an explicit NULL on a new row;
- rejects any code other than SDG;
- prevents a populated code from being changed or cleared;
- blocks any attempt to assign a currency to a legacy NULL in this candidate; any historical reconciliation requires a separate approved migration.

The migration does not read system_settings, does not backfill any row, does not change RPC signatures, and does not change grants/RLS/Auth/Storage.

## Verification

The disposable PostgreSQL 17 workflow covers all seven tables: new-row defaults, explicit NULL rejection, non-SDG rejection, legacy currency assignment rejection, currency immutability, and trigger/default catalog presence. It never connects to Supabase.

## Remaining gates

- Exact-head CI must pass.
- Independent SQL/security review is required.
- Production/QA migration and financial function provenance must be reconciled before hosted application.
- Legacy NULL records must remain non-printable until a separately approved evidence-backed reconciliation.
- QA and Production migration application require separate explicit owner approval.


## Parent/source currency integrity follow-up — 2026-11-09

The private BEFORE INSERT trigger now also validates source provenance:

- `payments.invoice_id` must resolve to an invoice whose persisted `currency_code` equals the new payment currency. A legacy NULL-currency invoice therefore cannot accept a new payment until a separately approved evidence-backed reconciliation exists.
- A `supplier_payments` row linked to a supplier bill must match that bill's persisted currency.
- Cashbox rows sourced from `payment`, `expense`, or `supplier_payment` must match the source record. Reversal rows must reference an original cashbox row with the same currency; a row labelled as a reversal without `reversal_of` is rejected.
- The trigger uses nested table-name branches so it never dereferences a `NEW` field that is absent from the target table.
- This keeps the existing RPC signatures and environment-specific security-definer function bodies unchanged. The permanent SDG invariant is enforced at the database write boundary.

Additional PG17 evidence:
- The invoice atomicity workflow now applies Phase 58 and asserts the real `create_invoice_atomic` RPC persists SDG.
- The finance-only RPC workflow applies Phase 27, the finite-expense guard, and Phase 58 before exercising `post_invoice_payment` and `post_expense`. It proves a legacy NULL-currency invoice rejects a payment without leaving a payment row, while new SDG invoice/payment/expense/supplier-bill paths pass.
- The security-candidate bundle's finance matrix and combined-schema replay also include Phase 58 in the same psql session as fixture and integration assertions, preserving session-scoped auth/permission settings.

At candidate head `70becde517557cfb18c2718988fe0cf9f5c712a8`, focused Phase 58, Phase 59, invoice atomicity, finance-only RPC, security bundle, and insurance UI validation passed. Full main CI was still running. No hosted database was changed.
