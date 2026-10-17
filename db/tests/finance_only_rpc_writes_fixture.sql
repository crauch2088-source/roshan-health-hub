CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE TABLE public.users (
 id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz, active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.suppliers (
 id uuid PRIMARY KEY, active boolean NOT NULL DEFAULT true, deleted_at timestamptz
);
CREATE TABLE public.cashbox_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, transaction_type text, amount numeric,
 payment_method text, category text, description text, source_type text, transaction_date timestamptz, created_by uuid
);
CREATE TABLE public.expenses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, category text, amount numeric, description text,
 expense_date date, payment_method text, paid_to text, created_by uuid
);
CREATE TABLE public.invoices (
 id uuid PRIMARY KEY, branch_id uuid, net_amount numeric, total_amount numeric, paid_amount numeric DEFAULT 0, deleted_at timestamptz
);
CREATE TABLE public.payments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invoice_id uuid, amount numeric, payment_method text, method text,
 reference_no text, reference text, idempotency_key text UNIQUE, payment_date date, received_at timestamptz,
 received_by uuid, created_by uuid, branch_id uuid
);
CREATE TABLE public.supplier_bills (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, supplier_id uuid, invoice_number text,
 bill_date date, due_date date, subtotal numeric, discount_amount numeric, total_amount numeric, paid_amount numeric,
 status text, notes text, created_by uuid, deleted_at timestamptz, updated_at timestamptz, updated_by uuid
);
CREATE TABLE public.supplier_payments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, supplier_bill_id uuid, supplier_id uuid,
 amount numeric, payment_method text, reference text, payment_date date, notes text, created_by uuid, deleted_at timestamptz
);

CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT position('|' || p_permission || '|' IN '|' || COALESCE(current_setting('test.permissions',true),'') || '|')>0 $function$;
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.user_id',true),'')::uuid $function$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT COALESCE(NULLIF(current_setting('test.super_admin',true),'')::boolean,false) $function$;
CREATE FUNCTION private.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT public.app_has_perm(p_permission) $function$;
CREATE FUNCTION private.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT public.current_app_user_id() $function$;
CREATE FUNCTION private.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT public.is_super_admin() $function$;

-- Representative live grants before the proposed migration.
GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON
 public.cashbox_transactions,public.expenses,public.payments,public.supplier_bills,public.supplier_payments TO authenticated,anon;

CREATE FUNCTION public.add_cashbox_entry(_direction text,_amount numeric,_type text,_method text,_category text,_description text,_date timestamptz)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
CREATE FUNCTION public.post_expense(_category text,_amount numeric,_description text,_expense_date date,_method text,_paid_to text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
CREATE FUNCTION public.post_supplier_payment(_bill_id uuid,_amount numeric,_method text,_reference text,_payment_date date,_notes text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
CREATE FUNCTION public.reverse_cashbox_entry(_transaction_id uuid,_reason text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
GRANT EXECUTE ON FUNCTION public.add_cashbox_entry(text,numeric,text,text,text,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_expense(text,numeric,text,date,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_supplier_payment(uuid,numeric,text,text,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid,text) TO authenticated;

CREATE FUNCTION public.test_sync_invoice_paid_amount() RETURNS trigger LANGUAGE plpgsql
AS $function$ BEGIN UPDATE public.invoices SET paid_amount=COALESCE(paid_amount,0)+NEW.amount WHERE id=NEW.invoice_id; RETURN NEW; END $function$;
CREATE TRIGGER test_payment_paid_amount AFTER INSERT ON public.payments FOR EACH ROW EXECUTE FUNCTION public.test_sync_invoice_paid_amount();

INSERT INTO public.users VALUES ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',NULL,true);
INSERT INTO public.suppliers VALUES ('30000000-0000-0000-0000-000000000001',true,NULL);
INSERT INTO public.invoices VALUES ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',10,10,0,NULL);

SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.permissions','accounting.create|cashbox.create|payments.create|billing.create|debts.create|pharmacy.create',false);
SELECT set_config('test.super_admin','false',false);
