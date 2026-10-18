-- Tighten eligibility and make stock-movement writes RPC-only for atomic pharmacy receipt.
BEGIN;

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
  v_existing_stock bigint;
  v_active_branch_count bigint;
  existing public.pharmacy_inventory;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated_application_user_required' USING ERRCODE = '42501';
  END IF;
  IF NOT COALESCE(public.app_has_perm('pharmacy.update'), false) THEN
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
     OR p_quantity <= 0
     OR p_quantity > 2147483647 THEN
    RAISE EXCEPTION 'invalid_quantity' USING ERRCODE = '22023';
  END IF;

  IF p_purchase_price IS NULL
     OR p_purchase_price::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_purchase_price < 0
     OR p_purchase_price <> pg_catalog.round(p_purchase_price, 2) THEN
    RAISE EXCEPTION 'invalid_purchase_price' USING ERRCODE = '22023';
  END IF;

  IF p_selling_price IS NOT NULL
     AND (p_selling_price::text IN ('NaN', 'Infinity', '-Infinity')
       OR p_selling_price < 0
       OR p_selling_price <> pg_catalog.round(p_selling_price, 2)) THEN
    RAISE EXCEPTION 'invalid_selling_price' USING ERRCODE = '22023';
  END IF;

  IF p_expiry_date IS NOT NULL
     AND p_manufacture_date IS NOT NULL
     AND p_manufacture_date > p_expiry_date THEN
    RAISE EXCEPTION 'manufacture_after_expiry' USING ERRCODE = '22023';
  END IF;
  SELECT u.branch_id INTO v_branch
    FROM public.users AS u
   WHERE u.id = v_uid
     AND u.deleted_at IS NULL
     AND u.active IS TRUE
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active_application_user_not_found' USING ERRCODE = '42501';
  END IF;
  -- Branch-scoped dispensing must never receive an orphan batch. A global
  -- super-admin without a profile branch may use the sole active branch; if
  -- zero or multiple branches are active, fail closed because this RPC has no
  -- explicit target-branch argument.
  IF v_branch IS NULL AND public.is_super_admin() THEN
    SELECT count(*), (array_agg(b.id ORDER BY b.id))[1]
      INTO v_active_branch_count, v_branch
      FROM public.branches AS b
     WHERE COALESCE(b.is_active, b.active, false)
       AND b.deleted_at IS NULL;
    IF v_active_branch_count <> 1 THEN
      v_branch := NULL;
    END IF;
  END IF;
  IF v_branch IS NULL THEN
    RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE = '42501';
  END IF;

  PERFORM 1
    FROM public.branches AS b
   WHERE b.id = v_branch
     AND COALESCE(b.is_active, b.active, false)
     AND b.deleted_at IS NULL;
  IF NOT FOUND THEN
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
      RAISE EXCEPTION 'idempotency_key_reused_with_different_receipt'
        USING ERRCODE = '22023';
    END IF;
    RETURN existing.id;
  END IF;

  IF p_expiry_date IS NOT NULL AND p_expiry_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'expired_batch' USING ERRCODE = '22023';
  END IF;
  IF p_manufacture_date IS NOT NULL AND p_manufacture_date > CURRENT_DATE THEN
    RAISE EXCEPTION 'future_manufacture_date' USING ERRCODE = '22023';
  END IF;

  IF p_supplier_id IS NOT NULL THEN
    PERFORM 1
      FROM public.suppliers AS s
     WHERE s.id = p_supplier_id
       AND s.active IS TRUE
       AND s.deleted_at IS NULL
     FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'active_supplier_not_found' USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT COALESCE(m.stock_quantity, 0)::bigint,
         COALESCE(p_selling_price, m.selling_price, 0)
    INTO v_existing_stock, v_sell
    FROM public.medicines AS m
   WHERE m.id = p_medicine_id
     AND m.deleted_at IS NULL
     AND m.active IS TRUE
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'active_medicine_not_found' USING ERRCODE = '22023';
  END IF;

  IF v_sell IS NULL
     OR v_sell::text IN ('NaN', 'Infinity', '-Infinity')
     OR v_sell < 0
     OR v_sell <> pg_catalog.round(v_sell, 2) THEN
    RAISE EXCEPTION 'invalid_selling_price' USING ERRCODE = '22023';
  END IF;
  IF v_existing_stock + p_quantity > 2147483647 THEN
    RAISE EXCEPTION 'stock_quantity_overflow' USING ERRCODE = '22023';
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
     SET stock_quantity = (v_existing_stock + p_quantity)::integer,
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

-- No frontend call site writes to this ledger directly anymore. Keep SELECT
-- under RLS, but force all inserts through guarded SECURITY DEFINER workflows.
DROP POLICY IF EXISTS stock_movements_insert ON public.stock_movements;
REVOKE INSERT ON TABLE public.stock_movements FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.fn_receive_pharmacy_batch_atomic(
  uuid, numeric, text, date, date, numeric, numeric, uuid, text, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_receive_pharmacy_batch_atomic(
  uuid, numeric, text, date, date, numeric, numeric, uuid, text, text
) TO authenticated;

-- The frontend has no remaining call site for the legacy, non-idempotent receive RPC.
-- Keep its definition for rollback/recovery, but remove it from the authenticated API.
REVOKE ALL ON FUNCTION public.fn_receive_pharmacy_batch(
  uuid, numeric, text, date, date, numeric, numeric, uuid, text
) FROM PUBLIC, anon, authenticated;

COMMIT;
