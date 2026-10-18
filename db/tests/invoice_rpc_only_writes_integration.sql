SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.auth_uid','20000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.permissions','billing.create|billing.read|billing.view|billing.update|billing.delete|lab.create|visits.create',false);
INSERT INTO public.users(id,branch_id,auth_user_id)
VALUES ('10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000002');

INSERT INTO public.invoices(id,branch_id,invoice_date,total_amount)
VALUES
 ('70000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',current_date,1),
 ('70000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002',current_date,1);
INSERT INTO public.invoice_items(invoice_id,item_type,item_name,quantity,unit_price,total_price)
VALUES
 ('70000000-0000-0000-0000-000000000001','service','branch-read-test',1,1,1),
 ('70000000-0000-0000-0000-000000000002','service','branch-read-test',1,1,1);

SET ROLE authenticated;

DO $test$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['invoices','invoice_items'] LOOP
    IF has_table_privilege('authenticated',format('public.%I',table_name),'INSERT')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'UPDATE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'DELETE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'TRUNCATE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'REFERENCES')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'TRIGGER') THEN
      RAISE EXCEPTION 'authenticated retains direct write privileges on %',table_name;
    END IF;

    BEGIN
      EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',table_name);
      RAISE EXCEPTION 'direct INSERT unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
      EXECUTE format('UPDATE public.%I SET id=id',table_name);
      RAISE EXCEPTION 'direct UPDATE unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
      EXECUTE format('DELETE FROM public.%I',table_name);
      RAISE EXCEPTION 'direct DELETE unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;

  IF NOT has_table_privilege('authenticated','public.invoices','SELECT')
     OR NOT has_table_privilege('authenticated','public.invoice_items','SELECT') THEN
    RAISE EXCEPTION 'invoice read privileges were unexpectedly revoked';
  END IF;
  IF (SELECT count(*) FROM public.invoice_items) <> 1 THEN
    RAISE EXCEPTION 'invoice item SELECT policy did not enforce parent-branch access';
  END IF;
  IF has_table_privilege('anon','public.invoices','INSERT')
     OR has_table_privilege('anon','public.invoice_items','INSERT') THEN
    RAISE EXCEPTION 'anon retains direct invoice INSERT';
  END IF;
END
$test$;

SELECT public.create_billing_invoice_atomic(
  '30000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  NULL,current_date,0,'[]'::jsonb,false,
  '50000000-0000-0000-0000-000000000001'
);
SELECT public.create_visit_consultation_invoice_atomic(
  '40000000-0000-0000-0000-000000000002',current_date
);
SELECT public.create_lab_order_with_invoice_atomic(
  '40000000-0000-0000-0000-000000000003','routine','test notes',
  ARRAY['60000000-0000-0000-0000-000000000001'::uuid],false,
  '50000000-0000-0000-0000-000000000002'
);

RESET ROLE;

DELETE FROM public.invoice_items WHERE item_name='branch-read-test';
DELETE FROM public.invoices
WHERE id IN ('70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000002');

DO $test$
DECLARE expected_branch uuid := '20000000-0000-0000-0000-000000000001';
BEGIN
  IF (SELECT count(*) FROM public.invoices) <> 3 THEN
    RAISE EXCEPTION 'expected three invoice RPC writes';
  END IF;
  IF (SELECT count(*) FROM public.invoice_items) <> 3 THEN
    RAISE EXCEPTION 'expected three invoice-item RPC writes';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoices WHERE branch_id IS DISTINCT FROM expected_branch) THEN
    RAISE EXCEPTION 'an invoice RPC failed to assign the caller branch';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.invoice_items i
    LEFT JOIN public.invoices inv ON inv.id=i.invoice_id
    WHERE inv.id IS NULL
  ) THEN
    RAISE EXCEPTION 'an invoice item was persisted without its invoice';
  END IF;
END
$test$;
