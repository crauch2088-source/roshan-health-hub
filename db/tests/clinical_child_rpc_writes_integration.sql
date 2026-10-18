INSERT INTO public.users(id, branch_id, auth_user_id, active)
VALUES
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',true),
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002',true);
INSERT INTO public.patients(id,branch_id)
VALUES
 ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.lab_orders(id,patient_id,branch_id)
VALUES
 ('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('50000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.lab_order_items(id,order_id)
VALUES
 ('60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001'),
 ('60000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000002');

SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.auth_uid','30000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.permissions','lab.update|certificates.create',false);

SET ROLE authenticated;
DO $test$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'prescriptions','prescription_items','lab_order_items',
    'medical_certificates','patient_discounts','insurance_prior_authorizations'
  ] LOOP
    IF NOT has_table_privilege('authenticated',format('public.%I',table_name),'SELECT') THEN
      RAISE EXCEPTION 'authenticated lost SELECT on %',table_name;
    END IF;
    IF has_table_privilege('authenticated',format('public.%I',table_name),'INSERT')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'UPDATE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'DELETE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'TRUNCATE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'REFERENCES')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'TRIGGER') THEN
      RAISE EXCEPTION 'authenticated retains direct write privilege on %',table_name;
    END IF;
    BEGIN
      EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',table_name);
      RAISE EXCEPTION 'direct INSERT unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
      EXECUTE format('UPDATE public.%I SET deleted_at=deleted_at',table_name);
      RAISE EXCEPTION 'direct UPDATE unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
      EXECUTE format('DELETE FROM public.%I',table_name);
      RAISE EXCEPTION 'direct DELETE unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=format('public.%I',table_name)::regclass) THEN
      RAISE EXCEPTION 'RLS was disabled on %',table_name;
    END IF;
    IF has_table_privilege('anon',format('public.%I',table_name),'INSERT') THEN
      RAISE EXCEPTION 'anon retains direct INSERT on %',table_name;
    END IF;
  END LOOP;

  IF NOT has_function_privilege('authenticated','public.complete_lab_order_item(uuid)','EXECUTE')
     OR has_function_privilege('anon','public.complete_lab_order_item(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'lab completion RPC grants are incorrect';
  END IF;
  IF NOT has_function_privilege('authenticated','public.create_medical_certificate(uuid,text,date,date)','EXECUTE')
     OR has_function_privilege('anon','public.create_medical_certificate(uuid,text,date,date)','EXECUTE') THEN
    RAISE EXCEPTION 'certificate RPC grants are incorrect';
  END IF;

  BEGIN
    PERFORM public.complete_lab_order_item('60000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'cross-branch lab completion unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.create_medical_certificate(
      '40000000-0000-0000-0000-000000000002','Sick leave','2026-10-18','2026-10-19'
    );
    RAISE EXCEPTION 'cross-branch certificate creation unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.create_medical_certificate(
      '40000000-0000-0000-0000-000000000001','Sick leave','2026-10-20','2026-10-19'
    );
    RAISE EXCEPTION 'invalid certificate dates unexpectedly succeeded';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  PERFORM public.complete_lab_order_item('60000000-0000-0000-0000-000000000001');
  PERFORM public.create_medical_certificate(
    '40000000-0000-0000-0000-000000000001','Sick leave — test','2026-10-18','2026-10-19'
  );
END
$test$;
RESET ROLE;

DO $test$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.lab_order_items
     WHERE id='60000000-0000-0000-0000-000000000001'
       AND status='completed'
       AND completed_at IS NOT NULL
       AND updated_by='10000000-0000-0000-0000-000000000001'
  ) THEN
    RAISE EXCEPTION 'same-branch lab completion did not persist expected values';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.lab_order_items
     WHERE id='60000000-0000-0000-0000-000000000002'
       AND status='completed'
  ) THEN
    RAISE EXCEPTION 'cross-branch lab item was modified';
  END IF;
  IF (SELECT count(*) FROM public.medical_certificates) <> 1 THEN
    RAISE EXCEPTION 'expected exactly one same-branch medical certificate';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.medical_certificates
     WHERE patient_id='40000000-0000-0000-0000-000000000001'
       AND doctor_id='10000000-0000-0000-0000-000000000001'
       AND diagnosis='Sick leave — test'
       AND start_date='2026-10-18'
       AND end_date='2026-10-19'
  ) THEN
    RAISE EXCEPTION 'certificate did not persist the expected patient, author, diagnosis, and dates';
  END IF;
END
$test$;
