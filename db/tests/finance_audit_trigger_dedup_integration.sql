SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.auth_uid','20000000-0000-0000-0000-000000000002',false);
INSERT INTO public.users(id,auth_user_id)
VALUES ('10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000002');

DO $test$
DECLARE
  table_name text;
  operation text;
  actual_count bigint;
  finance_table boolean;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'cashbox_transactions','expenses','payments','supplier_bills','supplier_payments','patients'
  ] LOOP
    EXECUTE format('INSERT INTO public.%I(value) VALUES (%L)',table_name,'before');
    EXECUTE format('UPDATE public.%I SET value = %L',table_name,'after');
    EXECUTE format('DELETE FROM public.%I',table_name);

    finance_table := table_name <> 'patients';

    FOREACH operation IN ARRAY ARRAY['INSERT','UPDATE','DELETE'] LOOP
      SELECT count(*) INTO actual_count
      FROM public.audit_logs
      WHERE public.audit_logs.table_name = table_name
        AND public.audit_logs.action = operation;

      IF actual_count <> 1 THEN
        RAISE EXCEPTION 'expected exactly one audit row for %.%, got %',
          table_name,operation,actual_count;
      END IF;
    END LOOP;

    IF finance_table THEN
      IF EXISTS (
        SELECT 1 FROM pg_trigger tr
        JOIN pg_class c ON c.oid=tr.tgrelid
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname=table_name
          AND tr.tgname='trg_audit_' || table_name AND NOT tr.tgisinternal
      ) THEN
        RAISE EXCEPTION 'duplicate generic audit trigger remains on %',table_name;
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM pg_trigger tr
        JOIN pg_class c ON c.oid=tr.tgrelid
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname=table_name
          AND tr.tgname='trg_finance_audit' AND NOT tr.tgisinternal
      ) THEN
        RAISE EXCEPTION 'canonical finance audit trigger missing on %',table_name;
      END IF;
    ELSE
      IF NOT EXISTS (
        SELECT 1 FROM pg_trigger tr
        JOIN pg_class c ON c.oid=tr.tgrelid
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname='patients'
          AND tr.tgname='trg_audit_patients' AND NOT tr.tgisinternal
      ) THEN
        RAISE EXCEPTION 'generic audit trigger was unexpectedly removed from patients';
      END IF;
    END IF;
  END LOOP;

  IF (SELECT count(*) FROM public.audit_logs) <> 18 THEN
    RAISE EXCEPTION 'expected 18 audit rows (one per operation/table), got %',
      (SELECT count(*) FROM public.audit_logs);
  END IF;
END
$test$;
