-- Proposed hardening for the already-deployed batch-receive RPC.
-- Keep this in source control for review; do not apply until migration parity and staging gates pass.
CREATE OR REPLACE FUNCTION public.fn_receive_pharmacy_batch(
  p_medicine_id uuid,
  p_quantity numeric,
  p_batch_number text DEFAULT NULL::text,
  p_expiry_date date DEFAULT NULL::date,
  p_manufacture_date date DEFAULT NULL::date,
  p_purchase_price numeric DEFAULT 0,
  p_selling_price numeric DEFAULT NULL::numeric,
  p_supplier_id uuid DEFAULT NULL::uuid,
  p_invoice_reference text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_branch uuid;
  v_batch_id uuid;
  v_existing_stock bigint;
  v_sell numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required' USING ERRCODE = '42501';
  END IF;
  IF NOT COALESCE(public.app_has_perm('pharmacy.update'), false) THEN
    RAISE EXCEPTION 'insufficient_permission' USING ERRCODE = '42501';
  END IF;
  IF p_quantity IS NULL
     OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_quantity <> pg_catalog.trunc(p_quantity)
     OR p_quantity <= 0
     OR p_quantity > 2147483647 THEN
    RAISE EXCEPTION 'invalid_quantity';
  END IF;
  IF p_purchase_price IS NULL
     OR p_purchase_price::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_purchase_price < 0
     OR p_purchase_price <> pg_catalog.round(p_purchase_price, 2) THEN
    RAISE EXCEPTION 'invalid_purchase_price';
  END IF;
  IF p_selling_price IS NOT NULL
     AND (p_selling_price::text IN ('NaN', 'Infinity', '-Infinity')
       OR p_selling_price < 0
       OR p_selling_price <> pg_catalog.round(p_selling_price, 2)) THEN
    RAISE EXCEPTION 'invalid_selling_price';
  END IF;
  IF p_expiry_date IS NOT NULL
     AND p_manufacture_date IS NOT NULL
     AND p_manufacture_date > p_expiry_date THEN
    RAISE EXCEPTION 'manufacture_after_expiry';
  END IF;
  IF p_expiry_date IS NOT NULL AND p_expiry_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'expired_batch';
  END IF;
  IF p_manufacture_date IS NOT NULL AND p_manufacture_date > CURRENT_DATE THEN
    RAISE EXCEPTION 'future_manufacture_date';
  END IF;

  SELECT u.branch_id INTO v_branch
    FROM public.users AS u
   WHERE u.id = v_uid AND u.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active_application_user_not_found' USING ERRCODE = '42501';
  END IF;
  IF v_branch IS NULL THEN
    -- This RPC has no explicit target-branch argument; even super-admins must
    -- receive stock while operating in a concrete branch to avoid orphan batches.
    RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE = '42501';
  END IF;

  IF p_supplier_id IS NOT NULL THEN
    PERFORM 1 FROM public.suppliers AS s
     WHERE s.id = p_supplier_id AND s.active IS TRUE AND s.deleted_at IS NULL
     FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'active_supplier_not_found'; END IF;
  END IF;

  SELECT COALESCE(m.stock_quantity, 0)::bigint,
         COALESCE(p_selling_price, m.selling_price, 0)
    INTO v_existing_stock, v_sell
    FROM public.medicines AS m
   WHERE m.id = p_medicine_id AND m.deleted_at IS NULL AND m.active IS TRUE
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active_medicine_not_found'; END IF;

  IF v_sell IS NULL
     OR v_sell::text IN ('NaN', 'Infinity', '-Infinity')
     OR v_sell < 0
     OR v_sell <> pg_catalog.round(v_sell, 2) THEN
    RAISE EXCEPTION 'invalid_selling_price';
  END IF;
  IF v_existing_stock + p_quantity > 2147483647 THEN
    RAISE EXCEPTION 'stock_quantity_overflow';
  END IF;

  INSERT INTO public.pharmacy_inventory (
    medicine_id, batch_number, batch_no, expiry_date, manufacture_date,
    quantity, quantity_received, quantity_remaining, purchase_price,
    selling_price, supplier_id, invoice_reference, branch_id, created_by, updated_by
  ) VALUES (
    p_medicine_id,
    NULLIF(pg_catalog.btrim(p_batch_number), ''),
    NULLIF(pg_catalog.btrim(p_batch_number), ''),
    p_expiry_date, p_manufacture_date, p_quantity, p_quantity, p_quantity,
    p_purchase_price, v_sell, p_supplier_id,
    NULLIF(pg_catalog.btrim(p_invoice_reference), ''), v_branch, v_uid, v_uid
  ) RETURNING id INTO v_batch_id;

  UPDATE public.medicines
     SET stock_quantity = COALESCE(stock_quantity, 0) + p_quantity::integer,
         cost_price = p_purchase_price,
         selling_price = v_sell,
         updated_at = pg_catalog.now(),
         updated_by = v_uid
   WHERE id = p_medicine_id;

  INSERT INTO public.stock_movements (
    medicine_id, batch_id, movement_type, quantity, reference_id,
    reference_table, branch_id, created_by
  ) VALUES (
    p_medicine_id, v_batch_id, 'purchase', p_quantity, v_batch_id,
    'pharmacy_inventory', v_branch, v_uid
  );
  RETURN v_batch_id;
END;
$function$;

-- Stock ledger writes must go through atomic SECURITY DEFINER workflows.
DROP POLICY IF EXISTS stock_movements_insert ON public.stock_movements;
REVOKE INSERT ON TABLE public.stock_movements FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.fn_receive_pharmacy_batch(uuid, numeric, text, date, date, numeric, numeric, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_receive_pharmacy_batch(uuid, numeric, text, date, date, numeric, numeric, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_receive_pharmacy_batch(uuid, numeric, text, date, date, numeric, numeric, uuid, text) TO authenticated;
