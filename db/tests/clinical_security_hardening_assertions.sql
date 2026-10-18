-- Run AFTER db/roshan_phase31_clinical_financial_security_hardening.sql on isolated PG17/staging.
-- Catalog assertions only; no business rows are read or changed.
DO $test$
DECLARE v_definition text;
BEGIN
  IF to_regprocedure('public.complete_visit_atomic(uuid)') IS NULL THEN RAISE EXCEPTION 'complete_visit_atomic missing'; END IF;
  IF to_regprocedure('public.complete_lab_order_item(uuid)') IS NULL THEN RAISE EXCEPTION 'complete_lab_order_item missing'; END IF;
  IF to_regprocedure('public.create_medical_certificate(uuid,text,date,date,uuid)') IS NULL THEN RAISE EXCEPTION 'visit-linked certificate RPC missing'; END IF;
  IF has_function_privilege('authenticated','public.fn_dispense_prescription(uuid)','EXECUTE') THEN RAISE EXCEPTION 'legacy dispense RPC remains executable'; END IF;
  IF has_function_privilege('authenticated','public.create_medical_certificate(uuid,text,date,date)','EXECUTE') THEN RAISE EXCEPTION 'legacy certificate RPC remains executable'; END IF;
  IF has_table_privilege('authenticated','public.lab_order_items','INSERT')
     OR has_table_privilege('authenticated','public.lab_order_items','UPDATE')
     OR has_table_privilege('authenticated','public.lab_order_items','DELETE') THEN RAISE EXCEPTION 'direct DML remains on lab_order_items'; END IF;
  IF has_table_privilege('authenticated','public.medical_certificates','INSERT')
     OR has_table_privilege('authenticated','public.medical_certificates','UPDATE')
     OR has_table_privilege('authenticated','public.medical_certificates','DELETE') THEN RAISE EXCEPTION 'direct DML remains on medical_certificates'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_indexes WHERE schemaname='public' AND indexname='patients_active_national_id_normalized_uq') THEN RAISE EXCEPTION 'national ID unique index missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_indexes WHERE schemaname='public' AND indexname='insurance_claims_one_active_nonrejected_per_invoice_uq') THEN RAISE EXCEPTION 'insurance claim unique index missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_indexes WHERE schemaname='public' AND indexname='medical_certificates_certificate_number_uq') THEN RAISE EXCEPTION 'certificate serial index missing'; END IF;
  v_definition := lower(pg_catalog.pg_get_functiondef('private.current_app_user_id()'::regprocedure));
  IF position('deleted_at is null' IN v_definition)=0 THEN RAISE EXCEPTION 'current_app_user_id ignores deleted_at'; END IF;
  v_definition := lower(pg_catalog.pg_get_functiondef('private.app_has_perm(text)'::regprocedure));
  IF position('deleted_at is null' IN v_definition)=0 THEN RAISE EXCEPTION 'app_has_perm ignores deleted_at'; END IF;
  v_definition := lower(pg_catalog.pg_get_functiondef('public.post_cashbox_entry(text,numeric,text,text,text,timestamptz)'::regprocedure));
  IF position('round(_amount, 2)' IN v_definition)=0 THEN RAISE EXCEPTION 'cashbox precision validation missing'; END IF;
  v_definition := lower(pg_catalog.pg_get_functiondef('public.post_supplier_payment(uuid,numeric,text,text,date,text)'::regprocedure));
  IF position('round(_amount, 2)' IN v_definition)=0 THEN RAISE EXCEPTION 'supplier payment precision validation missing'; END IF;
  v_definition := lower(pg_catalog.pg_get_functiondef('public.complete_lab_order_item(uuid)'::regprocedure));
  IF position('result_value' IN v_definition)=0 OR position('numeric_value' IN v_definition)=0
     OR position('invalid lab status transition' IN v_definition)=0 THEN RAISE EXCEPTION 'lab result/status checks missing'; END IF;
  v_definition := lower(pg_catalog.pg_get_functiondef('public.complete_visit_atomic(uuid)'::regprocedure));
  IF position('app_has_visit_branch_access' IN v_definition)=0 OR position('queue_tickets' IN v_definition)=0 THEN RAISE EXCEPTION 'atomic visit/queue logic missing'; END IF;
  v_definition := lower(pg_catalog.pg_get_functiondef('public.create_medical_certificate(uuid,text,date,date,uuid)'::regprocedure));
  IF position('r.code=''doctor''' IN v_definition)=0 OR position('p_visit_id' IN v_definition)=0 THEN RAISE EXCEPTION 'certificate role/visit checks missing'; END IF;
END;
$test$;
