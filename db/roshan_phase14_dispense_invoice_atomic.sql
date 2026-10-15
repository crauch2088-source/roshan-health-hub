-- Proposed follow-up migration. Keep unapplied until the recovered migration history
-- is canonical, and validate in an isolated Supabase branch before any production rollout.
-- Dispensing, FEFO stock movement, and pharmacy invoice lines share one transaction.
CREATE OR REPLACE FUNCTION public.fn_dispense_prescription_with_invoice(
  p_prescription_id uuid,
  p_separate_invoice boolean
)
RETURNS TABLE(
  item_id uuid,
  medicine_id uuid,
  medicine_name text,
  batch_id uuid,
  batch_number text,
  expiry_date date,
  quantity_dispensed numeric,
  batch_quantity_remaining numeric,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_item record;
  v_batch record;
  v_needed numeric;
  v_take numeric;
  v_shortfall numeric;
  v_stock numeric;
  v_uid uuid := public.current_app_user_id();
  v_branch uuid;
  v_patient_id uuid;
  v_patient_branch uuid;
  v_visit_id uuid;
  v_visit_branch uuid;
  v_status text;
  v_invoice_items jsonb := '[]'::jsonb;
  v_item_count integer := 0;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('pharmacy.update') THEN
    RAISE EXCEPTION 'insufficient_permission' USING ERRCODE = '42501';
  END IF;
  IF NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'pharmacy billing permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_prescription_id IS NULL OR p_separate_invoice IS NULL THEN
    RAISE EXCEPTION 'prescription and explicit invoice choice are required';
  END IF;

  SELECT u.branch_id INTO v_branch
    FROM public.users AS u
   WHERE u.id = v_uid AND u.deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active application user not found' USING ERRCODE = '42501';
  END IF;
  IF v_branch IS NULL AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;

  SELECT p.patient_id, p.visit_id, p.status
    INTO v_patient_id, v_visit_id, v_status
    FROM public.prescriptions AS p
   WHERE p.id = p_prescription_id AND p.deleted_at IS NULL
   FOR UPDATE;
  IF NOT FOUND OR v_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'prescription_not_pending';
  END IF;

  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients AS p
   WHERE p.id = v_patient_id AND p.deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'active patient not found'; END IF;

  IF v_visit_id IS NOT NULL THEN
    SELECT v.branch_id INTO v_visit_branch
      FROM public.visits AS v
     WHERE v.id = v_visit_id AND v.patient_id = v_patient_id AND v.deleted_at IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  END IF;

  IF NOT public.is_super_admin()
     AND (v_branch IS NULL
       OR v_patient_branch IS DISTINCT FROM v_branch
       OR v_visit_branch IS DISTINCT FROM v_branch) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;

  -- Build invoice lines from the active medicine catalog before any stock mutation.
  -- Only catalog-linked items that will actually be dispensed can be billed.
  FOR v_item IN
    SELECT pi.id, pi.medicine_id, COALESCE(pi.quantity,1) AS qty,
           COALESCE(NULLIF(btrim(m.name),''),NULLIF(btrim(m.brand_name),''),NULLIF(btrim(m.generic_name),'')) AS name,
           m.selling_price
      FROM public.prescription_items AS pi
      JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND m.deleted_at IS NULL
       AND COALESCE(m.active,m.is_active,true) IS TRUE
     ORDER BY pi.id
     FOR UPDATE OF pi, m
  LOOP
    IF v_item.qty::text IN ('NaN','Infinity','-Infinity')
       OR v_item.qty <= 0 OR v_item.qty <> trunc(v_item.qty)
       OR v_item.qty > 2147483647 THEN
      RAISE EXCEPTION 'prescription quantity must be a finite positive whole number';
    END IF;
    IF v_item.name IS NULL THEN RAISE EXCEPTION 'medicine catalog name is required'; END IF;
    IF v_item.selling_price IS NULL
       OR v_item.selling_price::text IN ('NaN','Infinity','-Infinity')
       OR v_item.selling_price < 0
       OR v_item.selling_price <> round(v_item.selling_price,2) THEN
      RAISE EXCEPTION 'medicine selling price must be configured with at most two decimal places';
    END IF;
    v_invoice_items := v_invoice_items || jsonb_build_array(jsonb_build_object(
      'item_name',v_item.name,
      'item_type','pharmacy',
      'quantity',v_item.qty,
      'unit_price',v_item.selling_price,
      'item_id',v_item.medicine_id
    ));
    v_item_count := v_item_count + 1;
  END LOOP;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'prescription has no active catalog-linked medicines to dispense';
  END IF;

  -- Consume batches in FEFO order, then the legacy stock balance, preserving the
  -- existing movement/audit behavior. Any invoice failure rolls all of this back.
  FOR v_item IN
    SELECT pi.id, pi.medicine_id, COALESCE(pi.quantity,1) AS qty,
           COALESCE(NULLIF(btrim(m.name),''),NULLIF(btrim(m.brand_name),''),NULLIF(btrim(m.generic_name),'')) AS name
      FROM public.prescription_items AS pi
      JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND m.deleted_at IS NULL
       AND COALESCE(m.active,m.is_active,true) IS TRUE
     ORDER BY pi.id
     FOR UPDATE OF pi, m
  LOOP
    v_needed := v_item.qty;
    FOR v_batch IN
      SELECT inv.id, inv.batch_number, inv.expiry_date, inv.quantity_remaining
        FROM public.pharmacy_inventory AS inv
       WHERE inv.medicine_id = v_item.medicine_id
         AND inv.quantity_remaining > 0
         AND inv.deleted_at IS NULL
         AND (inv.expiry_date IS NULL OR inv.expiry_date >= CURRENT_DATE)
         AND (public.is_super_admin() OR inv.branch_id = v_branch)
       ORDER BY inv.expiry_date ASC NULLS LAST, inv.created_at ASC
       FOR UPDATE
    LOOP
      EXIT WHEN v_needed <= 0;
      v_take := LEAST(v_needed, v_batch.quantity_remaining);
      UPDATE public.pharmacy_inventory AS inv
         SET quantity_remaining = inv.quantity_remaining - v_take,
             quantity = inv.quantity_remaining - v_take,
             updated_at = now(),
             updated_by = v_uid
       WHERE inv.id = v_batch.id;
      INSERT INTO public.stock_movements (
        medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by
      ) VALUES (
        v_item.medicine_id,v_batch.id,'dispense',-v_take,p_prescription_id,'prescriptions',
        COALESCE(v_visit_branch,v_branch),v_uid
      );
      item_id := v_item.id;
      medicine_id := v_item.medicine_id;
      medicine_name := v_item.name;
      batch_id := v_batch.id;
      batch_number := v_batch.batch_number;
      expiry_date := v_batch.expiry_date;
      quantity_dispensed := v_take;
      batch_quantity_remaining := v_batch.quantity_remaining - v_take;
      source := 'batch';
      RETURN NEXT;
      v_needed := v_needed - v_take;
    END LOOP;

    v_shortfall := GREATEST(v_needed,0);
    IF v_shortfall > 0 THEN
      SELECT m.stock_quantity INTO v_stock
        FROM public.medicines AS m
       WHERE m.id = v_item.medicine_id AND m.deleted_at IS NULL
       FOR UPDATE;
      IF COALESCE(v_stock,0) < v_shortfall THEN
        RAISE EXCEPTION 'insufficient_stock: %',v_item.name;
      END IF;
      INSERT INTO public.stock_movements (
        medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by
      ) VALUES (
        v_item.medicine_id,NULL,'dispense',-v_shortfall,p_prescription_id,'prescriptions',
        COALESCE(v_visit_branch,v_branch),v_uid
      );
      item_id := v_item.id;
      medicine_id := v_item.medicine_id;
      medicine_name := v_item.name;
      batch_id := NULL;
      batch_number := NULL;
      expiry_date := NULL;
      quantity_dispensed := v_shortfall;
      batch_quantity_remaining := NULL;
      source := 'legacy';
      RETURN NEXT;
    END IF;

    UPDATE public.medicines AS m
       SET stock_quantity = m.stock_quantity - v_item.qty::integer,
           updated_at = now(),
           updated_by = v_uid
     WHERE m.id = v_item.medicine_id;
    UPDATE public.prescription_items AS pi
       SET is_dispensed = true,
           dispensed_quantity = v_item.qty::integer,
           updated_at = now(),
           updated_by = v_uid
     WHERE pi.id = v_item.id;
  END LOOP;

  -- A visit uses the single primary invoice by default; a finalized primary
  -- invoice requires an explicit secondary invoice choice. A no-visit prescription
  -- (super-admin-only under the branch guard above) receives a standalone invoice.
  IF v_visit_id IS NOT NULL THEN
    PERFORM private.create_or_append_visit_invoice_atomic(
      v_visit_id,CURRENT_DATE,0,v_invoice_items,p_separate_invoice
    );
  ELSE
    PERFORM public.create_invoice_atomic(
      v_patient_id,NULL,CURRENT_DATE,0,v_invoice_items
    );
  END IF;

  UPDATE public.prescriptions AS p
     SET status = 'dispensed',
         dispensed_by = v_uid,
         dispensed_at = now(),
         updated_at = now(),
         updated_by = v_uid
   WHERE p.id = p_prescription_id;

  RETURN;
END;
$function$;

-- Close the legacy entry point so clients cannot dispense stock without billing.
REVOKE ALL ON FUNCTION public.fn_dispense_prescription(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_dispense_prescription_with_invoice(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_dispense_prescription_with_invoice(uuid, boolean) TO authenticated;
