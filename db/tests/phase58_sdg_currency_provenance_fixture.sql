-- Synthetic PostgreSQL 17 fixture for Phase 58. Never run against Supabase.
CREATE SCHEMA private;

CREATE TABLE public.invoices (id uuid PRIMARY KEY, note text);
CREATE TABLE public.payments (id uuid PRIMARY KEY, note text, invoice_id uuid);
CREATE TABLE public.cashbox_transactions (id uuid PRIMARY KEY, note text, source_type text, source_id uuid, reversal_of uuid);
CREATE TABLE public.expenses (id uuid PRIMARY KEY, note text);
CREATE TABLE public.supplier_bills (id uuid PRIMARY KEY, note text);
CREATE TABLE public.supplier_payments (id uuid PRIMARY KEY, note text, supplier_bill_id uuid);
CREATE TABLE public.pharmacy_inventory (id uuid PRIMARY KEY, note text);

-- Preserve the deployed cashbox immutability boundary in this synthetic fixture.
CREATE FUNCTION public.fn_cashbox_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS 'BEGIN
  RAISE EXCEPTION ''cashbox entries are immutable'' USING ERRCODE = ''55000'';
END;';
CREATE TRIGGER trg_cashbox_immutable
BEFORE UPDATE OR DELETE ON public.cashbox_transactions
FOR EACH ROW EXECUTE FUNCTION public.fn_cashbox_immutable();

DO $phase58$
BEGIN
  CREATE ROLE test_writer;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$phase58$;
DO $phase58$
BEGIN
  CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$phase58$;
DO $phase58$
BEGIN
  CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$phase58$;
DO $phase58$
BEGIN
  CREATE ROLE service_role NOLOGIN BYPASSRLS;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$phase58$;
GRANT INSERT ON public.invoices TO test_writer;

-- Seed pre-migration legacy rows. The migration must preserve their unknown provenance.
INSERT INTO public.invoices (id, note) VALUES ('58000000-0000-0000-0000-000000000001', 'legacy');
INSERT INTO public.payments (id, note) VALUES ('58000000-0000-0000-0000-000000000002', 'legacy');
INSERT INTO public.cashbox_transactions (id, note) VALUES ('58000000-0000-0000-0000-000000000003', 'legacy');
INSERT INTO public.expenses (id, note) VALUES ('58000000-0000-0000-0000-000000000004', 'legacy');
INSERT INTO public.supplier_bills (id, note) VALUES ('58000000-0000-0000-0000-000000000005', 'legacy');
INSERT INTO public.supplier_payments (id, note) VALUES ('58000000-0000-0000-0000-000000000006', 'legacy');
INSERT INTO public.pharmacy_inventory (id, note) VALUES ('58000000-0000-0000-0000-000000000007', 'legacy');

-- Simulate the legacy hosted-only insurance payment RPC so the migration's conditional
-- privilege revocation is exercised in disposable PostgreSQL 17 CI.
CREATE OR REPLACE FUNCTION public.post_insurance_claim_payment(
  p_claim_id uuid,
  p_amount numeric,
  p_method text,
  p_reference text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'synthetic legacy insurance payment RPC must never be called';
END;
$$;

GRANT EXECUTE ON FUNCTION public.post_insurance_claim_payment(uuid, numeric, text, text)
  TO anon, authenticated, service_role;
