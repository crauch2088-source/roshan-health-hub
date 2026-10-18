-- Run AFTER db/roshan_phase31_clinical_financial_security_hardening.sql on disposable PG17/staging.
-- Includes catalog assertions and synthetic behavior checks; never run against production as a test fixture.
DO $test$
DECLARE
  v_definition text;
  v_status text;
  v_user_id uuid;
  v_certificate_id integer;
  v_certificate_number bigint;
  v_doctor_role uuid := '00000000-0000-0000-0000-000000000001';
  v_clerk_role uuid := '00000000-0000-0000-0000-000000000002';
  v_doctor_id uuid := '00000000-0000-0000-0000-000000000011';
  v_deleted_id uuid := '00000000-0000-0000-0000-000000000012';
  v_clerk_id uuid := '00000000-0000-0000-0000-000000000013';
  v_doctor_auth uuid := '00000000-0000-0000-0000-000000000101';
  v_deleted_auth uuid := '00000000-0000-0000-0000-000000000102';
  v_clerk_auth uuid := '00000000-0000-0000-0000-000000000103';
  v_branch_id uuid := '00000000-0000-0000-0000-000000000201';
  v_patient_id uuid := '00000000-0000-0000-0000-000000000301';
  v_other_patient_id uuid := '00000000-0000-0000-0000-000000000302';
  v_visit_id uuid := '00000000-0000-0000-0000-000000000401';
  v_ticket_id uuid := '00000000-0000-0000-0000-000000000501';
  v_lab_order_id uuid := '00000000-0000-0000-0000-000000000601';
  v_lab_item_id uuid := '00000000-0000-0000-0000-000000000602';
  v_permission_visits uuid := '00000000-0000-0000-0000-000000000701';
  v_permission_lab uuid := '00000000-0000-0000-0000-000000000702';
  v_permission_cert uuid := '00000000-0000-0000-0000-000000000703';
  v_permission_cashbox uuid := '00000000-0000-0000-0000-000000000704';
  v_permission_debts uuid := '00000000-0000-0000-0000-000000000705';
  v_permission_test uuid := '00000000-0000-0000-0000-000000000706';
BEGIN
  -- Catalog and privilege assertions.
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
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_index i
    WHERE i.indexrelid='public.insurance_claims_one_active_nonrejected_per_invoice_uq'::regclass
      AND position('is distinct from' IN lower(pg_catalog.pg_get_expr(i.indpred,i.indrelid)))>0
  ) THEN RAISE EXCEPTION 'insurance claim unique index does not include null statuses'; END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='medical_certificates'
      AND column_name='visit_id' AND is_nullable='YES'
  ) THEN RAISE EXCEPTION 'medical certificate visit_id must be NOT NULL'; END IF;
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

  -- Synthetic authorization data: deleted users must be rejected even with a matching permission row.
  INSERT INTO public.roles(id,code) VALUES (v_doctor_role,'doctor'),(v_clerk_role,'clerk');
  INSERT INTO public.permissions(id,code) VALUES
    (v_permission_visits,'visits.update'),
    (v_permission_lab,'lab.update'),
    (v_permission_cert,'certificates.create'),
    (v_permission_cashbox,'cashbox.create'),
    (v_permission_debts,'debts.create'),
    (v_permission_test,'test.permission');
  INSERT INTO public.role_permissions(role_id,permission_id) VALUES
    (v_doctor_role,v_permission_visits),(v_doctor_role,v_permission_lab),
    (v_doctor_role,v_permission_cert),(v_doctor_role,v_permission_cashbox),
    (v_doctor_role,v_permission_debts),(v_doctor_role,v_permission_test),
    (v_clerk_role,v_permission_cert),(v_clerk_role,v_permission_test);
  INSERT INTO public.users(id,auth_user_id,active,deleted_at,branch_id,role_id) VALUES
    (v_doctor_id,v_doctor_auth,true,NULL,v_branch_id,v_doctor_role),
    (v_deleted_id,v_deleted_auth,true,pg_catalog.now(),v_branch_id,v_clerk_role),
    (v_clerk_id,v_clerk_auth,true,NULL,v_branch_id,v_clerk_role);
  PERFORM pg_catalog.set_config('test.auth_uid',v_deleted_auth::text,false);
  IF private.current_app_user_id() IS NOT NULL THEN RAISE EXCEPTION 'soft-deleted user resolved as current user'; END IF;
  IF private.app_has_perm('test.permission') THEN RAISE EXCEPTION 'soft-deleted user retained permission'; END IF;

  PERFORM pg_catalog.set_config('test.auth_uid',v_doctor_auth::text,false);
  v_user_id := private.current_app_user_id();
  IF v_user_id IS DISTINCT FROM v_doctor_id THEN RAISE EXCEPTION 'active doctor identity lookup failed'; END IF;

  -- Decimal precision and positive-amount checks must reject fractional cents.
  BEGIN
    PERFORM public.post_cashbox_entry('deposit',10.001);
    RAISE EXCEPTION 'cashbox accepted more than two decimal places';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  BEGIN
    PERFORM public.post_cashbox_entry('deposit',0);
    RAISE EXCEPTION 'cashbox accepted a non-positive amount';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  BEGIN
    PERFORM public.post_supplier_payment(NULL,10.001);
    RAISE EXCEPTION 'supplier payment accepted more than two decimal places';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  BEGIN
    PERFORM public.post_supplier_payment(NULL,0);
    RAISE EXCEPTION 'supplier payment accepted a non-positive amount';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  -- Atomic visit completion updates the visit and its queue ticket together.
  INSERT INTO public.patients(id,branch_id,national_id) VALUES (v_patient_id,v_branch_id,'CI-TEST-001');
  BEGIN
    INSERT INTO public.patients(id,branch_id,national_id)
    VALUES ('00000000-0000-0000-0000-000000000311',v_branch_id,' ci-test-001 ');
    RAISE EXCEPTION 'normalized duplicate national ID was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  INSERT INTO public.insurance_claims(id,invoice_id,status)
  VALUES ('00000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000802','draft');
  BEGIN
    INSERT INTO public.insurance_claims(id,invoice_id,status)
    VALUES ('00000000-0000-0000-0000-000000000803','00000000-0000-0000-0000-000000000802','submitted');
    RAISE EXCEPTION 'second active insurance claim for one invoice was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  INSERT INTO public.visits(id,branch_id,patient_id,status) VALUES (v_visit_id,v_branch_id,v_patient_id,'in_progress');
  INSERT INTO public.queue_tickets(id,visit_id,status) VALUES (v_ticket_id,v_visit_id,'in_progress');
  PERFORM public.complete_visit_atomic(v_visit_id);
  SELECT status INTO v_status FROM public.visits WHERE id=v_visit_id;
  IF v_status IS DISTINCT FROM 'completed' THEN RAISE EXCEPTION 'visit was not completed'; END IF;
  SELECT status INTO v_status FROM public.queue_tickets WHERE id=v_ticket_id;
  IF v_status IS DISTINCT FROM 'completed' THEN RAISE EXCEPTION 'queue ticket was not completed'; END IF;

  -- Lab completion fails without a result, then succeeds with a numeric result.
  INSERT INTO public.lab_orders(id) VALUES (v_lab_order_id);
  INSERT INTO public.lab_order_items(id,order_id,test_id,status)
  VALUES (v_lab_item_id,v_lab_order_id,'00000000-0000-0000-0000-000000000603','in_progress');
  BEGIN
    PERFORM public.complete_lab_order_item(v_lab_item_id);
    RAISE EXCEPTION 'lab item completed without a result';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  INSERT INTO public.lab_results(id,order_item_id,parameter_id,numeric_value)
  VALUES ('00000000-0000-0000-0000-000000000604',v_lab_item_id,'00000000-0000-0000-0000-000000000605',7.0);
  PERFORM public.complete_lab_order_item(v_lab_item_id);
  SELECT status INTO v_status FROM public.lab_order_items WHERE id=v_lab_item_id;
  IF v_status IS DISTINCT FROM 'completed' THEN RAISE EXCEPTION 'lab item did not complete with a result'; END IF;

  -- Certificate issuance links a real visit, uses a unique sequence, and denies non-doctors.
  v_certificate_id := public.create_medical_certificate(v_patient_id,'CI test diagnosis',CURRENT_DATE,CURRENT_DATE,v_visit_id);
  SELECT certificate_number INTO v_certificate_number FROM public.medical_certificates WHERE id=v_certificate_id;
  IF v_certificate_number IS NULL THEN RAISE EXCEPTION 'certificate serial was not assigned'; END IF;
  INSERT INTO public.patients(id,branch_id,national_id) VALUES (v_other_patient_id,v_branch_id,'CI-TEST-002');
  BEGIN
    PERFORM public.create_medical_certificate(v_other_patient_id,'Mismatch test',CURRENT_DATE,CURRENT_DATE,v_visit_id);
    RAISE EXCEPTION 'certificate accepted a visit for a different patient';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  PERFORM pg_catalog.set_config('test.auth_uid',v_clerk_auth::text,false);
  BEGIN
    PERFORM public.create_medical_certificate(v_patient_id,'Clerk test',CURRENT_DATE,CURRENT_DATE,v_visit_id);
    RAISE EXCEPTION 'non-doctor issued a medical certificate';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$test$;
