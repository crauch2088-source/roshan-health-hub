-- Phase 54: source-aware financial reversals.
-- Generic cashbox corrections must not detach a payment ledger reversal from its
-- authoritative source row. Invoice payments are reversed atomically here;
-- supplier and insurance payments remain blocked until dedicated source workflows exist.

BEGIN;

CREATE OR REPLACE FUNCTION public.reverse_cashbox_entry(
  _transaction_id uuid,
  _reason text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  orig public.cashbox_transactions;
  new_id uuid;
  uid uuid;
  bid uuid;
BEGIN
  IF NOT public.app_has_perm('cashbox.update') AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'not authorised to reverse cashbox entries' USING ERRCODE = '42501';
  END IF;
  IF _reason IS NULL OR pg_catalog.btrim(_reason) = '' THEN
    RAISE EXCEPTION 'a reversal reason is required' USING ERRCODE = '22023';
  END IF;

  SELECT *
    INTO orig
    FROM public.cashbox_transactions
   WHERE id = _transaction_id
   FOR UPDATE;

  IF orig.id IS NULL THEN
    RAISE EXCEPTION 'transaction not found' USING ERRCODE = 'P0002';
  END IF;
  IF orig.is_reversed THEN
    RAISE EXCEPTION 'transaction already reversed' USING ERRCODE = '22023';
  END IF;
  IF orig.reversal_of IS NOT NULL THEN
    RAISE EXCEPTION 'a reversal entry cannot itself be reversed' USING ERRCODE = '22023';
  END IF;
  IF orig.branch_id IS NULL THEN
    RAISE EXCEPTION 'cashbox transaction must be branch-bound before reversal' USING ERRCODE = '23514';
  END IF;
  IF orig.source_type IN ('payment', 'supplier_payment', 'insurance_claim_payment') THEN
    RAISE EXCEPTION 'payment ledger entries require a source-specific payment reversal workflow'
      USING ERRCODE = '22023';
  END IF;

  uid := public.current_app_user_id();
  SELECT branch_id INTO bid
    FROM public.users
   WHERE id = uid
     AND deleted_at IS NULL
     AND active IS TRUE;

  IF uid IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_super_admin() AND (bid IS NULL OR orig.branch_id IS DISTINCT FROM bid) THEN
    RAISE EXCEPTION 'cross-branch cashbox access denied' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.cashbox_transactions (
    branch_id, transaction_type, amount, payment_method, category, description,
    source_type, transaction_date, created_by, reversal_of, reversal_reason
  ) VALUES (
    orig.branch_id, 'adjustment', -orig.amount, orig.payment_method, orig.category,
    COALESCE(orig.description, '') || ' — reversal: ' || _reason,
    'reversal', pg_catalog.now(), uid, orig.id, _reason
  ) RETURNING id INTO new_id;

  PERFORM pg_catalog.set_config('roshan.cashbox_write', 'on', true);
  UPDATE public.cashbox_transactions
     SET is_reversed = true,
         reversal_reason = _reason
   WHERE id = orig.id
     AND NOT is_reversed;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'cashbox entry changed during reversal' USING ERRCODE = '40001';
  END IF;
  PERFORM pg_catalog.set_config('roshan.cashbox_write', 'off', true);

  RETURN new_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.reverse_invoice_payment(
  _payment_id uuid,
  _reason text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid;
  v_user_branch uuid;
  v_invoice_id uuid;
  v_invoice_branch uuid;
  v_payment public.payments;
  v_original public.cashbox_transactions;
  v_reversal_id uuid;
BEGIN
  IF NOT public.app_has_perm('cashbox.update') AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'not authorised to reverse invoice payments' USING ERRCODE = '42501';
  END IF;
  IF _payment_id IS NULL THEN
    RAISE EXCEPTION 'invoice payment is required' USING ERRCODE = '22023';
  END IF;
  IF _reason IS NULL OR pg_catalog.btrim(_reason) = '' THEN
    RAISE EXCEPTION 'a reversal reason is required' USING ERRCODE = '22023';
  END IF;

  v_uid := public.current_app_user_id();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;

  -- Lock the invoice before its payment row, matching post_invoice_payment's
  -- invoice-first lock order and preventing concurrent balance races.
  SELECT p.invoice_id
    INTO v_invoice_id
    FROM public.payments p
   WHERE p.id = _payment_id;
  IF NOT FOUND OR v_invoice_id IS NULL THEN
    RAISE EXCEPTION 'invoice payment not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT i.branch_id
    INTO v_invoice_branch
    FROM public.invoices i
   WHERE i.id = v_invoice_id
     AND i.deleted_at IS NULL
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active invoice not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT p.*
    INTO v_payment
    FROM public.payments p
   WHERE p.id = _payment_id
     AND p.invoice_id = v_invoice_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invoice payment changed during reversal' USING ERRCODE = '40001';
  END IF;
  IF v_payment.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'invoice payment is already voided or reversed' USING ERRCODE = '22023';
  END IF;
  IF v_invoice_branch IS NULL OR v_payment.branch_id IS NULL THEN
    RAISE EXCEPTION 'invoice payment and invoice must be branch-bound before reversal' USING ERRCODE = '23514';
  END IF;
  IF v_payment.branch_id IS DISTINCT FROM v_invoice_branch THEN
    RAISE EXCEPTION 'invoice payment branch does not match its invoice' USING ERRCODE = '23514';
  END IF;

  SELECT u.branch_id
    INTO v_user_branch
    FROM public.users u
   WHERE u.id = v_uid
     AND u.deleted_at IS NULL
     AND u.active IS TRUE;
  IF NOT public.is_super_admin()
     AND (v_user_branch IS NULL OR v_user_branch IS DISTINCT FROM v_invoice_branch) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;

  SELECT c.*
    INTO v_original
    FROM public.cashbox_transactions c
   WHERE c.source_type = 'payment'
     AND c.source_id = v_payment.id
     AND c.reversal_of IS NULL
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'posted invoice payment ledger entry not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_original.is_reversed THEN
    RAISE EXCEPTION 'invoice payment ledger entry is already reversed' USING ERRCODE = '22023';
  END IF;
  IF v_original.branch_id IS DISTINCT FROM v_invoice_branch
     OR v_original.amount IS DISTINCT FROM pg_catalog.abs(v_payment.amount) THEN
    RAISE EXCEPTION 'invoice payment and ledger entry do not match' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.cashbox_transactions (
    branch_id, transaction_type, amount, payment_method, category, description,
    source_type, transaction_date, created_by, reversal_of, reversal_reason
  ) VALUES (
    v_original.branch_id, 'adjustment', -v_original.amount, v_original.payment_method,
    v_original.category,
    COALESCE(v_original.description, '') || ' — reversal: ' || _reason,
    'reversal', pg_catalog.now(), v_uid, v_original.id, _reason
  ) RETURNING id INTO v_reversal_id;

  PERFORM pg_catalog.set_config('roshan.cashbox_write', 'on', true);
  UPDATE public.cashbox_transactions
     SET is_reversed = true,
         reversal_reason = _reason
   WHERE id = v_original.id
     AND NOT is_reversed;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invoice payment ledger entry changed during reversal' USING ERRCODE = '40001';
  END IF;
  PERFORM pg_catalog.set_config('roshan.cashbox_write', 'off', true);

  -- The existing AFTER UPDATE trigger recomputes invoice paid_amount/status
  -- from non-deleted payments. The audit trigger preserves actor and reason.
  UPDATE public.payments
     SET deleted_at = pg_catalog.now(),
         deleted_by = v_uid,
         updated_at = pg_catalog.now(),
         updated_by = v_uid
   WHERE id = v_payment.id
     AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invoice payment changed during reversal' USING ERRCODE = '40001';
  END IF;

  RETURN v_reversal_id;
END;
$function$;


CREATE OR REPLACE FUNCTION public.get_invoice_payment_receipt_status(
  _payment_ids uuid[]
) RETURNS TABLE (
  payment_id uuid,
  ledger_found boolean,
  ledger_matches boolean,
  ledger_is_reversed boolean,
  reversal_reason text,
  reversal_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.app_has_perm('payments.read')
     OR NOT public.app_has_perm('billing.read') THEN
    RAISE EXCEPTION 'not authorised to read invoice payment receipt status'
      USING ERRCODE = '42501';
  END IF;
  IF _payment_ids IS NULL OR pg_catalog.cardinality(_payment_ids) = 0 THEN
    RETURN;
  END IF;
  IF pg_catalog.cardinality(_payment_ids) > 200 THEN
    RAISE EXCEPTION 'at most 200 payment ids may be checked at once'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    c.id IS NOT NULL,
    c.id IS NOT NULL
      AND c.branch_id IS NOT NULL
      AND p.branch_id IS NOT NULL
      AND i.branch_id IS NOT NULL
      AND c.branch_id = p.branch_id
      AND p.branch_id = i.branch_id
      AND c.amount IS NOT DISTINCT FROM pg_catalog.abs(p.amount),
    COALESCE(c.is_reversed, false),
    CASE WHEN c.is_reversed THEN c.reversal_reason ELSE NULL END,
    r.transaction_date
  FROM public.payments p
  JOIN public.invoices i ON i.id = p.invoice_id AND i.deleted_at IS NULL
  LEFT JOIN public.cashbox_transactions c
    ON c.source_type = 'payment'
   AND c.source_id = p.id
   AND c.reversal_of IS NULL
  LEFT JOIN public.cashbox_transactions r
    ON r.reversal_of = c.id
  WHERE p.id = ANY(_payment_ids)
    AND private.app_has_branch_access(p.branch_id)
    AND private.app_has_branch_access(i.branch_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.reverse_invoice_payment(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reverse_invoice_payment(uuid, text) TO authenticated;
REVOKE ALL ON FUNCTION public.get_invoice_payment_receipt_status(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_invoice_payment_receipt_status(uuid[]) TO authenticated;

COMMIT;
