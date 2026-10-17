-- Synthetic cross-branch regression for insurance prior authorizations.
-- Run after the combined fixture and candidate migration using PostgreSQL 17.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('test.permissions','insurance.read|insurance.create|insurance.update',true);

DO $test$
DECLARE
  visible_count integer;
  affected integer;
BEGIN
  SELECT count(*) INTO visible_count FROM public.insurance_prior_authorizations;
  IF visible_count <> 1 THEN
    RAISE EXCEPTION 'expected exactly one same-branch prior authorization, got %', visible_count;
  END IF;

  UPDATE public.insurance_prior_authorizations
     SET status='approved'
   WHERE id='a2000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch update should affect one row, got %', affected; END IF;

  UPDATE public.insurance_prior_authorizations
     SET status='approved'
   WHERE id='a2000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch update unexpectedly affected % rows', affected; END IF;

  BEGIN
    INSERT INTO public.insurance_prior_authorizations(id,patient_insurance_id,status)
    VALUES ('a2000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000002','pending');
    RAISE EXCEPTION 'cross-branch insert unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  IF private.app_has_prior_authorization_branch_access('a1000000-0000-0000-0000-000000000099') THEN
    RAISE EXCEPTION 'missing parent must fail closed';
  END IF;
END
$test$;

RESET ROLE;
ROLLBACK;
