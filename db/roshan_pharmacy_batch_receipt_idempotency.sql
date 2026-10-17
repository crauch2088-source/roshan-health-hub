-- Add durable request idempotency to the atomic pharmacy batch receipt path.
BEGIN;

ALTER TABLE public.pharmacy_inventory
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS pharmacy_inventory_idempotency_key_unique
  ON public.pharmacy_inventory(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

COMMENT ON COLUMN public.pharmacy_inventory.idempotency_key IS
  'Client request key for safe retry of atomic batch receipts; null for legacy rows.';

CREATE OR REPLACE FUNCTION public.fn_receive_pharmacy_batch_atomic(
  p_medicine_id uuid,
  p_quantity numeric,
  p_batch_number text,
  p_expiry_date date,
  p_manufacture_date date,
  p_purchase_price numeric,
  p_selling_price numeric,
  p_supplier_id uuid,
  p_invoice_reference text,
  p_idempotency_key text
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
  v_sell numeric;
  v_key text;
  existing public.pharmacy_inventory;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update') THEN
    RAISE EXCEPTION 'insufficient_permission' USING ERRCODE = '42501';
  END IF;

  IF p_idempotency_key IS NULL
     OR pg_catalog.length(pg_catalog.btrim(p_idempotency_key)) = 0
     OR pg_catalog.length(pg_catalog.btrim(p_idempotency_key)) > 128 THEN
    RAISE EXCEPTION 'invalid_idempotency_key' USING ERRCODE = '22023';
  END IF;
  v_key := pg_catalog.btrim(p_idempotency_key);

  IF p_quantity IS NULL
     OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_quantity <> pg_catalog.trunc(p_quantity)
     OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'invalid_quantity' USING ERRCODE = '22023';
  END IF;

  IF p_purchase_price IS NULL
     OR p_purchase_price::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_purchase_price < 0
     OR p_purchase_price <> pg_catalog.round(p_purchase_price, 2) THEN
    RAISE EXCEPTION 'invalid_purchase_price' USING ERRCODE = '22023';
  END IF;

  IF p_expiry_date IS NOT NULL
     AND p_manufacture_date IS NOT NULL
     AND p_manufacture_date > p_expiry_date THEN
    RAISE EXCEPTION 'manufacture_after_expiry' USING ERRCODE = '22023';
  END IF;

  SELECT u.branch_id INTO v_branch
    FROM public.users AS u
   WHERE u.id = v_uid AND u.deleted_at IS NULL;

  IF NOT public.is_super_admin() AND v_branch IS NULL THEN
    RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('roshan.pharmacy.receive:' || v_key, 0)
  );

  SELECT b.* INTO existing
    FROM public.pharmacy_inventory AS b
   WHERE b.idempotency_key = v_key;

  IF FOUND THEN
    IF existing.medicine_id IS DISTINCT FROM p_medicine_id
       OR existing.quantity_received IS DISTINCT FROM p_quantity
       OR existing.batch_number IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_batch_number), '')
       OR existing.expiry_date IS DISTINCT FROM p_expiry_date
       OR existing.manufacture_date IS DISTINCT FROM p_manufacture_date
       OR existing.purchase_price IS DISTINCT FROM p_purchase_price
       OR (p_selling_price IS NOT NULL AND existing.selling_price IS DISTINCT FROM p_selling_price)
       OR existing.supplier_id IS DISTINCT FROM p_supplier_id
       OR existing.invoice_reference IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_invoice_reference), '')
       OR existing.branch_id IS DISTINCT FROM v_branch
       OR existing.created_by IS DISTINCT FROM v_uid THEN
      RAISE EXCEPTION 'idempotency key reused with different pharmacy receipt request'
        USING ERRCODE = '22023';
    END IF;
    RETURN existing.id;
  END IF;

  SELECT COALESCE(p_selling_price, m.selling_price, 0)
    INTO v_sell
    FROM public.medicines AS m
   WHERE m.id = p_medicine_id AND m.deleted_at IS NULL
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'medicine_not_found' USING ERRCODE = '22023';
  END IF;

  IF v_sell::text IN ('NaN', 'Infinity', '-Infinity')
     OR v_sell < 0
     OR v_sell <> pg_catalog.round(v_sell, 2) THEN
    RAISE EXCEPTION 'invalid_selling_price' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.pharmacy_inventory (
    medicine_id, batch_number, batch_no, expiry_date, manufacture_date,
    quantity, quantity_received, quantity_remaining, purchase_price, selling_price,
    supplier_id, invoice_reference, branch_id, created_by, updated_by, idempotency_key
  )
  VALUES (
    p_medicine_id,
    NULLIF(pg_catalog.btrim(p_batch_number), ''),
    NULLIF(pg_catalog.btrim(p_batch_number), ''),
    p_expiry_date, p_manufacture_date,
    p_quantity, p_quantity, p_quantity, p_purchase_price, v_sell,
    p_supplier_id, NULLIF(pg_catalog.btrim(p_invoice_reference), ''),
    v_branch, v_uid, v_uid, v_key
  )
  RETURNING id INTO v_batch_id;

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
  )
  VALUES (
    p_medicine_id, v_batch_id, 'purchase', p_quantity, v_batch_id,
    'pharmacy_inventory', v_branch, v_uid
  );

  RETURN v_batch_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_receive_pharmacy_batch_atomic(uuid,numeric,text,date,date,numeric,numeric,uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_receive_pharmacy_batch_atomic(uuid,numeric,text,date,date,numeric,numeric,uuid,text,text) TO authenticated;

COMMIT;
