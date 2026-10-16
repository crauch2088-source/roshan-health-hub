-- Proposed follow-up migration. Keep unapplied until migration reconciliation
-- is complete and the isolated PostgreSQL integration/concurrency tests pass.
-- Patient MRN allocation and patient creation must share one transaction; calling
-- next_mrn() and INSERT separately releases its advisory lock between operations.

CREATE OR REPLACE FUNCTION public.create_patient_atomic(
  _full_name text,
  _gender text,
  _date_of_birth date,
  _phone text,
  _national_id text
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

  -- Use the same transaction-scoped lock key as the hardened next_mrn() RPC,
  -- but keep the lock until the patient row is inserted and the transaction ends.
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
    branch_id, mrn, full_name, gender, date_of_birth, phone, national_id,
    created_by, registered_by, updated_by
  )
  VALUES (
    bid, new_mrn, BTRIM(_full_name), BTRIM(_gender), _date_of_birth,
    NULLIF(BTRIM(COALESCE(_phone, '')), ''),
    NULLIF(BTRIM(COALESCE(_national_id, '')), ''),
    uid, uid, uid
  )
  RETURNING id INTO patient_id;

  RETURN patient_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_patient_atomic(text, text, date, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_patient_atomic(text, text, date, text, text) TO authenticated;


-- Registration must go through the atomic RPC so callers cannot bypass
-- branch-derived assignment/MRN allocation or call the legacy allocator.
REVOKE INSERT ON TABLE public.patients FROM authenticated;
REVOKE ALL ON FUNCTION public.next_mrn() FROM PUBLIC, anon, authenticated;
