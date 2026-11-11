# Tasks: Transaction Currency Provenance

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [receipt-currency-contract.md](contracts/receipt-currency-contract.md)

**Status**: Owner policy confirmed. Additive SDG provenance schema/test candidate is in PR #211; receipt RPC integration and hosted rollout remain gated.

## Phase 0 — Decisions and source contracts

- [x] T001 Confirm permanent SDG-only clinic policy; no currency switching, multi-currency, FX, or cross-currency settlement.
- [x] T002 Inventory the approved financial source/ledger scope and classify deferred insurance/payroll plus SDG catalogue prices; see the 2026-11-09 addendum below.
- [ ] T003 Reconcile current Production/QA migration ledgers and deployed financial RPC definitions against canonical repository sources. Do not apply migrations.
- [ ] T004 Confirm historical/soft-deleted record policy and approved receipt display format (ISO code plus localized label).

## Phase 1 — Test-first database contract

- [x] T005 Add PostgreSQL 17 tests for invoice currency capture, payment inheritance from a persisted SDG invoice, and source-ledger currency matching.
- [x] T006 Cover explicit NULL/non-SDG rejection, legacy-parent NULL rejection with no partial payment row, immutable posted currency, and idempotent payment retry. The permanent SDG-only decision removes any mutable currency-setting input from the write contract.
- [x] T007 Cover valid reversal currency retention and reject reversals whose original ledger currency is unknown or inconsistent.
- [x] T008 Cover RPC-only finance writes, permission and branch guards, and no cross-branch receipt disclosure in disposable PostgreSQL 17 fixtures.

## Phase 2 — Authorized write and read implementation

- [ ] T009 Create a reviewed forward migration with currency columns, constraints, indexes only if justified, and an evidence-backed legacy-row strategy.
- [x] T010 Keep `create_invoice_atomic` signature stable; the database default/trigger persists SDG on invoice creation. The real RPC path is exercised after Phase 58 in the PG17 invoice integration job.
- [x] T011 Keep `post_invoice_payment` signature stable; the BEFORE INSERT trigger requires the locked source invoice to carry persisted SDG, rejecting legacy NULL invoices. The actual RPC, idempotent retry and no-partial-write behavior are covered by the finance-only PG17 workflow.
- [x] T012 Keep existing environment-specific ledger/reversal RPC bodies intact; database triggers require source-ledger and reversal currency equality. PG17 integration covers payment, expense, supplier-payment and reversal source relationships.
- [x] T013 Add candidate `get_invoice_payment_receipt_status_v2(uuid[])` with permission/branch guards, source-ledger uniqueness checks, and payment/invoice/cashbox/reversal currency outputs. Legacy NULL and inconsistent provenance returns a negative currency match.
- [x] T014 Update the PR #181 receipt model/route to use persisted currency only; require all applicable records to agree on SDG and fail closed for legacy NULL, missing, duplicate, or mismatched ledger provenance. The UI branch remains dependent on PR #211/Phase 59 and is not deployable alone.

## Phase 3 — QA acceptance

- [x] T015 Verify exact-head unit, typecheck, lint, build, source parity, and disposable PostgreSQL 17 tests. Exact candidate head `995cfbd0e0bc1ee1af463ef474e028ada46cda2f` passed all required CI checks, including Phase 58 and Phase 59 PostgreSQL 17 integration, security candidate bundle, migration source parity, CodeQL, dependency audit, typecheck, lint, and build.
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

PR #211 now contains Phase 58 schema guards plus Phase 59 receipt-currency RPC and disposable PostgreSQL 17 integration tests. The Phase 58 and Phase 59 PostgreSQL 17 jobs passed on the candidate branch. Full exact-head CI and independent review remain in progress. PR #181 was updated separately and must be rebased/revalidated after #211 is merged. No hosted migration or historical backfill has occurred.


## Candidate implementation note — 2026-11-09

The approved single-currency policy makes RPC replacement unnecessary and less safe than enforcing provenance at the database write boundary. Phase 58 uses a private trigger to apply SDG defaults and validate parent/source relationships while preserving the existing Production/QA RPC definitions. Phase 59 adds a branch-guarded receipt read RPC; PR #181 consumes only persisted values and remains non-printable for legacy NULL or inconsistent records.

At head `70becde517557cfb18c2718988fe0cf9f5c712a8`, focused PG17 Phase 58/59, invoice RPC, finance RPC, security-bundle and insurance UI checks passed. Exact-head full CI and independent review remain open. Hosted QA/Production apply and authenticated staff/print acceptance remain blocked.


## Exact-head regression closure — 2026-11-09, PR #211 head `995cfbd0e0bc1ee1af463ef474e028ada46cda2f`

- Added a regression test first to prove that an existing SDG payment could previously be re-pointed to a legacy invoice whose currency provenance is NULL; the same gap existed for supplier payments and legacy supplier bills. The disposable PostgreSQL 17 run failed on the new payment-source assertion before the implementation change (run 42629344093).
- Updated `private.enforce_roshan_sdg_currency()` to revalidate parent/source currency whenever a payment's `invoice_id`, supplier payment's `supplier_bill_id`, or cashbox source/reversal reference changes. Unrelated updates to legacy NULL rows remain possible; the immutable currency field itself still cannot be changed or backfilled.
- The new update-link regression passed on the fixed candidate head. Exact-head CI run 42629610078 passed, including Phase 58 and Phase 59 PostgreSQL 17 integrations, finance-only RPC isolation, cashbox reversal concurrency, security-candidate bundle, migration source parity, dependency audits, role tests, typecheck, lint, and build. The PR workflow 42629603090 also passed.
- PR #211 checks at this head: 29 successful, 1 intentionally skipped (canonical baseline/authenticated acceptance gate); no failures or pending checks. PR remains Draft and 40 commits ahead of main, 0 behind.
- PR #181 receipt UI branch head `00f09d956c0632d6e193e4864bdb0401b092b09a` also has all exact-head checks complete (29 successful, 1 intentionally skipped). It remains dependent on Phase 59 in PR #211 and must be rebased/revalidated after that migration is separately reviewed and merged.
- PRs #208, #209, and #210 also remain exact-head green and 0 commits behind main; all remain Draft pending their separate product/operational acceptance gates.

**No hosted change:** no QA/Production migration, DDL/DML, legacy backfill, RPC deployment, grant/RLS/Auth/Storage mutation, financial data write, or Vercel promotion was performed. All database integration ran only against disposable PostgreSQL 17 in GitHub Actions.

**Remaining Phase 58/59 blockers:** independent SQL/security review; Production/QA live migration and function-source reconciliation; evidence-backed legacy NULL receipt policy; separate QA and Production rollout approvals; authenticated finance staff acceptance; and Arabic/English browser, A4, Android printer acceptance.


## H+1 reconciled exact-head validation — 2026-11-11

- [x] Reconcile PR #211 with current main using a normal two-parent merge commit; 86 commits ahead, zero behind.
- [x] Verify exact head b0d1b5aca7facb1e6ca167c5c542f64568522dfe: 29 successful checks, one intentional authenticated clinical-acceptance skip, zero failures.
- [x] Phase 58 and Phase 59 PostgreSQL 17 tests, receipt fail-closed checks, finance-only RPC isolation, invoice-payment idempotency concurrency, migration source parity, security bundle, typecheck, lint, build and dependency audit pass.
- [ ] Independent SQL/security review and live Production/QA migration/function provenance reconciliation.
- [ ] Evidence-backed policy for legacy NULL receipt records; no currency inferred from settings.
- [ ] Rebase and revalidate PR #181 only after Phase 59 is separately reviewed/merged.
- [ ] Authenticated synthetic QA finance roles, receipt/reprint, idempotency, reversal, Arabic/English, A4 and Android acceptance.
- [ ] Separate owner approval, encrypted backup and isolated restore before any hosted migration.

**No hosted changes:** no QA/Production migration, DDL/DML, backfill, RPC deployment, financial data write, role/ACL/Storage mutation or Vercel promotion.
