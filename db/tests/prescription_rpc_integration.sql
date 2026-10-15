SELECT set_config('test.user_id', '10000000-0000-0000-0000-000000000001', false);
SELECT set_config('test.has_perm', 'true', false);
SELECT set_config('test.super_admin', 'false', false);
INSERT INTO public.users (id, branch_id) VALUES
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
INSERT INTO public.visits (id, patient_id, branch_id) VALUES
 ('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.medicines (id,name,generic_name,selling_price,active,is_active)
VALUES ('50000000-0000-0000-0000-000000000001','Amoxicillin 500 mg','Amoxicillin',12.50,true,true);

DO $$
DECLARE v_rx uuid;
BEGIN
 v_rx := public.create_prescription_atomic(
  '30000000-0000-0000-0000-000000000001', false,
  '[{"medicine_id":"50000000-0000-0000-0000-000000000001","medication_name":"spoofed","dose":"500 mg","frequency":"TID","duration":"5 days","quantity":15,"instructions":"After food","dosage_form":"Capsule","route":"Oral"},{"medication_name":"Custom topical medicine","quantity":1}]'::jsonb
 );
 IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE id=v_rx AND patient_id='40000000-0000-0000-0000-000000000001' AND prescribed_by='10000000-0000-0000-0000-000000000001' AND status='pending') THEN
  RAISE EXCEPTION 'header identity or visit linkage incorrect';
 END IF;
 IF (SELECT count(*) FROM public.prescription_items WHERE prescription_id=v_rx) <> 2 THEN RAISE EXCEPTION 'missing items'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id='50000000-0000-0000-0000-000000000001' AND medication_name='Amoxicillin 500 mg' AND unit_price=12.50) THEN RAISE EXCEPTION 'catalog values were not server-derived'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND medication_name='Custom topical medicine' AND unit_price=0) THEN RAISE EXCEPTION 'custom medicine failed'; END IF;
END;
$$;

DO $$
BEGIN
 BEGIN
  PERFORM public.create_prescription_atomic('30000000-0000-0000-0000-000000000001',false,'[{"medication_name":"bad","quantity":0}]'::jsonb);
  RAISE EXCEPTION 'test failed: zero quantity accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: zero quantity accepted' THEN RAISE; END IF; END;
 BEGIN
  BEGIN
   PERFORM public.create_prescription_atomic('30000000-0000-0000-0000-000000000001',false,'[{"medication_name":"fractional","quantity":1.5}]'::jsonb);
   RAISE EXCEPTION 'test failed: fractional quantity accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: fractional quantity accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_prescription_atomic('30000000-0000-0000-0000-000000000001',false,'[{"medicine_id":"50000000-0000-0000-0000-000000000099","medication_name":"missing","quantity":1}]'::jsonb);
  RAISE EXCEPTION 'test failed: missing medicine accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: missing medicine accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_prescription_atomic('30000000-0000-0000-0000-000000000002',false,'[{"medication_name":"cross branch","quantity":1}]'::jsonb);
  RAISE EXCEPTION 'test failed: cross branch accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: cross branch accepted' THEN RAISE; END IF; END;
 IF (SELECT count(*) FROM public.prescriptions) <> 1 THEN RAISE EXCEPTION 'invalid request created header'; END IF;
END;
$$;
SELECT set_config('test.has_perm','false',false);
DO $$
BEGIN
 BEGIN
  PERFORM public.create_prescription_atomic('30000000-0000-0000-0000-000000000001',false,'[{"medication_name":"unauthorized","quantity":1}]'::jsonb);
  RAISE EXCEPTION 'test failed: unauthorized request accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: unauthorized request accepted' THEN RAISE; END IF; END;
END;
$$;
SELECT set_config('test.has_perm','true',false);

CREATE FUNCTION public.test_fail_prescription_item() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF COALESCE(current_setting('test.fail_item',true)='true',false) THEN RAISE EXCEPTION 'injected item failure'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER test_fail_prescription_item BEFORE INSERT ON public.prescription_items
FOR EACH ROW EXECUTE FUNCTION public.test_fail_prescription_item();
SELECT set_config('test.fail_item','true',false);
DO $$
BEGIN
 BEGIN
  PERFORM public.create_prescription_atomic('30000000-0000-0000-0000-000000000001',false,'[{"medication_name":"rollback","quantity":1}]'::jsonb);
  RAISE EXCEPTION 'test failed: injected failure not raised';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='test failed: injected failure not raised' THEN RAISE; END IF;
  IF SQLERRM <> 'injected item failure' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.prescriptions) <> 1 THEN RAISE EXCEPTION 'orphan header after failure'; END IF;
 IF (SELECT count(*) FROM public.prescription_items) <> 2 THEN RAISE EXCEPTION 'partial items after failure'; END IF;
END;
$$;
DO $$
BEGIN
 IF NOT has_function_privilege('authenticated','public.create_prescription_atomic(uuid,boolean,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'authenticated cannot execute'; END IF;
 IF has_function_privilege('anon','public.create_prescription_atomic(uuid,boolean,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'anon can execute'; END IF;
END;
$$;
SELECT 'atomic prescription integration tests passed' AS result;
