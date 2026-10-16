CREATE OR REPLACE FUNCTION public.fn_receive_pharmacy_batch(p_medicine_id uuid, p_quantity numeric, p_batch_number text DEFAULT NULL::text, p_expiry_date date DEFAULT NULL::date, p_manufacture_date date DEFAULT NULL::date, p_purchase_price numeric DEFAULT 0, p_selling_price numeric DEFAULT NULL::numeric, p_supplier_id uuid DEFAULT NULL::uuid, p_invoice_reference text DEFAULT NULL::text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_branch uuid;
  v_batch_id uuid;
  v_sell numeric;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update') THEN RAISE EXCEPTION 'insufficient_permission' USING ERRCODE = '42501'; END IF;
  IF p_quantity IS NULL OR p_quantity <> pg_catalog.trunc(p_quantity) OR p_quantity <= 0 THEN RAISE EXCEPTION 'invalid_quantity'; END IF;
  IF p_purchase_price IS NULL OR p_purchase_price < 0 THEN RAISE EXCEPTION 'invalid_purchase_price'; END IF;
  IF p_expiry_date IS NOT NULL AND p_manufacture_date IS NOT NULL AND p_manufacture_date > p_expiry_date THEN RAISE EXCEPTION 'manufacture_after_expiry'; END IF;
  SELECT u.branch_id INTO v_branch FROM public.users AS u WHERE u.id = v_uid AND u.deleted_at IS NULL;
  IF NOT public.is_super_admin() AND v_branch IS NULL THEN RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE = '42501'; END IF;
  SELECT COALESCE(p_selling_price, m.selling_price, 0) INTO v_sell FROM public.medicines AS m WHERE m.id = p_medicine_id AND m.deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'medicine_not_found'; END IF;
  INSERT INTO public.pharmacy_inventory (medicine_id,batch_number,batch_no,expiry_date,manufacture_date,quantity,quantity_received,quantity_remaining,purchase_price,selling_price,supplier_id,invoice_reference,branch_id,created_by,updated_by)
  VALUES (p_medicine_id,NULLIF(pg_catalog.btrim(p_batch_number),''),NULLIF(pg_catalog.btrim(p_batch_number),''),p_expiry_date,p_manufacture_date,p_quantity,p_quantity,p_quantity,p_purchase_price,v_sell,p_supplier_id,NULLIF(pg_catalog.btrim(p_invoice_reference),''),v_branch,v_uid,v_uid)
  RETURNING id INTO v_batch_id;
  UPDATE public.medicines SET stock_quantity=COALESCE(stock_quantity,0)+p_quantity::integer,cost_price=p_purchase_price,selling_price=v_sell,updated_at=pg_catalog.now(),updated_by=v_uid WHERE id=p_medicine_id;
  INSERT INTO public.stock_movements (medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by)
  VALUES (p_medicine_id,v_batch_id,'purchase',p_quantity,v_batch_id,'pharmacy_inventory',v_branch,v_uid);
  RETURN v_batch_id;
END;
$function$;
