CREATE ROLE anon;
CREATE ROLE authenticated;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  branch_id uuid
);
CREATE TABLE public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  patient_id uuid,
  visit_id uuid,
  partner_id uuid,
  invoice_date date,
  discount_amount numeric,
  total_amount numeric,
  created_by uuid
);
CREATE TABLE public.invoice_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid,
  item_type text,
  item_name text,
  quantity numeric,
  unit_price numeric,
  total_price numeric,
  created_by uuid
);

CREATE FUNCTION public.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $function$;
CREATE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT position('|' || p_permission || '|' IN
    '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0
$function$;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.invoices, public.invoice_items TO authenticated, anon;

CREATE FUNCTION public.create_billing_invoice_atomic(
  p_patient_id uuid, p_visit_id uuid, p_partner_id uuid, p_invoice_date date,
  p_discount numeric, p_items jsonb, p_separate_invoice boolean, p_request_id uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE uid uuid; bid uuid; new_id uuid;
BEGIN
  IF NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'billing permission denied' USING ERRCODE = '42501';
  END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id=uid;
  INSERT INTO public.invoices(branch_id,patient_id,visit_id,partner_id,invoice_date,discount_amount,total_amount,created_by)
  VALUES(bid,p_patient_id,p_visit_id,p_partner_id,COALESCE(p_invoice_date,current_date),COALESCE(p_discount,0),10,uid)
  RETURNING id INTO new_id;
  INSERT INTO public.invoice_items(invoice_id,item_type,item_name,quantity,unit_price,total_price,created_by)
  VALUES(new_id,'service','billing test',1,10,10,uid);
  RETURN new_id;
END;
$function$;

CREATE FUNCTION public.create_visit_consultation_invoice_atomic(
  p_visit_id uuid, p_invoice_date date
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE uid uuid; bid uuid; new_id uuid;
BEGIN
  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id=uid;
  INSERT INTO public.invoices(branch_id,visit_id,invoice_date,discount_amount,total_amount,created_by)
  VALUES(bid,p_visit_id,COALESCE(p_invoice_date,current_date),0,5,uid)
  RETURNING id INTO new_id;
  INSERT INTO public.invoice_items(invoice_id,item_type,item_name,quantity,unit_price,total_price,created_by)
  VALUES(new_id,'consultation','visit test',1,5,5,uid);
  RETURN new_id;
END;
$function$;

CREATE FUNCTION public.create_lab_order_with_invoice_atomic(
  p_visit_id uuid, p_priority text, p_notes text, p_test_ids uuid[],
  p_separate_invoice boolean, p_request_id uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE uid uuid; bid uuid; new_id uuid;
BEGIN
  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id=uid;
  INSERT INTO public.invoices(branch_id,visit_id,invoice_date,discount_amount,total_amount,created_by)
  VALUES(bid,p_visit_id,current_date,0,7,uid)
  RETURNING id INTO new_id;
  INSERT INTO public.invoice_items(invoice_id,item_type,item_name,quantity,unit_price,total_price,created_by)
  VALUES(new_id,'lab','lab test',1,7,7,uid);
  RETURN new_id;
END;
$function$;
