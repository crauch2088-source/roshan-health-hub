CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  branch_id uuid,
  deleted_at timestamptz
);
CREATE TABLE public.medicines (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz,
  stock_quantity integer NOT NULL DEFAULT 0,
  cost_price numeric NOT NULL DEFAULT 0,
  selling_price numeric NOT NULL DEFAULT 0,
  updated_at timestamptz,
  updated_by uuid
);
CREATE TABLE public.suppliers (
  id uuid PRIMARY KEY,
  active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz
);
CREATE TABLE public.pharmacy_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id uuid NOT NULL,
  batch_number text,
  batch_no text,
  expiry_date date,
  manufacture_date date,
  quantity numeric NOT NULL,
  quantity_received numeric NOT NULL,
  quantity_remaining numeric NOT NULL,
  purchase_price numeric NOT NULL,
  selling_price numeric NOT NULL,
  supplier_id uuid,
  invoice_reference text,
  branch_id uuid,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamptz
);
CREATE TABLE public.stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id uuid NOT NULL,
  batch_id uuid,
  movement_type text NOT NULL,
  quantity numeric NOT NULL,
  reference_id uuid,
  reference_table text,
  branch_id uuid,
  created_by uuid
);
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY stock_movements_insert ON public.stock_movements
  FOR INSERT TO authenticated WITH CHECK (true);
GRANT SELECT, INSERT ON TABLE public.stock_movements TO authenticated;

CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.has_perm', true) = 'true', false) $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false) $$;

CREATE FUNCTION public.test_reject_stock_movement() RETURNS trigger LANGUAGE plpgsql
AS $test_trigger$
BEGIN
  IF current_setting('test.fail_movement', true) = 'true' THEN
    RAISE EXCEPTION 'injected_stock_movement_failure';
  END IF;
  RETURN NEW;
END;
$test_trigger$;
CREATE TRIGGER test_reject_stock_movement
BEFORE INSERT ON public.stock_movements
FOR EACH ROW EXECUTE FUNCTION public.test_reject_stock_movement();
