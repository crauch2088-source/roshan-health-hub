-- Minimal PostgreSQL 17 fixture for Phase 31 migration syntax/catalog regression.
-- Disposable CI database only. No production connection or data.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $auth_uid$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $auth_uid$;

CREATE TABLE public.roles (id uuid PRIMARY KEY, code text);
CREATE TABLE public.users (
  id uuid PRIMARY KEY, auth_user_id uuid, active boolean DEFAULT true,
  deleted_at timestamptz, branch_id uuid, role_id uuid, created_at timestamptz DEFAULT now()
);
CREATE TABLE public.permissions (id uuid PRIMARY KEY, code text);
CREATE TABLE public.role_permissions (role_id uuid, permission_id uuid);

CREATE FUNCTION private.current_app_user_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $body$ SELECT NULL::uuid $body$;
CREATE FUNCTION private.app_has_perm(_code text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $body$ SELECT true $body$;
CREATE FUNCTION private.is_super_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $body$ SELECT false $body$;
CREATE FUNCTION private.app_has_visit_branch_access(uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$ SELECT true $$;
CREATE FUNCTION private.app_has_lab_order_item_branch_access(uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$ SELECT true $$;
CREATE FUNCTION private.app_has_patient_branch(uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$ SELECT true $$;
CREATE FUNCTION public.app_has_perm(_code text) RETURNS boolean
LANGUAGE sql STABLE SET search_path TO '' AS $body$ SELECT private.app_has_perm(_code) $body$;
CREATE FUNCTION public.current_app_user_id() RETURNS uuid
LANGUAGE sql STABLE SET search_path TO '' AS $body$ SELECT private.current_app_user_id() $body$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean
LANGUAGE sql STABLE SET search_path TO '' AS $body$ SELECT private.is_super_admin() $body$;

CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, transaction_type text NOT NULL,
  amount numeric NOT NULL, payment_method text, category text, description text,
  source_type text, source_id uuid, transaction_date timestamptz NOT NULL DEFAULT now(),
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz,
  deleted_by uuid, is_reversed boolean NOT NULL DEFAULT false, reversal_of uuid, reversal_reason text
);
CREATE TABLE public.supplier_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), supplier_id uuid NOT NULL, branch_id uuid,
  invoice_number text, bill_date date NOT NULL DEFAULT CURRENT_DATE, due_date date,
  subtotal numeric NOT NULL DEFAULT 0, discount_amount numeric NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL DEFAULT 0, paid_amount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'unpaid', notes text, created_by uuid, updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz, deleted_by uuid
);
CREATE TABLE public.supplier_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), supplier_bill_id uuid NOT NULL,
  supplier_id uuid NOT NULL, branch_id uuid, amount numeric NOT NULL,
  payment_method text NOT NULL DEFAULT 'cash', reference text, payment_date timestamptz NOT NULL DEFAULT now(),
  notes text, created_by uuid, created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz, deleted_by uuid
);
CREATE TABLE public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, national_id text, deleted_at timestamptz
);
CREATE TABLE public.insurance_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invoice_id uuid, status text NOT NULL DEFAULT 'draft',
  deleted_at timestamptz
);
CREATE TABLE public.visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, patient_id uuid NOT NULL,
  status text DEFAULT 'waiting', completed_at timestamptz, updated_by uuid, updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);
CREATE TABLE public.queue_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), visit_id uuid, status text DEFAULT 'waiting',
  completed_at timestamptz, updated_by uuid, deleted_at timestamptz
);
CREATE TABLE public.lab_orders (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), deleted_at timestamptz);
CREATE TABLE public.lab_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL, test_id uuid NOT NULL,
  status varchar DEFAULT 'pending', deleted_at timestamptz, completed_at timestamptz, updated_by uuid
);
CREATE TABLE public.lab_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_item_id uuid NOT NULL,
  parameter_id uuid NOT NULL, result_value text, numeric_value numeric, deleted_at timestamptz
);
CREATE TABLE public.medical_certificates (
  id serial PRIMARY KEY, patient_id uuid, doctor_id uuid, diagnosis text,
  start_date date, end_date date, created_at timestamptz DEFAULT now(), deleted_at timestamptz
);

CREATE FUNCTION public.fn_dispense_prescription(uuid) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN RETURN; END $$;
CREATE FUNCTION public.create_medical_certificate(uuid,text,date,date) RETURNS integer
LANGUAGE sql AS $$ SELECT 1 $$;
GRANT EXECUTE ON FUNCTION public.fn_dispense_prescription(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_medical_certificate(uuid,text,date,date) TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lab_order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.medical_certificates TO authenticated;
GRANT ALL ON SEQUENCE public.medical_certificates_id_seq TO authenticated;
