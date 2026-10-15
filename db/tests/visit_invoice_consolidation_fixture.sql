CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;
CREATE TABLE public.users (id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.patients (id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.partners (id uuid PRIMARY KEY, active boolean, deleted_at timestamptz);
CREATE TABLE public.visits (id uuid PRIMARY KEY, patient_id uuid NOT NULL, deleted_at timestamptz);
CREATE TABLE public.lab_tests (id uuid PRIMARY KEY, name text NOT NULL, price numeric NOT NULL, active boolean DEFAULT true, deleted_at timestamptz);
CREATE TABLE public.lab_orders (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), patient_id uuid NOT NULL, visit_id uuid NOT NULL,
 ordered_by uuid, status text, priority text, notes text, created_by uuid, branch_id uuid, created_at timestamptz DEFAULT now()
);
CREATE TABLE public.lab_order_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL, test_id uuid NOT NULL,
 price numeric NOT NULL, created_by uuid
);
CREATE TABLE public.invoices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invoice_number varchar, patient_id uuid, visit_id uuid,
 total_amount numeric DEFAULT 0, discount_amount numeric DEFAULT 0, paid_amount numeric DEFAULT 0,
 payment_status varchar DEFAULT 'unpaid', created_at timestamptz DEFAULT now(), created_by uuid,
 updated_by uuid, deleted_at timestamptz, deleted_by uuid, status text DEFAULT 'unpaid',
 subtotal numeric DEFAULT 0, net_amount numeric DEFAULT 0, discount_type text,
 corporate_account_id uuid, branch_id uuid, updated_at timestamptz DEFAULT now(),
 invoice_date date DEFAULT CURRENT_DATE, partner_id uuid
);
CREATE TABLE public.invoice_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invoice_id uuid NOT NULL, item_type varchar,
 item_name varchar, quantity numeric, unit_price numeric, total_price numeric,
 created_by uuid, updated_by uuid, deleted_at timestamptz, deleted_by uuid,
 item_id uuid, discount numeric, created_at timestamptz DEFAULT now()
);
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $$
 SELECT CASE
   WHEN current_setting('test.perms', true) IS NULL
     THEN COALESCE(current_setting('test.has_perm', true) = 'true', false)
   ELSE position(',' || p_permission || ',' IN ',' || current_setting('test.perms', true) || ',') > 0
 END
$$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false) $$;
CREATE FUNCTION public.next_invoice_number() RETURNS text LANGUAGE sql SECURITY DEFINER
AS $$ SELECT 'INV-TEST-00001'::text $$;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.invoices, public.invoice_items TO authenticated;
