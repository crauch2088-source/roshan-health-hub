-- Behavioral regression for db/roshan_phase4_deduplicate_finance_audit_triggers.sql.
-- Run only against the disposable PostgreSQL fixture in CI.
BEGIN;
SELECT set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);

DO $test$
DECLARE
  tbl text;
  rid uuid;
  op text;
  actual_count integer;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['payments','expenses','supplier_payments','supplier_bills','cashbox_transactions'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger t
      JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=tbl
        AND t.tgname='trg_audit_' || tbl AND NOT t.tgisinternal
    ) THEN
      RAISE EXCEPTION 'generic audit trigger missing on %', tbl;
    END IF;

    IF EXISTS (
      SELECT 1 FROM pg_trigger t
      JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=tbl
        AND t.tgname='trg_finance_audit' AND NOT t.tgisinternal
    ) THEN
      RAISE EXCEPTION 'duplicate finance audit trigger remains on %', tbl;
    END IF;

    rid := gen_random_uuid();
    EXECUTE format('INSERT INTO public.%I(id,value) VALUES ($1,$2)',tbl) USING rid,'insert';
    EXECUTE format('UPDATE public.%I SET value=$2 WHERE id=$1',tbl) USING rid,'update';
    EXECUTE format('DELETE FROM public.%I WHERE id=$1',tbl) USING rid;

    FOREACH op IN ARRAY ARRAY['INSERT','UPDATE','DELETE'] LOOP
      SELECT count(*) INTO actual_count
      FROM public.audit_logs
      WHERE table_name=tbl AND record_id=rid AND action=op;
      IF actual_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one % audit row for %.% but found %',op,tbl,rid,actual_count;
      END IF;
    END LOOP;
  END LOOP;
  RAISE NOTICE 'PASS: one audit row per INSERT/UPDATE/DELETE across four finance tables; generic audit triggers retained';
END $test$;
ROLLBACK;
