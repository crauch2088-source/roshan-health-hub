CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;
CREATE TABLE public.users (id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.visits (id uuid PRIMARY KEY, patient_id uuid NOT NULL, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.medicines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text, generic_name text,
 selling_price numeric, active boolean DEFAULT true, is_active boolean DEFAULT true, deleted_at timestamptz
);
CREATE TABLE public.prescriptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), patient_id uuid NOT NULL, visit_id uuid,
 prescribed_by uuid, doctor_id uuid, prescription_type varchar, is_external boolean,
 status text, created_by uuid, created_at timestamptz DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE public.prescription_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), prescription_id uuid NOT NULL, medicine_id uuid,
 medication_name varchar, dose varchar, frequency varchar, duration varchar, quantity numeric,
 instructions text, created_by uuid, updated_by uuid, deleted_at timestamptz, deleted_by uuid,
 dosage text, is_dispensed boolean, dispensed_quantity integer, unit_price numeric,
 created_at timestamptz DEFAULT now(), dosage_form text, route text, updated_at timestamptz DEFAULT now()
);
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.has_perm', true) = 'true', false) $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false) $$;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT ON public.prescriptions, public.prescription_items TO authenticated;
