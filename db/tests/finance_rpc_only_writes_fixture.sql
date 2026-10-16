CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  branch_id uuid,
  deleted_at timestamptz,
  active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.suppliers (
  id uuid PRIMARY KEY,
  active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz
);
CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  transaction_type text,
  amount numeric,
  payment_method text,
  category text,
  description text,
  source_type text,
  source_id uuid,
  transaction_date timestamptz,
  created_by uuid
);
CREATE TABLE public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  category text,
  amount numeric,
  description text,
  expense_date date,
  payment_method text,
  paid_to text,
  created_by uuid
);
CREATE TABLE public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  invoice_id uuid,
  amount numeric,
  payment_method text,
  reference text,
  idempotency_key text,
  payment_date timestamptz,
  created_by uuid
);
CREATE TABLE public.supplier_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  supplier_id uuid,
  invoice_number text,
  bill_date date,
  due_date date,
  subtotal numeric,
  discount_amount numeric,
  total_amount numeric,
  paid_amount numeric,
  status text,
  notes text,
  created_by uuid,
  deleted_at timestamptz,
  updated_at timestamptz,
  updated_by uuid,
  CHECK (paid_amount <= total_amount)
);
CREATE TABLE public.supplier_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  supplier_bill_id uuid,
  supplier_id uuid,
  amount numeric,
  payment_method text,
  reference text,
  payment_date date,
  notes text,
  created_by uuid,
  deleted_at timestamptz
);

CREATE TABLE public.insurance_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_insurance_id uuid,
  invoice_id uuid,
  claim_number text,
  status text,
  submitted_amount numeric,
  approved_amount numeric,
  paid_amount numeric,
  paid_at timestamptz,
  notes text,
  created_by uuid,
  updated_by uuid,
  updated_at timestamptz,
  deleted_at timestamptz
);
CREATE TABLE public.insurance_claim_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid,
  service_type text,
  reference_id uuid,
  description text,
  gross_amount numeric,
  covered_amount numeric,
  patient_amount numeric,
  coverage_rule_id uuid
);
CREATE TABLE public.insurance_claim_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid,
  amount numeric,
  payment_method text,
  reference text,
  created_by uuid,
  deleted_at timestamptz
);

CREATE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $$
  SELECT position('|' || p_permission || '|' IN
    '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0
$$;
CREATE FUNCTION public.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;
CREATE FUNCTION public.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(NULLIF(current_setting('test.super_admin', true), '')::boolean, false) $$;

CREATE FUNCTION private.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT public.app_has_perm(p_permission) $$;
CREATE FUNCTION private.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT public.current_app_user_id() $$;
CREATE FUNCTION private.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT public.is_super_admin() $$;

-- Representative pre-migration direct grants, as observed in the live project.
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.cashbox_transactions, public.expenses, public.payments,
           public.supplier_bills, public.supplier_payments, public.insurance_claims,
           public.insurance_claim_items, public.insurance_claim_payments
  TO authenticated, anon;

CREATE FUNCTION public.post_expense(
  _category text, _amount numeric, _description text DEFAULT NULL,
  _expense_date date DEFAULT CURRENT_DATE, _method text DEFAULT 'cash',
  _paid_to text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE uid uuid; bid uuid; new_id uuid;
BEGIN
  IF NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record expenses' USING ERRCODE = '42501';
  END IF;
  IF _amount IS NULL OR _amount <= 0 THEN
    RAISE EXCEPTION 'expense amount must be greater than zero' USING ERRCODE = '22023';
  END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id = uid;
  IF NOT public.is_super_admin() AND bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.expenses(branch_id,category,amount,description,expense_date,payment_method,paid_to,created_by)
  VALUES(bid,COALESCE(_category,'other'),_amount,_description,COALESCE(_expense_date,current_date),
         COALESCE(_method,'cash'),_paid_to,uid)
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;

CREATE FUNCTION public.post_invoice_payment(
  _invoice_id uuid, _amount numeric, _method text DEFAULT 'cash',
  _reference text DEFAULT NULL, _idempotency_key text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE uid uuid; bid uuid; new_id uuid;
BEGIN
  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id = uid;
  INSERT INTO public.payments(branch_id,invoice_id,amount,payment_method,reference,idempotency_key,created_by)
  VALUES(bid,_invoice_id,_amount,_method,_reference,_idempotency_key,uid)
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;

CREATE FUNCTION public.post_supplier_payment(
  _bill_id uuid, _amount numeric, _method text DEFAULT 'cash',
  _reference text DEFAULT NULL, _payment_date date DEFAULT CURRENT_DATE,
  _notes text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE b public.supplier_bills; uid uuid; new_id uuid;
BEGIN
  uid := public.current_app_user_id();
  SELECT * INTO b FROM public.supplier_bills WHERE id = _bill_id;
  INSERT INTO public.supplier_payments(supplier_bill_id,supplier_id,branch_id,amount,payment_method,
    reference,payment_date,notes,created_by)
  VALUES(b.id,b.supplier_id,b.branch_id,_amount,_method,_reference,_payment_date,_notes,uid)
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;

CREATE FUNCTION public.reverse_cashbox_entry(_transaction_id uuid, _reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE new_id uuid;
BEGIN
  INSERT INTO public.cashbox_transactions(transaction_type,amount,description,source_type)
  VALUES('reversal',-1,'test reversal: ' || _reason,'reversal')
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;

CREATE FUNCTION public.create_insurance_claim(
  _patient_insurance_id uuid, _invoice_id uuid, _items jsonb, _notes text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $claim$
DECLARE claim_id uuid; uid uuid; item jsonb; total numeric := 0;
BEGIN
  IF NOT public.app_has_perm('insurance.create') THEN
    RAISE EXCEPTION 'not authorised to create insurance claims' USING ERRCODE = '42501';
  END IF;
  uid := public.current_app_user_id();
  SELECT COALESCE(sum((value->>'gross_amount')::numeric),0) INTO total
  FROM jsonb_array_elements(_items) AS entries(value);
  INSERT INTO public.insurance_claims(patient_insurance_id,invoice_id,status,submitted_amount,notes,created_by)
  VALUES(_patient_insurance_id,_invoice_id,'draft',total,_notes,uid) RETURNING id INTO claim_id;
  FOR item IN SELECT value FROM jsonb_array_elements(_items) AS entries(value) LOOP
    INSERT INTO public.insurance_claim_items(claim_id,service_type,description,gross_amount,covered_amount,patient_amount)
    VALUES(claim_id,item->>'service_type',coalesce(item->>'description',''),
      coalesce((item->>'gross_amount')::numeric,0),coalesce((item->>'covered_amount')::numeric,0),
      coalesce((item->>'patient_amount')::numeric,0));
  END LOOP;
  RETURN claim_id;
END $claim$;

CREATE FUNCTION public.update_insurance_claim_status(
  _claim_id uuid, _new_status text, _approved_amount numeric DEFAULT NULL, _notes text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $claim$
BEGIN
  IF NOT public.app_has_perm('insurance.update') THEN
    RAISE EXCEPTION 'not authorised to update insurance claims' USING ERRCODE = '42501';
  END IF;
  UPDATE public.insurance_claims
  SET status=_new_status, approved_amount=_approved_amount, notes=coalesce(_notes,notes)
  WHERE id=_claim_id;
END $claim$;

CREATE FUNCTION public.post_insurance_claim_payment(
  _claim_id uuid, _amount numeric, _method text DEFAULT 'bank', _reference text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $claim$
DECLARE uid uuid; new_id uuid;
BEGIN
  IF NOT public.app_has_perm('insurance.update') THEN
    RAISE EXCEPTION 'not authorised to record insurance payments' USING ERRCODE = '42501';
  END IF;
  uid:=public.current_app_user_id();
  INSERT INTO public.insurance_claim_payments(claim_id,amount,payment_method,reference,created_by)
  VALUES(_claim_id,_amount,coalesce(_method,'bank'),_reference,uid) RETURNING id INTO new_id;
  UPDATE public.insurance_claims SET paid_amount=coalesce(paid_amount,0)+_amount WHERE id=_claim_id;
  RETURN new_id;
END $claim$;

GRANT EXECUTE ON FUNCTION public.post_expense(text,numeric,text,date,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_invoice_payment(uuid,numeric,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_supplier_payment(uuid,numeric,text,text,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid,text) TO authenticated;
