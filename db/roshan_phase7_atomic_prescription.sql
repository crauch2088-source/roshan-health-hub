-- Atomic prescription creation. Keep under db/ until migration history is reconciled.
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

  IF NOT (public.app_has_perm('pharmacy.create') OR public.app_has_perm('emr.create')) THEN
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
    IF v_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'prescription quantity must be finite and positive';
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
         AND m.active IS TRUE;
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
         AND m.active IS TRUE;
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

REVOKE ALL ON FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_prescription_atomic(uuid, boolean, jsonb) TO authenticated;
