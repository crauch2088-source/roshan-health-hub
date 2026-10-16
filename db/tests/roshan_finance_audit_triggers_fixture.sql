-- Disposable PostgreSQL fixture for duplicate finance audit trigger regression.
-- Creates only minimal stand-ins; never run this fixture against production.
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  auth_user_id uuid UNIQUE
);
CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  record_id uuid,
  action text NOT NULL,
  user_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.users(id, auth_user_id)
VALUES ('10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001');

CREATE OR REPLACE FUNCTION public.current_app_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT id FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.audit_row_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid;
BEGIN
  SELECT id INTO uid FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1;
  INSERT INTO public.audit_logs(table_name, record_id, action, user_id, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    (CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)->>'id' ELSE to_jsonb(NEW)->>'id' END)::uuid,
    TG_OP, uid,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN COALESCE(NEW, OLD);
END $$;

CREATE OR REPLACE FUNCTION public.fn_finance_audit() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE uid uuid;
BEGIN
  uid := public.current_app_user_id();
  INSERT INTO public.audit_logs(table_name, record_id, action, user_id, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
    TG_OP, uid,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE TABLE public.payments (id uuid PRIMARY KEY, value text);
CREATE TABLE public.expenses (id uuid PRIMARY KEY, value text);
CREATE TABLE public.supplier_payments (id uuid PRIMARY KEY, value text);
CREATE TABLE public.supplier_bills (id uuid PRIMARY KEY, value text);
CREATE TABLE public.cashbox_transactions (id uuid PRIMARY KEY, value text);

DO $fixture$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['payments','expenses','supplier_payments','supplier_bills','cashbox_transactions'] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()',
      'trg_audit_' || tbl, tbl
    );
    EXECUTE format(
      'CREATE TRIGGER trg_finance_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.fn_finance_audit()',
      tbl
    );
  END LOOP;
END $fixture$;
