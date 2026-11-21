-- QA Operational Blockers Remediation (2026-11-21)
-- 1. P0: Allow authenticated users to SELECT their own authorized branch in public.branches
--    so SECURITY INVOKER trigger private.phase47_visit_branch_attribution() can verify
--    active branch status without weakening branch isolation or RLS.
-- 2. P1: Add optional _address parameter to public.create_patient_atomic() while preserving
--    backwards compatibility for 5-argument callers.
BEGIN;

DROP POLICY IF EXISTS branches_select ON public.branches;
CREATE POLICY branches_select
  ON public.branches
  FOR SELECT
  TO authenticated
  USING (
    (SELECT public.app_has_perm('admin.full'::text))
    OR (SELECT private.app_has_branch_access(id))
  );

DROP FUNCTION IF EXISTS public.create_patient_atomic(text, text, date, text, text);

CREATE OR REPLACE FUNCTION public.create_patient_atomic(
  _full_name text,
  _gender text,
  _date_of_birth date,
  _phone text,
  _national_id text,
  _address text DEFAULT NULL
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  uid uuid;
  bid uuid;
  next_no bigint;
  patient_id uuid;
  new_mrn text;
BEGIN
  IF NOT public.app_has_perm('patients.create') THEN
    RAISE EXCEPTION 'not authorised to register patients'
      USING ERRCODE = '42501';
  END IF;

  uid := public.current_app_user_id();
  IF uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required'
      USING ERRCODE = '42501';
  END IF;

  SELECT u.branch_id
    INTO bid
    FROM public.users AS u
   WHERE u.id = uid
     AND COALESCE(u.active, true) IS TRUE
     AND u.deleted_at IS NULL;

  IF bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured; patient registration requires a branch context'
      USING ERRCODE = '42501';
  END IF;

  IF NULLIF(BTRIM(COALESCE(_full_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'patient full name is required'
      USING ERRCODE = '22023';
  END IF;

  IF NULLIF(BTRIM(COALESCE(_gender, '')), '') IS NULL THEN
    RAISE EXCEPTION 'patient gender is required'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('roshan:mrn'));

  SELECT COALESCE(
           MAX(NULLIF(regexp_replace(p.mrn, '[^0-9]', '', 'g'), '')::bigint),
           0
         ) + 1
    INTO next_no
    FROM public.patients AS p
   WHERE p.mrn ~ '^RMC[0-9]+$';

  new_mrn := 'RMC' || lpad(next_no::text, 6, '0');

  INSERT INTO public.patients (
    branch_id, mrn, full_name, gender, date_of_birth, phone, national_id, address,
    created_by, registered_by, updated_by
  )
  VALUES (
    bid, new_mrn, BTRIM(_full_name), BTRIM(_gender), _date_of_birth,
    NULLIF(BTRIM(COALESCE(_phone, '')), ''),
    NULLIF(BTRIM(COALESCE(_national_id, '')), ''),
    NULLIF(BTRIM(COALESCE(_address, '')), ''),
    uid, uid, uid
  )
  RETURNING id INTO patient_id;

  RETURN patient_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_patient_atomic(text, text, date, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_patient_atomic(text, text, date, text, text, text) TO authenticated;

COMMIT;
