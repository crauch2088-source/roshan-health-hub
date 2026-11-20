-- Phase 63 (RHH-03): Ledger-based inventory adjustments, expiry quarantine, write-offs, audited price changes, and reconciliation.
-- PostgreSQL 17 compatible. Never silently overwrites stock or deletes stock_movements history.

ALTER TABLE public.pharmacy_inventory
  ADD COLUMN IF NOT EXISTS is_quarantined boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS quarantined_at timestamptz;

CREATE TABLE IF NOT EXISTS public.inventory_adjustment_idempotency (
  idempotency_key uuid PRIMARY KEY,
  movement_id uuid NOT NULL,
  batch_id uuid NOT NULL REFERENCES public.pharmacy_inventory(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL,
  delta numeric NOT NULL,
  reason text NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS public.inventory_expiry_quarantine (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES public.pharmacy_inventory(id) ON DELETE RESTRICT,
  medicine_id uuid NOT NULL REFERENCES public.medicines(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL,
  quarantined_quantity numeric NOT NULL CHECK (quarantined_quantity > 0),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  quarantined_by uuid NOT NULL,
  quarantined_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  status text NOT NULL DEFAULT 'quarantined' CHECK (status IN ('quarantined', 'written_off', 'returned_to_supplier')),
  resolved_by uuid,
  resolved_at timestamptz,
  idempotency_key uuid NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.inventory_writeoffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES public.pharmacy_inventory(id) ON DELETE RESTRICT,
  medicine_id uuid NOT NULL REFERENCES public.medicines(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  writeoff_type text NOT NULL CHECK (writeoff_type IN ('expired', 'damaged', 'lost', 'supplier_return')),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  approved_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  idempotency_key uuid NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS public.medicine_price_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id uuid NOT NULL REFERENCES public.medicines(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL,
  old_selling_price numeric(12,2) NOT NULL,
  new_selling_price numeric(12,2) NOT NULL CHECK (new_selling_price >= 0),
  effective_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  changed_by uuid NOT NULL,
  idempotency_key uuid NOT NULL UNIQUE
);

CREATE OR REPLACE FUNCTION private.reject_phase63_ledger_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  RAISE EXCEPTION 'phase63 ledger table % is append-only', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$$;
REVOKE ALL ON FUNCTION private.reject_phase63_ledger_mutation() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_stock_movements_immutable ON public.stock_movements;
CREATE TRIGGER trg_stock_movements_immutable
  BEFORE UPDATE OR DELETE ON public.stock_movements
  FOR EACH ROW EXECUTE FUNCTION private.reject_phase63_ledger_mutation();

DROP TRIGGER IF EXISTS trg_inventory_writeoffs_immutable ON public.inventory_writeoffs;
CREATE TRIGGER trg_inventory_writeoffs_immutable
  BEFORE UPDATE OR DELETE ON public.inventory_writeoffs
  FOR EACH ROW EXECUTE FUNCTION private.reject_phase63_ledger_mutation();

DROP TRIGGER IF EXISTS trg_medicine_price_history_immutable ON public.medicine_price_history;
CREATE TRIGGER trg_medicine_price_history_immutable
  BEFORE UPDATE OR DELETE ON public.medicine_price_history
  FOR EACH ROW EXECUTE FUNCTION private.reject_phase63_ledger_mutation();

ALTER TABLE public.inventory_expiry_quarantine ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_expiry_quarantine FORCE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_writeoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_writeoffs FORCE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_price_history FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inventory_expiry_quarantine_select ON public.inventory_expiry_quarantine;
CREATE POLICY inventory_expiry_quarantine_select ON public.inventory_expiry_quarantine
  FOR SELECT TO authenticated
  USING (public.app_has_perm('pharmacy.read') AND private.app_has_branch_access(branch_id));

DROP POLICY IF EXISTS inventory_writeoffs_select ON public.inventory_writeoffs;
CREATE POLICY inventory_writeoffs_select ON public.inventory_writeoffs
  FOR SELECT TO authenticated
  USING (public.app_has_perm('pharmacy.read') AND private.app_has_branch_access(branch_id));

DROP POLICY IF EXISTS medicine_price_history_select ON public.medicine_price_history;
CREATE POLICY medicine_price_history_select ON public.medicine_price_history
  FOR SELECT TO authenticated
  USING (public.app_has_perm('pharmacy.read') AND private.app_has_branch_access(branch_id));

REVOKE ALL ON TABLE public.inventory_adjustment_idempotency, public.inventory_expiry_quarantine, public.inventory_writeoffs, public.medicine_price_history FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.inventory_expiry_quarantine, public.inventory_writeoffs, public.medicine_price_history TO authenticated;

CREATE OR REPLACE FUNCTION public.adjust_inventory_batch_atomic(
  p_batch_id uuid,
  p_delta numeric,
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
  v_existing_mov uuid;
  v_batch record;
  v_mov_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'inventory_adjust_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase63:' || p_idempotency_key::text, 0));
  IF p_delta IS NULL OR p_delta = 0 THEN
    RAISE EXCEPTION 'adjustment_delta_must_be_nonzero' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'adjustment_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT movement_id INTO v_existing_mov
    FROM public.inventory_adjustment_idempotency
   WHERE idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN v_existing_mov;
  END IF;

  SELECT id, medicine_id, branch_id, quantity_remaining, is_quarantined, expiry_date
    INTO v_batch
    FROM public.pharmacy_inventory
   WHERE id = p_batch_id AND deleted_at IS NULL
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'batch_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_batch.branch_id IS NULL OR NOT private.app_has_branch_access(v_batch.branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_batch.is_quarantined THEN
    RAISE EXCEPTION 'batch_is_quarantined' USING ERRCODE = '22023';
  END IF;
  IF (v_batch.quantity_remaining + p_delta) < 0 THEN
    RAISE EXCEPTION 'negative_stock_not_permitted' USING ERRCODE = '22023';
  END IF;

  PERFORM 1 FROM public.medicines WHERE id = v_batch.medicine_id FOR UPDATE;

  UPDATE public.pharmacy_inventory
     SET quantity_remaining = quantity_remaining + p_delta,
         updated_at = clock_timestamp(),
         updated_by = v_uid
   WHERE id = p_batch_id;

  UPDATE public.medicines
     SET stock_quantity = GREATEST(0, stock_quantity + p_delta::integer),
         updated_at = clock_timestamp(),
         updated_by = v_uid
   WHERE id = v_batch.medicine_id;

  INSERT INTO public.stock_movements (
    medicine_id, batch_id, movement_type, quantity,
    reference_id, reference_table, notes, branch_id, created_by
  ) VALUES (
    v_batch.medicine_id, p_batch_id, 'stock_adjustment', p_delta,
    p_batch_id, 'pharmacy_inventory', trim(p_reason), v_batch.branch_id, v_uid
  ) RETURNING id INTO v_mov_id;

  INSERT INTO public.inventory_adjustment_idempotency (
    idempotency_key, movement_id, batch_id, branch_id, delta, reason, created_by
  ) VALUES (
    p_idempotency_key, v_mov_id, p_batch_id, v_batch.branch_id, p_delta, trim(p_reason), v_uid
  );

  RETURN v_mov_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.quarantine_expired_batch_atomic(
  p_batch_id uuid,
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
  v_batch record;
  v_q_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'inventory_quarantine_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase63:' || p_idempotency_key::text, 0));
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'quarantine_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_existing_id
    FROM public.inventory_expiry_quarantine
   WHERE idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN v_existing_id;
  END IF;

  SELECT id, medicine_id, branch_id, quantity_remaining, is_quarantined, expiry_date
    INTO v_batch
    FROM public.pharmacy_inventory
   WHERE id = p_batch_id AND deleted_at IS NULL
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'batch_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_batch.branch_id IS NULL OR NOT private.app_has_branch_access(v_batch.branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_batch.is_quarantined THEN
    RAISE EXCEPTION 'batch_already_quarantined' USING ERRCODE = '22023';
  END IF;
  IF v_batch.quantity_remaining <= 0 THEN
    RAISE EXCEPTION 'batch_has_no_remaining_stock' USING ERRCODE = '22023';
  END IF;

  PERFORM 1 FROM public.medicines WHERE id = v_batch.medicine_id FOR UPDATE;

  UPDATE public.pharmacy_inventory
     SET quantity_remaining = 0,
         is_quarantined = true,
         quarantined_at = clock_timestamp(),
         updated_at = clock_timestamp(),
         updated_by = v_uid
   WHERE id = p_batch_id;

  UPDATE public.medicines
     SET stock_quantity = GREATEST(0, stock_quantity - v_batch.quantity_remaining::integer),
         updated_at = clock_timestamp(),
         updated_by = v_uid
   WHERE id = v_batch.medicine_id;

  INSERT INTO public.inventory_expiry_quarantine (
    batch_id, medicine_id, branch_id, quarantined_quantity, reason, quarantined_by, idempotency_key
  ) VALUES (
    p_batch_id, v_batch.medicine_id, v_batch.branch_id, v_batch.quantity_remaining, trim(p_reason), v_uid, p_idempotency_key
  ) RETURNING id INTO v_q_id;

  INSERT INTO public.stock_movements (
    medicine_id, batch_id, movement_type, quantity,
    reference_id, reference_table, notes, branch_id, created_by
  ) VALUES (
    v_batch.medicine_id, p_batch_id, 'expiry_quarantine', -v_batch.quantity_remaining,
    v_q_id, 'inventory_expiry_quarantine', trim(p_reason), v_batch.branch_id, v_uid
  );

  RETURN v_q_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_inventory_writeoff_atomic(
  p_batch_id uuid,
  p_quantity numeric,
  p_writeoff_type text,
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
  v_batch record;
  v_q record;
  v_wo_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'inventory_writeoff_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase63:' || p_idempotency_key::text, 0));
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'writeoff_quantity_must_be_positive' USING ERRCODE = '22023';
  END IF;
  IF p_writeoff_type NOT IN ('expired', 'damaged', 'lost', 'supplier_return') THEN
    RAISE EXCEPTION 'invalid_writeoff_type' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'writeoff_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_existing_id
    FROM public.inventory_writeoffs
   WHERE idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN v_existing_id;
  END IF;

  SELECT id, medicine_id, branch_id, quantity_remaining, is_quarantined
    INTO v_batch
    FROM public.pharmacy_inventory
   WHERE id = p_batch_id AND deleted_at IS NULL
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'batch_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_batch.branch_id IS NULL OR NOT private.app_has_branch_access(v_batch.branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;

  IF v_batch.is_quarantined THEN
    SELECT * INTO v_q
      FROM public.inventory_expiry_quarantine
     WHERE batch_id = p_batch_id AND status = 'quarantined'
     ORDER BY quarantined_at DESC
     LIMIT 1
       FOR UPDATE;
    IF NOT FOUND OR p_quantity > v_q.quarantined_quantity THEN
      RAISE EXCEPTION 'quarantined_quantity_mismatch' USING ERRCODE = '22023';
    END IF;

    UPDATE public.inventory_expiry_quarantine
       SET status = CASE WHEN p_writeoff_type = 'supplier_return' THEN 'returned_to_supplier' ELSE 'written_off' END,
           resolved_by = v_uid,
           resolved_at = clock_timestamp()
     WHERE id = v_q.id;
  ELSE
    IF v_batch.quantity_remaining < p_quantity THEN
      RAISE EXCEPTION 'negative_stock_not_permitted' USING ERRCODE = '22023';
    END IF;
    PERFORM 1 FROM public.medicines WHERE id = v_batch.medicine_id FOR UPDATE;
    UPDATE public.pharmacy_inventory
       SET quantity_remaining = quantity_remaining - p_quantity,
           updated_at = clock_timestamp(),
           updated_by = v_uid
     WHERE id = p_batch_id;
    UPDATE public.medicines
       SET stock_quantity = GREATEST(0, stock_quantity - p_quantity::integer),
           updated_at = clock_timestamp(),
           updated_by = v_uid
     WHERE id = v_batch.medicine_id;
  END IF;

  INSERT INTO public.inventory_writeoffs (
    batch_id, medicine_id, branch_id, quantity, writeoff_type, reason, approved_by, idempotency_key
  ) VALUES (
    p_batch_id, v_batch.medicine_id, v_batch.branch_id, p_quantity, p_writeoff_type, trim(p_reason), v_uid, p_idempotency_key
  ) RETURNING id INTO v_wo_id;

  INSERT INTO public.stock_movements (
    medicine_id, batch_id, movement_type, quantity,
    reference_id, reference_table, notes, branch_id, created_by
  ) VALUES (
    v_batch.medicine_id, p_batch_id, 'writeoff_' || p_writeoff_type,
    CASE WHEN v_batch.is_quarantined THEN 0 ELSE -p_quantity END,
    v_wo_id, 'inventory_writeoffs', trim(p_reason), v_batch.branch_id, v_uid
  );

  RETURN v_wo_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_medicine_selling_price_atomic(
  p_medicine_id uuid,
  p_branch_id uuid,
  p_new_selling_price numeric,
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
  v_old_price numeric(12,2);
  v_hist_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') THEN
    RAISE EXCEPTION 'price_update_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_branch_id IS NULL OR NOT private.app_has_branch_access(p_branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'idempotency_key_required' USING ERRCODE = '22023';
  END IF;
PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase63:' || p_idempotency_key::text, 0));
  IF p_new_selling_price IS NULL OR p_new_selling_price < 0 THEN
    RAISE EXCEPTION 'selling_price_must_be_non_negative' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'price_change_reason_required' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_existing_id
    FROM public.medicine_price_history
   WHERE idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN v_existing_id;
  END IF;

  SELECT COALESCE(selling_price, 0)::numeric(12,2)
    INTO v_old_price
    FROM public.medicines
   WHERE id = p_medicine_id AND deleted_at IS NULL
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'medicine_not_found' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.medicines
     SET selling_price = ROUND(p_new_selling_price, 2),
         updated_at = clock_timestamp(),
         updated_by = v_uid
   WHERE id = p_medicine_id;

  INSERT INTO public.medicine_price_history (
    medicine_id, branch_id, old_selling_price, new_selling_price, reason, changed_by, idempotency_key
  ) VALUES (
    p_medicine_id, p_branch_id, v_old_price, ROUND(p_new_selling_price, 2), trim(p_reason), v_uid, p_idempotency_key
  ) RETURNING id INTO v_hist_id;

  RETURN v_hist_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reconcile_medicine_stock_ledger(
  p_medicine_id uuid,
  p_branch_id uuid
)
RETURNS TABLE(batch_sum numeric, ledger_net numeric, is_balanced boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_batch_sum numeric;
  v_ledger_net numeric;
BEGIN
  IF v_uid IS NULL OR NOT private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.read') THEN
    RAISE EXCEPTION 'inventory_reconcile_permission_denied' USING ERRCODE = '42501';
  END IF;
  IF p_branch_id IS NULL OR NOT private.app_has_branch_access(p_branch_id) THEN
    RAISE EXCEPTION 'branch_access_denied' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(SUM(pi.quantity_remaining), 0)
    INTO v_batch_sum
    FROM public.pharmacy_inventory pi
   WHERE pi.medicine_id = p_medicine_id AND pi.branch_id = p_branch_id AND pi.deleted_at IS NULL;

  -- Saleable batch quantity excludes post-handover returns held in quarantine.
  -- Phase 62 records those physical returns as positive stock_movements, but they
  -- must not inflate the saleable pharmacy_inventory.quantity_remaining balance.
  SELECT COALESCE(SUM(sm.quantity), 0)
    INTO v_ledger_net
    FROM public.stock_movements sm
   WHERE sm.medicine_id = p_medicine_id
     AND sm.branch_id = p_branch_id
     AND sm.movement_type <> 'return_quarantine';

  RETURN QUERY SELECT v_batch_sum, v_ledger_net, (v_batch_sum = v_ledger_net);
END;
$$;

REVOKE ALL ON FUNCTION public.adjust_inventory_batch_atomic(uuid, numeric, text, uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.quarantine_expired_batch_atomic(uuid, text, uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.record_inventory_writeoff_atomic(uuid, numeric, text, text, uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.update_medicine_selling_price_atomic(uuid, uuid, numeric, text, uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.reconcile_medicine_stock_ledger(uuid, uuid) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.adjust_inventory_batch_atomic(uuid, numeric, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quarantine_expired_batch_atomic(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_inventory_writeoff_atomic(uuid, numeric, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_medicine_selling_price_atomic(uuid, uuid, numeric, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_medicine_stock_ledger(uuid, uuid) TO authenticated;
