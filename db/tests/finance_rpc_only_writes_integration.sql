SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.permissions','accounting.create',false);
SELECT set_config('test.super_admin','false',false);

INSERT INTO public.users(id,branch_id,active)
VALUES ('10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',true);
INSERT INTO public.suppliers(id,active)
VALUES ('30000000-0000-0000-0000-000000000001',true);
INSERT INTO public.invoices(id,branch_id,net_amount,total_amount,paid_amount)
VALUES ('40000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',10,10,0);

SET ROLE authenticated;

DO $test$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'cashbox_transactions','expenses','payments','supplier_bills','supplier_payments',
    'insurance_claims','insurance_claim_items','insurance_claim_payments'
  ] LOOP
    IF has_table_privilege('authenticated',format('public.%I',table_name),'INSERT')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'UPDATE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'DELETE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'TRUNCATE')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'REFERENCES')
       OR has_table_privilege('authenticated',format('public.%I',table_name),'TRIGGER') THEN
      RAISE EXCEPTION 'authenticated retains direct DML/DDL-style table privileges on %',table_name;
    END IF;

    BEGIN
      EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',table_name);
      RAISE EXCEPTION 'direct INSERT unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;

    BEGIN
      EXECUTE format('UPDATE public.%I SET id = id',table_name);
      RAISE EXCEPTION 'direct UPDATE unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;

    BEGIN
      EXECUTE format('DELETE FROM public.%I',table_name);
      RAISE EXCEPTION 'direct DELETE unexpectedly succeeded on %',table_name;
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;
  END LOOP;

  IF has_table_privilege('anon','public.supplier_payments','INSERT') THEN
    RAISE EXCEPTION 'anon retains direct supplier payment INSERT';
  END IF;
END
$test$;

-- The two permission gates are deliberately exercised with accounting.create
-- only, matching the permission allowed by the live RLS policies and UI.
SELECT public.post_cashbox_entry('deposit',10,'cash','manual','test deposit',now());
SELECT public.post_expense('other',2,'test expense',current_date,'cash',NULL);
DO $payment_test$
DECLARE
  first_id uuid;
  retry_id uuid;
  rejected boolean := false;
  message text;
BEGIN
  BEGIN
    PERFORM public.post_invoice_payment(
      '40000000-0000-0000-0000-000000000001',11,'cash','overpayment','overpayment-key'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
    rejected := message LIKE '%exceeds outstanding balance%';
  END;
  IF NOT rejected THEN
    RAISE EXCEPTION 'payment RPC did not reject an amount above the outstanding balance';
  END IF;

  first_id := public.post_invoice_payment(
    '40000000-0000-0000-0000-000000000001',3,'cash','test payment','test-idempotency-key'
  );
  retry_id := public.post_invoice_payment(
    '40000000-0000-0000-0000-000000000001',3,'cash','test payment','test-idempotency-key'
  );
  IF first_id IS DISTINCT FROM retry_id THEN
    RAISE EXCEPTION 'payment RPC idempotent retry returned a different payment id';
  END IF;

  rejected := false;
  BEGIN
    PERFORM public.post_invoice_payment(
      '40000000-0000-0000-0000-000000000001',4,'cash','different amount','test-idempotency-key'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
    rejected := message LIKE '%idempotency key reused with different payment request%';
  END;
  IF NOT rejected THEN
    RAISE EXCEPTION 'payment RPC accepted a different payload for a committed idempotency key';
  END IF;
END
$payment_test$;
SELECT public.post_supplier_bill(
  '30000000-0000-0000-0000-000000000001','BILL-001',current_date,NULL,20,0,'test bill'
);
SELECT public.post_supplier_payment(
  (SELECT id FROM public.supplier_bills WHERE invoice_number='BILL-001'),
  1,'cash','test supplier payment',current_date,'test'
);

SELECT set_config('test.permissions','accounting.create|insurance.create|insurance.update',false);
SELECT public.create_insurance_claim(
  '50000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  '[{"service_type":"consultation","description":"test claim item","gross_amount":10,"covered_amount":8,"patient_amount":2}]'::jsonb,
  'test claim'
);
SELECT public.update_insurance_claim_status(
  (SELECT id FROM public.insurance_claims LIMIT 1),'approved',10,'approved'
);
SELECT public.post_insurance_claim_payment(
  (SELECT id FROM public.insurance_claims LIMIT 1),2,'bank','test insurance payment'
);

RESET ROLE;

DO $test$
DECLARE
  expected_branch uuid := '20000000-0000-0000-0000-000000000001';
BEGIN
  IF (SELECT count(*) FROM public.cashbox_transactions) <> 1 THEN
    RAISE EXCEPTION 'cashbox RPC did not create exactly one row';
  END IF;
  IF (SELECT count(*) FROM public.expenses) <> 1 THEN
    RAISE EXCEPTION 'expense RPC did not create exactly one row';
  END IF;
  IF (SELECT count(*) FROM public.payments) <> 1 THEN
    RAISE EXCEPTION 'payment RPC did not create exactly one row';
  END IF;
  IF (SELECT count(*) FROM public.supplier_bills) <> 1 THEN
    RAISE EXCEPTION 'supplier bill RPC did not create exactly one row';
  END IF;
  IF (SELECT count(*) FROM public.supplier_payments) <> 1 THEN
    RAISE EXCEPTION 'supplier payment RPC did not create exactly one row';
  END IF;
  IF (SELECT count(*) FROM public.insurance_claims) <> 1 THEN
    RAISE EXCEPTION 'insurance claim RPC did not create exactly one row';
  END IF;
  IF (SELECT count(*) FROM public.insurance_claim_items) <> 1 THEN
    RAISE EXCEPTION 'insurance claim RPC did not create one item';
  END IF;
  IF (SELECT count(*) FROM public.insurance_claim_payments) <> 1 THEN
    RAISE EXCEPTION 'insurance payment RPC did not create exactly one row';
  END IF;

  IF EXISTS (SELECT 1 FROM public.cashbox_transactions WHERE branch_id IS DISTINCT FROM expected_branch)
     OR EXISTS (SELECT 1 FROM public.expenses WHERE branch_id IS DISTINCT FROM expected_branch)
     OR EXISTS (SELECT 1 FROM public.payments WHERE branch_id IS DISTINCT FROM expected_branch)
     OR EXISTS (SELECT 1 FROM public.supplier_bills WHERE branch_id IS DISTINCT FROM expected_branch)
     OR EXISTS (SELECT 1 FROM public.supplier_payments WHERE branch_id IS DISTINCT FROM expected_branch) THEN
    RAISE EXCEPTION 'an RPC failed to assign the caller branch';
  END IF;
END
$test$;
