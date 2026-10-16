CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE TABLE public.users (id uuid PRIMARY KEY, auth_user_id uuid, branch_id uuid, active boolean DEFAULT true, deleted_at timestamptz);
CREATE TABLE public.patients (id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.patient_insurance (
 id uuid PRIMARY KEY, patient_id uuid NOT NULL, company_id uuid, plan_id uuid,
 status text, start_date date, expiry_date date, deleted_at timestamptz
);
CREATE TABLE public.insurance_companies (
 id uuid PRIMARY KEY, active boolean DEFAULT true, deleted_at timestamptz
);
CREATE TABLE public.insurance_plans (
 id uuid PRIMARY KEY, company_id uuid NOT NULL, default_coverage_percent numeric DEFAULT 0,
 requires_prior_auth boolean DEFAULT false, active boolean DEFAULT true, deleted_at timestamptz
);
CREATE TABLE public.insurance_coverage_rules (
 id uuid PRIMARY KEY, plan_id uuid NOT NULL, service_type text NOT NULL, reference_id uuid,
 generic_name text, coverage_percent numeric, fixed_amount numeric,
 requires_prior_auth boolean DEFAULT false, excluded boolean DEFAULT false, created_at timestamptz DEFAULT now(),
 deleted_at timestamptz
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
AS $public_admin$ SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false) $public_admin$;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $authuid$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $authuid$;
CREATE FUNCTION private.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $privateperm$ SELECT COALESCE(current_setting('test.has_perm', true) = 'true', false) $privateperm$;
CREATE FUNCTION private.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $private_admin$ SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false) $private_admin$;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT ON public.insurance_claims, public.insurance_claim_items TO authenticated;
