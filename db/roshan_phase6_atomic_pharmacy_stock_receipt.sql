-- Atomic pharmacy batch receipt.
-- Keep under db/ until the repository's historical migration ledger is reconciled.
CREATE OR REPLACE FUNCTION public.receive_pharmacy_stock(
  p_medicine_id uuid,
  p_quantity numeric,
  p_supplier_id uuid DEFAULT NULL,
  p_batch_number text DEFAULT NULL,
  p_purchase_price numeric DEFAULT NULL,
  p_selling_price numeric DEFAULT NULL,
  p_manufacture_date date DEFAULT NULL,
  p_expiry_date date DEFAULT NULL,
  p_invoice_reference text DEFAULT NULL
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
BEGIN
  IF NOT public.app_has_perm('pharmacy.create') THEN
    RAISE EXCEPTION 'not authorised to receive pharmacy stock' USING ERRCODE = '42501';
  END IF;

  IF p_medicine_id IS NULL OR p_quantity IS NULL OR p_quantity <= 0 OR p_quantity <> trunc(p_quantity) THEN
    RAISE EXCEPTION 'quantity must be a positive whole number';
  END IF;
  IF (p_purchase_price IS NOT NULL AND p_purchase_price < 0)
     OR (p_selling_price IS NOT NULL AND p_selling_price < 0) THEN
    RAISE EXCEPTION 'prices must not be negative';
  END IF;
  IF p_manufacture_date IS NOT NULL AND p_expiry_date IS NOT NULL
     AND p_expiry_date < p_manufacture_date THEN
    RAISE EXCEPTION 'expiry date cannot precede manufacture date';
  END IF;

  SELECT u.branch_id INTO v_branch
  FROM public.users u
  WHERE u.id = v_uid AND u.deleted_at IS NULL;
  IF v_branch IS NULL AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'user branch is not configured';
  END IF;

  PERFORM 1
  FROM public.medicines m
  WHERE m.id = p_medicine_id AND m.deleted_at IS NULL
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'medicine not found';
  END IF;

  IF p_supplier_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.suppliers s
    WHERE s.id = p_supplier_id AND s.deleted_at IS NULL AND s.active IS TRUE
  ) THEN
    RAISE EXCEPTION 'active supplier not found';
  END IF;

  INSERT INTO public.pharmacy_inventory (
    medicine_id, supplier_id, batch_number, quantity_received, quantity_remaining,
    quantity, purchase_price, selling_price, manufacture_date, expiry_date,
    invoice_reference, branch_id, created_by, updated_by
  )
  VALUES (
    p_medicine_id, p_supplier_id, p_batch_number, p_quantity, p_quantity,
    p_quantity, p_purchase_price, p_selling_price, p_manufacture_date, p_expiry_date,
    p_invoice_reference, v_branch, v_uid, v_uid
  )
  RETURNING id INTO v_batch_id;

  UPDATE public.medicines
  SET stock_quantity = stock_quantity + p_quantity::integer,
      updated_at = now(),
      updated_by = v_uid
  WHERE id = p_medicine_id;

  INSERT INTO public.stock_movements (
    medicine_id, batch_id, movement_type, quantity, reference_id,
    reference_table, branch_id, created_by
  )
  VALUES (
    p_medicine_id, v_batch_id, 'purchase', p_quantity, v_batch_id,
    'pharmacy_inventory', v_branch, v_uid
  );

  RETURN v_batch_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.receive_pharmacy_stock(uuid, numeric, uuid, text, numeric, numeric, date, date, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.receive_pharmacy_stock(uuid, numeric, uuid, text, numeric, numeric, date, date, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.receive_pharmacy_stock(uuid, numeric, uuid, text, numeric, numeric, date, date, text) TO authenticated;
