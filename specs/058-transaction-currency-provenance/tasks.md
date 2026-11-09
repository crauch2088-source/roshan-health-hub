# Tasks: Transaction Currency Provenance

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [receipt-currency-contract.md](contracts/receipt-currency-contract.md)

**Status**: Owner policy decided (SDG-only). Implementation remains blocked on complete monetary-scope inventory, live-source reconciliation, and disposable PG17 test contracts.

## Phase 0 — Decisions and source contracts

- [x] T001 Owner decision recorded: permanent single-currency SDG-only; no multi-currency or FX.
- [ ] T002 Inventory all monetary tables, catalog prices, write RPCs, triggers, and reports; classify which must carry currency provenance.
- [ ] T003 Reconcile current Production/QA migration ledgers and deployed financial RPC definitions against canonical repository sources. Do not apply migrations.
- [ ] T004 Confirm historical/soft-deleted record policy and approved receipt display format (ISO code plus localized label).

## Phase 1 — Test-first database contract

- [ ] T005 Add failing PostgreSQL 17 tests proving invoice, payment, cashbox and reversal currency is always SDG.
- [ ] T006 Add failing tests rejecting non-SDG/missing currency, proving idempotent retries preserve SDG, and proving rollback of all partial writes.
- [ ] T007 Add failing reversal tests proving the original and reversal retain the same currency.
- [ ] T008 Add privilege/branch tests proving no direct browser DML and no cross-branch receipt disclosure.

## Phase 2 — Authorized write and read implementation

- [ ] T009 Create a reviewed forward migration with SDG-only currency columns/constraints and an evidence-backed legacy-row strategy.
- [ ] T010 Update invoice creation RPCs to assign and persist SDG internally.
- [ ] T011 Update `post_invoice_payment` to require the locked invoice currency to be SDG and preserve it in idempotency semantics.
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
- [ ] T020 Obtain explicit approval for the migration/backfill and Production release plan; this is separate from the now-recorded SDG-only policy decision.
- [ ] T021 Apply only through the approved migration/release workflow after encrypted backup and isolated restore evidence; never create synthetic Production data.
- [ ] T022 Complete finance staff acceptance and update the Master Plan with evidence.

## Dependencies

- T002–T004 block implementation until monetary scope, legacy treatment and display contract are complete.
- T005–T008 must be written and fail before T009–T014.
- T015–T018 block any release.
- T019–T022 are separate Production gates; green CI does not authorize deployment or database changes.
