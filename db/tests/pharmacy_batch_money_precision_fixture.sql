-- Minimal PostgreSQL 17 fixture for pharmacy batch/master-price consistency.
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE TABLE public.users(id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz, active boolean);
CREATE TABLE public.medicines(id uuid PRIMARY KEY, deleted_at timestamptz, active boolean NOT NULL DEFAULT true, selling_price numeric, stock_quantity integer NOT NULL DEFAULT 0, cost_price numeric, updated_at timestamptz, updated_by uuid);
CREATE TABLE public.suppliers(id uuid PRIMARY KEY, active boolean NOT NULL DEFAULT true, deleted_at timestamptz);
CREATE TABLE public.pharmacy_inventory(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), medicine_id uuid NOT NULL, batch_number text, batch_no text, expiry_date date, manufacture_date date, quantity numeric, quantity_received numeric, quantity_remaining numeric, purchase_price numeric(14,2), selling_price numeric(14,2), supplier_id uuid, invoice_reference text, branch_id uuid, created_by uuid, updated_by uuid);
CREATE TABLE public.stock_movements(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), medicine_id uuid, batch_id uuid, movement_type text, quantity numeric, reference_id uuid, reference_table text, branch_id uuid, created_by uuid);
GRANT SELECT ON public.medicines,public.pharmacy_inventory,public.stock_movements TO authenticated;
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('test.user_id',true),'')::uuid $$;
CREATE FUNCTION public.app_has_perm(p text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT COALESCE(current_setting('test.permissions',true) LIKE '%'||p||'%',false) $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT COALESCE(current_setting('test.super_admin',true)='true',false) $$;
CREATE FUNCTION public.fn_receive_pharmacy_batch(p_medicine_id uuid,p_quantity numeric,p_batch_number text DEFAULT NULL::text,p_expiry_date date DEFAULT NULL::date,p_manufacture_date date DEFAULT NULL::date,p_purchase_price numeric DEFAULT 0,p_selling_price numeric DEFAULT NULL::numeric,p_supplier_id uuid DEFAULT NULL::uuid,p_invoice_reference text DEFAULT NULL::text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$ BEGIN RAISE EXCEPTION 'unpatched pharmacy batch RPC'; END; $$;
GRANT EXECUTE ON FUNCTION public.fn_receive_pharmacy_batch(uuid,numeric,text,date,date,numeric,numeric,uuid,text) TO authenticated;
INSERT INTO public.users VALUES('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',NULL,true);
INSERT INTO public.users VALUES('10000000-0000-0000-0000-000000000002',NULL,NULL,true);
INSERT INTO public.suppliers(id,active,deleted_at) VALUES('40000000-0000-0000-0000-000000000001',false,NULL);
INSERT INTO public.medicines(id,selling_price,stock_quantity) VALUES('30000000-0000-0000-0000-000000000001',2.50,0),('30000000-0000-0000-0000-000000000002',2.501,0);
