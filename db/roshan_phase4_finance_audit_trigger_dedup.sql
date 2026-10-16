-- Remove duplicate generic audit triggers from finance tables.
-- The newer trg_finance_audit trigger remains the single audit writer on these tables.
-- Safe to re-run. Review and test on a disposable/staging database before production use.

DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'payments',
    'expenses',
    'supplier_payments',
    'cashbox_transactions'
  ]
  LOOP
    IF to_regclass(format('public.%I', tbl)) IS NOT NULL THEN
      EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', 'trg_audit_' || tbl, tbl);
    END IF;
  END LOOP;
END;
$$;
