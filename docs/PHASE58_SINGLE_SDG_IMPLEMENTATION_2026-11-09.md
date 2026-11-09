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
- allows a legacy NULL to be explicitly assigned SDG only through a separately reviewed reconciliation.

The migration does not read system_settings, does not backfill any row, does not change RPC signatures, and does not change grants/RLS/Auth/Storage.

## Verification

The disposable PostgreSQL 17 workflow covers all seven tables: new-row defaults, explicit NULL rejection, non-SDG rejection, explicit legacy reconciliation, currency immutability, and trigger/default catalog presence. It never connects to Supabase.

## Remaining gates

- Exact-head CI must pass.
- Independent SQL/security review is required.
- Production/QA migration and financial function provenance must be reconciled before hosted application.
- Legacy NULL records must remain non-printable until a separately approved evidence-backed reconciliation.
- QA and Production migration application require separate explicit owner approval.
