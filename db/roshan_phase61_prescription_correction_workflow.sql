-- Phase 61: auditable pharmacist-to-prescriber correction workflow.
-- Forward-only; no stock, invoice, payment or existing prescription data is backfilled.
BEGIN;

CREATE TABLE public.prescription_item_correction_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id uuid NOT NULL REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
  prescription_item_id uuid NOT NULL REFERENCES public.prescription_items(id) ON DELETE RESTRICT,
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
  visit_id uuid NOT NULL REFERENCES public.visits(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE RESTRICT,
  prescriber_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  visit_doctor_id uuid REFERENCES public.users(id) ON DELETE RESTRICT,
  item_snapshot jsonb NOT NULL,
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 10 AND 1000),
  requested_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  requested_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','resolved','rejected')),
  disposition text
    CHECK (disposition IS NULL OR disposition IN ('replace_item','reject','cancel_and_reissue')),
  resolution_note text,
  corrected_item_id uuid REFERENCES public.prescription_items(id) ON DELETE RESTRICT,
  replacement_prescription_id uuid REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
  resolved_by uuid REFERENCES public.users(id) ON DELETE RESTRICT,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (status = 'pending' AND disposition IS NULL AND resolved_by IS NULL AND resolved_at IS NULL)
    OR
    (status IN ('resolved','rejected') AND disposition IS NOT NULL AND resolved_by IS NOT NULL AND resolved_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX prescription_item_correction_one_pending_per_item_idx
  ON public.prescription_item_correction_requests (prescription_item_id)
  WHERE status = 'pending';

CREATE INDEX prescription_item_correction_branch_status_requested_idx
  ON public.prescription_item_correction_requests (branch_id,status,requested_at DESC);

CREATE INDEX prescription_item_correction_prescription_idx
  ON public.prescription_item_correction_requests (prescription_id,requested_at DESC);

CREATE TABLE public.prescription_item_correction_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.prescription_item_correction_requests(id) ON DELETE RESTRICT,
  event_type text NOT NULL
    CHECK (event_type IN ('requested','item_replaced','rejected','prescription_cancelled_and_reissued')),
  actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX prescription_item_correction_events_request_time_idx
  ON public.prescription_item_correction_events (request_id,occurred_at,id);

-- Narrow permissions: pharmacists may request; doctors may resolve.
INSERT INTO public.permissions (code,name,module,action)
SELECT 'pharmacy.correction.request','Request prescription item correction','pharmacy','correction_request'
WHERE NOT EXISTS (
  SELECT 1 FROM public.permissions WHERE code='pharmacy.correction.request'
);

INSERT INTO public.permissions (code,name,module,action)
SELECT 'prescriptions.correction.resolve','Resolve prescription item correction','prescriptions','correction_resolve'
WHERE NOT EXISTS (
  SELECT 1 FROM public.permissions WHERE code='prescriptions.correction.resolve'
);

INSERT INTO public.role_permissions (role_id,permission_id)
SELECT r.id,p.id
FROM public.roles r
JOIN public.permissions p ON p.code='pharmacy.correction.request'
WHERE r.code='pharmacist'
  AND NOT EXISTS (
    SELECT 1 FROM public.role_permissions rp
    WHERE rp.role_id=r.id AND rp.permission_id=p.id
  );

INSERT INTO public.role_permissions (role_id,permission_id)
SELECT r.id,p.id
FROM public.roles r
JOIN public.permissions p ON p.code='prescriptions.correction.resolve'
WHERE r.code='doctor'
  AND NOT EXISTS (
    SELECT 1 FROM public.role_permissions rp
    WHERE rp.role_id=r.id AND rp.permission_id=p.id
  );

CREATE OR REPLACE FUNCTION private.can_read_prescription_item_correction_request(_request_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.prescription_item_correction_requests r
    JOIN public.prescriptions p ON p.id=r.prescription_id
    LEFT JOIN public.visits v ON v.id=r.visit_id
    WHERE r.id=_request_id
      AND private.app_has_branch_access(r.branch_id)
      AND (
        public.app_has_perm('pharmacy.correction.request')
        OR (
          public.app_has_perm('prescriptions.correction.resolve')
          AND private.current_app_user_id() IN (
            r.prescriber_id,r.visit_doctor_id,p.prescribed_by,p.doctor_id,v.doctor_id
          )
        )
      )
  )
$function$;

REVOKE ALL ON FUNCTION private.can_read_prescription_item_correction_request(uuid)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION private.can_read_prescription_item_correction_request(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.guard_prescription_item_correction_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP='DELETE' THEN
    RAISE EXCEPTION 'prescription correction requests are retained for audit'
      USING ERRCODE='42501';
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.prescription_id IS DISTINCT FROM OLD.prescription_id
     OR NEW.prescription_item_id IS DISTINCT FROM OLD.prescription_item_id
     OR NEW.patient_id IS DISTINCT FROM OLD.patient_id
     OR NEW.visit_id IS DISTINCT FROM OLD.visit_id
     OR NEW.branch_id IS DISTINCT FROM OLD.branch_id
     OR NEW.prescriber_id IS DISTINCT FROM OLD.prescriber_id
     OR NEW.visit_doctor_id IS DISTINCT FROM OLD.visit_doctor_id
     OR NEW.item_snapshot IS DISTINCT FROM OLD.item_snapshot
     OR NEW.reason IS DISTINCT FROM OLD.reason
     OR NEW.requested_by IS DISTINCT FROM OLD.requested_by
     OR NEW.requested_at IS DISTINCT FROM OLD.requested_at THEN
    RAISE EXCEPTION 'prescription correction request identity and original evidence are immutable'
      USING ERRCODE='23514';
  END IF;

  IF OLD.status IS DISTINCT FROM 'pending'
     OR NEW.status NOT IN ('resolved','rejected')
     OR NEW.resolved_by IS NULL
     OR NEW.resolved_at IS NULL
     OR NEW.disposition IS NULL THEN
    RAISE EXCEPTION 'invalid prescription correction request state transition'
      USING ERRCODE='23514';
  END IF;

  RETURN NEW;
END
$function$;

CREATE OR REPLACE FUNCTION private.reject_prescription_item_correction_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'prescription correction events are append-only'
    USING ERRCODE='42501';
END
$function$;

REVOKE ALL ON FUNCTION private.guard_prescription_item_correction_request()
  FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.reject_prescription_item_correction_event_mutation()
  FROM PUBLIC, anon, authenticated, service_role, authenticator;

CREATE TRIGGER prescription_item_correction_request_immutable
BEFORE UPDATE OR DELETE ON public.prescription_item_correction_requests
FOR EACH ROW EXECUTE FUNCTION private.guard_prescription_item_correction_request();

CREATE TRIGGER prescription_item_correction_request_no_truncate
BEFORE TRUNCATE ON public.prescription_item_correction_requests
FOR EACH STATEMENT EXECUTE FUNCTION private.reject_prescription_item_correction_event_mutation();

CREATE TRIGGER prescription_item_correction_event_append_only
BEFORE UPDATE OR DELETE ON public.prescription_item_correction_events
FOR EACH ROW EXECUTE FUNCTION private.reject_prescription_item_correction_event_mutation();

CREATE TRIGGER prescription_item_correction_event_no_truncate
BEFORE TRUNCATE ON public.prescription_item_correction_events
FOR EACH STATEMENT EXECUTE FUNCTION private.reject_prescription_item_correction_event_mutation();

ALTER TABLE public.prescription_item_correction_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_item_correction_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_item_correction_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_item_correction_events FORCE ROW LEVEL SECURITY;

CREATE POLICY prescription_item_correction_requests_read
ON public.prescription_item_correction_requests
FOR SELECT TO authenticated
USING (private.can_read_prescription_item_correction_request(id));

CREATE POLICY prescription_item_correction_events_read
ON public.prescription_item_correction_events
FOR SELECT TO authenticated
USING (private.can_read_prescription_item_correction_request(request_id));

REVOKE ALL ON TABLE public.prescription_item_correction_requests
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE public.prescription_item_correction_events
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.prescription_item_correction_requests,
  public.prescription_item_correction_events TO authenticated;

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
  v_user_id uuid := public.current_app_user_id();
  v_prescription_id uuid;
  v_prescription public.prescriptions%ROWTYPE;
  v_item public.prescription_items%ROWTYPE;
  v_visit public.visits%ROWTYPE;
  v_patient public.patients%ROWTYPE;
  v_prescriber_id uuid;
  v_snapshot jsonb;
  v_request_id uuid;
BEGIN
  IF v_user_id IS NULL OR NOT public.app_has_perm('pharmacy.correction.request') THEN
    RAISE EXCEPTION 'not authorized to request prescription correction'
      USING ERRCODE='42501';
  END IF;
  IF p_prescription_item_id IS NULL OR length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 10 AND 1000 THEN
    RAISE EXCEPTION 'a specific prescription item and a reason of 10 to 1000 characters are required'
      USING ERRCODE='22023';
  END IF;

  -- Resolve the parent without locking, then lock in the global order:
  -- prescription -> item -> correction request.
  SELECT pi.prescription_id INTO v_prescription_id
  FROM public.prescription_items pi
  WHERE pi.id=p_prescription_item_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription item not found' USING ERRCODE='P0002';
  END IF;

  SELECT p.* INTO v_prescription
  FROM public.prescriptions p
  WHERE p.id=v_prescription_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription not found' USING ERRCODE='P0002';
  END IF;

  SELECT pi.* INTO v_item
  FROM public.prescription_items pi
  WHERE pi.id=p_prescription_item_id
    AND pi.prescription_id=v_prescription.id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription item no longer belongs to its parent prescription'
      USING ERRCODE='23514';
  END IF;

  IF v_prescription.status IS DISTINCT FROM 'pending'
     OR v_prescription.deleted_at IS NOT NULL
     OR v_prescription.dispensed_at IS NOT NULL
     OR v_prescription.is_external IS TRUE
     OR v_prescription.prescription_type IS DISTINCT FROM 'internal' THEN
    RAISE EXCEPTION 'only an active pending internal prescription can be sent for correction'
      USING ERRCODE='23514';
  END IF;

  IF v_item.deleted_at IS NOT NULL
     OR v_item.medicine_id IS NOT NULL
     OR v_item.is_dispensed IS TRUE
     OR COALESCE(v_item.dispensed_quantity,0) <> 0 THEN
    RAISE EXCEPTION 'only an active unlinked, undispensed prescription item can be sent for correction'
      USING ERRCODE='23514';
  END IF;

  SELECT v.* INTO v_visit
  FROM public.visits v
  WHERE v.id=v_prescription.visit_id
    AND v.patient_id=v_prescription.patient_id
    AND v.deleted_at IS NULL;
  IF NOT FOUND OR v_visit.branch_id IS NULL
     OR v_prescription.branch_id IS DISTINCT FROM v_visit.branch_id THEN
    RAISE EXCEPTION 'prescription, visit and branch linkage is invalid'
      USING ERRCODE='23514';
  END IF;

  SELECT p.* INTO v_patient
  FROM public.patients p
  WHERE p.id=v_prescription.patient_id
    AND p.deleted_at IS NULL;
  IF NOT FOUND
     OR (v_patient.branch_id IS NOT NULL AND v_patient.branch_id IS DISTINCT FROM v_visit.branch_id)
     OR NOT private.app_has_branch_access(v_visit.branch_id) THEN
    RAISE EXCEPTION 'cross-branch or inactive prescription correction request denied'
      USING ERRCODE='42501';
  END IF;

  v_prescriber_id := COALESCE(v_prescription.prescribed_by,v_prescription.doctor_id,v_visit.doctor_id);
  IF v_prescriber_id IS NULL THEN
    RAISE EXCEPTION 'prescription has no recorded responsible prescriber; manual clinical reconciliation is required'
      USING ERRCODE='23514';
  END IF;

  v_snapshot := jsonb_build_object(
    'id',v_item.id,
    'prescription_id',v_item.prescription_id,
    'medicine_id',v_item.medicine_id,
    'medication_name',v_item.medication_name,
    'dose',v_item.dose,
    'dosage',v_item.dosage,
    'frequency',v_item.frequency,
    'duration',v_item.duration,
    'quantity',v_item.quantity,
    'instructions',v_item.instructions,
    'dosage_form',v_item.dosage_form,
    'route',v_item.route,
    'is_dispensed',v_item.is_dispensed,
    'dispensed_quantity',v_item.dispensed_quantity,
    'unit_price',v_item.unit_price,
    'deleted_at',v_item.deleted_at,
    'updated_at',v_item.updated_at
  );

  INSERT INTO public.prescription_item_correction_requests (
    prescription_id,prescription_item_id,patient_id,visit_id,branch_id,
    prescriber_id,visit_doctor_id,item_snapshot,reason,requested_by
  )
  VALUES (
    v_prescription.id,v_item.id,v_prescription.patient_id,v_prescription.visit_id,v_visit.branch_id,
    v_prescriber_id,v_visit.doctor_id,v_snapshot,btrim(p_reason),v_user_id
  )
  ON CONFLICT (prescription_item_id) WHERE status='pending'
  DO NOTHING
  RETURNING id INTO v_request_id;

  IF v_request_id IS NULL THEN
    SELECT r.id INTO v_request_id
    FROM public.prescription_item_correction_requests r
    WHERE r.prescription_item_id=v_item.id AND r.status='pending'
    FOR UPDATE;
    IF v_request_id IS NULL THEN
      RAISE EXCEPTION 'existing pending correction request could not be recovered'
        USING ERRCODE='40001';
    END IF;
    RETURN v_request_id;
  END IF;

  INSERT INTO public.prescription_item_correction_events(request_id,event_type,actor_id,payload)
  VALUES (
    v_request_id,'requested',v_user_id,
    jsonb_build_object('reason',btrim(p_reason),'item_snapshot',v_snapshot)
  );

  RETURN v_request_id;
END
$function$;

CREATE OR REPLACE FUNCTION public.resolve_prescription_item_correction(
  p_request_id uuid,
  p_action text,
  p_replacement jsonb,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := public.current_app_user_id();
  v_prescription_id uuid;
  v_item_id uuid;
  v_prescription public.prescriptions%ROWTYPE;
  v_item public.prescription_items%ROWTYPE;
  v_request public.prescription_item_correction_requests%ROWTYPE;
  v_visit public.visits%ROWTYPE;
  v_medicine public.medicines%ROWTYPE;
  v_medicine_id uuid;
  v_quantity numeric;
  v_payload jsonb := '[]'::jsonb;
  v_entry jsonb;
  v_source_item_id uuid;
  v_count integer;
  v_new_prescription_id uuid;
  v_snapshot jsonb;
  v_new_item jsonb;
  v_event_type text;
  v_disposition text;
  v_resolution_note text;
BEGIN
  IF v_user_id IS NULL OR NOT public.app_has_perm('prescriptions.correction.resolve') THEN
    RAISE EXCEPTION 'not authorized to resolve prescription correction'
      USING ERRCODE='42501';
  END IF;
  IF p_request_id IS NULL OR p_action NOT IN ('replace_item','reject','cancel_and_reissue') THEN
    RAISE EXCEPTION 'a valid correction request and disposition are required'
      USING ERRCODE='22023';
  END IF;

  -- Read immutable IDs first, then lock parent -> item -> request.
  SELECT r.prescription_id,r.prescription_item_id
    INTO v_prescription_id,v_item_id
  FROM public.prescription_item_correction_requests r
  WHERE r.id=p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription correction request not found' USING ERRCODE='P0002';
  END IF;

  SELECT p.* INTO v_prescription
  FROM public.prescriptions p
  WHERE p.id=v_prescription_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription not found for correction request' USING ERRCODE='P0002';
  END IF;

  SELECT pi.* INTO v_item
  FROM public.prescription_items pi
  WHERE pi.id=v_item_id AND pi.prescription_id=v_prescription_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription item not found for correction request' USING ERRCODE='P0002';
  END IF;

  SELECT r.* INTO v_request
  FROM public.prescription_item_correction_requests r
  WHERE r.id=p_request_id
  FOR UPDATE;
  IF NOT FOUND OR v_request.status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'prescription correction request is no longer pending'
      USING ERRCODE='40001';
  END IF;

  IF v_prescription.status IS DISTINCT FROM 'pending'
     OR v_prescription.deleted_at IS NOT NULL
     OR v_prescription.dispensed_at IS NOT NULL
     OR v_prescription.is_external IS TRUE
     OR v_prescription.prescription_type IS DISTINCT FROM 'internal'
     OR v_item.deleted_at IS NOT NULL
     OR v_item.medicine_id IS NOT NULL
     OR v_item.is_dispensed IS TRUE
     OR COALESCE(v_item.dispensed_quantity,0) <> 0 THEN
    RAISE EXCEPTION 'prescription or item is no longer eligible for correction'
      USING ERRCODE='23514';
  END IF;

  SELECT v.* INTO v_visit
  FROM public.visits v
  WHERE v.id=v_prescription.visit_id
    AND v.patient_id=v_prescription.patient_id
    AND v.deleted_at IS NULL;
  IF NOT FOUND OR v_visit.branch_id IS DISTINCT FROM v_request.branch_id
     OR v_prescription.branch_id IS DISTINCT FROM v_visit.branch_id
     OR NOT private.app_has_branch_access(v_visit.branch_id) THEN
    RAISE EXCEPTION 'cross-branch prescription correction resolution denied'
      USING ERRCODE='42501';
  END IF;

  IF NOT public.is_super_admin()
     AND v_user_id NOT IN (
       v_request.prescriber_id,v_request.visit_doctor_id,
       v_prescription.prescribed_by,v_prescription.doctor_id,v_visit.doctor_id
     ) THEN
    RAISE EXCEPTION 'only the responsible prescriber or assigned visit doctor can resolve this request'
      USING ERRCODE='42501';
  END IF;

  v_snapshot := jsonb_build_object(
    'id',v_item.id,
    'prescription_id',v_item.prescription_id,
    'medicine_id',v_item.medicine_id,
    'medication_name',v_item.medication_name,
    'dose',v_item.dose,
    'dosage',v_item.dosage,
    'frequency',v_item.frequency,
    'duration',v_item.duration,
    'quantity',v_item.quantity,
    'instructions',v_item.instructions,
    'dosage_form',v_item.dosage_form,
    'route',v_item.route,
    'is_dispensed',v_item.is_dispensed,
    'dispensed_quantity',v_item.dispensed_quantity,
    'unit_price',v_item.unit_price,
    'deleted_at',v_item.deleted_at,
    'updated_at',v_item.updated_at
  );
  IF v_snapshot IS DISTINCT FROM v_request.item_snapshot THEN
    RAISE EXCEPTION 'stale correction request: the original prescription item changed after the request'
      USING ERRCODE='40001';
  END IF;

  IF p_action='reject' THEN
    IF length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 10 AND 1000 THEN
      RAISE EXCEPTION 'a clinical rejection reason of 10 to 1000 characters is required'
        USING ERRCODE='22023';
    END IF;
    v_disposition := 'reject';
    v_event_type := 'rejected';
    v_resolution_note := btrim(p_reason);

  ELSIF p_action='replace_item' THEN
    IF jsonb_typeof(p_replacement) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'replacement item object is required' USING ERRCODE='22023';
    END IF;
    v_medicine_id := NULLIF(p_replacement->>'medicine_id','')::uuid;
    IF v_medicine_id IS NULL
       OR jsonb_typeof(p_replacement->'quantity') IS DISTINCT FROM 'number'
       OR length(btrim(COALESCE(p_replacement->>'dose',''))) = 0
       OR length(btrim(COALESCE(p_replacement->>'frequency',''))) = 0
       OR length(btrim(COALESCE(p_replacement->>'duration',''))) = 0
       OR length(btrim(COALESCE(p_replacement->>'dosage_form',''))) = 0
       OR length(btrim(COALESCE(p_replacement->>'route',''))) = 0 THEN
      RAISE EXCEPTION 'explicit catalogue medicine, dose, frequency, duration, quantity, form and route are required'
        USING ERRCODE='22023';
    END IF;

    v_quantity := (p_replacement->>'quantity')::numeric;
    IF v_quantity::text IN ('NaN','Infinity','-Infinity') OR v_quantity <= 0 OR v_quantity <> trunc(v_quantity) THEN
      RAISE EXCEPTION 'replacement quantity must be a finite positive whole number'
        USING ERRCODE='22023';
    END IF;

    SELECT m.* INTO v_medicine
    FROM public.medicines m
    WHERE m.id=v_medicine_id
      AND m.active IS TRUE
      AND m.is_active IS TRUE
      AND m.deleted_at IS NULL
    FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'explicit active catalogue medicine was not found'
        USING ERRCODE='23503';
    END IF;
    IF COALESCE(v_medicine.selling_price,0)::text IN ('NaN','Infinity','-Infinity')
       OR COALESCE(v_medicine.selling_price,0) < 0 THEN
      RAISE EXCEPTION 'catalogue medicine selling price must be finite and non-negative'
        USING ERRCODE='23514';
    END IF;

    UPDATE public.prescription_items
    SET medicine_id=v_medicine.id,
        medication_name=COALESCE(NULLIF(btrim(v_medicine.name),''),NULLIF(btrim(v_medicine.generic_name),'')),
        dose=btrim(p_replacement->>'dose'),
        dosage=btrim(p_replacement->>'dose'),
        frequency=btrim(p_replacement->>'frequency'),
        duration=btrim(p_replacement->>'duration'),
        quantity=v_quantity,
        instructions=NULLIF(btrim(COALESCE(p_replacement->>'instructions','')),''),
        dosage_form=btrim(p_replacement->>'dosage_form'),
        route=btrim(p_replacement->>'route'),
        unit_price=COALESCE(v_medicine.selling_price,0),
        updated_by=v_user_id,
        updated_at=now()
    WHERE id=v_item.id AND prescription_id=v_prescription.id
      AND medicine_id IS NULL AND deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'prescription item changed before replacement could be saved'
        USING ERRCODE='40001';
    END IF;

    v_disposition := 'replace_item';
    v_event_type := 'item_replaced';
    v_new_item := jsonb_build_object(
      'medicine_id',v_medicine.id,
      'medication_name',COALESCE(NULLIF(btrim(v_medicine.name),''),NULLIF(btrim(v_medicine.generic_name),'')),
      'dose',btrim(p_replacement->>'dose'),
      'frequency',btrim(p_replacement->>'frequency'),
      'duration',btrim(p_replacement->>'duration'),
      'quantity',v_quantity,
      'dosage_form',btrim(p_replacement->>'dosage_form'),
      'route',btrim(p_replacement->>'route'),
      'unit_price',COALESCE(v_medicine.selling_price,0)
    );
    v_resolution_note := NULLIF(btrim(COALESCE(p_reason,'')),'');
  ELSE
    IF jsonb_typeof(p_replacement) IS DISTINCT FROM 'array'
       OR jsonb_array_length(p_replacement)=0 THEN
      RAISE EXCEPTION 'complete replacement prescription item array is required'
        USING ERRCODE='22023';
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.prescription_item_correction_requests r
      WHERE r.prescription_id=v_prescription.id
        AND r.status='pending'
        AND r.id<>v_request.id
    ) THEN
      RAISE EXCEPTION 'other pending correction requests must be resolved before cancelling and reissuing this prescription'
        USING ERRCODE='23514';
    END IF;
    IF jsonb_array_length(p_replacement) <> (
      SELECT count(*) FROM public.prescription_items pi
      WHERE pi.prescription_id=v_prescription.id AND pi.deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION 'replacement order must preserve every active original item exactly once'
        USING ERRCODE='22023';
    END IF;

    FOR v_entry IN SELECT value FROM jsonb_array_elements(p_replacement) AS x(value)
    LOOP
      IF jsonb_typeof(v_entry) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'each replacement prescription item must be an object'
          USING ERRCODE='22023';
      END IF;
      v_source_item_id := NULLIF(v_entry->>'source_item_id','')::uuid;
      IF v_source_item_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.prescription_items pi
        WHERE pi.id=v_source_item_id
          AND pi.prescription_id=v_prescription.id
          AND pi.deleted_at IS NULL
      ) THEN
        RAISE EXCEPTION 'replacement item source must identify an active item on the original prescription'
          USING ERRCODE='22023';
      END IF;
      IF jsonb_typeof(v_entry->'quantity') IS DISTINCT FROM 'number'
         OR length(btrim(COALESCE(v_entry->>'dose',''))) = 0
         OR length(btrim(COALESCE(v_entry->>'frequency',''))) = 0
         OR length(btrim(COALESCE(v_entry->>'duration',''))) = 0
         OR length(btrim(COALESCE(v_entry->>'dosage_form',''))) = 0
         OR length(btrim(COALESCE(v_entry->>'route',''))) = 0 THEN
        RAISE EXCEPTION 'every replacement item requires a complete explicit regimen'
          USING ERRCODE='22023';
      END IF;
      v_quantity := (v_entry->>'quantity')::numeric;
      IF v_quantity::text IN ('NaN','Infinity','-Infinity') OR v_quantity <= 0 OR v_quantity <> trunc(v_quantity) THEN
        RAISE EXCEPTION 'replacement quantity must be a finite positive whole number'
          USING ERRCODE='22023';
      END IF;
      v_medicine_id := NULLIF(v_entry->>'medicine_id','')::uuid;
      IF v_medicine_id IS NULL THEN
        RAISE EXCEPTION 'all replacement prescription items must be explicitly linked to the active catalogue'
          USING ERRCODE='22023';
      END IF;
      SELECT m.* INTO v_medicine
      FROM public.medicines m
      WHERE m.id=v_medicine_id
        AND m.active IS TRUE
        AND m.is_active IS TRUE
        AND m.deleted_at IS NULL
      FOR SHARE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'replacement item catalogue medicine is inactive or missing'
          USING ERRCODE='23503';
      END IF;
      v_payload := v_payload || jsonb_build_array(jsonb_build_object(
        'medicine_id',v_medicine.id,
        'medication_name',COALESCE(NULLIF(btrim(v_medicine.name),''),NULLIF(btrim(v_medicine.generic_name),'')),
        'dose',btrim(v_entry->>'dose'),
        'frequency',btrim(v_entry->>'frequency'),
        'duration',btrim(v_entry->>'duration'),
        'quantity',v_quantity,
        'instructions',NULLIF(btrim(COALESCE(v_entry->>'instructions','')),''),
        'dosage_form',btrim(v_entry->>'dosage_form'),
        'route',btrim(v_entry->>'route')
      ));
    END LOOP;

    IF (
      SELECT count(DISTINCT value->>'source_item_id')
      FROM jsonb_array_elements(p_replacement) AS x(value)
    ) <> jsonb_array_length(p_replacement)
    OR EXISTS (
      SELECT 1 FROM public.prescription_items pi
      WHERE pi.prescription_id=v_prescription.id AND pi.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM jsonb_array_elements(p_replacement) AS x(value)
          WHERE x.value->>'source_item_id'=pi.id::text
        )
    )
    OR NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_replacement) AS x(value)
      WHERE x.value->>'source_item_id'=v_item.id::text
    ) THEN
      RAISE EXCEPTION 'replacement order must map every original item once, including the requested item'
        USING ERRCODE='22023';
    END IF;
    IF length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 10 AND 1000 THEN
      RAISE EXCEPTION 'a reason of 10 to 1000 characters is required for prescription cancellation and reissue'
        USING ERRCODE='22023';
    END IF;

    UPDATE public.prescriptions
    SET status='cancelled',updated_by=v_user_id,updated_at=now()
    WHERE id=v_prescription.id AND status='pending' AND dispensed_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'original prescription changed before cancellation'
        USING ERRCODE='40001';
    END IF;

    v_new_prescription_id := public.create_prescription_atomic(
      v_prescription.visit_id,false,v_payload
    );
    v_disposition := 'cancel_and_reissue';
    v_event_type := 'prescription_cancelled_and_reissued';
    v_resolution_note := btrim(p_reason);
  END IF;

  UPDATE public.prescription_item_correction_requests
  SET status=CASE WHEN p_action='reject' THEN 'rejected' ELSE 'resolved' END,
      disposition=v_disposition,
      resolution_note=v_resolution_note,
      corrected_item_id=CASE WHEN p_action='replace_item' THEN v_item.id ELSE NULL END,
      replacement_prescription_id=v_new_prescription_id,
      resolved_by=v_user_id,
      resolved_at=now()
  WHERE id=v_request.id AND status='pending';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'correction request changed before resolution could be committed'
      USING ERRCODE='40001';
  END IF;

  INSERT INTO public.prescription_item_correction_events(request_id,event_type,actor_id,payload)
  VALUES (
    v_request.id,v_event_type,v_user_id,
    jsonb_build_object(
      'action',p_action,
      'reason',v_resolution_note,
      'original_item',v_snapshot,
      'replacement_item',v_new_item,
      'replacement_prescription_id',v_new_prescription_id
    )
  );

  RETURN v_request.id;
END
$function$;

REVOKE ALL ON FUNCTION public.request_prescription_item_correction(uuid,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_prescription_item_correction(uuid,text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.resolve_prescription_item_correction(uuid,text,jsonb,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_prescription_item_correction(uuid,text,jsonb,text)
  TO authenticated;

COMMENT ON TABLE public.prescription_item_correction_requests IS
  'Branch-scoped, auditable requests from pharmacy to the responsible prescriber for a specific unlinked prescription item.';
COMMENT ON TABLE public.prescription_item_correction_events IS
  'Append-only actor/timestamp evidence for each prescription item correction request and resolution.';

COMMIT;
