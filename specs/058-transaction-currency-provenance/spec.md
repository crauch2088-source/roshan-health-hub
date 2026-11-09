# Feature Specification: Single-Currency SDG Provenance

**Feature Branch**: 058-transaction-currency-provenance
**Created**: 2026-11-09
**Status**: Draft — owner policy confirmed; candidate implementation in PR #211

## Owner decision

Roshan is permanently SDG-only. No currency selector, currency switching, multi-currency transaction, FX rate, conversion, or cross-currency settlement is supported. This is a fixed product invariant, not a configurable preference.

## User Story 1 — New financial records carry SDG

An authorized user creates a financial record through an existing workflow. The database records SDG on the financial source and associated ledger row even if the caller omits the currency field.

**Acceptance**
1. New invoices, payments, cashbox transactions, expenses, supplier bills/payments, and pharmacy inventory batches receive currency_code='SDG'.
2. An explicit NULL or any non-SDG currency is rejected at the database boundary.
3. Existing RPC, trigger, RLS, branch, audit and idempotency boundaries remain unchanged.

## User Story 2 — Posted currency cannot be relabelled

A user edits a financial record or reprints a document. Once a row has a currency code, it cannot be changed or cleared.

**Acceptance**
1. A posted SDG record remains SDG after ordinary updates.
2. Attempts to change or clear its currency fail.
3. A historical receipt never derives currency from mutable application settings.

## User Story 3 — Unknown legacy provenance remains explicit

A pre-migration financial row has no persisted currency code. The system must not silently infer one from current settings.

**Acceptance**
1. Existing rows remain NULL after the additive migration.
2. Official receipt printing for a row with missing provenance is blocked until a separately approved evidence-backed reconciliation assigns SDG.
3. No historical backfill occurs in this migration.

## Scope

Included source/ledger records: invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, and pharmacy_inventory batches.

Invoice line items inherit the parent invoice currency. Current medicine, lab, service, and procedure catalogue prices use the clinic-wide SDG invariant and are not independent posted ledger records.

Deferred: insurance claims, claim items/payments, insurance coverage values, payroll/salary, and later modules not required for opening. Insurance remains deferred by the owner's earlier instruction.

## Functional Requirements

- FR-001: New included financial records MUST receive literal SDG from a database default.
- FR-002: The database MUST reject explicit NULL and any non-SDG code on new included records.
- FR-003: A populated currency code MUST be immutable; it cannot be changed or cleared.
- FR-004: Legacy NULL values MUST remain NULL until a separately reviewed reconciliation explicitly assigns SDG.
- FR-005: The system MUST NOT use current settings as historical currency provenance.
- FR-006: Existing atomic RPC, RLS, branch, audit, and idempotency boundaries MUST remain unchanged.
- FR-007: No direct browser INSERT/UPDATE/DELETE grants are introduced.
- FR-008: No FX, currency conversion, or cross-currency reporting is implemented.
- FR-009: Insurance monetary workflows remain outside this phase.

## Success Criteria

- 100% of new rows in the seven included tables receive SDG when currency is omitted.
- 100% of explicit NULL and non-SDG insert attempts are rejected.
- 100% of attempts to mutate a populated currency code are rejected.
- Existing legacy rows retain NULL and are never silently relabelled.
- All assertions pass on disposable PostgreSQL 17; no hosted Supabase project is written by CI.

## Safety Boundaries

The candidate migration is additive and source-only. Green CI does not authorize QA or Production application. Production/QA migration-ledger differences and financial RPC source differences remain release gates.
