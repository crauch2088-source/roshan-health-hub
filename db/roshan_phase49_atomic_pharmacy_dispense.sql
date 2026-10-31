-- Phase 49: idempotent, branch-safe, expiry-safe pharmacy dispensing.
-- Candidate only. Replay on disposable PostgreSQL 17 before any QA/production use.
BEGIN;

ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.medicines, public.pharmacy_inventory,
  public.stock_movements, public.prescriptions, public.prescription_items FROM anon;

-- Stock movements are a ledger: browser users can read their branch only; writes
-- must pass through audited atomic SECURITY DEFINER RPCs.
REVOKE ALL ON TABLE public.stock_movements, public.pharmacy_inventory FROM PUBLIC, authenticated;
GRANT SELECT ON TABLE public.stock_movements, public.pharmacy_inventory TO authenticated;
DROP POLICY IF EXISTS stock_movements_select ON public.stock_movements;
CREATE POLICY stock_movements_select ON public.stock_movements
  FOR SELECT TO authenticated
  USING (
    (SELECT public.app_has_perm('pharmacy.read'))
    AND (SELECT private.app_has_branch_access(stock_movements.branch_id))
  );
COMMENT ON POLICY stock_movements_select ON public.stock_movements IS
  'Authenticated, permission-checked, branch-scoped SELECT only; all ledger writes are RPC-only.';

CREATE OR REPLACE FUNCTION private.guard_pharmacy_batch_expiry()
RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
BEGIN
  IF NEW.quantity_received > 0 AND NEW.expiry_date IS NULL THEN
    RAISE EXCEPTION 'pharmacy_batch_expiry_required' USING ERRCODE = '22023';
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.quantity_remaining > 0 AND NEW.expiry_date < CURRENT_DATE THEN
      RAISE EXCEPTION 'expired_batch_cannot_be_received' USING ERRCODE = '22023';
    END IF;
  ELSE
    IF NEW.quantity_remaining > 0 AND NEW.expiry_date < CURRENT_DATE
       AND (NEW.expiry_date IS DISTINCT FROM OLD.expiry_date
         OR NEW.quantity_received > OLD.quantity_received) THEN
      RAISE EXCEPTION 'expired_batch_cannot_be_received_or_reactivated' USING ERRCODE = '22023';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS trg_pharmacy_inventory_expiry_guard ON public.pharmacy_inventory;
CREATE TRIGGER trg_pharmacy_inventory_expiry_guard
  BEFORE INSERT OR UPDATE OF expiry_date, quantity_received
  ON public.pharmacy_inventory FOR EACH ROW
  EXECUTE FUNCTION private.guard_pharmacy_batch_expiry();

CREATE OR REPLACE FUNCTION private.guard_medicine_stock_aggregate()
RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
BEGIN
  IF current_user = 'authenticated' THEN
    IF TG_OP = 'INSERT' AND COALESCE(NEW.stock_quantity,0) <> 0 THEN
      RAISE EXCEPTION 'medicine_stock_is_rpc_managed' USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.stock_quantity IS DISTINCT FROM OLD.stock_quantity THEN
      RAISE EXCEPTION 'medicine_stock_is_rpc_managed' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS trg_guard_medicine_stock_aggregate ON public.medicines;
CREATE TRIGGER trg_guard_medicine_stock_aggregate
  BEFORE INSERT OR UPDATE OF stock_quantity ON public.medicines
  FOR EACH ROW EXECUTE FUNCTION private.guard_medicine_stock_aggregate();
REVOKE ALL ON FUNCTION private.guard_pharmacy_batch_expiry() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION private.guard_medicine_stock_aggregate() FROM PUBLIC, anon, authenticated, service_role;

-- Harden the existing invoice-coupled FEFO implementation: branch ownership is
-- always anchored to the patient, including super-admin dispensing, and a NULL
-- expiry is unknown rather than safe-to-dispense.
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
   WHERE u.id = v_uid AND u.deleted_at IS NULL AND u.active IS TRUE;
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

  -- Even super-admins consume stock only from the patient's own branch.
  IF v_patient_branch IS NULL
     OR (v_visit_id IS NOT NULL AND v_visit_branch IS DISTINCT FROM v_patient_branch) THEN
    RAISE EXCEPTION 'prescription_branch_mismatch' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_super_admin()
     AND (v_branch IS NULL OR v_patient_branch IS DISTINCT FROM v_branch) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.prescription_items AS pi
      LEFT JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND (m.id IS NULL OR m.deleted_at IS NOT NULL
         OR COALESCE(m.active,true) IS NOT TRUE
         OR COALESCE(m.is_active,true) IS NOT TRUE)
  ) THEN
    RAISE EXCEPTION 'prescription contains an inactive or missing catalog medicine';
  END IF;

  -- Build invoice lines from the active medicine catalog before any stock mutation.
  -- Only catalog-linked items that will actually be dispensed can be billed.
  FOR v_item IN
    SELECT pi.id, pi.medicine_id, COALESCE(pi.quantity,1) AS qty,
           COALESCE(NULLIF(btrim(m.name),''),NULLIF(btrim(m.brand_name),''),NULLIF(btrim(m.generic_name),'')) AS name,
           m.selling_price, m.stock_quantity
      FROM public.prescription_items AS pi
      JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND m.deleted_at IS NULL
       AND COALESCE(m.active,true) IS TRUE
       AND COALESCE(m.is_active,true) IS TRUE
     ORDER BY pi.id
     FOR UPDATE OF pi, m
  LOOP
    IF v_item.qty::text IN ('NaN','Infinity','-Infinity')
       OR v_item.qty <= 0 OR v_item.qty <> trunc(v_item.qty)
       OR v_item.qty > 2147483647 THEN
      RAISE EXCEPTION 'prescription quantity must be a finite positive whole number';
    END IF;
    IF v_item.name IS NULL THEN RAISE EXCEPTION 'medicine catalog name is required'; END IF;
    IF COALESCE(v_item.stock_quantity,0) < v_item.qty THEN
      RAISE EXCEPTION 'medicine aggregate stock is insufficient or inconsistent';
    END IF;
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

  -- Aggregate duplicate prescription lines by medicine before changing any stock.
  -- A per-line check alone could allow two individually valid lines to drive the
  -- shared medicine stock_quantity below zero.
  IF EXISTS (
    SELECT 1
      FROM (
        SELECT pi.medicine_id, SUM(COALESCE(pi.quantity,1)) AS required_qty
          FROM public.prescription_items AS pi
         WHERE pi.prescription_id = p_prescription_id
           AND pi.deleted_at IS NULL
           AND pi.medicine_id IS NOT NULL
         GROUP BY pi.medicine_id
      ) AS required
      JOIN public.medicines AS m ON m.id = required.medicine_id
     WHERE required.required_qty > m.stock_quantity
  ) THEN
    RAISE EXCEPTION 'medicine aggregate stock is insufficient or inconsistent';
  END IF;

  -- Consume only branch-assigned, unexpired batches in FEFO order. The legacy
  -- medicine stock balance has no branch owner and must never be used as fallback.
  FOR v_item IN
    SELECT pi.id, pi.medicine_id, COALESCE(pi.quantity,1) AS qty,
           COALESCE(NULLIF(btrim(m.name),''),NULLIF(btrim(m.brand_name),''),NULLIF(btrim(m.generic_name),'')) AS name
      FROM public.prescription_items AS pi
      JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND m.deleted_at IS NULL
       AND COALESCE(m.active,true) IS TRUE
       AND COALESCE(m.is_active,true) IS TRUE
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
         AND inv.expiry_date IS NOT NULL
         AND inv.expiry_date >= CURRENT_DATE
         AND inv.branch_id = v_patient_branch
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
        v_patient_branch,v_uid
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
      -- Legacy medicine.stock_quantity has no branch ownership. Never use it as
      -- a substitute for an assigned, unexpired batch: doing so can consume
      -- another branch's stock or stock with no expiry/audit trail.
      RAISE EXCEPTION 'insufficient_branch_batch_stock: %',v_item.name;
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

-- Keep the legacy entry point available during the compatibility window.
-- Phase17 revokes it only after the new UI is deployed and authenticated smoke tests pass.
REVOKE ALL ON FUNCTION public.fn_dispense_prescription_with_invoice(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_dispense_prescription_with_invoice(uuid, boolean) TO authenticated;


REVOKE ALL ON FUNCTION public.fn_dispense_prescription(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.pharmacy_dispense_idempotency (
  request_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL,
  prescription_id uuid NOT NULL,
  request_payload jsonb NOT NULL,
  result_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  completed_at timestamptz,
  CONSTRAINT pharmacy_dispense_idempotency_payload_array
    CHECK (result_payload IS NULL OR pg_catalog.jsonb_typeof(result_payload) = 'array')
);
ALTER TABLE private.pharmacy_dispense_idempotency ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.pharmacy_dispense_idempotency
  FROM PUBLIC, anon, authenticated, service_role;
CREATE INDEX IF NOT EXISTS pharmacy_dispense_idempotency_actor_created_idx
  ON private.pharmacy_dispense_idempotency(actor_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.atomic_pharmacy_dispense(
  p_prescription_id uuid, p_separate_invoice boolean, p_request_id uuid
)
RETURNS TABLE (
  item_id uuid, medicine_id uuid, medicine_name text, batch_id uuid,
  batch_number text, expiry_date date, quantity_dispensed numeric,
  batch_quantity_remaining numeric, source text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_payload jsonb;
  v_actor uuid;
  v_prescription uuid;
  v_existing_payload jsonb;
  v_result jsonb;
  v_row record;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('pharmacy.update') THEN
    RAISE EXCEPTION 'pharmacy_dispense_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'pharmacy_billing_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_prescription_id IS NULL OR p_separate_invoice IS NULL OR p_request_id IS NULL THEN
    RAISE EXCEPTION 'prescription, invoice choice, and request id are required' USING ERRCODE = '22023';
  END IF;

  v_payload := pg_catalog.jsonb_build_object(
    'prescription_id', p_prescription_id,
    'separate_invoice', p_separate_invoice
  );
  INSERT INTO private.pharmacy_dispense_idempotency(request_id,actor_id,prescription_id,request_payload)
  VALUES(p_request_id,v_uid,p_prescription_id,v_payload)
  ON CONFLICT(request_id) DO NOTHING;

  SELECT d.actor_id,d.prescription_id,d.request_payload,d.result_payload
    INTO v_actor,v_prescription,v_existing_payload,v_result
    FROM private.pharmacy_dispense_idempotency d
   WHERE d.request_id=p_request_id
   FOR UPDATE;

  IF NOT FOUND OR v_actor IS DISTINCT FROM v_uid
     OR v_prescription IS DISTINCT FROM p_prescription_id
     OR v_existing_payload IS DISTINCT FROM v_payload THEN
    RAISE EXCEPTION 'pharmacy_dispense_idempotency_conflict' USING ERRCODE = '22023';
  END IF;

  IF v_result IS NOT NULL THEN
    RETURN QUERY
    SELECT r.item_id,r.medicine_id,r.medicine_name,r.batch_id,r.batch_number,
           r.expiry_date,r.quantity_dispensed,r.batch_quantity_remaining,r.source
      FROM pg_catalog.jsonb_to_recordset(v_result) AS r(
        item_id uuid, medicine_id uuid, medicine_name text, batch_id uuid,
        batch_number text, expiry_date date, quantity_dispensed numeric,
        batch_quantity_remaining numeric, source text
      )
     ORDER BY r.item_id,r.batch_id;
    RETURN;
  END IF;

  v_result := '[]'::jsonb;
  FOR v_row IN
    SELECT * FROM public.fn_dispense_prescription_with_invoice(
      p_prescription_id,p_separate_invoice
    )
  LOOP
    v_result := v_result || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'item_id',v_row.item_id,'medicine_id',v_row.medicine_id,
        'medicine_name',v_row.medicine_name,'batch_id',v_row.batch_id,
        'batch_number',v_row.batch_number,'expiry_date',v_row.expiry_date,
        'quantity_dispensed',v_row.quantity_dispensed,
        'batch_quantity_remaining',v_row.batch_quantity_remaining,'source',v_row.source
      )
    );
  END LOOP;

  UPDATE private.pharmacy_dispense_idempotency
     SET result_payload=v_result,completed_at=pg_catalog.now()
   WHERE request_id=p_request_id;

  RETURN QUERY
  SELECT r.item_id,r.medicine_id,r.medicine_name,r.batch_id,r.batch_number,
         r.expiry_date,r.quantity_dispensed,r.batch_quantity_remaining,r.source
    FROM pg_catalog.jsonb_to_recordset(v_result) AS r(
      item_id uuid, medicine_id uuid, medicine_name text, batch_id uuid,
      batch_number text, expiry_date date, quantity_dispensed numeric,
      batch_quantity_remaining numeric, source text
    )
   ORDER BY r.item_id,r.batch_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.atomic_pharmacy_dispense(uuid,boolean,uuid)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.atomic_pharmacy_dispense(uuid,boolean,uuid) TO authenticated;
COMMENT ON FUNCTION public.atomic_pharmacy_dispense(uuid,boolean,uuid) IS
  'Idempotent FEFO dispense-and-invoice entry point; repeated request IDs replay the exact prior batch result.';

COMMIT;
