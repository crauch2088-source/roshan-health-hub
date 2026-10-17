DO $test$
DECLARE policy_count integer;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='patients' AND policyname='optimized_auth_policy_patients') THEN
    RAISE EXCEPTION 'stale patient policy was not removed';
  END IF;
  SELECT count(*) INTO policy_count FROM pg_policies
    WHERE schemaname='public' AND tablename='patients'
      AND policyname IN ('patients_select','patients_insert','patients_update','patients_delete')
      AND 'authenticated'=ANY(roles);
  IF policy_count<>4 THEN RAISE EXCEPTION 'expected four authenticated patient policies, got %',policy_count; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='patients' AND policyname='patients_select' AND cmd='SELECT' AND qual LIKE '%patients.read%') THEN
    RAISE EXCEPTION 'patient SELECT permission predicate missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='patients' AND policyname='patients_insert' AND cmd='INSERT' AND with_check LIKE '%patients.create%') THEN
    RAISE EXCEPTION 'patient INSERT permission predicate missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='patients' AND policyname='patients_update' AND cmd='UPDATE' AND qual LIKE '%patients.update%' AND with_check LIKE '%patients.update%') THEN
    RAISE EXCEPTION 'patient UPDATE predicates missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='patients' AND policyname='patients_delete' AND cmd='DELETE' AND qual LIKE '%patients.delete%') THEN
    RAISE EXCEPTION 'patient DELETE permission predicate missing';
  END IF;
  IF (SELECT auth_user_id FROM public.users WHERE id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') IS NOT NULL THEN
    RAISE EXCEPTION 'replay-safe variant must not link an environment-specific identity';
  END IF;
END
$test$;
SET ROLE authenticated;
DO $test$
DECLARE affected integer;
BEGIN
  IF (SELECT count(*) FROM public.patients)<>1 THEN RAISE EXCEPTION 'patient SELECT policy failed'; END IF;
  INSERT INTO public.patients (id,label) VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','insert test');
  GET DIAGNOSTICS affected=ROW_COUNT;
  IF affected<>1 THEN RAISE EXCEPTION 'patient INSERT policy failed'; END IF;
  UPDATE public.patients SET label='updated test' WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  GET DIAGNOSTICS affected=ROW_COUNT;
  IF affected<>1 THEN RAISE EXCEPTION 'patient UPDATE policy failed'; END IF;
  DELETE FROM public.patients WHERE id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  GET DIAGNOSTICS affected=ROW_COUNT;
  IF affected<>1 THEN RAISE EXCEPTION 'patient DELETE policy failed'; END IF;
END
$test$;
RESET ROLE;
