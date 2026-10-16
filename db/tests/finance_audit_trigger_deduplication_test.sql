-- Regression: every finance row change should write exactly one audit row.
-- Runs only against the disposable PostgreSQL fixture after the proposed migration.
BEGIN;

CREATE TEMP TABLE _finance_test_ids (table_name text PRIMARY KEY, id uuid NOT NULL);

WITH created AS (INSERT INTO public.payments(amount) VALUES (11) RETURNING id)
INSERT INTO _finance_test_ids SELECT 'payments', id FROM created;
WITH created AS (INSERT INTO public.expenses(amount) VALUES (12) RETURNING id)
INSERT INTO _finance_test_ids SELECT 'expenses', id FROM created;
WITH created AS (INSERT INTO public.supplier_payments(amount) VALUES (13) RETURNING id)
INSERT INTO _finance_test_ids SELECT 'supplier_payments', id FROM created;
WITH created AS (INSERT INTO public.cashbox_transactions(amount) VALUES (14) RETURNING id)
INSERT INTO _finance_test_ids SELECT 'cashbox_transactions', id FROM created;

DO $$
DECLARE
  t text;
  op text;
  n integer;
  target_id uuid;
BEGIN
  FOREACH t IN ARRAY ARRAY['payments','expenses','supplier_payments','cashbox_transactions']
  LOOP
    SELECT id INTO target_id FROM _finance_test_ids WHERE table_name=t;
    EXECUTE format('UPDATE public.%I SET amount = amount + 1 WHERE id = $1', t) USING target_id;
    EXECUTE format('DELETE FROM public.%I WHERE id = $1', t) USING target_id;

    FOREACH op IN ARRAY ARRAY['INSERT','UPDATE','DELETE']
    LOOP
      SELECT count(*) INTO n
        FROM public.audit_logs
       WHERE table_name=t AND action=op AND record_id=target_id;
      IF n <> 1 THEN
        RAISE EXCEPTION 'FAIL: expected one audit row for % %, got %', t, op, n;
      END IF;
      RAISE NOTICE 'PASS: one audit row for % %', t, op;
    END LOOP;
  END LOOP;
END;
$$;

ROLLBACK;
