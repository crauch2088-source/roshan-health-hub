-- Synthetic PostgreSQL 17 fixture for Phase 59. Never run against Supabase.
CREATE SCHEMA private;

DO $phase59$
BEGIN
  CREATE ROLE authenticated;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$phase59$;
DO $phase59$
BEGIN
  CREATE ROLE anon;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$phase59$;
DO $phase59$
BEGIN
  CREATE ROLE service_role NOLOGIN BYPASSRLS;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$phase59$;

CREATE FUNCTION public.app_has_perm(_permission text)
RETURNS boolean
LANGUAGE sql
STABLE
AS $function$
  SELECT pg_catalog.current_setting('test.allow_perm', true) = 'on';
$function$;

CREATE FUNCTION private.app_has_branch_access(_branch_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $function$
  SELECT pg_catalog.current_setting('test.allow_branch', true) = 'on';
$function$;

CREATE TABLE public.invoices (
  id uuid PRIMARY KEY,
  branch_id uuid NOT NULL,
  deleted_at timestamptz
);
CREATE TABLE public.payments (
  id uuid PRIMARY KEY,
  invoice_id uuid NOT NULL,
  amount numeric NOT NULL,
  branch_id uuid NOT NULL,
  deleted_at timestamptz
);
CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY,
  source_type text,
  source_id uuid,
  reversal_of uuid,
  branch_id uuid,
  amount numeric,
  is_reversed boolean NOT NULL DEFAULT false,
  reversal_reason text,
  transaction_date timestamptz NOT NULL DEFAULT pg_catalog.now()
);
CREATE TABLE public.expenses (id uuid PRIMARY KEY);
CREATE TABLE public.supplier_bills (id uuid PRIMARY KEY);
CREATE TABLE public.supplier_payments (id uuid PRIMARY KEY);
CREATE TABLE public.pharmacy_inventory (id uuid PRIMARY KEY);

CREATE FUNCTION public.fn_cashbox_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'DELETE'
     OR pg_catalog.current_setting('roshan.cashbox_write', true) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'cashbox entries are immutable' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_cashbox_immutable
BEFORE UPDATE OR DELETE ON public.cashbox_transactions
FOR EACH ROW EXECUTE FUNCTION public.fn_cashbox_immutable();

-- Legacy rows predate Phase 58 and must remain NULL, not inherit a current setting.
INSERT INTO public.invoices (id, branch_id)
VALUES (
  '59000000-0000-0000-0000-000000000001',
  '59000000-0000-0000-0000-000000000099'
);
INSERT INTO public.payments (id, invoice_id, amount, branch_id)
VALUES (
  '59000000-0000-0000-0000-000000000002',
  '59000000-0000-0000-0000-000000000001',
  50,
  '59000000-0000-0000-0000-000000000099'
);
INSERT INTO public.cashbox_transactions (
  id, source_type, source_id, branch_id, amount
) VALUES (
  '59000000-0000-0000-0000-000000000003',
  'payment',
  '59000000-0000-0000-0000-000000000002',
  '59000000-0000-0000-0000-000000000099',
  50
);
