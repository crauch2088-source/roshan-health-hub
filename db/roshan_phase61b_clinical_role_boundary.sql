-- Phase 61B: separate system administration from clinical/pharmacy write authority.
-- Forward-only correction for QA environments where the original Phase 61 migration is already applied.
BEGIN;

CREATE OR REPLACE FUNCTION private.app_has_role_permission(
  _allowed_role_codes text[],
  _permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS u
    JOIN public.roles AS r ON r.id = u.role_id
    JOIN public.role_permissions AS rp ON rp.role_id = r.id
    JOIN public.permissions AS p ON p.id = rp.permission_id
    WHERE u.id = private.current_app_user_id()
      AND COALESCE(u.active, true) IS TRUE
      AND u.deleted_at IS NULL
      AND r.code = ANY(COALESCE(_allowed_role_codes, ARRAY[]::text[]))
      AND p.code = _permission_code
  )
$function$;

REVOKE ALL ON FUNCTION private.app_has_role_permission(text[], text)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION private.app_has_role_permission(text[], text)
  TO authenticated;

DROP POLICY IF EXISTS prescription_item_correction_requests_select
  ON public.prescription_item_correction_requests;
CREATE POLICY prescription_item_correction_requests_select
ON public.prescription_item_correction_requests
FOR SELECT TO authenticated
USING (
  (SELECT public.is_super_admin())
  OR (
    (SELECT private.app_has_role_permission(ARRAY['pharmacist','legacy_pharmacist'], 'pharmacy.correction.request'))
    AND (SELECT private.app_has_prescription_branch_access(prescription_id))
  )
  OR (
    (SELECT private.app_has_role_permission(ARRAY['doctor','legacy_gp','legacy_specialist','legacy_dentist'], 'prescriptions.correction.resolve'))
    AND (SELECT private.app_can_resolve_prescription_item_correction(prescription_id))
  )
);

DO $phase61b_move$
BEGIN
  IF to_regprocedure('private.request_prescription_item_correction_unchecked(uuid,text)') IS NULL THEN
    IF to_regprocedure('public.request_prescription_item_correction(uuid,text)') IS NULL THEN
      RAISE EXCEPTION 'Phase 61 request RPC is missing; refusing an incomplete role-boundary upgrade';
    END IF;
    EXECUTE 'ALTER FUNCTION public.request_prescription_item_correction(uuid, text) SET SCHEMA private';
    EXECUTE 'ALTER FUNCTION private.request_prescription_item_correction(uuid, text) RENAME TO request_prescription_item_correction_unchecked';
  END IF;

  IF to_regprocedure('private.resolve_prescription_item_correction_unchecked(uuid,text,jsonb,text)') IS NULL THEN
    IF to_regprocedure('public.resolve_prescription_item_correction(uuid,text,jsonb,text)') IS NULL THEN
      RAISE EXCEPTION 'Phase 61 resolve RPC is missing; refusing an incomplete role-boundary upgrade';
    END IF;
    EXECUTE 'ALTER FUNCTION public.resolve_prescription_item_correction(uuid, text, jsonb, text) SET SCHEMA private';
    EXECUTE 'ALTER FUNCTION private.resolve_prescription_item_correction(uuid, text, jsonb, text) RENAME TO resolve_prescription_item_correction_unchecked';
  END IF;

  IF to_regprocedure('private.create_prescription_atomic_unchecked(uuid,boolean,jsonb)') IS NULL THEN
    IF to_regprocedure('public.create_prescription_atomic(uuid,boolean,jsonb)') IS NULL THEN
      RAISE EXCEPTION 'Phase 61 prescription RPC is missing; refusing an incomplete role-boundary upgrade';
    END IF;
    EXECUTE 'ALTER FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb) SET SCHEMA private';
    EXECUTE 'ALTER FUNCTION private.create_prescription_atomic(uuid, boolean, jsonb) RENAME TO create_prescription_atomic_unchecked';
  END IF;
END;
$phase61b_move$;

REVOKE ALL ON FUNCTION private.request_prescription_item_correction_unchecked(uuid, text)
  FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.resolve_prescription_item_correction_unchecked(uuid, text, jsonb, text)
  FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.create_prescription_atomic_unchecked(uuid, boolean, jsonb)
  FROM PUBLIC, anon, authenticated, service_role, authenticator;

CREATE OR REPLACE FUNCTION public.request_prescription_item_correction(
  p_prescription_item_id uuid,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.app_has_role_permission(
    ARRAY['pharmacist','legacy_pharmacist'],
    'pharmacy.correction.request'
  ) THEN
    RAISE EXCEPTION 'prescription_correction_request_permission_denied'
      USING ERRCODE = '42501';
  END IF;

  RETURN private.request_prescription_item_correction_unchecked(
    p_prescription_item_id,
    p_reason
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.request_prescription_item_correction(uuid, text)
  FROM PUBLIC, anon, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.request_prescription_item_correction(uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.resolve_prescription_item_correction(
  p_request_id uuid,
  p_action text,
  p_replacement jsonb DEFAULT NULL,
  p_reason text DEFAULT NULL
)
RETURNS TABLE (
  request_id uuid,
  corrected_item_id uuid,
  replacement_prescription_id uuid,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.app_has_role_permission(
    ARRAY['doctor','legacy_gp','legacy_specialist','legacy_dentist'],
    'prescriptions.correction.resolve'
  ) THEN
    RAISE EXCEPTION 'prescription_correction_resolve_permission_denied'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT *
  FROM private.resolve_prescription_item_correction_unchecked(
    p_request_id,
    p_action,
    p_replacement,
    p_reason
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.resolve_prescription_item_correction(uuid, text, jsonb, text)
  FROM PUBLIC, anon, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.resolve_prescription_item_correction(uuid, text, jsonb, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.create_prescription_atomic(
  p_visit_id uuid,
  p_is_external boolean,
  p_items jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.app_has_role_permission(
    ARRAY['doctor','legacy_gp','legacy_specialist','legacy_dentist'],
    'prescriptions.create'
  ) THEN
    RAISE EXCEPTION 'not authorised to create prescriptions'
      USING ERRCODE = '42501';
  END IF;

  RETURN private.create_prescription_atomic_unchecked(
    p_visit_id,
    p_is_external,
    p_items
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb)
  FROM PUBLIC, anon, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb)
  TO authenticated;

COMMIT;
