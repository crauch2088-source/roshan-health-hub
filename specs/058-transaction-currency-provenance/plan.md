# Implementation Plan: Single-Currency SDG Provenance

**Branch**: 058-transaction-currency-provenance | **Date**: 2026-11-09

## Summary

Persist the permanent SDG-only invariant on new financial source and ledger records without rewriting existing financial RPCs. Add an SDG default and a private trigger guard to seven approved tables. Keep legacy rows NULL; do not infer or backfill historical currency. Receipt printing must later consume persisted provenance and fail closed for NULL/mismatched rows.

## Data and write model

Included tables: invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, pharmacy_inventory.

For each table:
- Add nullable currency_code text without a column-level backfill.
- Set DEFAULT 'SDG' for new rows.
- Add CHECK (currency_code IS NULL OR currency_code = 'SDG').
- Attach a private BEFORE INSERT OR UPDATE trigger: new inserts cannot explicitly use NULL; non-SDG is rejected; populated codes cannot be changed or cleared.
- Preserve NULL for legacy rows. Explicitly assigning SDG to a legacy row is allowed only as a separately reviewed reconciliation operation.

Invoice line items inherit invoice currency. Current medicine, lab-test, procedure and service catalogue prices remain SDG under the global product invariant. Insurance and payroll are deferred.

## Why no RPC replacement

Read-only Production/QA function fingerprints match for invoice creation/payment, expense posting, supplier bill/payment posting, and standard ledger triggers. Pharmacy dispensing and reversal functions differ; invoice-payment reversal exists in QA only. Replacing these functions now could overwrite environment-specific branch/security behavior. Database defaults cover inserts that omit the new column without changing function signatures.

## Test-first sequence

1. Create synthetic pre-migration rows in all seven tables.
2. Apply the candidate migration on PostgreSQL 17.
3. Assert old rows remain NULL.
4. Assert new rows with omitted currency receive SDG.
5. Assert explicit NULL and USD inserts fail.
6. Assert legacy NULL can be explicitly reconciled to SDG, but populated SDG cannot be cleared or changed.
7. Assert all seven defaults and triggers exist.

## Release Gates

- Exact-head CI and PostgreSQL 17 integration pass.
- Independent SQL/security review.
- Live migration/function source reconciliation before hosted application.
- Evidence-backed policy for legacy NULL rows before official receipts/reprints.
- Separate explicit approval for QA application and Production rollout.
