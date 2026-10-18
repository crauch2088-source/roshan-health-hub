-- Phase 28: move the remaining clinical child-table writes behind narrow RPCs.
-- This additive migration intentionally preserves direct table grants during rollout.
-- Apply before deploying the frontend RPC call sites; Phase 29 revokes direct DML.

CREATE OR REPLACE FUNCTION public.complete_lab_order_item(p_order_item_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
BEGIN
  IF NOT public.app_has_perm('lab.update') THEN
    RAISE EXCEPTION 'lab update permission required' USING ERRCODE = '42501';
  END IF;
  IF p_order_item_id IS NULL THEN
    RAISE EXCEPTION 'lab order item is required' USING ERRCODE = '22023';
  END IF;

  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;

  SELECT item.order_id
    INTO v_order_id
    FROM public.lab_order_items AS item
    JOIN public.lab_orders AS orders ON orders.id = item.order_id
   WHERE item.id = p_order_item_id
     AND item.deleted_at IS NULL
     AND orders.deleted_at IS NULL;

  IF v_order_id IS NULL THEN
    RAISE EXCEPTION 'lab order item not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.app_has_lab_order_item_branch_access(v_order_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;

  UPDATE public.lab_order_items
     SET status = 'completed',
         completed_at = COALESCE(completed_at, pg_catalog.now()),
         updated_by = v_user_id
   WHERE id = p_order_item_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'lab order item not found' USING ERRCODE = 'P0002';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_medical_certificate(
  p_patient_id uuid,
  p_diagnosis text,
  p_start_date date,
  p_end_date date
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid;
  v_certificate_id integer;
BEGIN
  IF NOT public.app_has_perm('certificates.create') THEN
    RAISE EXCEPTION 'certificate create permission required' USING ERRCODE = '42501';
  END IF;
  IF p_patient_id IS NULL THEN
    RAISE EXCEPTION 'patient is required' USING ERRCODE = '22023';
  END IF;
  IF p_start_date IS NULL OR p_end_date IS NULL OR p_end_date < p_start_date THEN
    RAISE EXCEPTION 'certificate dates are invalid' USING ERRCODE = '22023';
  END IF;
  IF NULLIF(pg_catalog.btrim(COALESCE(p_diagnosis, '')), '') IS NULL THEN
    RAISE EXCEPTION 'certificate diagnosis is required' USING ERRCODE = '22023';
  END IF;

  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;
  IF NOT private.app_has_patient_branch(p_patient_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.medical_certificates (
    patient_id, doctor_id, diagnosis, start_date, end_date
  )
  VALUES (
    p_patient_id,
    v_user_id,
    pg_catalog.btrim(p_diagnosis),
    p_start_date,
    p_end_date
  )
  RETURNING id INTO v_certificate_id;

  RETURN v_certificate_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_lab_order_item(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_lab_order_item(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.create_medical_certificate(uuid, text, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_medical_certificate(uuid, text, date, date) TO authenticated;
