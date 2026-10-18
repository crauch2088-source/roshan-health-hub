CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  branch_id uuid,
  auth_user_id uuid,
  active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz
);
CREATE TABLE public.patients (
  id uuid PRIMARY KEY,
  branch_id uuid,
  deleted_at timestamptz
);
CREATE TABLE public.visits (
  id uuid PRIMARY KEY,
  branch_id uuid,
  patient_id uuid,
  deleted_at timestamptz
);
CREATE TABLE public.lab_orders (
  id uuid PRIMARY KEY,
  patient_id uuid NOT NULL,
  visit_id uuid,
  branch_id uuid,
  status text DEFAULT 'ordered',
  deleted_at timestamptz
);
CREATE TABLE public.lab_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL,
  status varchar DEFAULT 'pending',
  completed_at timestamptz,
  updated_by uuid,
  deleted_at timestamptz
);
CREATE TABLE public.medical_certificates (
  id serial PRIMARY KEY,
  patient_id uuid,
  doctor_id uuid,
  diagnosis text,
  start_date date,
  end_date date,
  created_at timestamptz DEFAULT now(),
  deleted_at timestamptz,
  deleted_by uuid
);
CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid,
  visit_id uuid,
  status text,
  deleted_at timestamptz
);
CREATE TABLE public.prescription_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id uuid,
  medicine_id uuid,
  quantity numeric,
  deleted_at timestamptz
);
CREATE TABLE public.patient_discounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid,
  discount_amount numeric,
  deleted_at timestamptz
);
CREATE TABLE public.patient_insurance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL
);
CREATE TABLE public.insurance_prior_authorizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_insurance_id uuid NOT NULL,
  status text,
  deleted_at timestamptz
);

ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_prior_authorizations ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $function$;
CREATE FUNCTION public.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $function$;
CREATE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT position('|' || p_permission || '|' IN
    '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0
$function$;
CREATE FUNCTION private.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT COALESCE(NULLIF(current_setting('test.super_admin', true), '')::boolean, false) $function$;
CREATE FUNCTION private.app_has_patient_branch(_patient_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false) OR EXISTS (
    SELECT 1
      FROM public.patients p
      JOIN public.users u ON u.auth_user_id = auth.uid()
     WHERE p.id = _patient_id
       AND p.branch_id = u.branch_id
       AND u.active IS TRUE
       AND u.deleted_at IS NULL
  )
$function$;
CREATE FUNCTION private.app_has_lab_order_item_branch_access(_order_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false) OR EXISTS (
    SELECT 1
      FROM public.lab_orders lo
      JOIN public.users u ON u.auth_user_id = auth.uid()
     WHERE lo.id = _order_id
       AND lo.branch_id = u.branch_id
       AND lo.deleted_at IS NULL
       AND u.active IS TRUE
       AND u.deleted_at IS NULL
  )
$function$;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.prescriptions, public.prescription_items, public.lab_order_items,
           public.medical_certificates, public.patient_discounts,
           public.insurance_prior_authorizations
  TO authenticated, anon;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE public.medical_certificates_id_seq TO authenticated, anon;
