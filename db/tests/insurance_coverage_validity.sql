INSERT INTO public.patients (id,branch_id,deleted_at) VALUES
 ('40000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001',NULL),
 ('40000000-0000-0000-0000-000000000002','80000000-0000-0000-0000-000000000002',NULL);
INSERT INTO public.users (id,auth_user_id,branch_id,active,deleted_at) VALUES
 ('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001',true,NULL);
SELECT set_config('test.auth_uid','93000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.has_perm','true',false);
SELECT set_config('test.super_admin','false',false);

INSERT INTO public.insurance_companies (id, active, deleted_at) VALUES
 ('60000000-0000-0000-0000-000000000001', true, NULL),
 ('60000000-0000-0000-0000-000000000002', false, NULL);
INSERT INTO public.insurance_plans
 (id, company_id, default_coverage_percent, requires_prior_auth, active, deleted_at) VALUES
 ('61000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001',40,true,true,NULL),
 ('61000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000001',90,false,false,NULL),
 ('61000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000002',90,false,true,NULL);
INSERT INTO public.insurance_coverage_rules
 (id, plan_id, service_type, reference_id, generic_name, coverage_percent, fixed_amount, requires_prior_auth, excluded, deleted_at) VALUES
 ('62000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001','consultation',NULL,NULL,70,NULL,true,false,NULL),
 ('62000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000001','medicine',NULL,'amoxicillin',80,NULL,false,false,NULL);

INSERT INTO public.patient_insurance
 (id, patient_id, company_id, plan_id, status, start_date, expiry_date, deleted_at) VALUES
 ('63000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001','active',CURRENT_DATE-1,CURRENT_DATE+30,NULL),
 ('63000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001','active',CURRENT_DATE+1,CURRENT_DATE+30,NULL),
 ('63000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000002','active',CURRENT_DATE-1,CURRENT_DATE+30,NULL),
 ('63000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000003','active',CURRENT_DATE-1,CURRENT_DATE+30,NULL),
 ('63000000-0000-0000-0000-000000000005','40000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000001','active',CURRENT_DATE-1,CURRENT_DATE+30,NULL),
 ('63000000-0000-0000-0000-000000000006','40000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001','active',CURRENT_DATE-30,CURRENT_DATE-1,NULL),
 ('63000000-0000-0000-0000-000000000007','40000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001','active',CURRENT_DATE-1,CURRENT_DATE+30,NULL);

DO $coverage$
DECLARE
  v_result record;
  v_id uuid;
BEGIN
  SELECT * INTO v_result FROM public.fn_calculate_insurance_coverage(
    '63000000-0000-0000-0000-000000000001','consultation',NULL,NULL,100
  );
  IF v_result.covered_amount <> 70 OR v_result.patient_amount <> 30
     OR NOT v_result.requires_prior_auth
     OR v_result.coverage_rule_id <> '62000000-0000-0000-0000-000000000001' THEN
    RAISE EXCEPTION 'valid policy did not apply its consultation coverage rule';
  END IF;

  FOREACH v_id IN ARRAY ARRAY[
    '63000000-0000-0000-0000-000000000002'::uuid,
    '63000000-0000-0000-0000-000000000003'::uuid,
    '63000000-0000-0000-0000-000000000004'::uuid,
    '63000000-0000-0000-0000-000000000005'::uuid,
    '63000000-0000-0000-0000-000000000006'::uuid
  ]
  LOOP
    SELECT * INTO v_result FROM public.fn_calculate_insurance_coverage(
      v_id,'consultation',NULL,NULL,100
    );
    IF v_result.covered_amount <> 0 OR v_result.patient_amount <> 100
       OR v_result.requires_prior_auth OR v_result.coverage_rule_id IS NOT NULL THEN
      RAISE EXCEPTION 'invalid policy/plan/company % incorrectly received coverage', v_id;
    END IF;
  END LOOP;

  -- The RPC must enforce its own permission gate.
  PERFORM set_config('test.has_perm','false',false);
  BEGIN
    SELECT * INTO v_result FROM public.fn_calculate_insurance_coverage(
      '63000000-0000-0000-0000-000000000001','consultation',NULL,NULL,100
    );
    RAISE EXCEPTION 'test failed: missing insurance.read permission accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    NULL;
  END;
  PERFORM set_config('test.has_perm','true',false);

  -- Non-admin users cannot calculate coverage for another branch.
  BEGIN
    SELECT * INTO v_result FROM public.fn_calculate_insurance_coverage(
      '63000000-0000-0000-0000-000000000007','consultation',NULL,NULL,100
    );
    RAISE EXCEPTION 'test failed: cross-branch coverage access accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    NULL;
  END;

  -- Super-admin retains cross-branch access.
  PERFORM set_config('test.super_admin','true',false);
  SELECT * INTO v_result FROM public.fn_calculate_insurance_coverage(
    '63000000-0000-0000-0000-000000000007','consultation',NULL,NULL,100
  );
  IF v_result.covered_amount <> 70 OR v_result.patient_amount <> 30 THEN
    RAISE EXCEPTION 'super-admin cross-branch coverage lookup failed';
  END IF;
  PERFORM set_config('test.super_admin','false',false);

  SELECT * INTO v_result FROM public.fn_calculate_insurance_coverage(
    '63000000-0000-0000-0000-000000000001','medicine',NULL,'Amoxicillin',100
  );
  IF v_result.covered_amount <> 80 OR v_result.patient_amount <> 20
     OR v_result.coverage_rule_id <> '62000000-0000-0000-0000-000000000002' THEN
    RAISE EXCEPTION 'generic medicine coverage rule was not applied';
  END IF;

  -- The calculator must accept only supported service types and currency-scale amounts.
  BEGIN
    PERFORM * FROM public.fn_calculate_insurance_coverage(
      '63000000-0000-0000-0000-000000000001','unsupported',NULL,NULL,100
    );
    RAISE EXCEPTION 'test failed: unsupported service type accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;

  BEGIN
    PERFORM * FROM public.fn_calculate_insurance_coverage(
      '63000000-0000-0000-0000-000000000001','consultation',NULL,NULL,10.001
    );
    RAISE EXCEPTION 'test failed: over-precision gross amount accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
END;
$coverage$;

DO $permissions$
BEGIN
  IF NOT has_function_privilege('authenticated','public.fn_calculate_insurance_coverage(uuid,text,uuid,text,numeric)','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated cannot execute insurance coverage calculator';
  END IF;
  IF has_function_privilege('anon','public.fn_calculate_insurance_coverage(uuid,text,uuid,text,numeric)','EXECUTE') THEN
    RAISE EXCEPTION 'anon can execute insurance coverage calculator';
  END IF;
END;
$permissions$;

SELECT 'insurance coverage validity tests passed' AS result;
