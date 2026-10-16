-- Disposable PostgreSQL fixture for finance audit-trigger regression.
-- Intentionally installs both trigger families as observed in production.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE public.audit_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name text NOT NULL,
  record_id uuid NOT NULL,
  action text NOT NULL,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.payments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), amount numeric NOT NULL DEFAULT 1);
CREATE TABLE public.expenses (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), amount numeric NOT NULL DEFAULT 1);
CREATE TABLE public.supplier_payments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), amount numeric NOT NULL DEFAULT 1);
CREATE TABLE public.cashbox_transactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), amount numeric NOT NULL DEFAULT 1);

CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.audit_logs(table_name, record_id, action, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    (CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)->>'id' ELSE to_jsonb(NEW)->>'id' END)::uuid,
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_finance_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.audit_logs(table_name, record_id, action, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    (CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)->>'id' ELSE to_jsonb(NEW)->>'id' END)::uuid,
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE TRIGGER trg_audit_payments AFTER INSERT OR UPDATE OR DELETE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR UPDATE OR DELETE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.fn_finance_audit();

CREATE TRIGGER trg_audit_expenses AFTER INSERT OR UPDATE OR DELETE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR UPDATE OR DELETE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION public.fn_finance_audit();

CREATE TRIGGER trg_audit_supplier_payments AFTER INSERT OR UPDATE OR DELETE ON public.supplier_payments
FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR UPDATE OR DELETE ON public.supplier_payments
FOR EACH ROW EXECUTE FUNCTION public.fn_finance_audit();

CREATE TRIGGER trg_audit_cashbox_transactions AFTER INSERT OR UPDATE OR DELETE ON public.cashbox_transactions
FOR EACH ROW EXECUTE FUNCTION public.audit_row_change();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR UPDATE OR DELETE ON public.cashbox_transactions
FOR EACH ROW EXECUTE FUNCTION public.fn_finance_audit();
