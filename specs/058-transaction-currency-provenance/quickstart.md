# Quickstart: Transaction Currency Provenance

This document describes the QA-only acceptance path. It is not permission to write to Production.

## Preconditions

1. Owner policy is permanently SDG-only.
2. Candidate migration source is reconciled with deployed Production/QA functions.
3. Use disposable PostgreSQL 17 for migration tests; use hosted QA only after separate explicit approval.
4. Use an authorized synthetic cashier account for later receipt acceptance.

## Receipt acceptance scenario

1. Create a synthetic QA patient and visit using the approved atomic workflow.
2. Create an invoice through the authorized invoice RPC and assert its saved currency_code is SDG.
3. Post a payment and assert payment and generated cashbox ledger provenance agree.
4. Load the payment through the authorized receipt read path and print the saved receipt.
5. Confirm current display settings cannot relabel the historical receipt.
6. Retry the same idempotency key and assert no duplicate payment or ledger row.
7. Reverse the payment and assert reversal retains SDG.
8. Attempt missing/mismatched currency and assert rollback with no partial writes.
9. Repeat allowed/denied role and cross-branch cases.

## Phase 58 disposable PostgreSQL 17 test

Run these files in order:
1. db/tests/phase58_sdg_currency_provenance_fixture.sql
2. db/roshan_phase58_single_sdg_currency_provenance.sql
3. db/tests/phase58_sdg_currency_provenance_integration.sql

Assertions cover legacy NULL preservation, SDG defaults on new records, explicit NULL/USD rejection, blocking any attempt to assign a currency to a legacy NULL, and immutability after posting. The cashbox fixture preserves the existing immutable-ledger trigger. Any historical reconciliation requires a separate approved migration. CI never connects to Supabase.

## Required evidence

- Exact candidate commit and GitHub Actions run links.
- PostgreSQL 17 integration output with synthetic fixtures.
- Authenticated QA role/branch results.
- Browser print preview for Arabic RTL and English LTR.
- Android print-path and physical A4 printer acceptance.
- No Production test records or unapproved Production DDL/DML.
