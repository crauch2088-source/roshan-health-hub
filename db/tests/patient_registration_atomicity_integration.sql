SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.allow_create','true',false);
INSERT INTO public.users(id,branch_id) VALUES
  ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');

DO $test$
DECLARE
  first_id uuid;
  second_id uuid;
  first_mrn text;
  second_mrn text;
  row_count integer;
BEGIN
  first_id := public.create_patient_atomic('Atomic Test Patient One','male',NULL,'555-0101','TEST-NID-1');
  second_id := public.create_patient_atomic('Atomic Test Patient Two','female',NULL,'555-0102','TEST-NID-2');

  SELECT mrn INTO first_mrn FROM public.patients WHERE id=first_id;
  SELECT mrn INTO second_mrn FROM public.patients WHERE id=second_id;
  IF first_id IS NULL OR second_id IS NULL OR first_id=second_id THEN
    RAISE EXCEPTION 'patient RPC must return distinct created patient IDs';
  END IF;
  IF first_mrn !~ '^RMC[0-9]{6,}$' OR second_mrn !~ '^RMC[0-9]{6,}$' OR first_mrn=second_mrn THEN
    RAISE EXCEPTION 'patient MRNs must be valid and unique';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.patients
    WHERE id IN (first_id,second_id)
      AND (branch_id IS DISTINCT FROM '20000000-0000-0000-0000-000000000001'::uuid
        OR created_by IS DISTINCT FROM '10000000-0000-0000-0000-000000000001'::uuid)
  ) THEN
    RAISE EXCEPTION 'patient must be attributed to the caller and caller branch';
  END IF;

  BEGIN
    PERFORM public.create_patient_atomic('   ','male',NULL,NULL,NULL);
    RAISE EXCEPTION 'blank patient name unexpectedly succeeded';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;
  SELECT count(*) INTO row_count FROM public.patients;
  IF row_count <> 2 THEN RAISE EXCEPTION 'invalid registration created a row'; END IF;

  PERFORM set_config('test.allow_create','false',false);
  BEGIN
    PERFORM public.create_patient_atomic('Permission Denied Patient','male',NULL,NULL,NULL);
    RAISE EXCEPTION 'registration without permission unexpectedly succeeded';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    NULL;
  END;
  SELECT count(*) INTO row_count FROM public.patients;
  IF row_count <> 2 THEN RAISE EXCEPTION 'denied registration created a row'; END IF;

  PERFORM set_config('test.allow_create','true',false);
  UPDATE public.users SET branch_id=NULL WHERE id='10000000-0000-0000-0000-000000000001';
  BEGIN
    PERFORM public.create_patient_atomic('No Branch Patient','male',NULL,NULL,NULL);
    RAISE EXCEPTION 'registration without branch unexpectedly succeeded';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    NULL;
  END;
  SELECT count(*) INTO row_count FROM public.patients;
  IF row_count <> 2 THEN RAISE EXCEPTION 'unassigned registration created a row'; END IF;
END
$test$;
