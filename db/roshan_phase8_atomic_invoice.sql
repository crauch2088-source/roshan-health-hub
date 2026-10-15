-- Atomic invoice creation. Keep under db/ until migration history is reconciled.
CREATE OR REPLACE FUNCTION public.create_invoice_atomic(
  p_patient_id uuid,
  p_partner_id uuid,
  p_invoice_date date,
  p_discount numeric,
  p_items jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_user_branch uuid;
  v_patient_branch uuid;
  v_invoice_id uuid;
  v_invoice_number text;
  v_item jsonb;
  v_item_name text;
  v_item_type text;
  v_quantity numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_subtotal numeric := 0;
  v_net numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'not authorised to create invoices' USING ERRCODE = '42501';
  END IF;
  IF p_patient_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'patient and invoice date are required';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'invoice items must be a JSON array';
  END IF;
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invoice must contain at least one item';
  END IF;
  IF p_discount IS NULL OR p_discount::text IN ('NaN','Infinity','-Infinity')
     OR p_discount < 0 OR p_discount <> round(p_discount, 2) THEN
    RAISE EXCEPTION 'discount must be finite, non-negative, and have at most two decimal places';
  END IF;

  SELECT u.branch_id INTO v_user_branch
    FROM public.users u
   WHERE u.id = v_uid AND u.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active application user not found' USING ERRCODE = '42501';
  END IF;

  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients p
   WHERE p.id = p_patient_id AND p.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active patient not found';
  END IF;
  IF NOT public.is_super_admin()
     AND (v_user_branch IS NULL OR v_patient_branch IS DISTINCT FROM v_user_branch) THEN
    RAISE EXCEPTION 'cross-branch invoice access denied' USING ERRCODE = '42501';
  END IF;

  IF p_partner_id IS NOT NULL THEN
    PERFORM 1 FROM public.partners p
     WHERE p.id = p_partner_id AND p.deleted_at IS NULL AND p.active IS TRUE
     FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'active partner not found'; END IF;
  END IF;

  -- Validate all line items and calculate totals before creating the header.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each invoice item must be an object';
    END IF;
    v_item_name := btrim(COALESCE(v_item->>'item_name',''));
    v_item_type := v_item->>'item_type';
    IF v_item_name = '' THEN RAISE EXCEPTION 'invoice item description is required'; END IF;
    IF v_item_type IS NULL OR v_item_type NOT IN ('consultation','lab','pharmacy','procedure','other') THEN
      RAISE EXCEPTION 'unsupported invoice item type';
    END IF;
    IF jsonb_typeof(v_item->'quantity') IS DISTINCT FROM 'number'
       OR jsonb_typeof(v_item->'unit_price') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'invoice quantity and unit price must be JSON numbers';
    END IF;

    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    IF v_quantity::text IN ('NaN','Infinity','-Infinity')
       OR v_quantity <= 0 OR v_quantity <> trunc(v_quantity) THEN
      RAISE EXCEPTION 'invoice quantity must be a finite positive whole number';
    END IF;
    IF v_unit_price::text IN ('NaN','Infinity','-Infinity')
       OR v_unit_price < 0 OR v_unit_price <> round(v_unit_price, 2) THEN
      RAISE EXCEPTION 'unit price must be finite, non-negative, and have at most two decimal places';
    END IF;
    v_line_total := round(v_quantity * v_unit_price, 2);
    IF v_line_total::text IN ('NaN','Infinity','-Infinity') THEN
      RAISE EXCEPTION 'invoice line total is outside the supported numeric range';
    END IF;
    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  IF v_subtotal::text IN ('NaN','Infinity','-Infinity') OR p_discount > v_subtotal THEN
    RAISE EXCEPTION 'discount cannot exceed invoice subtotal';
  END IF;
  v_net := round(v_subtotal - p_discount, 2);

  v_invoice_number := public.next_invoice_number();
  INSERT INTO public.invoices (
    invoice_number, patient_id, partner_id, invoice_date, total_amount,
    subtotal, discount_amount, net_amount, paid_amount, status,
    payment_status, branch_id, created_by, updated_by
  )
  VALUES (
    v_invoice_number, p_patient_id, p_partner_id, p_invoice_date, v_subtotal,
    v_subtotal, p_discount, v_net, 0, 'unpaid',
    'unpaid', v_patient_branch, v_uid, v_uid
  )
  RETURNING id INTO v_invoice_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    v_item_name := btrim(v_item->>'item_name');
    v_item_type := v_item->>'item_type';
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    v_line_total := round(v_quantity * v_unit_price, 2);
    INSERT INTO public.invoice_items (
      invoice_id, item_name, item_type, quantity, unit_price, total_price, created_by, updated_by
    )
    VALUES (
      v_invoice_id, v_item_name, v_item_type, v_quantity, v_unit_price, v_line_total, v_uid, v_uid
    );
  END LOOP;

  RETURN v_invoice_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_invoice_atomic(uuid, uuid, date, numeric, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_invoice_atomic(uuid, uuid, date, numeric, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_invoice_atomic(uuid, uuid, date, numeric, jsonb) TO authenticated;
