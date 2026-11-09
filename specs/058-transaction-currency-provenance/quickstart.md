# Quickstart: Single-Currency SDG Provenance

This is a disposable PostgreSQL 17 test only. It is not permission to write to hosted QA or Production.

Run in this order:
1. db/tests/phase58_sdg_currency_provenance_fixture.sql
2. db/roshan_phase58_single_sdg_currency_provenance.sql
3. db/tests/phase58_sdg_currency_provenance_integration.sql

Expected assertions:
- Legacy rows created before the migration remain NULL.
- New records in all seven included tables receive SDG by database default.
- Explicit NULL and USD inserts fail.
- A legacy NULL may be explicitly assigned SDG in a separately reviewed operation.
- Once populated, SDG cannot be cleared or changed.
- No hosted database, application user, patient, invoice, payment, or financial record is touched.

Included scope: invoices, payments, cashbox transactions, expenses, supplier bills/payments, and pharmacy inventory batches. Insurance and payroll are deferred. Invoice line items inherit invoice currency; catalogue prices are SDG under the permanent product invariant.
