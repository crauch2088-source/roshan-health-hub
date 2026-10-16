CREATE SCHEMA auth;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  auth_user_id uuid
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

CREATE TABLE public.cashbox_transactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), value text);
CREATE TABLE public.expenses (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), value text);
CREATE TABLE public.payments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), value text);
CREATE TABLE public.supplier_bills (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), value text);
CREATE TABLE public.supplier_payments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), value text);
CREATE TABLE public.patients (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), value text);

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $$;

CREATE FUNCTION public.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;

CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE uid uuid;
BEGIN
  SELECT id INTO uid FROM public.users WHERE auth_user_id = auth.uid() LIMIT 1;
  INSERT INTO public.audit_logs(user_id, action, table_name, record_id, old_data, new_data)
  VALUES (
    uid, TG_OP, TG_TABLE_NAME,
    (CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD)->>'id' ELSE to_jsonb(NEW)->>'id' END)::uuid,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN COALESCE(NEW, OLD);
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_finance_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE uid uuid;
BEGIN
  BEGIN
    uid := public.current_app_user_id();
  EXCEPTION WHEN OTHERS THEN
    uid := NULL;
  END;
  INSERT INTO public.audit_logs(table_name, record_id, action, user_id, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    COALESCE((CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END), gen_random_uuid()),
    TG_OP, uid,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$function$;

DO $setup$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'cashbox_transactions','expenses','payments','supplier_bills','supplier_payments'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()',
      'trg_audit_' || table_name, table_name
    );
    EXECUTE format(
      'CREATE TRIGGER trg_finance_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.fn_finance_audit()',
      table_name
    );
  END LOOP;
  EXECUTE 'CREATE TRIGGER trg_audit_patients AFTER INSERT OR UPDATE OR DELETE ON public.patients FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()';
END;
$setup$;
