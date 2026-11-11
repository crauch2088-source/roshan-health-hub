# Implementation Plan: Transaction Currency Provenance

**Branch**: `058-transaction-currency-provenance` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

Persist transaction currency at the authoritative database write boundary and render historical receipts from saved currency provenance. The current receipt model receives currency from mutable application settings, while the live invoice/payment/cashbox schema has no currency-code fields. The feature must first obtain an explicit owner decision on single-currency locking versus multi-currency operation. No migration or code behavior change is authorized by this draft plan.

## Technical Context

**Language/Version**: TypeScript, React, PostgreSQL 17

**Primary Dependencies**: Existing React/TanStack application, Supabase JS, PostgreSQL RPCs, current receipt print model

**Storage**: Supabase PostgreSQL 17

**Testing**: Vitest, repository guard tests, disposable PostgreSQL 17 integration workflows, authenticated role/branch acceptance

**Target Platform**: Android-installable PWA and desktop web; Arabic RTL and English LTR

**Project Type**: Existing web application with Supabase backend

**Performance Goals**: No additional per-row settings lookups during receipt rendering; currency must be returned in the existing saved-record read path.

**Constraints**: Atomic RPC-only financial writes; exact decimal precision; branch isolation; idempotency; no Production DDL/DML in this feature PR; no paid dependencies.

**Scale/Scope**: Invoice, payment, cashbox ledger, receipt read model, and the clinic currency-setting boundary. Broader monetary modules must be inventoried before any policy lock is implemented.

## Constitution Check

- Clinical/data fidelity: PASS — no currency or amount may be inferred for historical records.
- Least privilege: PASS — preserve existing RPC and RLS boundaries.
- Accounting integrity: PASS — currency must travel with immutable financial source and reversal records.
- Migration/Production safety: PASS — implementation starts in a candidate branch and disposable PostgreSQL 17; Production remains untouched.
- Test-first engineering: REQUIRED — add failing currency provenance and reprint regressions before implementation.
- Source of truth: PASS — this spec is subordinate to `docs/MASTER_PLAN.md`.
- Mobile/bilingual usability: PASS — receipt rendering retains existing RTL/LTR behavior.
- Cost efficiency: PASS — no new service or paid dependency.

## Research Summary

See [research.md](research.md). The existing receipt builder accepts `currencyValue` as an external mutable input. The live database has no currency-code field on invoices, payments, or cashbox ledger rows. Production has no active invoice/payment/cashbox rows and is configured as SDG; QA has no such rows and no currency setting row. This is a clean baseline for a future controlled migration, but the owner policy decision remains necessary.

## Proposed Data and Write Model

Subject to owner approval:

1. Persist a validated ISO 4217 `currency_code` on invoices.
2. At payment posting, copy currency from the locked invoice row; do not trust a client-supplied currency.
3. Ensure the cashbox payment ledger row and any reversal copy the source payment currency.
4. Expose the saved currency through the authorized receipt read model.
5. Make the receipt model reject missing/invalid currency and remove its dependency on current settings for historical documents.
6. Define how manual cashbox entries and other monetary modules are governed by the clinic currency policy before enabling a setting change.

No database migration should be authored until the exact current live function definitions, canonical migration sources, and source-parity constraints are reconciled.

## Project Structure

```text
specs/058-transaction-currency-provenance/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    └── receipt-currency-contract.md

src/lib/print/receipt.ts
src/routes/_authenticated/billing_.$invoiceId.tsx
db/
tests/
```

**Structure Decision**: Keep the feature within the existing single React/Supabase application and extend the existing receipt model, authorized read path, financial RPCs, canonical migration source, and PostgreSQL 17 test harness. Do not create a parallel accounting service.

## Risks and Mitigations

- **Owner policy unresolved**: keep all implementation tasks blocked at T001 until the policy is explicitly accepted.
- **Live migration source drift**: compare actual Production/QA function definitions with canonical migration files before creating a forward migration.
- **Legacy records**: require an evidence-backed backfill or explicitly quarantine non-printable records; never use the current setting as a blanket historical default.
- **Incomplete monetary scope**: inventory all monetary tables and catalogue prices before implementing any currency-setting lock.
- **Currency precision**: preserve exact numeric storage and use currency-specific minor-unit rules only when formally specified; do not silently round existing values.

## Complexity Tracking

No new service, provider, or architectural layer is proposed. The only justified schema work is persisted currency provenance at existing atomic write boundaries.


## Superseding implementation addendum — 2026-11-09

The owner has confirmed permanent SDG-only operation. The first candidate is additive and limited to invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, and pharmacy_inventory. It adds nullable currency_code columns with SDG defaults for new records, a CHECK allowing only NULL legacy values or SDG, and a private trigger that rejects explicit NULL/non-SDG inserts and prevents changing a populated code.

Existing rows remain NULL; there is no settings-derived backfill. Insurance is deferred. Current Production/QA function fingerprints match for invoice creation/payment, expense posting, supplier bill/payment posting, and standard ledger triggers, but differ for pharmacy dispense and reversals; invoice-payment reversal is QA-only. Therefore this phase does not replace any existing SECURITY DEFINER RPC.

Candidate SQL and disposable PostgreSQL 17 tests are in PR #211. It is not applied to hosted QA or Production. Independent review, live migration/function provenance reconciliation, legacy-row policy, and separate owner approval remain release gates.


## Reconciled candidate status — 2026-11-11

The current mainline-reconciled Phase 58/59 candidate is PR #211 head b0d1b5aca7facb1e6ca167c5c542f64568522dfe (86 commits ahead, zero behind). Exact-head CI completed with 29 successful checks, one intentional authenticated clinical-acceptance skip and zero failures. Phase58/59 PostgreSQL 17, finance-only write isolation, receipt fail-closed, idempotency concurrency, typecheck, lint, build, dependency audit and source parity passed. This does not authorize a hosted migration, legacy backfill or financial workflow release.
