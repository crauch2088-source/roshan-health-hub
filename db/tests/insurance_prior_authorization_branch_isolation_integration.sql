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
  IF private.app_has_prior_authorization_branch_access(NULL) THEN
    RAISE EXCEPTION 'NULL parent must fail closed';
  END IF;

  SELECT count(*) INTO visible_count FROM public.insurance_prior_authorizations;
  PERFORM set_config('test.permissions','insurance.create|insurance.update',true);
  SELECT count(*) INTO visible_count FROM public.insurance_prior_authorizations;
  IF visible_count <> 0 THEN RAISE EXCEPTION 'SELECT must still require insurance.read'; END IF;

  PERFORM set_config('test.permissions','insurance.read|insurance.update',true);
  BEGIN
    INSERT INTO public.insurance_prior_authorizations(id,patient_insurance_id,status)
    VALUES ('a2000000-0000-0000-0000-000000000004','a1000000-0000-0000-0000-000000000001','pending');
    RAISE EXCEPTION 'INSERT without insurance.create unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  PERFORM set_config('test.permissions','insurance.read|insurance.create',true);
  UPDATE public.insurance_prior_authorizations
     SET status='denied'
   WHERE id='a2000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'UPDATE must still require insurance.update'; END IF;

  IF has_function_privilege('anon','private.app_has_prior_authorization_branch_access(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute the private branch helper';
  END IF;
  SELECT count(*) INTO visible_count
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname='public' AND c.relname='insurance_prior_authorizations';
  IF visible_count <> 3 THEN RAISE EXCEPTION 'expected 3 prior-authorization policies, got %', visible_count; END IF;
END
$test$;

RESET ROLE;
ROLLBACK;
