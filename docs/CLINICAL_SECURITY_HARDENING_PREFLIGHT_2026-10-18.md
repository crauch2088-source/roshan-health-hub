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

The national-ID index normalizes with lower(btrim(national_id)), excluding null/blank IDs and soft-deleted patients. The claim index applies to non-null invoice IDs, non-deleted claims and statuses other than rejected (including a null status, if one exists).

## Verified live schema names

- lab_order_items: id, order_id, test_id, status, deleted_at, completed_at, updated_by.
- lab_results: order_item_id, result_value, numeric_value, deleted_at. Results live here, not on lab_order_items.
- supplier_bills: id, supplier_id, branch_id, total_amount, paid_amount, deleted_at.
- medical_certificates: serial integer id, patient_id, doctor_id, diagnosis, start_date, end_date, deleted_at; no visit_id or certificate_number before Phase 31.
- visits: id, branch_id, patient_id, status, completed_at, updated_by, updated_at, deleted_at.
- queue_tickets: id, visit_id, status, completed_at, updated_by, deleted_at.

private.current_app_user_id() and private.app_has_perm(text) did not filter users.deleted_at. post_cashbox_entry rejected non-positive/non-finite values but did not reject excess decimal precision. post_supplier_payment rejected non-positive values but did not reject non-finite values or excess precision.

The migration makes medical_certificates.visit_id NOT NULL because this snapshot contains zero certificates. If any certificate row exists at rollout time, the migration will stop and roll back rather than invent a visit link; resolve/backfill under explicit review first.

The live privilege check also confirmed the current exposure: authenticated can execute public.fn_dispense_prescription(uuid); anon cannot. Authenticated currently has INSERT and UPDATE table privileges on both public.lab_order_items and public.medical_certificates. These grants are not being changed during preflight; Phase 31 revokes them only after the matching frontend is deployed and smoke-tested.

## Full tracked-source scan

At commit 66139e6, scanned 137 tracked TypeScript/JavaScript files under src/. All 137 were fetched successfully. Results:

- Exact client call .rpc("fn_dispense_prescription"): 0.
- Direct .from("lab_order_items") write chains (insert/update/upsert/delete): 0.
- Direct .from("medical_certificates") write chains (insert/update/upsert/delete): 0.

Legacy-name mentions in comments/history are not RPC invocations. The pharmacy UI already targets the invoice-backed RPC. ConsultationPage still used two separate writes to visits and queue_tickets; this branch changes it to complete_visit_atomic.

## Prepared files

- db/roshan_phase31_clinical_financial_security_hardening.sql (expand)
- db/roshan_phase31_contract_security_cutover.sql (contract)
- db/tests/clinical_security_hardening_assertions.sql
- src/features/clinic/consultation/ConsultationPage.tsx
- src/routes/_authenticated/certificates.tsx
- tests/clinical-security-hardening.test.ts
- package.json
- docs/CLINICAL_SECURITY_HARDENING_PREFLIGHT_2026-10-18.md

## Mandatory rollout gate

The rollout is split into expand/contract because the new frontend requires RPCs that do not exist before the migration, while the old frontend must not continue creating unlinked certificates.

1. Review the branch/PR and wait for CI (typecheck, lint, build, and PostgreSQL 17 behavior tests).
2. Obtain explicit approval to apply the expand migration: db/roshan_phase31_clinical_financial_security_hardening.sql. It adds the new RPCs/columns/indexes and strengthens helpers, financial validation and lab completion without revoking the legacy pharmacy RPC or lab-item DML.
3. During the short expand/deploy window, certificate issuance is intentionally paused: the old four-argument RPC raises a clear error and direct certificate-table DML is revoked. Do not leave this window open longer than necessary.
4. Deploy the matching frontend to the canonical production domain, then smoke-test invoice-backed pharmacy dispensing, lab result entry/completion, atomic visit/queue completion, and doctor-only visit-linked certificate issuance.
5. Re-run the duplicate preflight queries below. Obtain explicit approval to apply db/roshan_phase31_contract_security_cutover.sql. It enforces visit_id NOT NULL and revokes the old pharmacy RPC and direct clinical-table writes.
6. Run db/tests/clinical_security_hardening_assertions.sql after both migrations and re-check Supabase security advisors. If the NOT NULL step fails, stop and inspect any new certificate rows; never invent visit links.

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
  WHERE deleted_at IS NULL AND invoice_id IS NOT NULL AND status IS DISTINCT FROM 'rejected'
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
# Deploy the matching frontend and pass smoke tests; after separate approval, run:
psql "$ROSHAN_PRODUCTION_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f db/roshan_phase31_contract_security_cutover.sql
~~~

Neither command is executed. Obtain explicit approval before each production migration; do not use Supabase MCP apply_migration before approval.


## Register Phase 31 in the Supabase migration ledger

The read-only live preflight on 2026-10-18 confirmed supabase_migrations.schema_migrations contains 109 entries through version 20261018065708. The live table shape is version text NOT NULL, statements text[], name text, and created_by text. After each phase has actually been applied and postconditions pass, register the exact source SQL immediately; these are post-apply bookkeeping commands, not migration commands.

~~~bash
# AFTER the EXPAND SQL has succeeded; do not run before applying and verifying it.
EXPAND_VERSION=20261018195500
EXPAND_SQL="$(cat db/roshan_phase31_clinical_financial_security_hardening.sql)"
psql "$ROSHAN_PRODUCTION_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v migration_version="$EXPAND_VERSION" \
  -v migration_sql="$EXPAND_SQL" \
  -v migration_name="roshan_phase31_clinical_financial_security_hardening" \
  -c "INSERT INTO supabase_migrations.schema_migrations(version, statements, name, created_by)
      VALUES (:'migration_version', ARRAY[:'migration_sql'], :'migration_name', 'manual')
      ON CONFLICT (version) DO NOTHING;"

psql "$ROSHAN_PRODUCTION_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v migration_version="$EXPAND_VERSION" -v migration_sql="$EXPAND_SQL" \
  -c "SELECT version, name, statements[1] = :'migration_sql' AS exact_source_match
      FROM supabase_migrations.schema_migrations WHERE version = :'migration_version';"

# AFTER frontend deployment/smoke tests AND successful CONTRACT SQL.
CONTRACT_VERSION=20261018195600
CONTRACT_SQL="$(cat db/roshan_phase31_contract_security_cutover.sql)"
psql "$ROSHAN_PRODUCTION_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v migration_version="$CONTRACT_VERSION" \
  -v migration_sql="$CONTRACT_SQL" \
  -v migration_name="roshan_phase31_contract_security_cutover" \
  -c "INSERT INTO supabase_migrations.schema_migrations(version, statements, name, created_by)
      VALUES (:'migration_version', ARRAY[:'migration_sql'], :'migration_name', 'manual')
      ON CONFLICT (version) DO NOTHING;"

psql "$ROSHAN_PRODUCTION_DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v migration_version="$CONTRACT_VERSION" -v migration_sql="$CONTRACT_SQL" \
  -c "SELECT version, name, statements[1] = :'migration_sql' AS exact_source_match
      FROM supabase_migrations.schema_migrations WHERE version = :'migration_version';"
~~~

Each verification query must return exactly one row with exact_source_match = true. If a version already exists, compare the stored SQL first; ON CONFLICT DO NOTHING alone is not proof of source parity. The expected ledger count becomes 110 after Expand registration and 111 after Contract registration. These commands are documentation only; neither migration nor ledger was changed in production.

## Limitations

- Live schema/duplicate checks were SELECT-only; no function, grant, index, sequence or row was changed in Supabase.
- The SQL assertion file checks catalog state plus synthetic deleted-user, money-precision, visit/queue, lab-result and certificate behavior in disposable PostgreSQL 17. Real authenticated frontend smoke tests are still required before production rollout.
- The unique indexes are safe against the observed snapshot only; concurrent writes can introduce duplicates between preflight and DDL. If index creation fails, stop and rerun the duplicate report; clean conflicts only under an approved merge/audit plan. Never delete a patient or claim automatically.
