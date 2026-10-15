-- Proposed follow-up migration. Route manual billing through the visit's primary invoice.
-- Keep unapplied until migration-history reconciliation and isolated Supabase validation are complete.
CREATE OR REPLACE FUNCTION public.create_billing_invoice_atomic(
  p_patient_id uuid,
  p_visit_id uuid,
  p_partner_id uuid,
  p_invoice_date date,
  p_discount numeric,
  p_items jsonb,
  p_separate_invoice boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_visit_patient_id uuid;
  v_invoice_id uuid;
  v_existing_partner uuid;
  v_item jsonb;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'billing permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_patient_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'patient and invoice date are required';
  END IF;
  IF p_separate_invoice IS NULL THEN
    RAISE EXCEPTION 'separate-invoice choice must be explicit';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invoice items must be a non-empty JSON array';
  END IF;

  -- The manual screen is for services not already billed by clinical workflows.
  -- Consultation, lab, and pharmacy items must use their own validated RPCs.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object'
       OR COALESCE(v_item->>'item_type','') NOT IN ('procedure','other') THEN
      RAISE EXCEPTION 'manual billing supports procedure and other item types only';
    END IF;
  END LOOP;

  IF p_visit_id IS NULL THEN
    IF NOT p_separate_invoice THEN
      RAISE EXCEPTION 'standalone invoices must be explicitly selected';
    END IF;
    v_invoice_id := public.create_invoice_atomic(
      p_patient_id,p_partner_id,p_invoice_date,p_discount,p_items
    );
    UPDATE public.invoices
       SET is_primary = false, updated_by = v_uid, updated_at = pg_catalog.now()
     WHERE id = v_invoice_id;
    RETURN v_invoice_id;
  END IF;

  SELECT v.patient_id INTO v_visit_patient_id
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  IF v_visit_patient_id IS DISTINCT FROM p_patient_id THEN
    RAISE EXCEPTION 'selected visit does not belong to the selected patient';
  END IF;

  IF p_partner_id IS NOT NULL THEN
    PERFORM 1 FROM public.partners AS p
     WHERE p.id = p_partner_id AND p.deleted_at IS NULL AND p.active IS TRUE
     FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'active partner not found'; END IF;
  END IF;

  v_invoice_id := private.create_or_append_visit_invoice_atomic(
    p_visit_id,p_invoice_date,p_discount,p_items,p_separate_invoice
  );

  IF p_partner_id IS NOT NULL THEN
    SELECT i.partner_id INTO v_existing_partner
      FROM public.invoices AS i
     WHERE i.id = v_invoice_id AND i.deleted_at IS NULL
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'invoice not found after creation'; END IF;
    IF v_existing_partner IS NOT NULL AND v_existing_partner IS DISTINCT FROM p_partner_id THEN
      RAISE EXCEPTION 'invoice partner mismatch; refusing to mix billing partners';
    END IF;
    UPDATE public.invoices
       SET partner_id = p_partner_id,
           updated_by = v_uid,
           updated_at = pg_catalog.now()
     WHERE id = v_invoice_id;
  END IF;

  RETURN v_invoice_id;
END;
$function$;

-- All application writes now go through the context-aware wrapper. SECURITY DEFINER
-- workflows may still call create_invoice_atomic internally using their owner privileges.
REVOKE ALL ON FUNCTION public.create_invoice_atomic(uuid,uuid,date,numeric,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_billing_invoice_atomic(uuid,uuid,uuid,date,numeric,jsonb,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_billing_invoice_atomic(uuid,uuid,uuid,date,numeric,jsonb,boolean) TO authenticated;
