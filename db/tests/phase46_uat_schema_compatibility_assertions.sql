-- Phase 46 PostgreSQL 17 behavioral assertions.
BEGIN;

DO $phase46_schema$
DECLARE
  v_type text;
  v_branch uuid;
  v_count integer;
BEGIN
  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'patients' AND column_name = 'allergies';
  IF v_type IS DISTINCT FROM 'text' THEN
    RAISE EXCEPTION 'patients.allergies must exist as text; got %', v_type;
  END IF;

  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'patients' AND column_name = 'chronic_conditions';
  IF v_type IS DISTINCT FROM 'text' THEN
    RAISE EXCEPTION 'patients.chronic_conditions must exist as text; got %', v_type;
  END IF;

  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'prescriptions' AND column_name = 'branch_id';
  IF v_type IS DISTINCT FROM 'uuid' THEN
    RAISE EXCEPTION 'prescriptions.branch_id must exist as uuid; got %', v_type;
  END IF;

  SELECT branch_id INTO v_branch FROM public.prescriptions
  WHERE id = '00000000-0000-0000-0000-000000046301';
  IF v_branch IS DISTINCT FROM '00000000-0000-0000-0000-000000046001'::uuid THEN
    RAISE EXCEPTION 'existing prescription branch was not backfilled from its visit';
  END IF;

  SELECT branch_id INTO v_branch FROM public.prescriptions
  WHERE id = '00000000-0000-0000-0000-000000046302';
  IF v_branch IS DISTINCT FROM '00000000-0000-0000-0000-000000046002'::uuid THEN
    RAISE EXCEPTION 'second existing prescription branch was not backfilled from its visit';
  END IF;

  SELECT branch_id INTO v_branch FROM public.prescriptions
  WHERE id = '00000000-0000-0000-0000-000000046303';
  IF v_branch IS NOT NULL THEN
    RAISE EXCEPTION 'legacy unlinked prescription must not receive a guessed branch';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.prescriptions'::regclass
      AND conname = 'prescriptions_branch_id_fkey'
      AND contype = 'f'
  ) THEN
    RAISE EXCEPTION 'prescriptions.branch_id foreign key is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'prescriptions'
      AND indexname = 'prescriptions_branch_status_created_at_idx'
  ) THEN
    RAISE EXCEPTION 'branch/status pharmacy index is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = 'phase46_prescription_branch_attribution'
      AND p.prosecdef
      AND COALESCE(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
  ) THEN
    RAISE EXCEPTION 'branch attribution trigger function must be SECURITY DEFINER with empty search_path';
  END IF;

  IF has_function_privilege('anon', 'private.phase46_prescription_branch_attribution()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.phase46_prescription_branch_attribution()', 'EXECUTE') THEN
    RAISE EXCEPTION 'trigger function must not be executable directly by browser roles';
  END IF;
END
$phase46_schema$;

-- Allergy text remains writable and NULL is not silently translated to "no known allergies".
UPDATE public.patients
SET allergies = 'Penicillin'
WHERE id = '00000000-0000-0000-0000-000000046101';
DO $allergy$
BEGIN
  IF (SELECT allergies FROM public.patients
      WHERE id = '00000000-0000-0000-0000-000000046101') IS DISTINCT FROM 'Penicillin' THEN
    RAISE EXCEPTION 'patients.allergies text value did not persist';
  END IF;
  IF (SELECT allergies FROM public.patients
      WHERE id = '00000000-0000-0000-0000-000000046102') IS NOT NULL THEN
    RAISE EXCEPTION 'unrecorded allergies must remain NULL';
  END IF;
END
$allergy$;

-- Valid insert: the trigger derives branch_id from the visit, never from caller input.
INSERT INTO public.prescriptions(id, patient_id, visit_id, status)
VALUES (
  '00000000-0000-0000-0000-000000046311',
  '00000000-0000-0000-0000-000000046101',
  '00000000-0000-0000-0000-000000046201',
  'pending'
);
DO $valid_insert$
BEGIN
  IF (SELECT branch_id FROM public.prescriptions
      WHERE id = '00000000-0000-0000-0000-000000046311')
     IS DISTINCT FROM '00000000-0000-0000-0000-000000046001'::uuid THEN
    RAISE EXCEPTION 'new prescription did not inherit visit branch';
  END IF;
END
$valid_insert$;

-- Invalid branch, patient, missing/deleted visit, and unlinked new prescription all fail closed.
DO $reject_invalid$
BEGIN
  BEGIN
    INSERT INTO public.prescriptions(id, patient_id, visit_id, branch_id)
    VALUES ('00000000-0000-0000-0000-000000046312',
      '00000000-0000-0000-0000-000000046101',
      '00000000-0000-0000-0000-000000046201',
      '00000000-0000-0000-0000-000000046002');
    RAISE EXCEPTION 'wrong-branch prescription insert unexpectedly succeeded';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.prescriptions(id, patient_id, visit_id)
    VALUES ('00000000-0000-0000-0000-000000046313',
      '00000000-0000-0000-0000-000000046102',
      '00000000-0000-0000-0000-000000046201');
    RAISE EXCEPTION 'patient/visit mismatch unexpectedly succeeded';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.prescriptions(id, patient_id, visit_id)
    VALUES ('00000000-0000-0000-0000-000000046314',
      '00000000-0000-0000-0000-000000046101',
      '00000000-0000-0000-0000-000000046299');
    RAISE EXCEPTION 'missing visit unexpectedly succeeded';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.prescriptions(id, patient_id, visit_id)
    VALUES ('00000000-0000-0000-0000-000000046315',
      '00000000-0000-0000-0000-000000046103',
      '00000000-0000-0000-0000-000000046203');
    RAISE EXCEPTION 'deleted visit unexpectedly succeeded';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.prescriptions(id, patient_id, visit_id)
    VALUES ('00000000-0000-0000-0000-000000046316',
      '00000000-0000-0000-0000-000000046101', NULL);
    RAISE EXCEPTION 'new unlinked prescription unexpectedly succeeded';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END
$reject_invalid$;

-- Existing branch cannot be changed to another branch.
DO $reject_update$
BEGIN
  BEGIN
    UPDATE public.prescriptions
    SET branch_id = '00000000-0000-0000-0000-000000046002'
    WHERE id = '00000000-0000-0000-0000-000000046301';
    RAISE EXCEPTION 'branch reassignment unexpectedly succeeded';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE public.prescriptions
    SET patient_id = '00000000-0000-0000-0000-000000046102'
    WHERE id = '00000000-0000-0000-0000-000000046301';
    RAISE EXCEPTION 'patient reassignment unexpectedly succeeded';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END
$reject_update$;

-- Legacy unlinked prescriptions can still have status updated, but cannot be assigned a guessed branch.
UPDATE public.prescriptions SET status = 'reviewed'
WHERE id = '00000000-0000-0000-0000-000000046303';
DO $legacy$
BEGIN
  IF (SELECT status FROM public.prescriptions
      WHERE id = '00000000-0000-0000-0000-000000046303') IS DISTINCT FROM 'reviewed' THEN
    RAISE EXCEPTION 'legacy unlinked prescription status update was blocked';
  END IF;
  BEGIN
    UPDATE public.prescriptions
    SET branch_id = '00000000-0000-0000-0000-000000046001'
    WHERE id = '00000000-0000-0000-0000-000000046303';
    RAISE EXCEPTION 'legacy unlinked prescription accepted arbitrary branch';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END
$legacy$;

ROLLBACK;
