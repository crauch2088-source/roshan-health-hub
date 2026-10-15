-- Proposed follow-up migration. Do not apply until migration-history reconciliation,
-- isolated Supabase validation, and authenticated smoke tests are complete.
-- Preserve legacy invoices as primary by default; intentional secondary invoices are explicit.
CREATE SCHEMA IF NOT EXISTS private;
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS is_primary boolean NOT NULL DEFAULT true;

DROP INDEX IF EXISTS public.uq_invoices_visit_id;
CREATE UNIQUE INDEX uq_invoices_visit_id
  ON public.invoices (visit_id)
  WHERE visit_id IS NOT NULL AND deleted_at IS NULL AND is_primary IS TRUE;

CREATE OR REPLACE FUNCTION private.create_or_append_visit_invoice_atomic(
  p_visit_id uuid,
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
  v_user_branch uuid;
  v_patient_id uuid;
  v_patient_branch uuid;
  v_invoice_id uuid;
  v_invoice_number text;
  v_month_key text;
  v_next_no bigint;
  v_item jsonb;
  v_item_name text;
  v_item_type text;
  v_quantity numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_net numeric := 0;
  v_paid numeric := 0;
  v_existing_status text;
  v_existing_payment_status text;
  v_existing_net numeric := 0;
  v_type_count integer := 0;
  v_has_consultation boolean := false;
  v_has_lab boolean := false;
  v_has_pharmacy boolean := false;
  v_has_other boolean := false;
  v_existing boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required' USING ERRCODE = '42501';
  END IF;
  IF p_visit_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'visit and invoice date are required';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invoice items must be a non-empty JSON array';
  END IF;
  IF p_discount IS NULL OR p_discount::text IN ('NaN','Infinity','-Infinity')
     OR p_discount < 0 OR p_discount <> round(p_discount, 2) THEN
    RAISE EXCEPTION 'discount must be finite, non-negative, and have at most two decimal places';
  END IF;
  IF p_separate_invoice IS NULL THEN
    RAISE EXCEPTION 'separate-invoice choice must be explicit';
  END IF;

  SELECT u.branch_id INTO v_user_branch
    FROM public.users AS u
   WHERE u.id = v_uid AND u.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active application user not found' USING ERRCODE = '42501';
  END IF;

  SELECT v.patient_id INTO v_patient_id
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;

  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients AS p
   WHERE p.id = v_patient_id AND p.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active patient not found'; END IF;
  IF NOT public.is_super_admin()
     AND (v_user_branch IS NULL OR v_patient_branch IS DISTINCT FROM v_user_branch) THEN
    RAISE EXCEPTION 'cross-branch invoice access denied' USING ERRCODE = '42501';
  END IF;

  -- Validate incoming line items and derive the narrowest permission required.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each invoice item must be an object';
    END IF;
    v_item_name := btrim(COALESCE(v_item->>'item_name',''));
    v_item_type := CASE WHEN v_item->>'item_type' = 'laboratory' THEN 'lab' ELSE v_item->>'item_type' END;
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
    IF v_item_type = 'consultation' THEN v_has_consultation := true;
    ELSIF v_item_type = 'lab' THEN v_has_lab := true;
    ELSIF v_item_type = 'pharmacy' THEN v_has_pharmacy := true;
    ELSE v_has_other := true;
    END IF;
  END LOOP;

  v_type_count := v_has_consultation::integer + v_has_lab::integer
    + v_has_pharmacy::integer + v_has_other::integer;
  IF p_separate_invoice AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'separate invoices require billing.create' USING ERRCODE = '42501';
  ELSIF v_type_count > 1 AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'mixed-service invoices require billing.create' USING ERRCODE = '42501';
  ELSIF v_has_consultation AND NOT (public.app_has_perm('visits.create') OR public.app_has_perm('billing.create')) THEN
    RAISE EXCEPTION 'consultation invoice permission denied' USING ERRCODE = '42501';
  ELSIF v_has_lab AND NOT (public.app_has_perm('lab.create') OR public.app_has_perm('billing.create')) THEN
    RAISE EXCEPTION 'laboratory invoice permission denied' USING ERRCODE = '42501';
  ELSIF v_has_pharmacy AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'pharmacy line items require the billing workflow RPC' USING ERRCODE = '42501';
  ELSIF v_has_other AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'billing permission denied' USING ERRCODE = '42501';
  END IF;

  -- Serialize invoice selection/creation per visit so simultaneous lab requests
  -- cannot create two primary invoices or race their totals.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('roshan:visit-invoice:' || p_visit_id::text));

  IF NOT p_separate_invoice THEN
    SELECT i.id, COALESCE(i.discount_amount,0), COALESCE(i.paid_amount,0),
           i.status, i.payment_status, COALESCE(i.net_amount,0)
      INTO v_invoice_id, v_discount, v_paid, v_existing_status, v_existing_payment_status, v_existing_net
      FROM public.invoices AS i
     WHERE i.visit_id = p_visit_id AND i.is_primary IS TRUE AND i.deleted_at IS NULL
     FOR UPDATE;
    v_existing := FOUND;
  END IF;

  IF v_existing THEN
    IF p_discount <> 0 THEN
      RAISE EXCEPTION 'discount cannot be changed while appending invoice items';
    END IF;
    -- Consultation creation can be retried after a network timeout; do not double-charge it.
    IF v_has_consultation AND v_type_count = 1 AND EXISTS (
      SELECT 1 FROM public.invoice_items AS ii
       WHERE ii.invoice_id = v_invoice_id
         AND ii.item_type = 'consultation'
         AND ii.deleted_at IS NULL
    ) THEN
      RETURN v_invoice_id;
    END IF;
    IF v_existing_status IN ('paid','closed','finalized')
       OR v_existing_payment_status = 'paid'
       OR (v_existing_net > 0 AND v_paid >= v_existing_net) THEN
      RAISE EXCEPTION 'invoice is finalized; choose a separate invoice';
    END IF;
    IF v_paid < 0 THEN RAISE EXCEPTION 'invalid existing paid amount'; END IF;
    -- Insert only after all authorization and invoice-state checks have passed.
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
    LOOP
      v_item_name := btrim(v_item->>'item_name');
      v_item_type := CASE WHEN v_item->>'item_type' = 'laboratory' THEN 'lab' ELSE v_item->>'item_type' END;
      v_quantity := (v_item->>'quantity')::numeric;
      v_unit_price := (v_item->>'unit_price')::numeric;
      v_line_total := round(v_quantity * v_unit_price, 2);
      INSERT INTO public.invoice_items (
        invoice_id, item_name, item_type, quantity, unit_price, total_price,
        item_id, created_by, updated_by
      ) VALUES (
        v_invoice_id, v_item_name, v_item_type, v_quantity, v_unit_price, v_line_total,
        NULLIF(v_item->>'item_id','')::uuid, v_uid, v_uid
      );
    END LOOP;
    SELECT COALESCE(sum(ii.total_price),0) INTO v_subtotal
      FROM public.invoice_items AS ii
     WHERE ii.invoice_id = v_invoice_id AND ii.deleted_at IS NULL;
    IF v_discount > v_subtotal THEN RAISE EXCEPTION 'existing discount exceeds updated subtotal'; END IF;
    v_net := round(v_subtotal - v_discount, 2);
    IF v_paid > v_net THEN RAISE EXCEPTION 'updated invoice total is below paid amount'; END IF;
    UPDATE public.invoices
       SET subtotal = v_subtotal,
           total_amount = v_subtotal,
           net_amount = v_net,
           status = CASE WHEN v_net > 0 AND v_paid >= v_net THEN 'paid'
                         WHEN v_paid > 0 THEN 'partial' ELSE 'unpaid' END,
           payment_status = CASE WHEN v_net > 0 AND v_paid >= v_net THEN 'paid'
                                 WHEN v_paid > 0 THEN 'partial' ELSE 'unpaid' END,
           updated_by = v_uid,
           updated_at = pg_catalog.now()
     WHERE id = v_invoice_id;
    RETURN v_invoice_id;
  END IF;

  IF p_discount > v_subtotal THEN RAISE EXCEPTION 'discount cannot exceed invoice subtotal'; END IF;
  v_net := round(v_subtotal - p_discount, 2);
  v_month_key := pg_catalog.to_char(pg_catalog.now(), 'YYYYMM');
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('roshan:invoice:' || v_month_key));
  SELECT COALESCE(max((pg_catalog.regexp_match(i.invoice_number, '^INV-[0-9]{6}-([0-9]+)$'))[1]::bigint),0) + 1
    INTO v_next_no
    FROM public.invoices AS i
   WHERE i.invoice_number LIKE 'INV-' || v_month_key || '-%';
  v_invoice_number := 'INV-' || v_month_key || '-' || pg_catalog.lpad(v_next_no::text, 5, '0');

  INSERT INTO public.invoices (
    invoice_number, patient_id, visit_id, invoice_date, total_amount, subtotal,
    discount_amount, net_amount, paid_amount, status, payment_status, branch_id,
    created_by, updated_by, is_primary
  ) VALUES (
    v_invoice_number, v_patient_id, p_visit_id, p_invoice_date, v_subtotal, v_subtotal,
    p_discount, v_net, 0, 'unpaid', 'unpaid', v_patient_branch,
    v_uid, v_uid, NOT p_separate_invoice
  ) RETURNING id INTO v_invoice_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    v_item_name := btrim(v_item->>'item_name');
    v_item_type := CASE WHEN v_item->>'item_type' = 'laboratory' THEN 'lab' ELSE v_item->>'item_type' END;
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    v_line_total := round(v_quantity * v_unit_price, 2);
    INSERT INTO public.invoice_items (
      invoice_id, item_name, item_type, quantity, unit_price, total_price,
      item_id, created_by, updated_by
    ) VALUES (
      v_invoice_id, v_item_name, v_item_type, v_quantity, v_unit_price, v_line_total,
      NULLIF(v_item->>'item_id','')::uuid, v_uid, v_uid
    );
  END LOOP;
  RETURN v_invoice_id;
END;
$function$;

REVOKE ALL ON FUNCTION private.create_or_append_visit_invoice_atomic(uuid,date,numeric,jsonb,boolean) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_visit_consultation_invoice_atomic(
  p_visit_id uuid,
  p_invoice_date date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_fee numeric;
BEGIN
  IF v_uid IS NULL OR NOT (
    public.app_has_perm('visits.create') OR public.app_has_perm('billing.create')
  ) THEN
    RAISE EXCEPTION 'consultation invoice permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_visit_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'visit and invoice date are required';
  END IF;
  SELECT v.consultation_fee INTO v_fee
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  IF v_fee IS NULL OR v_fee::text IN ('NaN','Infinity','-Infinity')
     OR v_fee < 0 OR v_fee <> round(v_fee, 2) THEN
    RAISE EXCEPTION 'visit consultation fee is invalid';
  END IF;
  IF v_fee = 0 THEN RAISE EXCEPTION 'consultation fee is zero'; END IF;

  RETURN private.create_or_append_visit_invoice_atomic(
    p_visit_id, p_invoice_date, 0,
    jsonb_build_array(jsonb_build_object(
      'item_name','Consultation','item_type','consultation','quantity',1,'unit_price',v_fee
    )),
    false
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.create_visit_consultation_invoice_atomic(uuid,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_visit_consultation_invoice_atomic(uuid,date) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_lab_order_with_invoice_atomic(
  p_visit_id uuid,
  p_priority text,
  p_notes text,
  p_test_ids uuid[],
  p_separate_invoice boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_patient_id uuid;
  v_patient_branch uuid;
  v_order_id uuid;
  v_count integer;
  v_invoice_items jsonb;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('lab.create') THEN
    RAISE EXCEPTION 'laboratory order permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_priority IS NULL OR p_priority NOT IN ('normal','urgent','stat') THEN RAISE EXCEPTION 'invalid laboratory priority'; END IF;
  IF p_test_ids IS NULL OR cardinality(p_test_ids) = 0 THEN
    RAISE EXCEPTION 'at least one laboratory test is required';
  END IF;
  IF cardinality(p_test_ids) <> (SELECT count(DISTINCT test_id) FROM unnest(p_test_ids) AS ids(test_id)) THEN
    RAISE EXCEPTION 'duplicate laboratory test ids are not allowed';
  END IF;
  SELECT v.patient_id INTO v_patient_id
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients AS p
   WHERE p.id = v_patient_id AND p.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active patient not found'; END IF;
  IF NOT public.is_super_admin() AND NOT EXISTS (
    SELECT 1 FROM public.users AS u
     WHERE u.id = v_uid AND u.deleted_at IS NULL
       AND u.branch_id IS NOT DISTINCT FROM v_patient_branch
  ) THEN
    RAISE EXCEPTION 'cross-branch laboratory order denied' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_count
    FROM public.lab_tests AS t
   WHERE t.id = ANY(p_test_ids) AND t.active IS TRUE AND t.deleted_at IS NULL;
  IF v_count <> cardinality(p_test_ids) THEN
    RAISE EXCEPTION 'one or more laboratory tests are inactive or missing';
  END IF;

  INSERT INTO public.lab_orders (
    patient_id, visit_id, ordered_by, status, priority, notes, created_by, branch_id
  ) VALUES (
    v_patient_id, p_visit_id, v_uid, 'ordered', p_priority, NULLIF(btrim(p_notes),''), v_uid, v_patient_branch
  ) RETURNING id INTO v_order_id;

  INSERT INTO public.lab_order_items (order_id, test_id, price, created_by)
  SELECT v_order_id, t.id, t.price, v_uid
    FROM unnest(p_test_ids) WITH ORDINALITY AS x(test_id, ordinality)
    JOIN public.lab_tests AS t ON t.id = x.test_id
   ORDER BY x.ordinality;

  SELECT jsonb_agg(jsonb_build_object(
    'item_name', t.name, 'item_type', 'lab', 'quantity', 1,
    'unit_price', t.price, 'item_id', t.id
  ) ORDER BY x.ordinality)
    INTO v_invoice_items
    FROM unnest(p_test_ids) WITH ORDINALITY AS x(test_id, ordinality)
    JOIN public.lab_tests AS t ON t.id = x.test_id;

  PERFORM private.create_or_append_visit_invoice_atomic(
    p_visit_id, CURRENT_DATE, 0, v_invoice_items, p_separate_invoice
  );
  RETURN v_order_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean) TO authenticated;
