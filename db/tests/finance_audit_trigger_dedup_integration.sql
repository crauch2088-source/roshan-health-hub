-- Disposable PostgreSQL integration test for duplicate finance audit triggers.
-- Run ONLY against a fresh, disposable database:
--   psql -v ON_ERROR_STOP=1 -f db/tests/finance_audit_trigger_dedup_integration.sql
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.expenses CASCADE;
DROP TABLE IF EXISTS public.supplier_payments CASCADE;
DROP TABLE IF EXISTS public.cashbox_transactions CASCADE;

CREATE TABLE public.audit_logs (
  id bigserial PRIMARY KEY,
  table_name text NOT NULL,
  record_id uuid NOT NULL,
  action text NOT NULL,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.audit_logs(table_name, record_id, action, old_data, new_data)
  VALUES (TG_TABLE_NAME, CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END, TG_OP,
          CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
          CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END);
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_finance_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.audit_logs(table_name, record_id, action, old_data, new_data)
  VALUES (TG_TABLE_NAME, CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END, TG_OP,
          CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
          CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END);
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE TABLE public.payments (id uuid PRIMARY KEY, amount numeric NOT NULL);
CREATE TABLE public.expenses (id uuid PRIMARY KEY, amount numeric NOT NULL);
CREATE TABLE public.supplier_payments (id uuid PRIMARY KEY, amount numeric NOT NULL);
CREATE TABLE public.cashbox_transactions (id uuid PRIMARY KEY, amount numeric NOT NULL);

DO $$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['payments','expenses','supplier_payments','cashbox_transactions']
  LOOP
    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()',
      'trg_audit_' || tbl, tbl
    );
    EXECUTE format(
      'CREATE TRIGGER trg_finance_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.fn_finance_audit()',
      tbl
    );
  END LOOP;
END;
$$;

-- This migration must preserve finance-specific auditing while removing duplicates.
\ir ../roshan_phase4_finance_audit_trigger_dedup.sql

DO $$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['payments','expenses','supplier_payments','cashbox_transactions']
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_trigger
      WHERE tgrelid = format('public.%I', tbl)::regclass
        AND tgname = 'trg_audit_' || tbl
        AND NOT tgisinternal
    ) THEN
      RAISE EXCEPTION 'duplicate generic audit trigger remains on %', tbl;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger
      WHERE tgrelid = format('public.%I', tbl)::regclass
        AND tgname = 'trg_finance_audit'
        AND NOT tgisinternal
    ) THEN
      RAISE EXCEPTION 'finance audit trigger missing on %', tbl;
    END IF;
  END LOOP;
END;
$$;

INSERT INTO public.payments VALUES ('00000000-0000-0000-0000-000000000001', 10);
INSERT INTO public.expenses VALUES ('00000000-0000-0000-0000-000000000002', 20);
INSERT INTO public.supplier_payments VALUES ('00000000-0000-0000-0000-000000000003', 30);
INSERT INTO public.cashbox_transactions VALUES ('00000000-0000-0000-0000-000000000004', 40);

DO $$
BEGIN
  IF (SELECT count(*) FROM public.audit_logs) <> 4 THEN
    RAISE EXCEPTION 'expected one audit row per INSERT, got %', (SELECT count(*) FROM public.audit_logs);
  END IF;
END;
$$;

UPDATE public.payments SET amount = 11;
UPDATE public.expenses SET amount = 21;
UPDATE public.supplier_payments SET amount = 31;
UPDATE public.cashbox_transactions SET amount = 41;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.audit_logs) <> 8 THEN
    RAISE EXCEPTION 'expected one audit row per UPDATE, got %', (SELECT count(*) FROM public.audit_logs);
  END IF;
END;
$$;

DELETE FROM public.payments;
DELETE FROM public.expenses;
DELETE FROM public.supplier_payments;
DELETE FROM public.cashbox_transactions;

DO $$
BEGIN
  IF (SELECT count(*) FROM public.audit_logs) <> 12 THEN
    RAISE EXCEPTION 'expected one audit row per DELETE, got %', (SELECT count(*) FROM public.audit_logs);
  END IF;
END;
$$;

-- Confirm idempotency: running the migration again must leave the same triggers.
\ir ../roshan_phase4_finance_audit_trigger_dedup.sql

DO $$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['payments','expenses','supplier_payments','cashbox_transactions']
  LOOP
    IF (SELECT count(*) FROM pg_trigger
        WHERE tgrelid = format('public.%I', tbl)::regclass
          AND NOT tgisinternal
          AND tgname IN ('trg_audit_' || tbl, 'trg_finance_audit')) <> 1 THEN
      RAISE EXCEPTION 'unexpected audit trigger count after rerun on %', tbl;
    END IF;
  END LOOP;
END;
$$;

SELECT 'PASS: one finance audit record per row operation; migration is idempotent' AS result;
