SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.has_perm','true',false);
SELECT set_config('test.super_admin','false',false);
INSERT INTO public.users (id,branch_id) VALUES
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
INSERT INTO public.insurance_companies (id,active,deleted_at) VALUES
 ('70000000-0000-0000-0000-000000000001',true,NULL),
 ('70000000-0000-0000-0000-000000000002',false,NULL),
 ('70000000-0000-0000-0000-000000000003',true,NULL);
INSERT INTO public.insurance_plans (id,company_id,default_coverage_percent,requires_prior_auth,active,deleted_at) VALUES
 ('71000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001',40,true,true,NULL),
 ('71000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000001',40,true,false,NULL),
 ('71000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000002',40,true,true,NULL);
INSERT INTO public.patient_insurance
 (id,patient_id,company_id,plan_id,status,start_date,expiry_date) VALUES
 ('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','active',CURRENT_DATE-30,CURRENT_DATE+30),
 ('30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','active',CURRENT_DATE-30,CURRENT_DATE+30),
 ('30000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','expired',CURRENT_DATE-90,CURRENT_DATE-1),
 ('30000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','active',CURRENT_DATE-1,CURRENT_DATE+30),
 ('30000000-0000-0000-0000-000000000005','40000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000003','active',CURRENT_DATE-1,CURRENT_DATE+30),
 ('30000000-0000-0000-0000-000000000006','40000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000003','71000000-0000-0000-0000-000000000001','active',CURRENT_DATE-1,CURRENT_DATE+30);
INSERT INTO public.invoices (id,patient_id,branch_id) VALUES
 ('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('50000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');

DO $$
DECLARE v_claim uuid;
BEGIN
 v_claim := public.create_insurance_claim(
  '30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
  '[{"service_type":"consultation","description":"Consultation","gross_amount":100,"covered_amount":70,"patient_amount":30}]'::jsonb,
  'test claim'
 );
 IF NOT EXISTS (SELECT 1 FROM public.insurance_claims WHERE id=v_claim AND submitted_amount=100 AND created_by='10000000-0000-0000-0000-000000000001') THEN RAISE EXCEPTION 'valid claim header totals or ownership incorrect'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.insurance_claim_items WHERE claim_id=v_claim AND gross_amount=100 AND covered_amount=70 AND patient_amount=30) THEN RAISE EXCEPTION 'valid claim item missing'; END IF;
END;
$$;

DO $$
DECLARE v_before integer;
BEGIN
 SELECT count(*) INTO v_before FROM public.insurance_claims;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"bad split","gross_amount":100,"covered_amount":70,"patient_amount":20}]'::jsonb);
  RAISE EXCEPTION 'test failed: unbalanced split accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: unbalanced split accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"bad precision","gross_amount":10.001,"covered_amount":5,"patient_amount":5.001}]'::jsonb);
  RAISE EXCEPTION 'test failed: over-precision accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: over-precision accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"unsupported","description":"bad service","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: unsupported service accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: unsupported service accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"expired","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: expired insurance accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: expired insurance accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"patient mismatch","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: mismatched patient accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: mismatched patient accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000004','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"inactive plan","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: inactive plan accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: inactive plan accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000005','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"inactive company","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: inactive company accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: inactive company accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000006','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"company plan mismatch","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: mismatched plan/company accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: mismatched plan/company accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002',
   '[{"service_type":"consultation","description":"cross branch","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: cross branch accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: cross branch accepted' THEN RAISE; END IF; END;
 IF (SELECT count(*) FROM public.insurance_claims) <> v_before THEN RAISE EXCEPTION 'invalid claims left parent rows'; END IF;
END;
$$;

SELECT set_config('test.has_perm','false',false);
DO $$
BEGIN
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"unauthorized","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: unauthorized claim accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: unauthorized claim accepted' THEN RAISE; END IF; END;
END;
$$;
SELECT set_config('test.has_perm','true',false);

CREATE FUNCTION public.test_fail_insurance_item() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF COALESCE(current_setting('test.fail_item',true)='true',false) THEN RAISE EXCEPTION 'injected insurance item failure'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER test_fail_insurance_item BEFORE INSERT ON public.insurance_claim_items FOR EACH ROW EXECUTE FUNCTION public.test_fail_insurance_item();
SELECT set_config('test.fail_item','true',false);
DO $$
BEGIN
 BEGIN
  PERFORM public.create_insurance_claim('30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
   '[{"service_type":"consultation","description":"rollback","gross_amount":10,"covered_amount":5,"patient_amount":5}]'::jsonb);
  RAISE EXCEPTION 'test failed: injected failure not raised';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='test failed: injected failure not raised' THEN RAISE; END IF;
  IF SQLERRM <> 'injected insurance item failure' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.insurance_claims) <> 1 THEN RAISE EXCEPTION 'insurance claim header not rolled back'; END IF;
 IF (SELECT count(*) FROM public.insurance_claim_items) <> 1 THEN RAISE EXCEPTION 'insurance item rows not rolled back'; END IF;
END;
$$;
SELECT 'insurance claim behavioral integration tests passed' AS result;
