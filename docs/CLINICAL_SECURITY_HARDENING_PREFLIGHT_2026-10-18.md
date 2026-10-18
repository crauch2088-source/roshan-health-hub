# Phase 31 — Clinical and financial security hardening preflight

Date: 2026-10-18  
Live Supabase project: jewzonxplxhogqrnhosl (PostgreSQL 17.6)  
Repository baseline: 66139e645fd7886df08cb33f9f71a4be9c65cf2a  
Safety: all production database calls in this preflight were SELECT-only. The Phase 31 migration has not been applied.

## Pre-flight findings (aggregate only)

| Check | Live result | Decision |
|---|---:|---|
| Duplicate normalized active patients.national_id groups | 0 groups / 0 excess rows | Partial unique index clear at preflight; re-run immediately before applying |
| Duplicate active, non-rejected insurance_claims.invoice_id groups | 0 groups / 0 excess rows | Partial unique index clear at preflight; re-run immediately before applying |
| medical_certificates rows | 0 total / 0 active | No certificate backfill needed in this snapshot |
| visits rows | 7 total / 0 active | All current visit rows are soft-deleted; do not use for smoke tests |
| queue_tickets rows | 0 total / 0 active | No queue rows in this snapshot |

The national-ID index normalizes with lower(btrim(national_id)), excluding null/blank IDs and soft-deleted patients. The claim index applies to non-null invoice IDs, non-deleted claims and statuses other than rejected.

## Verified live schema names

- lab_order_items: id, order_id, test_id, status, deleted_at, completed_at, updated_by.
- lab_results: order_item_id, result_value, numeric_value, deleted_at. Results live here, not on lab_order_items.
- supplier_bills: id, supplier_id, branch_id, total_amount, paid_amount, deleted_at.
- medical_certificates: serial integer id, patient_id, doctor_id, diagnosis, start_date, end_date, deleted_at; no visit_id or certificate_number before Phase 31.
- visits: id, branch_id, patient_id, status, completed_at, updated_by, updated_at, deleted_at.
- queue_tickets: id, visit_id, status, completed_at, updated_by, deleted_at.

private.current_app_user_id() and private.app_has_perm(text) did not filter users.deleted_at. post_cashbox_entry rejected non-positive/non-finite values but did not reject excess decimal precision. post_supplier_payment rejected non-positive values but did not reject non-finite values or excess precision.

## Full tracked-source scan

At commit 66139e6, scanned 137 tracked TypeScript/JavaScript files under src/. All 137 were fetched successfully. Results:

- Exact client call .rpc("fn_dispense_prescription"): 0.
- Direct .from("lab_order_items") write chains (insert/update/upsert/delete): 0.
- Direct .from("medical_certificates") write chains (insert/update/upsert/delete): 0.

Legacy-name mentions in comments/history are not RPC invocations. The pharmacy UI already targets the invoice-backed RPC. ConsultationPage still used two separate writes to visits and queue_tickets; this branch changes it to complete_visit_atomic.

## Prepared files

- db/roshan_phase31_clinical_financial_security_hardening.sql
- db/tests/clinical_security_hardening_assertions.sql
- src/features/clinic/consultation/ConsultationPage.tsx
- src/routes/_authenticated/certificates.tsx
- tests/clinical-security-hardening.test.ts
- package.json
- docs/CLINICAL_SECURITY_HARDENING_PREFLIGHT_2026-10-18.md

## Mandatory rollout gate

This migration revokes direct DML on the clinical tables, revokes the legacy dispense RPC and disables the old four-argument certificate RPC. Therefore:

1. Review the branch/PR and wait for CI (typecheck, lint, build, test guards).
2. Deploy the matching frontend to the canonical production domain.
3. Authenticated smoke-test invoice-backed pharmacy dispensing, lab result entry/completion, atomic visit/queue completion, and doctor-only visit-linked certificate issuance.
4. Re-run the duplicate query below immediately before applying.
5. Obtain explicit approval, then apply once.
6. Run db/tests/clinical_security_hardening_assertions.sql against the migrated catalog and re-check Supabase security advisors.

### Read-only duplicate re-check

~~~sql
SELECT 'patients_normalized_national_id' AS check_name,
       COUNT(*)::bigint AS duplicate_groups,
       COALESCE(SUM(n-1),0)::bigint AS excess_rows
FROM (
  SELECT lower(btrim(national_id)) AS k, COUNT(*) AS n
  FROM public.patients
  WHERE deleted_at IS NULL AND national_id IS NOT NULL AND btrim(national_id) <> ''
  GROUP BY lower(btrim(national_id))
  HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'insurance_claims_invoice_id_active_nonrejected',
       COUNT(*)::bigint, COALESCE(SUM(n-1),0)::bigint
FROM (
  SELECT invoice_id, COUNT(*) AS n
  FROM public.insurance_claims
  WHERE deleted_at IS NULL AND invoice_id IS NOT NULL AND status <> 'rejected'
  GROUP BY invoice_id
  HAVING COUNT(*) > 1
) d;
~~~

### Apply command (after approval only)

From a checkout authenticated to project jewzonxplxhogqrnhosl, after reviewing the branch and passing the deployment/smoke-test gate:

~~~bash
# Do not run until frontend deployment/smoke tests pass and explicit approval is given.
psql "$ROSHAN_PRODUCTION_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f db/roshan_phase31_clinical_financial_security_hardening.sql
~~~

This command is not executed. Do not use Supabase MCP apply_migration before approval.

## Limitations

- Live schema/duplicate checks were SELECT-only; no function, grant, index, sequence or row was changed in Supabase.
- The SQL assertion file checks catalog state after migration; behavior smoke tests still require an authenticated deployed frontend and isolated/staging records.
- The unique indexes are safe against the observed snapshot only; concurrent writes can introduce duplicates between preflight and DDL. If index creation fails, stop and rerun the duplicate report; clean conflicts only under an approved merge/audit plan. Never delete a patient or claim automatically.
