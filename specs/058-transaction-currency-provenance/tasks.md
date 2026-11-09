# Tasks: Transaction Currency Provenance

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [receipt-currency-contract.md](contracts/receipt-currency-contract.md)

**Status**: Specification only. Implementation is blocked until the owner approves the currency operating policy and the monetary-table scope.

## Phase 0 — Decisions and source contracts

- [ ] T001 Obtain explicit owner decision: single immutable clinic currency or multi-currency.
- [ ] T002 Inventory all monetary tables, catalog prices, write RPCs, triggers, and reports; classify which must carry currency provenance.
- [ ] T003 Reconcile current Production/QA migration ledgers and deployed financial RPC definitions against canonical repository sources. Do not apply migrations.
- [ ] T004 Confirm historical/soft-deleted record policy and approved receipt display format (ISO code plus localized label).

## Phase 1 — Test-first database contract

- [ ] T005 Add failing PostgreSQL 17 tests for invoice currency capture, payment inherits invoice currency, and cashbox ledger currency matches payment.
- [ ] T006 Add failing tests for missing/invalid currency, mismatched currency, idempotent retry after setting change, and rollback of all partial writes.
- [ ] T007 Add failing reversal tests proving the original and reversal retain the same currency.
- [ ] T008 Add privilege/branch tests proving no direct browser DML and no cross-branch receipt disclosure.

## Phase 2 — Authorized write and read implementation

- [ ] T009 Create a reviewed forward migration with currency columns, constraints, indexes only if justified, and an evidence-backed legacy-row strategy.
- [ ] T010 Update the invoice creation RPC to persist the authoritative currency at invoice creation.
- [ ] T011 Update `post_invoice_payment` to copy the locked invoice currency and include it in idempotency semantics.
- [ ] T012 Update payment ledger triggers and reversal RPCs to preserve currency provenance atomically.
- [ ] T013 Update the authorized receipt read path to return persisted currency and validate invoice/payment/ledger agreement.
- [ ] T014 Update `buildInvoicePaymentReceiptModel` to use persisted currency and remove mutable settings fallback.

## Phase 3 — QA acceptance

- [ ] T015 Verify exact-head unit, typecheck, lint, build, source parity, and disposable PostgreSQL 17 tests.
- [ ] T016 Run authenticated synthetic QA role/branch tests for posting, receipt, reprint, idempotency, and reversal.
- [ ] T017 Prove changing current settings cannot change any historical receipt currency.
- [ ] T018 Verify Arabic RTL, English LTR, A4 browser preview, Android print path, and selected-document isolation.

## Phase 4 — Release gate

- [ ] T019 Reconcile Production and QA live migration ledgers and canonical migration sources.
- [ ] T020 Obtain explicit owner approval for the migration/backfill and Production release plan.
- [ ] T021 Apply only through the approved migration/release workflow after encrypted backup and isolated restore evidence; never create synthetic Production data.
- [ ] T022 Complete finance staff acceptance and update the Master Plan with evidence.

## Dependencies

- T001–T004 block all implementation.
- T005–T008 must be written and fail before T009–T014.
- T015–T018 block any release.
- T019–T022 are separate Production gates; green CI does not authorize deployment or database changes.


## Superseding owner decision and candidate status — 2026-11-09

- [x] T001 Owner policy is permanently SDG-only; no currency switching, multi-currency, FX, or cross-currency settlement.
- [x] T002 Read-only monetary schema inventory completed for the approved first scope: invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, pharmacy_inventory. Insurance is deferred; payroll is not yet implemented.
- [ ] T003 Full Production/QA migration and financial-function provenance reconciliation remains open. Fingerprints match for invoice create/payment, expense, supplier bill/payment and ordinary ledger triggers; pharmacy dispense and reversal functions differ, and invoice-payment reversal is QA-only.
- [ ] T004 Legacy-row evidence and official receipt/reprint policy remain open. NULL provenance is not inferred from settings.

PR #211 contains the additive SDG-default/immutability migration and disposable PostgreSQL 17 tests. Its schema/test slice is implemented in the candidate branch, but exact-head CI and independent review are still required. No hosted migration or historical backfill has occurred.
