-- Proposed follow-up migration; do not apply before full migration reconciliation
-- and isolated Supabase validation. Finance writes must pass through validated RPCs.
--
-- The authenticated app uses post_cashbox_entry / post_expense /
-- post_invoice_payment / post_supplier_bill / post_supplier_payment. Direct table
-- DML can bypass their business invariants (notably supplier-payment outstanding
-- checks, idempotency, branch assignment, and balanced ledger side effects).

CREATE OR REPLACE FUNCTION public.post_cashbox_entry(
  _direction text,
  _amount numeric,
  _method text DEFAULT 'cash',
  _category text DEFAULT 'manual',
  _description text DEFAULT NULL,
  _date timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  signed_amount numeric;
  new_id uuid;
  uid uuid;
  bid uuid;
BEGIN
  IF NOT public.app_has_perm('cashbox.create')
     AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to post cashbox entries'
      USING ERRCODE = '42501';
  END IF;

  IF _amount IS NULL OR _amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than zero'
      USING ERRCODE = '22023';
  END IF;

  IF _direction NOT IN ('deposit', 'withdrawal') THEN
    RAISE EXCEPTION 'direction must be deposit or withdrawal'
      USING ERRCODE = '22023';
  END IF;

  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id = uid;

  IF NOT public.is_super_admin() AND bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured'
      USING ERRCODE = '42501';
  END IF;

  signed_amount := CASE WHEN _direction = 'deposit' THEN _amount ELSE -_amount END;

  INSERT INTO public.cashbox_transactions (
    branch_id, transaction_type, amount, payment_method, category,
    description, source_type, transaction_date, created_by
  )
  VALUES (
    bid, _direction, signed_amount, COALESCE(_method, 'cash'),
    COALESCE(_category, 'manual'), _description, 'manual',
    COALESCE(_date, now()), uid
  )
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.post_invoice_payment(
  _invoice_id uuid,
  _amount numeric,
  _method text DEFAULT 'cash',
  _reference text DEFAULT NULL,
  _idempotency_key text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  net numeric;
  already numeric;
  outstanding numeric;
  pay_id uuid;
  uid uuid;
  invoice_branch uuid;
  user_branch uuid;
BEGIN
  IF NOT public.app_has_perm('payments.create')
     AND NOT public.app_has_perm('billing.create')
     AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record payments'
      USING ERRCODE = '42501';
  END IF;

  IF _amount IS NULL OR _amount <= 0 THEN
    RAISE EXCEPTION 'payment amount must be greater than zero'
      USING ERRCODE = '22023';
  END IF;

  uid := public.current_app_user_id();
  SELECT branch_id INTO user_branch
  FROM public.users
  WHERE id = uid AND deleted_at IS NULL;

  IF NOT public.is_super_admin() AND user_branch IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured'
      USING ERRCODE = '42501';
  END IF;

  IF _idempotency_key IS NOT NULL THEN
    SELECT id INTO pay_id
    FROM public.payments
    WHERE idempotency_key = _idempotency_key;
    IF pay_id IS NOT NULL THEN
      RETURN pay_id;
    END IF;
  END IF;

  SELECT COALESCE(i.net_amount, i.total_amount, 0),
         COALESCE(i.paid_amount, 0),
         i.branch_id
    INTO net, already, invoice_branch
  FROM public.invoices AS i
  WHERE i.id = _invoice_id AND i.deleted_at IS NULL
  FOR UPDATE;

  IF net IS NULL THEN
    RAISE EXCEPTION 'invoice not found'
      USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_super_admin() AND invoice_branch IS DISTINCT FROM user_branch THEN
    RAISE EXCEPTION 'cross_branch_access_denied'
      USING ERRCODE = '42501';
  END IF;

  outstanding := GREATEST(net - already, 0);
  IF _amount > outstanding THEN
    RAISE EXCEPTION 'payment (%) exceeds outstanding balance (%)', _amount, outstanding
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.payments (
    invoice_id, amount, payment_method, method, reference_no, reference,
    payment_date, received_at, received_by, created_by, branch_id, idempotency_key
  )
  VALUES (
    _invoice_id, _amount, COALESCE(_method, 'cash'), COALESCE(_method, 'cash'),
    NULLIF(BTRIM(COALESCE(_reference, '')), ''),
    NULLIF(BTRIM(COALESCE(_reference, '')), ''),
    CURRENT_DATE, now(), uid, uid, invoice_branch, _idempotency_key
  )
  RETURNING id INTO pay_id;

  RETURN pay_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.post_supplier_bill(
  _supplier_id uuid,
  _invoice_number text,
  _bill_date date,
  _due_date date,
  _subtotal numeric,
  _discount numeric DEFAULT 0,
  _notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  bill_id uuid;
  uid uuid;
  user_branch uuid;
  is_admin boolean;
  discount_value numeric := COALESCE(_discount, 0);
  net numeric;
BEGIN
  IF NOT private.app_has_perm('debts.create')
     AND NOT private.app_has_perm('accounting.create')
     AND NOT private.app_has_perm('pharmacy.create') THEN
    RAISE EXCEPTION 'not authorised to record supplier bills'
      USING ERRCODE = '42501';
  END IF;

  IF _supplier_id IS NULL THEN
    RAISE EXCEPTION 'supplier is required' USING ERRCODE = '22023';
  END IF;

  IF _subtotal IS NULL OR _subtotal <= 0 THEN
    RAISE EXCEPTION 'bill subtotal must be greater than zero' USING ERRCODE = '22023';
  END IF;

  IF discount_value < 0 OR discount_value > _subtotal THEN
    RAISE EXCEPTION 'discount must be between zero and subtotal' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.suppliers AS s
    WHERE s.id = _supplier_id AND s.deleted_at IS NULL AND s.active IS TRUE
  ) THEN
    RAISE EXCEPTION 'active supplier not found' USING ERRCODE = '22023';
  END IF;

  uid := private.current_app_user_id();
  is_admin := private.is_super_admin();

  SELECT u.branch_id INTO user_branch
  FROM public.users AS u
  WHERE u.id = uid AND u.deleted_at IS NULL AND u.active IS TRUE;

  IF user_branch IS NULL AND NOT is_admin THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;

  net := _subtotal - discount_value;

  INSERT INTO public.supplier_bills (
    supplier_id, branch_id, invoice_number, bill_date, due_date,
    subtotal, discount_amount, total_amount, paid_amount, status, notes, created_by
  )
  VALUES (
    _supplier_id, user_branch, NULLIF(BTRIM(COALESCE(_invoice_number, '')), ''),
    COALESCE(_bill_date, CURRENT_DATE), _due_date, _subtotal, discount_value,
    net, 0, 'unpaid', _notes, uid
  )
  RETURNING id INTO bill_id;

  RETURN bill_id;
END;
$function$;

-- Preserve RPC access while denying direct client-side financial table mutations.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.cashbox_transactions, public.expenses, public.payments,
           public.supplier_bills, public.supplier_payments, public.insurance_claims,
           public.insurance_claim_items, public.insurance_claim_payments
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.post_cashbox_entry(text, numeric, text, text, text, timestamptz)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_cashbox_entry(text, numeric, text, text, text, timestamptz)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.post_expense(text, numeric, text, date, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_expense(text, numeric, text, date, text, text)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.post_invoice_payment(uuid, numeric, text, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_invoice_payment(uuid, numeric, text, text, text)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.post_supplier_bill(uuid, text, date, date, numeric, numeric, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_supplier_bill(uuid, text, date, date, numeric, numeric, text)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.post_supplier_payment(uuid, numeric, text, text, date, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_supplier_payment(uuid, numeric, text, text, date, text)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.create_insurance_claim(uuid, uuid, jsonb, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_insurance_claim(uuid, uuid, jsonb, text)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.update_insurance_claim_status(uuid, text, numeric, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_insurance_claim_status(uuid, text, numeric, text)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.post_insurance_claim_payment(uuid, numeric, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_insurance_claim_payment(uuid, numeric, text, text)
  TO authenticated;
