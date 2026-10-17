-- Minimal PostgreSQL 17 fixture for claim approval/payment amount precision.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;

CREATE TABLE public.users (id uuid PRIMARY KEY, branch_id uuid);
CREATE TABLE public.invoices (id uuid PRIMARY KEY, branch_id uuid NOT NULL);
CREATE TABLE public.insurance_claims (
  id uuid PRIMARY KEY, claim_number text NOT NULL, invoice_id uuid NOT NULL REFERENCES public.invoices(id),
  status text NOT NULL, submitted_amount numeric(14,2) NOT NULL, approved_amount numeric(14,2),
  paid_amount numeric(14,2) NOT NULL DEFAULT 0, submitted_at timestamptz, decided_at timestamptz,
  paid_at timestamptz, notes text, created_by uuid, updated_by uuid, updated_at timestamptz, deleted_at timestamptz
);
CREATE TABLE public.insurance_claim_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), claim_id uuid NOT NULL REFERENCES public.insurance_claims(id),
  amount numeric(14,2) NOT NULL, payment_method text NOT NULL, reference text,
  received_at timestamptz NOT NULL DEFAULT now(), created_by uuid, created_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE public.test_ledger_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), transaction_type text NOT NULL, amount numeric NOT NULL,
  method text, category text, description text, source_type text, source_id uuid, created_at timestamptz, branch_id uuid
);
GRANT SELECT ON public.insurance_claims, public.insurance_claim_payments, public.test_ledger_posts TO authenticated;

CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('test.user_id', true), '')::uuid
$$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(current_setting('test.has_perm', true) = 'true', false)
$$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false)
$$;
CREATE FUNCTION private.app_has_claim_branch(p_claim_id uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT true $$;
CREATE FUNCTION public.fn_ledger_post(p_type text, p_amount numeric, p_method text, p_category text, p_description text, p_source_type text, p_source_id uuid, p_created_at timestamptz, p_branch_id uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE ledger_id uuid;
BEGIN
  INSERT INTO public.test_ledger_posts(transaction_type, amount, method, category, description, source_type, source_id, created_at, branch_id)
  VALUES (p_type, p_amount, p_method, p_category, p_description, p_source_type, p_source_id, p_created_at, p_branch_id)
  RETURNING id INTO ledger_id;
  RETURN ledger_id;
END;
$$;

-- Stubs ensure the migration must replace the exact callable signatures.
CREATE FUNCTION public.update_insurance_claim_status(_claim_id uuid, _new_status text, _approved_amount numeric DEFAULT NULL::numeric, _notes text DEFAULT NULL::text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$ BEGIN RAISE EXCEPTION 'unpatched status RPC'; END; $$;
CREATE FUNCTION public.post_insurance_claim_payment(_claim_id uuid, _amount numeric, _method text DEFAULT 'bank'::text, _reference text DEFAULT NULL::text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$ BEGIN RAISE EXCEPTION 'unpatched payment RPC'; END; $$;
GRANT EXECUTE ON FUNCTION public.update_insurance_claim_status(uuid,text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_insurance_claim_payment(uuid,numeric,text,text) TO authenticated;

INSERT INTO public.users(id, branch_id) VALUES ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
INSERT INTO public.invoices(id, branch_id) VALUES ('50000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
INSERT INTO public.insurance_claims(id, claim_number, invoice_id, status, submitted_amount, paid_amount, created_by)
VALUES ('30000000-0000-0000-0000-000000000001','CLM-TEST-001','50000000-0000-0000-0000-000000000001','draft',100.00,0,'10000000-0000-0000-0000-000000000001');
