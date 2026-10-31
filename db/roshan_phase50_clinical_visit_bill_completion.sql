-- Phase 50: atomic clinical visit completion with consultation billing.
-- Candidate only. The existing complete_visit_atomic signature is preserved.
BEGIN;

CREATE OR REPLACE FUNCTION public.complete_clinical_visit_and_bill(p_visit_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_visit_branch uuid;
  v_patient_branch uuid;
  v_status text;
  v_completed_at timestamptz;
  v_fee numeric;
  v_invoice_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('visits.update') THEN
    RAISE EXCEPTION 'visit_completion_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_visit_id IS NULL THEN
    RAISE EXCEPTION 'visit is required' USING ERRCODE = '22023';
  END IF;

  SELECT v.branch_id,p.branch_id,v.status,v.completed_at,v.consultation_fee
    INTO v_visit_branch,v_patient_branch,v_status,v_completed_at,v_fee
    FROM public.visits v
    JOIN public.patients p ON p.id=v.patient_id AND p.deleted_at IS NULL
   WHERE v.id=p_visit_id AND v.deleted_at IS NULL
   FOR UPDATE OF v,p;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'active_visit_or_patient_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.app_has_visit_branch_access(p_visit_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_visit_branch IS NULL OR v_patient_branch IS NULL
     OR v_visit_branch IS DISTINCT FROM v_patient_branch THEN
    RAISE EXCEPTION 'visit_patient_branch_mismatch' USING ERRCODE = '42501';
  END IF;
  IF v_status='cancelled' THEN
    RAISE EXCEPTION 'cancelled_visit_cannot_be_completed' USING ERRCODE = '22023';
  END IF;
  IF v_fee IS NULL OR v_fee::text IN ('NaN','Infinity','-Infinity')
     OR v_fee<0 OR v_fee<>pg_catalog.round(v_fee,2) THEN
    RAISE EXCEPTION 'invalid_consultation_fee' USING ERRCODE = '22023';
  END IF;

  -- Invoice first, visit/queue second: any billing failure rolls the whole call back.
  IF v_fee>0 THEN
    v_invoice_id := public.create_visit_consultation_invoice_atomic(p_visit_id,CURRENT_DATE);
  ELSE
    SELECT i.id INTO v_invoice_id
      FROM public.invoices i
     WHERE i.visit_id=p_visit_id AND i.is_primary IS TRUE AND i.deleted_at IS NULL
     FOR UPDATE;
  END IF;

  IF v_status='completed' THEN
    IF v_completed_at IS NULL THEN
      RAISE EXCEPTION 'completed_visit_missing_timestamp_manual_repair_required'
        USING ERRCODE = '22023';
    END IF;
    UPDATE public.queue_tickets q
       SET status='completed',completed_at=v_completed_at,updated_by=v_uid
     WHERE q.visit_id=p_visit_id AND q.deleted_at IS NULL
       AND q.status IN ('waiting','called','in_progress','completed')
       AND (q.status IS DISTINCT FROM 'completed' OR q.completed_at IS DISTINCT FROM v_completed_at);
    RETURN pg_catalog.jsonb_build_object(
      'visit_id',p_visit_id,'invoice_id',v_invoice_id,'consultation_fee',v_fee,
      'completed_at',v_completed_at,'status','completed','replayed',true
    );
  END IF;

  v_completed_at := pg_catalog.clock_timestamp();
  UPDATE public.visits v
     SET status='completed',completed_at=v_completed_at,updated_by=v_uid,updated_at=v_completed_at
   WHERE v.id=p_visit_id AND v.deleted_at IS NULL;
  UPDATE public.queue_tickets q
     SET status='completed',completed_at=v_completed_at,updated_by=v_uid
   WHERE q.visit_id=p_visit_id AND q.deleted_at IS NULL
     AND q.status IN ('waiting','called','in_progress','completed');

  RETURN pg_catalog.jsonb_build_object(
    'visit_id',p_visit_id,'invoice_id',v_invoice_id,'consultation_fee',v_fee,
    'completed_at',v_completed_at,'status','completed','replayed',false
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_visit_atomic(p_visit_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  PERFORM public.complete_clinical_visit_and_bill(p_visit_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_clinical_visit_and_bill(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.complete_clinical_visit_and_bill(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.complete_visit_atomic(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.complete_visit_atomic(uuid) TO authenticated;
COMMENT ON FUNCTION public.complete_clinical_visit_and_bill(uuid) IS
  'Bills consultation before visit completion and aligns active queue tickets to the visit completion timestamp.';

COMMIT;
