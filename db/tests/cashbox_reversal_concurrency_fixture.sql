-- Isolated fixture for a real two-session cashbox reversal race.
CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  branch_id uuid
);

CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  transaction_type text NOT NULL,
  amount numeric NOT NULL,
  payment_method text,
  category text,
  description text,
  source_type text,
  transaction_date timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  reversal_of uuid,
  reversal_reason text,
  is_reversed boolean NOT NULL DEFAULT false
);

CREATE OR REPLACE FUNCTION public.app_has_perm(_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT true $$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT true $$;

CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT '10000000-0000-0000-0000-000000000001'::uuid $$;

-- Keep the first reversal transaction open long enough for the second psql
-- session to overlap while the function holds SELECT ... FOR UPDATE on original.
CREATE OR REPLACE FUNCTION public.test_delay_reversal_insert()
RETURNS trigger LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.source_type = 'reversal' THEN
    PERFORM pg_sleep(1.0);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER test_delay_reversal_insert
BEFORE INSERT ON public.cashbox_transactions
FOR EACH ROW EXECUTE FUNCTION public.test_delay_reversal_insert();
