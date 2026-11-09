# Implementation Plan: Transaction Currency Provenance

**Branch**: `058-transaction-currency-provenance` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

Persist transaction currency at the authoritative database write boundary and render historical receipts from saved currency provenance. The current receipt model receives currency from mutable application settings, while the live invoice/payment/cashbox schema has no currency-code fields. The owner has explicitly decided on permanent SDG-only operation: no currency switching, multi-currency support, or FX features are to be implemented. No migration or code behavior change is authorized by this draft plan.

## Technical Context

**Language/Version**: TypeScript, React, PostgreSQL 17

**Primary Dependencies**: Existing React/TanStack application, Supabase JS, PostgreSQL RPCs, current receipt print model

**Storage**: Supabase PostgreSQL 17

**Testing**: Vitest, repository guard tests, disposable PostgreSQL 17 integration workflows, authenticated role/branch acceptance

**Target Platform**: Android-installable PWA and desktop web; Arabic RTL and English LTR

**Project Type**: Existing web application with Supabase backend

**Performance Goals**: No additional per-row settings lookups during receipt rendering; currency must be returned in the existing saved-record read path.

**Constraints**: Atomic RPC-only financial writes; exact decimal precision; branch isolation; idempotency; no Production DDL/DML in this feature PR; no paid dependencies.

**Scale/Scope**: Invoice, payment, cashbox ledger, receipt read model, and the clinic currency-setting boundary. All monetary domains must be inventoried for the SDG-only invariant before implementation.

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

- **Owner policy**: decided — permanent SDG-only operation. Implementation remains blocked on complete monetary-scope inventory and canonical-source reconciliation.
- **Live migration source drift**: compare actual Production/QA function definitions with canonical migration files before creating a forward migration.
- **Legacy records**: require an evidence-backed backfill or explicitly quarantine non-printable records; never use the current setting as a blanket historical default.
- **Incomplete monetary scope**: inventory all monetary tables and catalogue prices before implementing any currency-setting lock.
- **Currency precision**: preserve exact numeric storage and use currency-specific minor-unit rules only when formally specified; do not silently round existing values.

## Complexity Tracking

No new service, provider, or architectural layer is proposed. The only justified schema work is persisted currency provenance at existing atomic write boundaries.
