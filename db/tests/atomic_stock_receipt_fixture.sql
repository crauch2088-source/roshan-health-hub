-- Disposable PostgreSQL 17 fixture for atomic stock-receipt integration tests.
-- This runs only in an isolated CI service, never against Supabase production.
CREATE ROLE anon;
CREATE ROLE authenticated;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  branch_id uuid,
  deleted_at timestamptz
);

CREATE TABLE public.medicines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_quantity integer NOT NULL DEFAULT 0,
  deleted_at timestamptz,
  updated_at timestamptz DEFAULT now(),
  updated_by uuid
);

CREATE TABLE public.suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  active boolean DEFAULT true,
  deleted_at timestamptz
);

CREATE TABLE public.pharmacy_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id uuid NOT NULL,
  supplier_id uuid,
  batch_number text,
  quantity_received numeric NOT NULL,
  quantity_remaining numeric NOT NULL,
  quantity numeric,
  purchase_price numeric,
  selling_price numeric,
  manufacture_date date,
  expiry_date date,
  invoice_reference text,
  branch_id uuid,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
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
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  notes text
);

CREATE FUNCTION public.current_app_user_id()
RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT NULLIF(current_setting('test.user_id', true), '')::uuid
$$;

CREATE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT p_permission = 'pharmacy.create'
     AND COALESCE(current_setting('test.has_perm', true) = 'true', false)
$$;

CREATE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false)
$$;
