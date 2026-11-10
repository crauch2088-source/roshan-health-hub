-- Phase 61: auditable pharmacist-to-prescriber correction requests for unlinked internal prescription items.
-- Candidate only. No hosted QA/Production DDL or business-data writes are authorized by this migration.
BEGIN;

INSERT INTO public.permissions (code, name, module, action)
VALUES
  ('pharmacy.correction.request', 'Request prescription item correction', 'pharmacy', 'correction_request'),
  ('prescriptions.correction.resolve', 'Resolve prescription item correction', 'prescriptions', 'correction_resolve')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.permissions (code, name, module, action)
VALUES ('prescriptions.create', 'Create clinical prescriptions', 'prescriptions', 'create')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code = 'pharmacy.correction.request'
WHERE r.code = 'pharmacist'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code = 'prescriptions.correction.resolve'
WHERE r.code = 'doctor'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code = 'prescriptions.create'
WHERE r.code = 'doctor'
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.prescription_item_correction_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id uuid NOT NULL REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
  prescription_item_id uuid NOT NULL REFERENCES public.prescription_items(id) ON DELETE RESTRICT,
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  visit_id uuid NOT NULL REFERENCES public.visits(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE RESTRICT,
  item_snapshot jsonb NOT NULL CHECK (jsonb_typeof(item_snapshot) = 'object'),
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 10 AND 1000),
  requested_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'resolved', 'rejected')),
  resolved_by uuid REFERENCES public.users(id) ON DELETE RESTRICT,
  resolved_at timestamptz,
  disposition text
    CHECK (disposition IS NULL OR disposition IN ('replace_item', 'reject', 'cancel_and_reissue')),
  resolution_note text,
  corrected_item_id uuid REFERENCES public.prescription_items(id) ON DELETE RESTRICT,
  replacement_prescription_id uuid REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT prescription_item_correction_request_state_check CHECK (
    (
      status = 'pending'
      AND resolved_by IS NULL
      AND resolved_at IS NULL
      AND disposition IS NULL
      AND resolution_note IS NULL
      AND corrected_item_id IS NULL
      AND replacement_prescription_id IS NULL
    )
    OR (
      status = 'rejected'
      AND resolved_by IS NOT NULL
      AND resolved_at IS NOT NULL
      AND disposition = 'reject'
      AND resolution_note IS NOT NULL
      AND corrected_item_id IS NULL
      AND replacement_prescription_id IS NULL
    )
    OR (
      status = 'resolved'
      AND resolved_by IS NOT NULL
      AND resolved_at IS NOT NULL
      AND (
        (disposition = 'replace_item' AND corrected_item_id IS NOT NULL AND replacement_prescription_id IS NULL)
        OR
        (disposition = 'cancel_and_reissue' AND corrected_item_id IS NULL AND replacement_prescription_id IS NOT NULL)
      )
    )
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS prescription_item_correction_one_pending_per_item
ON public.prescription_item_correction_requests (prescription_item_id)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS prescription_item_correction_branch_status_requested
ON public.prescription_item_correction_requests (branch_id, status, requested_at DESC);

CREATE INDEX IF NOT EXISTS prescription_item_correction_prescription_requested
ON public.prescription_item_correction_requests (prescription_id, requested_at DESC);

CREATE TABLE IF NOT EXISTS public.prescription_item_correction_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.prescription_item_correction_requests(id) ON DELETE RESTRICT,
  event_type text NOT NULL
    CHECK (event_type IN ('requested', 'item_replaced', 'rejected', 'cancelled_and_reissued')),
  actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object')
);

CREATE INDEX IF NOT EXISTS prescription_item_correction_events_request_time
ON public.prescription_item_correction_events (request_id, occurred_at, id);

ALTER TABLE public.prescription_item_correction_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_item_correction_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_item_correction_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_item_correction_events FORCE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION private.app_can_resolve_prescription_item_correction(
  _prescription_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.prescriptions AS p
    JOIN public.visits AS v
      ON v.id = p.visit_id
     AND v.patient_id = p.patient_id
    WHERE p.id = _prescription_id
      AND private.app_has_prescription_branch_access(p.id)
      AND (
        p.prescribed_by = private.current_app_user_id()
        OR p.doctor_id = private.current_app_user_id()
        OR v.doctor_id = private.current_app_user_id()
      )
  )
$function$;

REVOKE ALL ON FUNCTION private.app_can_resolve_prescription_item_correction(uuid)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION private.app_can_resolve_prescription_item_correction(uuid)
  TO authenticated;

DROP POLICY IF EXISTS prescription_item_correction_requests_select
  ON public.prescription_item_correction_requests;
CREATE POLICY prescription_item_correction_requests_select
ON public.prescription_item_correction_requests
FOR SELECT TO authenticated
USING (
  (SELECT public.is_super_admin())
  OR (
    (SELECT public.app_has_perm('pharmacy.correction.request'))
    AND (SELECT private.app_has_prescription_branch_access(prescription_id))
  )
  OR (
    (SELECT public.app_has_perm('prescriptions.correction.resolve'))
    AND (SELECT private.app_can_resolve_prescription_item_correction(prescription_id))
  )
);

DROP POLICY IF EXISTS prescription_item_correction_events_select
  ON public.prescription_item_correction_events;
CREATE POLICY prescription_item_correction_events_select
ON public.prescription_item_correction_events
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.prescription_item_correction_requests AS r
    WHERE r.id = prescription_item_correction_events.request_id
  )
);

REVOKE ALL ON TABLE public.prescription_item_correction_requests
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE public.prescription_item_correction_events
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.prescription_item_correction_requests,
  public.prescription_item_correction_events TO authenticated;

CREATE OR REPLACE FUNCTION private.guard_prescription_item_correction_request_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.prescription_id IS DISTINCT FROM OLD.prescription_id
     OR NEW.prescription_item_id IS DISTINCT FROM OLD.prescription_item_id
     OR NEW.patient_id IS DISTINCT FROM OLD.patient_id
     OR NEW.visit_id IS DISTINCT FROM OLD.visit_id
     OR NEW.branch_id IS DISTINCT FROM OLD.branch_id
     OR NEW.item_snapshot IS DISTINCT FROM OLD.item_snapshot
     OR NEW.reason IS DISTINCT FROM OLD.reason
     OR NEW.requested_by IS DISTINCT FROM OLD.requested_by
     OR NEW.requested_at IS DISTINCT FROM OLD.requested_at THEN
    RAISE EXCEPTION 'prescription correction request origin is immutable'
      USING ERRCODE = '55000';
  END IF;

  IF OLD.status <> 'pending' OR NEW.status NOT IN ('resolved', 'rejected') THEN
    RAISE EXCEPTION 'prescription correction request can transition only once from pending'
      USING ERRCODE = '55000';
  END IF;

  IF NEW.resolved_by IS NULL OR NEW.resolved_at IS NULL OR NEW.disposition IS NULL THEN
    RAISE EXCEPTION 'prescription correction resolution actor, time and disposition are required'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.guard_prescription_item_correction_request_update()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.reject_prescription_item_correction_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'prescription correction history is immutable'
    USING ERRCODE = '55000';
END;
$function$;
REVOKE ALL ON FUNCTION private.reject_prescription_item_correction_mutation()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS prescription_item_correction_requests_guard_update
  ON public.prescription_item_correction_requests;
CREATE TRIGGER prescription_item_correction_requests_guard_update
BEFORE UPDATE ON public.prescription_item_correction_requests
FOR EACH ROW EXECUTE FUNCTION private.guard_prescription_item_correction_request_update();

DROP TRIGGER IF EXISTS prescription_item_correction_requests_no_delete
  ON public.prescription_item_correction_requests;
CREATE TRIGGER prescription_item_correction_requests_no_delete
BEFORE DELETE ON public.prescription_item_correction_requests
FOR EACH ROW EXECUTE FUNCTION private.reject_prescription_item_correction_mutation();

DROP TRIGGER IF EXISTS prescription_item_correction_requests_no_truncate
  ON public.prescription_item_correction_requests;
CREATE TRIGGER prescription_item_correction_requests_no_truncate
BEFORE TRUNCATE ON public.prescription_item_correction_requests
FOR EACH STATEMENT EXECUTE FUNCTION private.reject_prescription_item_correction_mutation();

DROP TRIGGER IF EXISTS prescription_item_correction_events_no_update_delete
  ON public.prescription_item_correction_events;
CREATE TRIGGER prescription_item_correction_events_no_update_delete
BEFORE UPDATE OR DELETE ON public.prescription_item_correction_events
FOR EACH ROW EXECUTE FUNCTION private.reject_prescription_item_correction_mutation();

DROP TRIGGER IF EXISTS prescription_item_correction_events_no_truncate
  ON public.prescription_item_correction_events;
CREATE TRIGGER prescription_item_correction_events_no_truncate
BEFORE TRUNCATE ON public.prescription_item_correction_events
FOR EACH STATEMENT EXECUTE FUNCTION private.reject_prescription_item_correction_mutation();

CREATE OR REPLACE FUNCTION public.request_prescription_item_correction(
  p_prescription_item_id uuid,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_prescription_id uuid;
  v_parent record;
  v_item public.prescription_items%ROWTYPE;
  v_user_branch uuid;
  v_responsible_exists boolean;
  v_request_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('pharmacy.correction.request') THEN
    RAISE EXCEPTION 'prescription_correction_request_permission_denied'
      USING ERRCODE = '42501';
  END IF;

  IF p_prescription_item_id IS NULL
     OR char_length(btrim(COALESCE(p_reason, ''))) NOT BETWEEN 10 AND 1000 THEN
    RAISE EXCEPTION 'prescription_correction_reason_required'
      USING ERRCODE = '22023';
  END IF;

  SELECT pi.prescription_id
    INTO v_prescription_id
  FROM public.prescription_items AS pi
  WHERE pi.id = p_prescription_item_id;

  IF NOT FOUND OR v_prescription_id IS NULL THEN
    RAISE EXCEPTION 'prescription_item_not_found'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT
    p.id,
    p.patient_id,
    p.visit_id,
    p.prescribed_by,
    p.doctor_id,
    p.prescription_type,
    p.is_external,
    p.status,
    p.deleted_at,
    p.dispensed_at,
    p.dispensed_by,
    p.branch_id AS prescription_branch_id,
    v.branch_id AS visit_branch_id,
    v.doctor_id AS visit_doctor_id,
    v.deleted_at AS visit_deleted_at,
    pt.branch_id AS patient_branch_id,
    pt.deleted_at AS patient_deleted_at,
    pt.active AS patient_active
  INTO v_parent
  FROM public.prescriptions AS p
  JOIN public.visits AS v ON v.id = p.visit_id AND v.patient_id = p.patient_id
  JOIN public.patients AS pt ON pt.id = p.patient_id
  WHERE p.id = v_prescription_id
  FOR UPDATE OF p, v, pt;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_parent_context_not_found'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT pi.*
    INTO v_item
  FROM public.prescription_items AS pi
  WHERE pi.id = p_prescription_item_id
    AND pi.prescription_id = v_parent.id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_item_parent_mismatch'
      USING ERRCODE = '23514';
  END IF;

  IF v_parent.status IS DISTINCT FROM 'pending'
     OR v_parent.prescription_type IS DISTINCT FROM 'internal'
     OR COALESCE(v_parent.is_external, false)
     OR v_parent.deleted_at IS NOT NULL
     OR v_parent.dispensed_at IS NOT NULL
     OR v_parent.dispensed_by IS NOT NULL
     OR v_parent.visit_deleted_at IS NOT NULL
     OR v_parent.patient_deleted_at IS NOT NULL
     OR COALESCE(v_parent.patient_active, true) IS NOT TRUE THEN
    RAISE EXCEPTION 'prescription_not_eligible_for_correction'
      USING ERRCODE = '23514';
  END IF;

  IF v_parent.visit_branch_id IS NULL
     OR (v_parent.prescription_branch_id IS NOT NULL
         AND v_parent.prescription_branch_id IS DISTINCT FROM v_parent.visit_branch_id)
     OR (v_parent.patient_branch_id IS NOT NULL
         AND v_parent.patient_branch_id IS DISTINCT FROM v_parent.visit_branch_id) THEN
    RAISE EXCEPTION 'prescription_correction_branch_context_invalid'
      USING ERRCODE = '42501';
  END IF;

  SELECT u.branch_id
    INTO v_user_branch
  FROM public.users AS u
  WHERE u.id = v_uid
    AND COALESCE(u.active, true) IS TRUE
    AND u.deleted_at IS NULL;

  IF NOT public.is_super_admin()
     AND v_user_branch IS DISTINCT FROM v_parent.visit_branch_id THEN
    RAISE EXCEPTION 'cross_branch_prescription_correction_request_denied'
      USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE u.id IN (v_parent.prescribed_by, v_parent.doctor_id, v_parent.visit_doctor_id)
      AND COALESCE(u.active, true) IS TRUE
      AND u.deleted_at IS NULL
      AND u.branch_id = v_parent.visit_branch_id
  ) INTO v_responsible_exists;

  IF NOT v_responsible_exists THEN
    RAISE EXCEPTION 'responsible_prescriber_not_found_in_branch'
      USING ERRCODE = '23514';
  END IF;

  IF v_item.deleted_at IS NOT NULL
     OR v_item.medicine_id IS NOT NULL
     OR COALESCE(v_item.is_dispensed, false)
     OR COALESCE(v_item.dispensed_quantity, 0) <> 0 THEN
    RAISE EXCEPTION 'prescription_item_not_eligible_for_correction'
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.prescription_item_correction_requests (
    prescription_id, prescription_item_id, patient_id, visit_id, branch_id,
    item_snapshot, reason, requested_by
  )
  VALUES (
    v_parent.id, v_item.id, v_parent.patient_id, v_parent.visit_id,
    v_parent.visit_branch_id, to_jsonb(v_item), btrim(p_reason), v_uid
  )
  ON CONFLICT (prescription_item_id) WHERE status = 'pending'
  DO NOTHING
  RETURNING id INTO v_request_id;

  IF v_request_id IS NULL THEN
    SELECT r.id
      INTO v_request_id
    FROM public.prescription_item_correction_requests AS r
    WHERE r.prescription_item_id = p_prescription_item_id
      AND r.status = 'pending';
    RETURN v_request_id;
  END IF;

  INSERT INTO public.prescription_item_correction_events (
    request_id, event_type, actor_id, payload
  )
  VALUES (
    v_request_id, 'requested', v_uid,
    jsonb_build_object(
      'item_snapshot', to_jsonb(v_item),
      'reason', btrim(p_reason),
      'prescription_id', v_parent.id,
      'visit_id', v_parent.visit_id,
      'patient_id', v_parent.patient_id,
      'branch_id', v_parent.visit_branch_id
    )
  );

  RETURN v_request_id;
END;
$function$;

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
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_request public.prescription_item_correction_requests%ROWTYPE;
  v_prescription_id uuid;
  v_prescription_item_id uuid;
  v_parent record;
  v_item public.prescription_items%ROWTYPE;
  v_user_branch uuid;
  v_medicine_id uuid;
  v_medicine_name text;
  v_generic_name text;
  v_unit_price numeric;
  v_quantity numeric;
  v_dose text;
  v_frequency text;
  v_duration text;
  v_dosage_form text;
  v_route text;
  v_instructions text;
  v_new_item_id uuid;
  v_new_prescription_id uuid;
  v_normalized_items jsonb := '[]'::jsonb;
  v_payload_item jsonb;
  v_status text;
  v_item_count integer := 0;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('prescriptions.correction.resolve') THEN
    RAISE EXCEPTION 'prescription_correction_resolve_permission_denied'
      USING ERRCODE = '42501';
  END IF;

  IF p_request_id IS NULL OR p_action IS NULL OR p_action NOT IN ('replace_item', 'reject', 'cancel_and_reissue') THEN
    RAISE EXCEPTION 'prescription_correction_action_invalid'
      USING ERRCODE = '22023';
  END IF;

  SELECT r.prescription_id, r.prescription_item_id
    INTO v_prescription_id, v_prescription_item_id
  FROM public.prescription_item_correction_requests AS r
  WHERE r.id = p_request_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_correction_request_not_found'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT
    p.id,
    p.patient_id,
    p.visit_id,
    p.prescribed_by,
    p.doctor_id,
    p.prescription_type,
    p.is_external,
    p.status,
    p.deleted_at,
    p.dispensed_at,
    p.dispensed_by,
    p.branch_id AS prescription_branch_id,
    v.branch_id AS visit_branch_id,
    v.doctor_id AS visit_doctor_id,
    v.deleted_at AS visit_deleted_at,
    pt.branch_id AS patient_branch_id,
    pt.deleted_at AS patient_deleted_at,
    pt.active AS patient_active
  INTO v_parent
  FROM public.prescriptions AS p
  JOIN public.visits AS v ON v.id = p.visit_id AND v.patient_id = p.patient_id
  JOIN public.patients AS pt ON pt.id = p.patient_id
  WHERE p.id = v_prescription_id
  FOR UPDATE OF p, v, pt;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_parent_context_not_found'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT pi.*
    INTO v_item
  FROM public.prescription_items AS pi
  WHERE pi.id = v_prescription_item_id
    AND pi.prescription_id = v_parent.id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_item_parent_mismatch'
      USING ERRCODE = '23514';
  END IF;

  SELECT r.*
    INTO v_request
  FROM public.prescription_item_correction_requests AS r
  WHERE r.id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_correction_request_not_found'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_request.status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'prescription_correction_request_already_resolved'
      USING ERRCODE = '40001';
  END IF;

  IF v_request.prescription_id IS DISTINCT FROM v_prescription_id
     OR v_request.prescription_item_id IS DISTINCT FROM v_prescription_item_id THEN
    RAISE EXCEPTION 'prescription_correction_request_identity_changed'
      USING ERRCODE = '40001';
  END IF;

  IF v_parent.status IS DISTINCT FROM 'pending'
     OR v_parent.prescription_type IS DISTINCT FROM 'internal'
     OR COALESCE(v_parent.is_external, false)
     OR v_parent.deleted_at IS NOT NULL
     OR v_parent.dispensed_at IS NOT NULL
     OR v_parent.dispensed_by IS NOT NULL
     OR v_parent.visit_deleted_at IS NOT NULL
     OR v_parent.patient_deleted_at IS NOT NULL
     OR COALESCE(v_parent.patient_active, true) IS NOT TRUE
     OR v_item.deleted_at IS NOT NULL
     OR v_item.medicine_id IS NOT NULL
     OR COALESCE(v_item.is_dispensed, false)
     OR COALESCE(v_item.dispensed_quantity, 0) <> 0
     OR to_jsonb(v_item) IS DISTINCT FROM v_request.item_snapshot THEN
    RAISE EXCEPTION 'prescription_correction_request_stale_or_ineligible'
      USING ERRCODE = '40001';
  END IF;

  IF v_parent.visit_branch_id IS NULL
     OR v_request.branch_id IS DISTINCT FROM v_parent.visit_branch_id
     OR v_request.patient_id IS DISTINCT FROM v_parent.patient_id
     OR v_request.visit_id IS DISTINCT FROM v_parent.visit_id
     OR (v_parent.prescription_branch_id IS NOT NULL
         AND v_parent.prescription_branch_id IS DISTINCT FROM v_parent.visit_branch_id)
     OR (v_parent.patient_branch_id IS NOT NULL
         AND v_parent.patient_branch_id IS DISTINCT FROM v_parent.visit_branch_id) THEN
    RAISE EXCEPTION 'prescription_correction_branch_context_invalid'
      USING ERRCODE = '42501';
  END IF;

  SELECT u.branch_id
    INTO v_user_branch
  FROM public.users AS u
  WHERE u.id = v_uid
    AND COALESCE(u.active, true) IS TRUE
    AND u.deleted_at IS NULL;

  IF NOT public.is_super_admin() THEN
    IF v_user_branch IS DISTINCT FROM v_parent.visit_branch_id
       OR (
         v_uid IS DISTINCT FROM v_parent.prescribed_by
         AND v_uid IS DISTINCT FROM v_parent.doctor_id
         AND v_uid IS DISTINCT FROM v_parent.visit_doctor_id
       ) THEN
      RAISE EXCEPTION 'prescription_correction_responsible_doctor_or_branch_required'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF p_action = 'reject' THEN
    IF char_length(btrim(COALESCE(p_reason, ''))) NOT BETWEEN 10 AND 1000
       OR p_replacement IS NOT NULL THEN
      RAISE EXCEPTION 'prescription_correction_rejection_reason_required'
        USING ERRCODE = '22023';
    END IF;

    UPDATE public.prescription_item_correction_requests
    SET status = 'rejected',
        resolved_by = v_uid,
        resolved_at = clock_timestamp(),
        disposition = 'reject',
        resolution_note = btrim(p_reason),
        updated_at = clock_timestamp()
    WHERE id = p_request_id;

    INSERT INTO public.prescription_item_correction_events (
      request_id, event_type, actor_id, payload
    )
    VALUES (
      p_request_id, 'rejected', v_uid,
      jsonb_build_object(
        'item_snapshot', v_request.item_snapshot,
        'reason', btrim(p_reason)
      )
    );

    v_status := 'rejected';

  ELSIF p_action = 'replace_item' THEN
    IF jsonb_typeof(p_replacement) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'prescription_correction_replacement_object_required'
        USING ERRCODE = '22023';
    END IF;

    v_medicine_id := NULLIF(p_replacement->>'medicine_id', '')::uuid;
    v_dose := NULLIF(btrim(COALESCE(p_replacement->>'dose', '')), '');
    v_frequency := NULLIF(btrim(COALESCE(p_replacement->>'frequency', '')), '');
    v_duration := NULLIF(btrim(COALESCE(p_replacement->>'duration', '')), '');
    v_dosage_form := NULLIF(btrim(COALESCE(p_replacement->>'dosage_form', '')), '');
    v_route := NULLIF(btrim(COALESCE(p_replacement->>'route', '')), '');
    v_instructions := NULLIF(btrim(COALESCE(p_replacement->>'instructions', '')), '');

    IF v_medicine_id IS NULL
       OR v_dose IS NULL
       OR v_frequency IS NULL
       OR v_duration IS NULL
       OR v_dosage_form IS NULL
       OR v_route IS NULL
       OR jsonb_typeof(p_replacement->'quantity') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'prescription_correction_complete_regimen_required'
        USING ERRCODE = '22023';
    END IF;

    v_quantity := (p_replacement->>'quantity')::numeric;
    IF v_quantity::text IN ('NaN', 'Infinity', '-Infinity')
       OR v_quantity <= 0
       OR v_quantity <> trunc(v_quantity)
       OR v_quantity > 1000000 THEN
      RAISE EXCEPTION 'prescription quantity must be a finite positive whole number'
        USING ERRCODE = '22023';
    END IF;

    SELECT
      m.name,
      m.generic_name,
      m.selling_price
    INTO v_medicine_name, v_generic_name, v_unit_price
    FROM public.medicines AS m
    WHERE m.id = v_medicine_id
      AND m.deleted_at IS NULL
      AND m.active IS TRUE
      AND m.is_active IS TRUE
    FOR SHARE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'active_catalog_medicine_not_found'
        USING ERRCODE = 'P0002';
    END IF;

    v_medicine_name := COALESCE(NULLIF(btrim(v_medicine_name), ''), NULLIF(btrim(v_generic_name), ''));
    IF v_medicine_name IS NULL THEN
      RAISE EXCEPTION 'catalog_medicine_has_no_usable_name'
        USING ERRCODE = '23514';
    END IF;

    IF v_unit_price IS NULL OR v_unit_price::text IN ('NaN', 'Infinity', '-Infinity') OR v_unit_price < 0 THEN
      RAISE EXCEPTION 'catalog_medicine_price_invalid'
        USING ERRCODE = '23514';
    END IF;

    UPDATE public.prescription_items
    SET deleted_at = clock_timestamp(),
        deleted_by = v_uid,
        updated_by = v_uid,
        updated_at = clock_timestamp()
    WHERE id = v_item.id
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'prescription_item_changed_before_replacement'
        USING ERRCODE = '40001';
    END IF;

    INSERT INTO public.prescription_items (
      prescription_id, medicine_id, medication_name, dose, dosage, frequency,
      duration, quantity, instructions, dosage_form, route, unit_price,
      created_by, updated_by, is_dispensed, dispensed_quantity
    )
    VALUES (
      v_item.prescription_id, v_medicine_id, v_medicine_name, v_dose, v_dose,
      v_frequency, v_duration, v_quantity, v_instructions, v_dosage_form,
      v_route, v_unit_price, v_uid, v_uid, false, 0
    )
    RETURNING id INTO v_new_item_id;

    UPDATE public.prescription_item_correction_requests
    SET status = 'resolved',
        resolved_by = v_uid,
        resolved_at = clock_timestamp(),
        disposition = 'replace_item',
        resolution_note = NULLIF(btrim(COALESCE(p_reason, '')), ''),
        corrected_item_id = v_new_item_id,
        updated_at = clock_timestamp()
    WHERE id = p_request_id;

    INSERT INTO public.prescription_item_correction_events (
      request_id, event_type, actor_id, payload
    )
    SELECT
      p_request_id, 'item_replaced', v_uid,
      jsonb_build_object(
        'before', v_request.item_snapshot,
        'after', to_jsonb(pi),
        'note', NULLIF(btrim(COALESCE(p_reason, '')), '')
      )
    FROM public.prescription_items AS pi
    WHERE pi.id = v_new_item_id;

    v_status := 'resolved';

  ELSE
    IF jsonb_typeof(p_replacement) IS DISTINCT FROM 'array' THEN
      RAISE EXCEPTION 'complete_replacement_order_required'
        USING ERRCODE = '22023';
    END IF;
    IF jsonb_array_length(p_replacement) = 0 THEN
      RAISE EXCEPTION 'complete_replacement_order_required'
        USING ERRCODE = '22023';
    END IF;

    IF NOT (public.is_super_admin() OR public.app_has_perm('prescriptions.create')) THEN
      RAISE EXCEPTION 'prescription_create_permission_required_for_reissue'
        USING ERRCODE = '42501';
    END IF;

    FOR v_payload_item IN
      SELECT value FROM jsonb_array_elements(p_replacement) AS x(value)
    LOOP
      IF jsonb_typeof(v_payload_item) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'each replacement prescription item must be an object'
          USING ERRCODE = '22023';
      END IF;

      v_medicine_id := NULLIF(v_payload_item->>'medicine_id', '')::uuid;
      v_dose := NULLIF(btrim(COALESCE(v_payload_item->>'dose', '')), '');
      v_frequency := NULLIF(btrim(COALESCE(v_payload_item->>'frequency', '')), '');
      v_duration := NULLIF(btrim(COALESCE(v_payload_item->>'duration', '')), '');
      v_dosage_form := NULLIF(btrim(COALESCE(v_payload_item->>'dosage_form', '')), '');
      v_route := NULLIF(btrim(COALESCE(v_payload_item->>'route', '')), '');
      v_instructions := NULLIF(btrim(COALESCE(v_payload_item->>'instructions', '')), '');

      IF v_medicine_id IS NULL
         OR v_dose IS NULL
         OR v_frequency IS NULL
         OR v_duration IS NULL
         OR v_dosage_form IS NULL
         OR v_route IS NULL
         OR jsonb_typeof(v_payload_item->'quantity') IS DISTINCT FROM 'number' THEN
        RAISE EXCEPTION 'every replacement item must be catalogue-linked with a complete regimen'
          USING ERRCODE = '22023';
      END IF;

      v_quantity := (v_payload_item->>'quantity')::numeric;
      IF v_quantity::text IN ('NaN', 'Infinity', '-Infinity')
         OR v_quantity <= 0
         OR v_quantity <> trunc(v_quantity)
         OR v_quantity > 1000000 THEN
        RAISE EXCEPTION 'replacement quantity must be a finite positive whole number'
          USING ERRCODE = '22023';
      END IF;

      SELECT
        COALESCE(NULLIF(btrim(m.name), ''), NULLIF(btrim(m.generic_name), '')),
        m.selling_price
      INTO v_medicine_name, v_unit_price
      FROM public.medicines AS m
      WHERE m.id = v_medicine_id
        AND m.deleted_at IS NULL
        AND m.active IS TRUE
        AND m.is_active IS TRUE
      FOR SHARE;

      IF NOT FOUND OR v_medicine_name IS NULL THEN
        RAISE EXCEPTION 'replacement_catalog_medicine_not_found_or_unusable'
          USING ERRCODE = 'P0002';
      END IF;

      IF v_unit_price IS NULL OR v_unit_price::text IN ('NaN', 'Infinity', '-Infinity') OR v_unit_price < 0 THEN
        RAISE EXCEPTION 'replacement_catalog_medicine_price_invalid'
          USING ERRCODE = '23514';
      END IF;

      v_normalized_items := v_normalized_items || jsonb_build_array(
        jsonb_build_object(
          'medicine_id', v_medicine_id,
          'medication_name', v_medicine_name,
          'dose', v_dose,
          'frequency', v_frequency,
          'duration', v_duration,
          'quantity', v_quantity,
          'instructions', v_instructions,
          'dosage_form', v_dosage_form,
          'route', v_route
        )
      );
      v_item_count := v_item_count + 1;
    END LOOP;

    IF v_item_count = 0 THEN
      RAISE EXCEPTION 'complete_replacement_order_required'
        USING ERRCODE = '22023';
    END IF;

    v_new_prescription_id := public.create_prescription_atomic(
      v_parent.visit_id,
      false,
      v_normalized_items
    );

    UPDATE public.prescriptions AS original_prescription
    SET status = 'cancelled',
        updated_by = v_uid,
        updated_at = clock_timestamp()
    WHERE original_prescription.id = v_parent.id
      AND original_prescription.status = 'pending'
      AND original_prescription.deleted_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'original_prescription_changed_before_reissue'
        USING ERRCODE = '40001';
    END IF;

    UPDATE public.prescription_item_correction_requests
    SET status = 'resolved',
        resolved_by = v_uid,
        resolved_at = clock_timestamp(),
        disposition = 'cancel_and_reissue',
        resolution_note = NULLIF(btrim(COALESCE(p_reason, '')), ''),
        replacement_prescription_id = v_new_prescription_id,
        updated_at = clock_timestamp()
    WHERE id = p_request_id;

    INSERT INTO public.prescription_item_correction_events (
      request_id, event_type, actor_id, payload
    )
    VALUES (
      p_request_id, 'cancelled_and_reissued', v_uid,
      jsonb_build_object(
        'original_prescription_id', v_parent.id,
        'replacement_prescription_id', v_new_prescription_id,
        'original_item_snapshot', v_request.item_snapshot,
        'replacement_items', v_normalized_items,
        'note', NULLIF(btrim(COALESCE(p_reason, '')), '')
      )
    );

    v_status := 'resolved';
  END IF;

  RETURN QUERY
  SELECT p_request_id, v_new_item_id, v_new_prescription_id, v_status;
END;
$function$;

REVOKE ALL ON FUNCTION public.request_prescription_item_correction(uuid, text)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.request_prescription_item_correction(uuid, text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.resolve_prescription_item_correction(uuid, text, jsonb, text)
  FROM PUBLIC, anon, service_role;
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
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_branch uuid;
  v_visit_patient uuid;
  v_visit_branch uuid;
  v_rx_id uuid;
  v_item jsonb;
  v_medicine_id uuid;
  v_medicine_name text;
  v_catalog_name text;
  v_generic_name text;
  v_unit_price numeric;
  v_quantity numeric;
  v_item_count integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required' USING ERRCODE = '42501';
  END IF;

  IF p_is_external IS NULL THEN
    RAISE EXCEPTION 'prescription type must be explicit' USING ERRCODE = '22023';
  END IF;

  IF NOT (public.is_super_admin() OR public.app_has_perm('prescriptions.create')) THEN
    RAISE EXCEPTION 'not authorised to create prescriptions' USING ERRCODE = '42501';
  END IF;

  IF p_visit_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'visit and prescription item array are required';
  END IF;
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'prescription must contain at least one item';
  END IF;

  SELECT v.patient_id, v.branch_id
    INTO v_visit_patient, v_visit_branch
    FROM public.visits v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL;
  IF v_visit_patient IS NULL THEN
    RAISE EXCEPTION 'active visit not found';
  END IF;

  SELECT u.branch_id INTO v_branch
    FROM public.users u
   WHERE u.id = v_uid AND u.deleted_at IS NULL;
  IF NOT public.is_super_admin()
     AND (v_branch IS NULL OR v_visit_branch IS DISTINCT FROM v_branch) THEN
    RAISE EXCEPTION 'cross-branch prescription access denied' USING ERRCODE = '42501';
  END IF;

  -- Validate all payloads before inserting the parent record.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each prescription item must be an object';
    END IF;
    IF jsonb_typeof(v_item->'quantity') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'prescription quantity must be a JSON number';
    END IF;
    v_quantity := (v_item->>'quantity')::numeric;
    IF v_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR v_quantity <= 0 OR v_quantity <> trunc(v_quantity) THEN
      RAISE EXCEPTION 'prescription quantity must be a finite positive whole number';
    END IF;
    IF btrim(COALESCE(v_item->>'medication_name', '')) = '' THEN
      RAISE EXCEPTION 'medication name is required';
    END IF;

    v_medicine_id := NULLIF(v_item->>'medicine_id', '')::uuid;
    IF v_medicine_id IS NOT NULL THEN
      SELECT m.name, m.generic_name, COALESCE(m.selling_price, 0)
        INTO v_catalog_name, v_generic_name, v_unit_price
        FROM public.medicines m
       WHERE m.id = v_medicine_id
         AND m.deleted_at IS NULL
         AND m.active IS TRUE
         AND m.is_active IS TRUE
       FOR SHARE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'active catalog medicine not found';
      END IF;
      IF v_unit_price::text IN ('NaN', 'Infinity', '-Infinity') OR v_unit_price < 0 THEN
        RAISE EXCEPTION 'catalog medicine price must be finite and non-negative';
      END IF;
      IF btrim(COALESCE(v_catalog_name, '')) = '' AND btrim(COALESCE(v_generic_name, '')) = '' THEN
        RAISE EXCEPTION 'catalog medicine has no usable name';
      END IF;
    END IF;
    v_item_count := v_item_count + 1;
  END LOOP;

  INSERT INTO public.prescriptions (
    patient_id, visit_id, prescribed_by, doctor_id, prescription_type,
    is_external, status, created_by
  )
  VALUES (
    v_visit_patient, p_visit_id, v_uid, v_uid,
    CASE WHEN p_is_external THEN 'external' ELSE 'internal' END,
    COALESCE(p_is_external, false), 'pending', v_uid
  )
  RETURNING id INTO v_rx_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    v_medicine_id := NULLIF(v_item->>'medicine_id', '')::uuid;
    v_unit_price := 0;
    IF v_medicine_id IS NOT NULL THEN
      SELECT COALESCE(m.selling_price, 0), COALESCE(NULLIF(btrim(m.name), ''), NULLIF(btrim(m.generic_name), ''))
        INTO v_unit_price, v_medicine_name
        FROM public.medicines m
       WHERE m.id = v_medicine_id
         AND m.deleted_at IS NULL
         AND m.active IS TRUE
         AND m.is_active IS TRUE
       FOR SHARE;
    ELSE
      v_medicine_name := btrim(v_item->>'medication_name');
    END IF;

    INSERT INTO public.prescription_items (
      prescription_id, medicine_id, medication_name, dose, dosage, frequency,
      duration, quantity, instructions, dosage_form, route, unit_price, created_by, updated_by
    )
    VALUES (
      v_rx_id,
      v_medicine_id,
      v_medicine_name,
      NULLIF(btrim(COALESCE(v_item->>'dose', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'dose', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'frequency', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'duration', '')), ''),
      (v_item->>'quantity')::numeric,
      NULLIF(btrim(COALESCE(v_item->>'instructions', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'dosage_form', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'route', '')), ''),
      v_unit_price,
      v_uid,
      v_uid
    );
  END LOOP;

  RETURN v_rx_id;
END;
$function$;


REVOKE ALL ON FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb)
  TO authenticated;

COMMIT;
