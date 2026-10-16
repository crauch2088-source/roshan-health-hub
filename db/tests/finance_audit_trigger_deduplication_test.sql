-- Regression: every finance row change should write exactly one audit row.
-- Apply db/roshan_phase17_deduplicate_finance_audit_triggers.sql first; this test runs only on disposable PostgreSQL.
BEGIN;

INSERT INTO public.payments(amount) VALUES (11);
INSERT INTO public.expenses(amount) VALUES (12);
INSERT INTO public.supplier_payments(amount) VALUES (13);
INSERT INTO public.cashbox_transactions(amount) VALUES (14);

DO $$
DECLARE
  t text;
  n integer;
BEGIN
  FOREACH t IN ARRAY ARRAY['payments','expenses','supplier_payments','cashbox_transactions']
  LOOP
    SELECT count(*) INTO n FROM public.audit_logs WHERE table_name=t AND action='INSERT';
    IF n <> 1 THEN
      RAISE EXCEPTION 'FAIL: expected one audit row for %, got %', t, n;
    END IF;
    RAISE NOTICE 'PASS: one audit row for %', t;
  END LOOP;
END;
$$;

ROLLBACK;
