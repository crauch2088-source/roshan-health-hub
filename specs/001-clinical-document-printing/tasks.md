# Tasks: Clinical Document Printing

**Status**: QA-only implementation remains in draft PRs #179 and #181. PR #178's invoice/certificate fix is merged and deployed. The encrypted Production backup, isolated PostgreSQL 17 restore rehearsal, and owner-device decryption/archive verification are complete; this closes the backup/recovery sub-gate only. No Production migration, application data write, or release promotion has occurred.

## Phase 58 currency addendum — 2026-11-09

The owner has confirmed Roshan is permanently SDG-only. This resolves the earlier single- versus multi-currency policy question. PR #181 uses the fixed SDG invariant in its receipt candidate, but historical receipt printing remains gated on persisted provenance. Phase 58 candidate PR #211 adds SDG defaults and immutability to invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, and pharmacy_inventory while preserving legacy NULL values. Insurance remains deferred. Do not mark receipt currency tasks accepted until exact-head CI, independent SQL review, receipt-status RPC parity, and the legacy-row policy are complete. No hosted migration or historical backfill has been performed.

## Existing release gates (unchanged)

- Authenticated role/branch E2E and finance staff acceptance remain required.
- Browser print preview, Android/mobile print path, actual A4 hardware, RTL/LTR and selected-document isolation remain required.
- Phase54C receipt-status RPC is QA-only; Production receipt output remains blocked.
- Production/QA migration-ledger reconciliation remains open.
