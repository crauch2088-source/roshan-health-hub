-- Source-only forward candidate: reject non-finite expense amounts.
-- Apply only after PostgreSQL 17 regression and migration review; not a live hotfix.
BEGIN;

CREATE OR REPLACE FUNCTION public.post_expense(
  _category text,
  _amount numeric,
  _description text DEFAULT NULL::text,
  _expense_date date DEFAULT CURRENT_DATE,
  _method text DEFAULT 'cash'::text,
  _paid_to text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  exp_id uuid;
  uid uuid;
  bid uuid;
BEGIN
  IF NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record expenses';
  END IF;

  IF _amount IS NULL
     OR _amount::text IN ('NaN', 'Infinity', '-Infinity')
     OR _amount <= 0 THEN
    RAISE EXCEPTION 'expense amount must be finite and greater than zero'
      USING ERRCODE = '22023';
  END IF;

  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id = uid;

  IF NOT public.is_super_admin() AND bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured';
  END IF;

  INSERT INTO public.expenses (
    branch_id, category, amount, description, expense_date,
    payment_method, paid_to, created_by
  )
  VALUES (
    bid, COALESCE(_category, 'other'), _amount, _description,
    COALESCE(_expense_date, CURRENT_DATE), COALESCE(_method, 'cash'),
    _paid_to, uid
  )
  RETURNING id INTO exp_id;

  RETURN exp_id;
END;
$function$;

COMMIT;
