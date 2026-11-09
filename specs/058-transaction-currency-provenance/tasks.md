# Tasks: Single-Currency SDG Provenance

**Status**: Owner policy confirmed. Candidate implementation is in PR #211; not applied to hosted QA or Production.

## Phase 0 — Policy and scope

- [x] T001 Confirm permanent SDG-only policy; no future currency switching or FX.
- [x] T002 Inventory financial schema in Production and QA. Included seven tables: invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, pharmacy_inventory. Insurance deferred; catalogues inherit global SDG.
- [x] T003 Fingerprint key financial RPC definitions read-only. Invoice creation/payment, expense posting, supplier bill/payment posting, and ordinary ledger triggers match; pharmacy dispense/reversal differ and invoice-payment reversal is absent in Production.
- [ ] T004 Obtain independent review of exact deployed migration/function source provenance before hosted application.

## Phase 1 — Additive schema and regression tests

- [x] T005 Add nullable currency_code columns with SDG defaults for new rows on the seven approved tables.
- [x] T006 Add database constraints and private trigger enforcement for SDG-only inserts and immutable populated currency codes.
- [x] T007 Preserve existing NULL rows; no historical backfill or setting-derived inference.
- [x] T008 Add synthetic PostgreSQL 17 fixture and integration assertions for default, NULL/foreign-currency rejection, immutability, and legacy preservation.
- [ ] T009 Verify exact-head CI on PR #211 and review all PostgreSQL job output.

## Phase 2 — Receipt integration

- [ ] T010 Update Phase54C receipt-status RPC to return and verify payment/invoice/ledger currency_code.
- [ ] T011 Update receipt UI/model to consume persisted currency_code and block missing/mismatched provenance; no constant fallback for legacy rows.
- [ ] T012 Add synthetic receipt regressions for settings changes, partial payment, reversal, duplicate retry, and branch mismatch.
- [ ] T013 Reconcile Phase54C Production/QA source before proposing any hosted migration.

## Phase 3 — Legacy reconciliation and release

- [ ] T014 Determine evidence-backed treatment of any legacy NULL rows. Do not infer from mutable settings.
- [ ] T015 Obtain separate explicit approval for QA application and authenticated cashier acceptance.
- [ ] T016 Obtain separate explicit approval for Production migration after full migration-ledger reconciliation and backup/restore checks.
- [ ] T017 Complete finance staff receipt/reprint acceptance in Arabic RTL and English LTR.

## Boundaries

- No FX or currency conversion.
- Insurance monetary tables remain deferred.
- No hosted database writes, permission changes, Auth/Storage changes, or deployment promotion in PR #211.
