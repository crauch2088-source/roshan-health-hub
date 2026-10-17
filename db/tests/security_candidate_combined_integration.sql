-- Run every existing candidate regression in one shared database/schema.
-- The fixture and candidate SQL are synthetic test-only artifacts.
\echo 'Combined regression: invoice-item isolation'
\i db/tests/invoice_item_branch_isolation_integration.sql
\echo 'Combined regression: patient/visit child isolation'
\i db/tests/parent_branch_isolation_integration.sql
\echo 'Combined regression: queue/follow-up isolation'
\i db/tests/queue_followup_branch_isolation_integration.sql
\echo 'Combined regression: prescription/lab child isolation'
\i db/tests/prescription_lab_child_branch_isolation_integration.sql
\echo 'Combined regression: finance RPC-only writes'
\i db/tests/finance_only_rpc_writes_integration.sql

-- Assert the final combined policy catalog, not just individual row behavior.
DO $catalog$
DECLARE
  target record;
  policy_count integer;
  unscoped_count integer;
  function_definition text;
BEGIN
  FOR target IN
    SELECT * FROM (VALUES
      ('invoice_items','app_has_invoice_branch'),
      ('certificates','app_has_patient_visit_branch_access'),
      ('medical_certificates','app_has_patient_branch'),
      ('patient_discounts','app_has_patient_branch'),
      ('procedure_orders','app_has_patient_visit_branch_access'),
      ('procedure_results','app_has_procedure_order_branch_access'),
      ('followups','app_has_patient_visit_branch_access'),
      ('queue_tickets','app_has_patient_visit_branch_access'),
      ('prescriptions','app_has_prescription_parent_branch_access'),
      ('prescription_items','app_has_prescription_branch_access'),
      ('lab_order_items','app_has_lab_order_item_branch_access')
    ) AS expected(table_name, required_helper)
  LOOP
    SELECT count(*),
           count(*) FILTER (
             WHERE (COALESCE(qual,'') || ' ' || COALESCE(with_check,'')) NOT ILIKE '%' || target.required_helper || '%'
           )
      INTO policy_count, unscoped_count
    FROM pg_policies
    WHERE schemaname='public' AND tablename=target.table_name;
    IF policy_count <> 4 THEN
      RAISE EXCEPTION 'expected exactly four policies for %, found %', target.table_name, policy_count;
    END IF;
    IF unscoped_count <> 0 THEN
      RAISE EXCEPTION '% has % policies without required branch helper %',
        target.table_name, unscoped_count, target.required_helper;
    END IF;
  END LOOP;

  function_definition := pg_get_functiondef(
    'private.app_has_patient_visit_branch_access(uuid,uuid)'::regprocedure
  );
  IF function_definition NOT ILIKE '%app_has_attachment_branch_access%'
     OR function_definition NOT ILIKE '%v.patient_id = _patient_id%' THEN
    RAISE EXCEPTION 'shared patient/visit helper lost its branch or identity-consistency contract';
  END IF;

  IF has_table_privilege('authenticated','public.payments','INSERT')
     OR has_table_privilege('authenticated','public.cashbox_transactions','UPDATE')
     OR has_table_privilege('authenticated','public.supplier_bills','DELETE') THEN
    RAISE EXCEPTION 'finance direct-write privileges unexpectedly remain in combined catalog';
  END IF;

  IF has_table_privilege('authenticated','public.insurance_claims','INSERT')
     OR has_table_privilege('authenticated','public.insurance_claims','UPDATE')
     OR has_table_privilege('authenticated','public.insurance_claims','DELETE')
     OR has_table_privilege('authenticated','public.insurance_claim_items','INSERT')
     OR has_table_privilege('authenticated','public.insurance_claim_items','UPDATE')
     OR has_table_privilege('authenticated','public.insurance_claim_items','DELETE')
     OR has_table_privilege('authenticated','public.insurance_claim_payments','INSERT')
     OR has_table_privilege('authenticated','public.insurance_claim_payments','UPDATE')
     OR has_table_privilege('authenticated','public.insurance_claim_payments','DELETE')
     OR has_table_privilege('anon','public.insurance_claims','INSERT')
     OR has_table_privilege('anon','public.insurance_claims','UPDATE')
     OR has_table_privilege('anon','public.insurance_claims','DELETE')
     OR has_table_privilege('anon','public.insurance_claim_items','INSERT')
     OR has_table_privilege('anon','public.insurance_claim_items','UPDATE')
     OR has_table_privilege('anon','public.insurance_claim_items','DELETE')
     OR has_table_privilege('anon','public.insurance_claim_payments','INSERT')
     OR has_table_privilege('anon','public.insurance_claim_payments','UPDATE')
     OR has_table_privilege('anon','public.insurance_claim_payments','DELETE') THEN
    RAISE EXCEPTION 'insurance direct-write privileges unexpectedly remain in combined catalog';
  END IF;

  IF has_function_privilege('authenticated','public.next_invoice_number()','EXECUTE')
     OR has_function_privilege('anon','public.next_invoice_number()','EXECUTE') THEN
    RAISE EXCEPTION 'unscoped next_invoice_number RPC remains callable';
  END IF;
  IF NOT has_function_privilege('postgres','public.next_invoice_number()','EXECUTE') THEN
    RAISE EXCEPTION 'invoice-number allocator owner execution was unexpectedly revoked';
  END IF;

  IF NOT has_table_privilege('authenticated','public.insurance_claims','SELECT')
     OR NOT has_table_privilege('authenticated','public.insurance_claim_items','SELECT')
     OR NOT has_table_privilege('authenticated','public.insurance_claim_payments','SELECT') THEN
    RAISE EXCEPTION 'authenticated lost insurance claim read access';
  END IF;
END
$catalog$;
