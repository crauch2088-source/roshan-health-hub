CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;
CREATE TABLE public.users (id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.patient_insurance (
 id uuid PRIMARY KEY, patient_id uuid NOT NULL, status text, start_date date, expiry_date date, deleted_at timestamptz
);
CREATE TABLE public.invoices (id uuid PRIMARY KEY, patient_id uuid, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.insurance_claims (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), patient_insurance_id uuid, invoice_id uuid,
 status text, submitted_amount numeric, notes text, created_by uuid
);
CREATE TABLE public.insurance_claim_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), claim_id uuid, service_type text, reference_id uuid,
 description text, gross_amount numeric, covered_amount numeric, patient_amount numeric, coverage_rule_id uuid
);
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.has_perm', true) = 'true', false) $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false) $$;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT ON public.insurance_claims, public.insurance_claim_items TO authenticated;
