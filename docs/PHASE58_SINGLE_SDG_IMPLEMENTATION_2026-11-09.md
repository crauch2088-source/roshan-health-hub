# Phase 58 — Single SDG Currency Provenance

**Owner decision:** Roshan is permanently SDG-only. No future currency switch, multi-currency, FX conversion, or cross-currency settlement is supported.

## Read-only schema inventory (Production and QA)

The following seven tables have monetary source/ledger meaning and currently lack a currency-code column in both environments:

- invoices
- payments
- cashbox_transactions
- expenses
- supplier_bills
- supplier_payments
- pharmacy_inventory (received batch purchase/selling price)

Insurance claims, claim items, claim payments, and insurance coverage are deferred per the owner's earlier scope decision. Employee salary/payroll is deferred until an actual payroll transaction workflow exists. Medicine/lab/service/procedure master prices remain expressed in SDG under the global product invariant. Invoice line items inherit their parent invoice currency.

## Financial function source comparison

Read-only pg_get_functiondef fingerprints were compared across Production and QA. Invoice creation/payment, expense posting, supplier bill/payment posting, and standard ledger triggers match. Pharmacy dispensing and cashbox reversal differ; invoice-payment reversal is QA-only. This candidate intentionally does not replace any existing financial RPC, because doing so before the live source/migration provenance is reconciled could overwrite environment-specific security and branch logic.

## Candidate database behavior

The migration adds nullable currency_code columns with DEFAULT 'SDG' for new rows on the seven approved tables. Existing rows stay NULL. A private trigger:
- rejects an explicit NULL on a new row;
- rejects any code other than SDG;
- prevents a populated code from being changed or cleared;
- blocks any attempt to assign a currency to a legacy NULL in this candidate; any historical reconciliation requires a separate approved migration.

The migration does not read system_settings, does not backfill any row, does not change RPC signatures, and does not change grants/RLS/Auth/Storage.

## Verification

The disposable PostgreSQL 17 workflow covers all seven tables: new-row defaults, explicit NULL rejection, non-SDG rejection, legacy currency assignment rejection, currency immutability, and trigger/default catalog presence. It never connects to Supabase.

## Remaining gates

- Exact-head CI must pass.
- Independent SQL/security review is required.
- Production/QA migration and financial function provenance must be reconciled before hosted application.
- Legacy NULL records must remain non-printable until a separately approved evidence-backed reconciliation.
- QA and Production migration application require separate explicit owner approval.


## Parent/source currency integrity follow-up — 2026-11-09

The private BEFORE INSERT trigger now also validates source provenance:

- `payments.invoice_id` must resolve to an invoice whose persisted `currency_code` equals the new payment currency. A legacy NULL-currency invoice therefore cannot accept a new payment until a separately approved evidence-backed reconciliation exists.
- A `supplier_payments` row linked to a supplier bill must match that bill's persisted currency.
- Cashbox rows sourced from `payment`, `expense`, or `supplier_payment` must match the source record. Reversal rows must reference an original cashbox row with the same currency; a row labelled as a reversal without `reversal_of` is rejected.
- The trigger uses nested table-name branches so it never dereferences a `NEW` field that is absent from the target table.
- This keeps the existing RPC signatures and environment-specific security-definer function bodies unchanged. The permanent SDG invariant is enforced at the database write boundary.

Additional PG17 evidence:
- The invoice atomicity workflow now applies Phase 58 and asserts the real `create_invoice_atomic` RPC persists SDG.
- The finance-only RPC workflow applies Phase 27, the finite-expense guard, and Phase 58 before exercising `post_invoice_payment` and `post_expense`. It proves a legacy NULL-currency invoice rejects a payment without leaving a payment row, while new SDG invoice/payment/expense/supplier-bill paths pass.
- The security-candidate bundle's finance matrix and combined-schema replay also include Phase 58 in the same psql session as fixture and integration assertions, preserving session-scoped auth/permission settings.

At candidate head `70becde517557cfb18c2718988fe0cf9f5c712a8`, focused Phase 58, Phase 59, invoice atomicity, finance-only RPC, security bundle, and insurance UI validation passed. Full main CI was still running. No hosted database was changed.


## Deferred insurance cashbox source guard — 2026-11-10

Independent review found that Phase 54 names `insurance_claim_payment` as a payment-ledger source, while Phase 58 deliberately excludes insurance claim/payment tables from the persisted-currency scope. The cashbox trigger now rejects new rows with that source type using SQLSTATE `23514` until a dedicated persisted-currency source workflow is approved. This is a fail-closed deferral, not insurance functionality. A PostgreSQL 17 integration regression covers the rejection.


## Final exact-head CI — 2026-11-10

At PR #211 head `6d2440381e78710fc5579598ff7684b1909884a8`, the Phase 58 SDG provenance and Phase 59 receipt-currency PostgreSQL 17 jobs passed in CI run [42775216135](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216135). The full CI completed with 20 successful jobs and one intentional skip for authenticated clinical acceptance. Insurance UI validation [42775216669](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775216669) and PR validation [42775210843](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42775210843) also passed. These are isolated candidate tests; no hosted migration was applied.


## Cashbox source-discriminator hardening — 2026-11-10

Independent review found that the original source-currency trigger validated known linked source types but did not reject an unknown source_type, an untyped source_id, or a payment ID disguised as a manual entry. The source field is independent of transaction_type; the latter's CHECK constraint does not close this gap.

The candidate now fails closed on new/changed cashbox source references:
- accepted source types are exactly manual, payment, expense, supplier_payment, and reversal;
- insurance_claim_payment remains explicitly deferred and rejected until its own persisted-currency workflow exists;
- unknown or NULL source types are rejected;
- manual rows cannot carry source_id or reversal_of;
- reversal rows must carry exactly one reversal_of reference and cannot also carry source_id;
- non-reversal rows cannot carry reversal_of;
- payment, expense, and supplier-payment sources must resolve to a persisted source row with matching SDG provenance.

The PostgreSQL 17 integration suite now covers unknown, untyped, disguised-manual, malformed-reversal, and valid-manual cases. The first exact-head run exposed the new guard's interaction with the generic cashbox fixture; the fixture was corrected to model a valid manual source rather than weakening the guard.

At PR #211 exact head 7e7b610f9ef2d99534e0f06d39fb1a1424865b22, the complete pull-request workflow run 42781299925 completed with 20 successful jobs, zero failures, and one intentional skip for the canonical PostgreSQL baseline/authenticated clinical acceptance. The dedicated Phase 58 and Phase 59 PostgreSQL 17 jobs both passed on this exact head. No hosted Supabase database was changed; the PR remains Draft pending independent review, migration provenance reconciliation, and separate QA/Production approvals.


## Trigger/RPC execution ACL closure — 2026-11-10

The currency enforcement function is trigger-only: EXECUTE is explicitly revoked from PUBLIC, anon, authenticated and service_role. The receipt-status RPC is explicitly revoked from those same principals, then EXECUTE is granted only to authenticated. The integration fixtures now create the Supabase anon, authenticated and service_role roles so the PG17 checks exercise the intended ACL boundary rather than relying on absent fixture roles.

The first ACL-hardening run exposed incomplete role modeling in the isolated fixtures; the fixtures were corrected to include the Supabase roles. The source-contract assertion was also updated to match the expanded deny message. No application permission was weakened and trigger execution continues to work under normal DML.

Exact code head faec5ddd9fdec54081332628ab037a2f7e770243 passed the complete PR workflow: 20 CI jobs succeeded, zero failed, and one canonical-baseline/authenticated-clinical-acceptance job was intentionally skipped. Phase 58 and Phase 59 PostgreSQL 17 integration jobs both passed. The Vercel preview status is a build-rate-limit failure, not a build/test result; no Production deployment or hosted database change occurred. PR #211 remains Draft.

## Deferred insurance claim cash posting

The Phase 58 currency-provenance guard rejects `insurance_claim_payment` ledger rows because the insurance source workflow does not yet persist and validate the same SDG provenance contract. To avoid leaving an apparently usable action that must fail after this migration, the candidate now:
- conditionally revokes `post_insurance_claim_payment(uuid,numeric,text,text)` from PUBLIC, anon, authenticated and service_role when present. It exists in current hosted schemas but is absent from the canonical PG17 baseline, so the migration and tests tolerate both states;
- removes the payment mutation/dialog from the insurance claims UI and shows a bilingual deferred-state notice;
- keeps claim creation and review available; only cash posting is disabled until the insurance provenance phase is explicitly approved;
- verifies the RPC is not executable by application roles in the PostgreSQL 17 integration test.

This is a fail-closed deferral, not an insurance implementation. No existing claim or ledger row is rewritten.
