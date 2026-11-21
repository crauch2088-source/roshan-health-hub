-- Phase 62 (RHH-01): Pharmacy pre-handover cancellation, post-handover quarantine return, and immutable financial compensation.
-- PostgreSQL 17 compatible. Does not modify historical invoices or automatically restock returned medicines.

ALTER TABLE public.prescriptions
  ADD COLUMN IF NOT EXISTS handed_over_at timestamptz,
  ADD COLUMN IF NOT EXISTS handed_over_by uuid;

CREATE TABLE IF NOT EXISTS public.financial_compensations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_invoice_id uuid NOT NULL REFERENCES public.invoices(id) ON DELETE RESTRICT,
  source_event_type text NOT NULL CHECK (source_event_type IN ('pre_handover_cancellation', 'post_handover_return')),
  source_event_id uuid NOT NULL,
  invoice_payment_state text NOT NULL CHECK (invoice_payment_state IN ('unpaid', 'partially_paid', 'paid')),
  credit_amount numeric(12,2) NOT NULL CHECK (credit_amount >= 0),
  refund_due_amount numeric(12,2) NOT NULL CHECK (refund_due_amount >= 0),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  branch_id uuid NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  idempotency_key uuid NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.pharmacy_dispense_cancellations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id uuid NOT NULL UNIQUE REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL,
  cancelled_by uuid NOT NULL,
  cancelled_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  restocked_total numeric NOT NULL DEFAULT 0 CHECK (restocked_total >= 0),
  compensation_id uuid REFERENCES public.financial_compensations(id) ON DELETE RESTRICT,
  idempotency_key uuid NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.pharmacy_returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id uuid NOT NULL REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
  medicine_id uuid NOT NULL REFERENCES public.medicines(id) ON DELETE RESTRICT,
  batch_id uuid NOT NULL REFERENCES public.pharmacy_inventory(id) ON DELETE RESTRICT,
  quantity numeric NOT NULL CHECK (quantity > 0),
  condition text NOT NULL CHECK (condition IN ('unopened_intact', 'opened', 'damaged', 'expired', 'contaminated', 'uncertain')),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  returned_by uuid NOT NULL,
  returned_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  branch_id uuid NOT NULL,
  compensation_id uuid REFERENCES public.financial_compensations(id) ON DELETE RESTRICT,
  idempotency_key uuid NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.pharmacy_return_quarantine (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  return_id uuid NOT NULL UNIQUE REFERENCES public.pharmacy_returns(id) ON DELETE RESTRICT,
  medicine_id uuid NOT NULL REFERENCES public.medicines(id) ON DELETE RESTRICT,
  batch_id uuid NOT NULL REFERENCES public.pharmacy_inventory(id) ON DELETE RESTRICT,
  quantity numeric NOT NULL CHECK (quantity > 0),
  condition text NOT NULL CHECK (condition IN ('unopened_intact', 'opened', 'damaged', 'expired', 'contaminated', 'uncertain')),
  branch_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'quarantined' CHECK (status IN ('quarantined', 'approved_restock', 'destroyed_writeoff', 'returned_to_supplier')),
  disposition_by uuid,
  disposition_at timestamptz,
  disposition_notes text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION private.reject_phase62_append_only_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  RAISE EXCEPTION 'phase62 ledger table % is append-only', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$$;
REVOKE ALL ON FUNCTION private.reject_phase62_append_only_mutation() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_financial_compensations_immutable ON public.financial_compensations;
CREATE TRIGGER trg_financial_compensations_immutable
  BEFORE UPDATE OR DELETE ON public.financial_compensations
  FOR EACH ROW EXECUTE FUNCTION private.reject_phase62_append_only_mutation();

DROP TRIGGER IF EXISTS trg_pharmacy_cancellations_immutable ON public.pharmacy_dispense_cancellations;
CREATE TRIGGER trg_pharmacy_cancellations_immutable
  BEFORE UPDATE OR DELETE ON public.pharmacy_dispense_cancellations
  FOR EACH ROW EXECUTE FUNCTION private.reject_phase62_append_only_mutation();

DROP TRIGGER IF EXISTS trg_pharmacy_returns_immutable ON public.pharmacy_returns;
CREATE TRIGGER trg_pharmacy_returns_immutable
  BEFORE UPDATE OR DELETE ON public.pharmacy_returns
  FOR EACH ROW EXECUTE FUNCTION private.reject_phase62_append_only_mutation();

ALTER TABLE public.financial_compensations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_compensations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_dispense_cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_dispense_cancellations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_returns FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_return_quarantine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_return_quarantine FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS financial_compensations_select ON public.financial_compensations;
CREATE POLICY financial_compensations_select ON public.financial_compensations
  FOR SELECT TO authenticated
  USING (public.app_has_perm('pharmacy.read') AND private.app_has_branch_access(branch_id));

DROP POLICY IF EXISTS pharmacy_cancellations_select ON public.pharmacy_dispense_cancellations;
CREATE POLICY pharmacy_cancellations_select ON public.pharmacy_dispense_cancellations
  FOR SELECT TO authenticated
  USING (public.app_has_perm('pharmacy.read') AND private.app_has_branch_access(branch_id));

DROP POLICY IF EXISTS pharmacy_returns_select ON public.pharmacy_returns;
CREATE POLICY pharmacy_returns_select ON public.pharmacy_returns
  FOR SELECT TO authenticated
  USING (public.app_has_perm('pharmacy.read') AND private.app_has_branch_access(branch_id));

DROP POLICY IF EXISTS pharmacy_return_quarantine_select ON public.pharmacy_return_quarantine;
CREATE POLICY pharmacy_return_quarantine_select ON public.pharmacy_return_quarantine
  FOR SELECT TO authenticated
  USING (public.app_has_perm('pharmacy.read') AND private.app_has_branch_access(branch_id));

REVOKE ALL ON TABLE public.financial_compensations, public.pharmacy_dispense_cancellations, public.pharmacy_returns, public.pharmacy_return_quarantine FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.financial_compensations, public.pharmacy_dispense_cancellations, public.pharmacy_returns, public.pharmacy_return_quarantine TO authenticated;
CREATE OR REPLACE FUNCTION public.confirm_pharmacy_handover(p_prescription_id uuid)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_rx record;
  v_branch_id uuid;
  v_now timestamptz;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'pharmacy_handover_permission_denied' USING ERRCODE = '42501';
  END IF;

  SELECT p.id, p.status, p.handed_over_at, COALESCE(v.branch_id, pt.branch_id) AS branch_id
    INTO v_rx
    FROM public.prescriptions p
    LEFT JOIN public.visits v ON v.id = p.visit_id
    LEFT JOIN public.patients pt ON pt.id = p.patient_id
   WHERE p.id = p_prescription_id AND p.deleted_at IS NULL
     FOR UPDATE OF p;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_not_found' USING ERRCODE = 'P0002';
  END IF;

  v_branch_id := v_rx.branch_id;
  IF v_branch_id IS NULL OR NOT private.app_has_branch_access(v_branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;

  IF v_rx.status <> 'dispensed' THEN
    RAISE EXCEPTION 'prescription_not_dispensed' USING ERRCODE = '22023';
  END IF;

  IF v_rx.handed_over_at IS NOT NULL THEN
    RETURN v_rx.handed_over_at;
  END IF;

  v_now := clock_timestamp();
  UPDATE public.prescriptions
     SET handed_over_at = v_now,
         handed_over_by = v_uid,
         updated_at = v_now,
         updated_by = v_uid
   WHERE id = p_prescription_id;

  RETURN v_now;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_dispense_before_handover(
  p_prescription_id uuid,
  p_reason text,
  p_idempotency_key uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_existing_id uuid;
  v_rx record;
  v_inv record;
  v_mov record;
  v_cancel_id uuid := gen_random_uuid();
  v_comp_id uuid := NULL;
  v_restocked numeric := 0;
  v_credit numeric(12,2) := 0;
  v_refund_due numeric(12,2) := 0;
  v_pay_state text;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'pharmacy_cancel_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase62:' || p_idempotency_key::text, 0));
    IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'cancellation_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_existing_id
    FROM public.pharmacy_dispense_cancellations
   WHERE idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN v_existing_id;
  END IF;

  SELECT p.id, p.visit_id, p.patient_id, p.status, p.handed_over_at,
         COALESCE(v.branch_id, pt.branch_id) AS branch_id
    INTO v_rx
    FROM public.prescriptions p
    LEFT JOIN public.visits v ON v.id = p.visit_id
    LEFT JOIN public.patients pt ON pt.id = p.patient_id
   WHERE p.id = p_prescription_id AND p.deleted_at IS NULL
     FOR UPDATE OF p;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_rx.branch_id IS NULL OR NOT private.app_has_branch_access(v_rx.branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_rx.handed_over_at IS NOT NULL THEN
    RAISE EXCEPTION 'handover_already_recorded_use_return_workflow' USING ERRCODE = '22023';
  END IF;
  IF v_rx.status = 'cancelled' THEN
    RAISE EXCEPTION 'dispense_already_cancelled' USING ERRCODE = '22023';
  END IF;
  IF v_rx.status <> 'dispensed' THEN
    RAISE EXCEPTION 'prescription_not_dispensed' USING ERRCODE = '22023';
  END IF;

  FOR v_mov IN
    SELECT sm.medicine_id, sm.batch_id, ABS(sm.quantity) AS qty
      FROM public.stock_movements sm
     WHERE sm.reference_id = p_prescription_id
       AND sm.reference_table = 'prescriptions'
       AND sm.movement_type = 'dispense'
     ORDER BY sm.created_at, sm.id
  LOOP
    PERFORM 1 FROM public.pharmacy_inventory WHERE id = v_mov.batch_id FOR UPDATE;
    UPDATE public.pharmacy_inventory
       SET quantity_remaining = quantity_remaining + v_mov.qty,
           updated_at = clock_timestamp(),
           updated_by = v_uid
     WHERE id = v_mov.batch_id;

    UPDATE public.medicines
       SET stock_quantity = stock_quantity + v_mov.qty::integer,
           updated_at = clock_timestamp(),
           updated_by = v_uid
     WHERE id = v_mov.medicine_id;

    INSERT INTO public.stock_movements (
      medicine_id, batch_id, movement_type, quantity,
      reference_id, reference_table, notes, branch_id, created_by
    ) VALUES (
      v_mov.medicine_id, v_mov.batch_id, 'cancellation_restock', v_mov.qty,
      v_cancel_id, 'pharmacy_dispense_cancellations', trim(p_reason), v_rx.branch_id, v_uid
    );
    v_restocked := v_restocked + v_mov.qty;
  END LOOP;

  SELECT COALESCE(SUM(COALESCE(pi.dispensed_quantity, 0) * COALESCE(pi.unit_price, 0)), 0)::numeric(12,2)
    INTO v_credit
    FROM public.prescription_items pi
   WHERE pi.prescription_id = p_prescription_id AND pi.deleted_at IS NULL;

  SELECT i.id, COALESCE(i.net_amount, i.total_amount, 0) AS net_amount, COALESCE(i.paid_amount, 0) AS paid_amount
    INTO v_inv
    FROM public.invoices i
   WHERE i.deleted_at IS NULL
     AND i.patient_id = v_rx.patient_id AND ((v_rx.visit_id IS NOT NULL AND i.visit_id = v_rx.visit_id) OR (v_rx.visit_id IS NULL AND i.visit_id IS NULL)) AND i.branch_id = v_rx.branch_id
   ORDER BY i.created_at DESC
   LIMIT 1
     FOR UPDATE;

  IF FOUND THEN
    IF v_inv.paid_amount <= 0 THEN
      v_pay_state := 'unpaid';
      v_refund_due := 0;
    ELSIF v_inv.paid_amount < v_inv.net_amount THEN
      v_pay_state := 'partially_paid';
      v_refund_due := LEAST(v_inv.paid_amount, v_credit);
    ELSE
      v_pay_state := 'paid';
      v_refund_due := LEAST(v_inv.paid_amount, v_credit);
    END IF;

    INSERT INTO public.financial_compensations (
      source_invoice_id, source_event_type, source_event_id,
      invoice_payment_state, credit_amount, refund_due_amount,
      reason, branch_id, created_by, idempotency_key
    ) VALUES (
      v_inv.id, 'pre_handover_cancellation', v_cancel_id,
      v_pay_state, v_credit, v_refund_due,
      trim(p_reason), v_rx.branch_id, v_uid, p_idempotency_key
    ) RETURNING id INTO v_comp_id;
  END IF;

  UPDATE public.prescriptions
     SET status = 'cancelled',
         updated_at = clock_timestamp(),
         updated_by = v_uid
   WHERE id = p_prescription_id;

  UPDATE public.prescription_items
     SET is_dispensed = false,
         dispensed_quantity = 0,
         updated_at = clock_timestamp(),
         updated_by = v_uid
   WHERE prescription_id = p_prescription_id AND deleted_at IS NULL;

  INSERT INTO public.pharmacy_dispense_cancellations (
    id, prescription_id, branch_id, cancelled_by, reason,
    restocked_total, compensation_id, idempotency_key
  ) VALUES (
    v_cancel_id, p_prescription_id, v_rx.branch_id, v_uid, trim(p_reason),
    v_restocked, v_comp_id, p_idempotency_key
  );

  RETURN v_cancel_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_post_handover_return(
  p_prescription_id uuid,
  p_medicine_id uuid,
  p_batch_id uuid,
  p_quantity numeric,
  p_condition text,
  p_reason text,
  p_idempotency_key uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_existing_id uuid;
  v_rx record;
  v_inv record;
  v_dispensed_qty numeric := 0;
  v_returned_qty numeric := 0;
  v_unit_price numeric := 0;
  v_return_id uuid := gen_random_uuid();
  v_comp_id uuid := NULL;
  v_credit numeric(12,2) := 0;
  v_refund_due numeric(12,2) := 0;
  v_pay_state text;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'pharmacy_return_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase62:' || p_idempotency_key::text, 0));
IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'return_quantity_must_be_positive' USING ERRCODE = '22023';
  END IF;
  IF p_condition NOT IN ('unopened_intact', 'opened', 'damaged', 'expired', 'contaminated', 'uncertain') THEN
    RAISE EXCEPTION 'invalid_return_condition' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'return_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_existing_id
    FROM public.pharmacy_returns
   WHERE idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN v_existing_id;
  END IF;

  SELECT p.id, p.visit_id, p.patient_id, p.status, p.handed_over_at,
         COALESCE(v.branch_id, pt.branch_id) AS branch_id
    INTO v_rx
    FROM public.prescriptions p
    LEFT JOIN public.visits v ON v.id = p.visit_id
    LEFT JOIN public.patients pt ON pt.id = p.patient_id
   WHERE p.id = p_prescription_id AND p.deleted_at IS NULL
     FOR UPDATE OF p;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'prescription_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_rx.branch_id IS NULL OR NOT private.app_has_branch_access(v_rx.branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_rx.handed_over_at IS NULL THEN
    RAISE EXCEPTION 'return_requires_handover_use_cancellation' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(SUM(ABS(sm.quantity)), 0)
    INTO v_dispensed_qty
    FROM public.stock_movements sm
   WHERE sm.reference_id = p_prescription_id
     AND sm.reference_table = 'prescriptions'
     AND sm.movement_type = 'dispense'
     AND sm.medicine_id = p_medicine_id
     AND sm.batch_id = p_batch_id;

  SELECT COALESCE(SUM(pr.quantity), 0)
    INTO v_returned_qty
    FROM public.pharmacy_returns pr
   WHERE pr.prescription_id = p_prescription_id
     AND pr.medicine_id = p_medicine_id
     AND pr.batch_id = p_batch_id;

  IF v_dispensed_qty <= 0 OR (v_returned_qty + p_quantity) > v_dispensed_qty THEN
    RAISE EXCEPTION 'return_quantity_exceeds_dispensed' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(pi.unit_price, m.selling_price, 0)
    INTO v_unit_price
    FROM public.medicines m
    LEFT JOIN public.prescription_items pi
      ON pi.prescription_id = p_prescription_id AND pi.medicine_id = m.id AND pi.deleted_at IS NULL
   WHERE m.id = p_medicine_id
   LIMIT 1;

  v_credit := ROUND((p_quantity * COALESCE(v_unit_price, 0))::numeric, 2);

  SELECT i.id, COALESCE(i.net_amount, i.total_amount, 0) AS net_amount, COALESCE(i.paid_amount, 0) AS paid_amount
    INTO v_inv
    FROM public.invoices i
   WHERE i.deleted_at IS NULL
     AND i.patient_id = v_rx.patient_id AND ((v_rx.visit_id IS NOT NULL AND i.visit_id = v_rx.visit_id) OR (v_rx.visit_id IS NULL AND i.visit_id IS NULL)) AND i.branch_id = v_rx.branch_id
   ORDER BY i.created_at DESC
   LIMIT 1
     FOR UPDATE;

  IF FOUND THEN
    IF v_inv.paid_amount <= 0 THEN
      v_pay_state := 'unpaid';
      v_refund_due := 0;
    ELSIF v_inv.paid_amount < v_inv.net_amount THEN
      v_pay_state := 'partially_paid';
      v_refund_due := LEAST(v_inv.paid_amount, v_credit);
    ELSE
      v_pay_state := 'paid';
      v_refund_due := LEAST(v_inv.paid_amount, v_credit);
    END IF;

    INSERT INTO public.financial_compensations (
      source_invoice_id, source_event_type, source_event_id,
      invoice_payment_state, credit_amount, refund_due_amount,
      reason, branch_id, created_by, idempotency_key
    ) VALUES (
      v_inv.id, 'post_handover_return', v_return_id,
      v_pay_state, v_credit, v_refund_due,
      trim(p_reason), v_rx.branch_id, v_uid, p_idempotency_key
    ) RETURNING id INTO v_comp_id;
  END IF;

  INSERT INTO public.pharmacy_returns (
    id, prescription_id, medicine_id, batch_id, quantity,
    condition, reason, returned_by, branch_id, compensation_id, idempotency_key
  ) VALUES (
    v_return_id, p_prescription_id, p_medicine_id, p_batch_id, p_quantity,
    p_condition, trim(p_reason), v_uid, v_rx.branch_id, v_comp_id, p_idempotency_key
  );

  INSERT INTO public.pharmacy_return_quarantine (
    return_id, medicine_id, batch_id, quantity, condition, branch_id, status
  ) VALUES (
    v_return_id, p_medicine_id, p_batch_id, p_quantity, p_condition, v_rx.branch_id, 'quarantined'
  );

  -- Record non-saleable quarantine receipt in ledger; NEVER increments saleable stock automatically.
  INSERT INTO public.stock_movements (
    medicine_id, batch_id, movement_type, quantity,
    reference_id, reference_table, notes, branch_id, created_by
  ) VALUES (
    p_medicine_id, p_batch_id, 'return_quarantine', p_quantity,
    v_return_id, 'pharmacy_returns', p_condition || ': ' || trim(p_reason), v_rx.branch_id, v_uid
  );

  RETURN v_return_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_quarantine_disposition(
  p_quarantine_id uuid,
  p_disposition text,
  p_notes text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_q record;
  v_batch record;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'quarantine_disposition_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_disposition NOT IN ('approved_restock', 'destroyed_writeoff', 'returned_to_supplier') THEN
    RAISE EXCEPTION 'invalid_quarantine_disposition' USING ERRCODE = '22023';
  END IF;
  IF p_notes IS NULL OR length(trim(p_notes)) = 0 THEN
    RAISE EXCEPTION 'disposition_notes_required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_q
    FROM public.pharmacy_return_quarantine
   WHERE id = p_quarantine_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'quarantine_record_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.app_has_branch_access(v_q.branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_q.status <> 'quarantined' THEN
    RAISE EXCEPTION 'quarantine_already_resolved' USING ERRCODE = '22023';
  END IF;

  IF p_disposition = 'approved_restock' THEN
    IF v_q.condition <> 'unopened_intact' THEN
      RAISE EXCEPTION 'only_unopened_intact_may_be_restocked' USING ERRCODE = '22023';
    END IF;

    SELECT id, expiry_date INTO v_batch
      FROM public.pharmacy_inventory
     WHERE id = v_q.batch_id
       FOR UPDATE;

    IF v_batch.expiry_date IS NOT NULL AND v_batch.expiry_date <= CURRENT_DATE THEN
      RAISE EXCEPTION 'cannot_restock_expired_batch' USING ERRCODE = '22023';
    END IF;

    UPDATE public.pharmacy_inventory
       SET quantity_remaining = quantity_remaining + v_q.quantity,
           updated_at = clock_timestamp(),
           updated_by = v_uid
     WHERE id = v_q.batch_id;

    UPDATE public.medicines
       SET stock_quantity = stock_quantity + v_q.quantity::integer,
           updated_at = clock_timestamp(),
           updated_by = v_uid
     WHERE id = v_q.medicine_id;

    INSERT INTO public.stock_movements (
      medicine_id, batch_id, movement_type, quantity,
      reference_id, reference_table, notes, branch_id, created_by
    ) VALUES (
      v_q.medicine_id, v_q.batch_id, 'quarantine_restock', v_q.quantity,
      v_q.id, 'pharmacy_return_quarantine', trim(p_notes), v_q.branch_id, v_uid
    );
  ELSE
    INSERT INTO public.stock_movements (
      medicine_id, batch_id, movement_type, quantity,
      reference_id, reference_table, notes, branch_id, created_by
    ) VALUES (
      v_q.medicine_id, v_q.batch_id,
      CASE WHEN p_disposition = 'destroyed_writeoff' THEN 'quarantine_writeoff' ELSE 'quarantine_supplier_return' END,
      0, v_q.id, 'pharmacy_return_quarantine', trim(p_notes), v_q.branch_id, v_uid
    );
  END IF;

  UPDATE public.pharmacy_return_quarantine
     SET status = p_disposition,
         disposition_by = v_uid,
         disposition_at = clock_timestamp(),
         disposition_notes = trim(p_notes)
   WHERE id = p_quarantine_id;

  RETURN p_disposition;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_pharmacy_handover(uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.cancel_dispense_before_handover(uuid, text, uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.record_post_handover_return(uuid, uuid, uuid, numeric, text, text, uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.resolve_quarantine_disposition(uuid, text, text) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.confirm_pharmacy_handover(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_dispense_before_handover(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_post_handover_return(uuid, uuid, uuid, numeric, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_quarantine_disposition(uuid, text, text) TO authenticated;
