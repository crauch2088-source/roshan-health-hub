# Quickstart: Transaction Currency Provenance

This document describes the future QA-only acceptance path. It is not permission to write to Production.

## Preconditions

1. Owner has approved the single-currency or multi-currency policy.
2. Candidate migration source is reconciled with deployed Production/QA functions.
3. Use disposable PostgreSQL 17 or the isolated QA project with synthetic data only.
4. Use an authorized synthetic receptionist/cashier account with the required billing/payment permissions.

## Test Scenario

1. Create a synthetic QA patient and visit using the approved atomic workflow.
2. Create an invoice through the authorized invoice RPC and assert its saved `currency_code`.
3. Post a payment through `post_invoice_payment`; assert the payment and generated cashbox ledger use the invoice currency.
4. Load the payment through the authorized receipt read path and print the saved receipt.
5. Change the currency setting only in the disposable test fixture; reload and reprint the same payment.
6. Assert the historical receipt currency is unchanged.
7. Retry the same idempotency key and assert the original payment and currency are returned without duplicate ledger rows.
8. Reverse the payment through the authorized reversal RPC and assert the reversal ledger row retains the original currency.
9. Attempt a missing/mismatched currency write and assert the transaction rolls back with no payment, ledger, or invoice state mutation.
10. Repeat allowed/denied role and cross-branch cases.

## Required Evidence

- Exact candidate commit and GitHub Actions run links.
- PostgreSQL 17 integration output with synthetic fixtures.
- Authenticated QA role/branch results.
- Browser print preview for Arabic RTL and English LTR.
- Android print-path and physical A4 printer acceptance.
- No Production test records or unapproved Production DDL/DML.


## Superseding Phase 58 disposable SQL test — 2026-11-09

This is the candidate migration's PostgreSQL 17-only path; it is not permission to write to hosted QA or Production.

Run:
1. db/tests/phase58_sdg_currency_provenance_fixture.sql
2. db/roshan_phase58_single_sdg_currency_provenance.sql
3. db/tests/phase58_sdg_currency_provenance_integration.sql

Assertions cover legacy NULL preservation, SDG defaults on new records, explicit NULL and USD rejection, explicit legacy assignment, and immutability after assignment. PR #211 adds a focused GitHub Actions workflow. Insurance and payroll are deferred; no hosted database is contacted.
