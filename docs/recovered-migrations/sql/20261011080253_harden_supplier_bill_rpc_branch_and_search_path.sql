CREATE OR REPLACE FUNCTION public.post_supplier_bill(
  _supplier_id uuid,
  _invoice_number text,
  _bill_date date,
  _due_date date,
  _subtotal numeric,
  _discount numeric DEFAULT 0,
  _notes text DEFAULT NULL::text
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
  discount_value numeric := COALESCE(_discount, 0);
  net numeric;
BEGIN
  IF NOT private.app_has_perm('debts.create')
     AND NOT private.app_has_perm('pharmacy.create') THEN
    RAISE EXCEPTION 'not authorised to record supplier bills'
      USING ERRCODE = '42501';
  END IF;

  IF _supplier_id IS NULL THEN
    RAISE EXCEPTION 'supplier is required'
      USING ERRCODE = '22023';
  END IF;

  IF _subtotal IS NULL OR _subtotal <= 0 THEN
    RAISE EXCEPTION 'bill subtotal must be greater than zero'
      USING ERRCODE = '22023';
  END IF;

  IF discount_value < 0 OR discount_value > _subtotal THEN
    RAISE EXCEPTION 'discount must be between zero and subtotal'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.suppliers AS s
    WHERE s.id = _supplier_id
      AND s.deleted_at IS NULL
      AND s.active IS TRUE
  ) THEN
    RAISE EXCEPTION 'active supplier not found'
      USING ERRCODE = '22023';
  END IF;

  uid := private.current_app_user_id();

  SELECT u.branch_id
    INTO user_branch
  FROM public.users AS u
  WHERE u.id = uid
    AND u.deleted_at IS NULL
    AND u.active IS TRUE;

  -- This RPC has no branch argument, so it must use the caller's configured
  -- branch. Even a super-admin must have a branch context for this operation.
  IF user_branch IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured; supplier bill creation requires a branch context'
      USING ERRCODE = '42501';
  END IF;

  net := _subtotal - discount_value;

  INSERT INTO public.supplier_bills (
    supplier_id,
    branch_id,
    invoice_number,
    bill_date,
    due_date,
    subtotal,
    discount_amount,
    total_amount,
    paid_amount,
    status,
    notes,
    created_by
  )
  VALUES (
    _supplier_id,
    user_branch,
    NULLIF(BTRIM(COALESCE(_invoice_number, '')), ''),
    COALESCE(_bill_date, CURRENT_DATE),
    _due_date,
    _subtotal,
    discount_value,
    net,
    0,
    'unpaid',
    _notes,
    uid
  )
  RETURNING id INTO bill_id;

  RETURN bill_id;
END;
$function$;
