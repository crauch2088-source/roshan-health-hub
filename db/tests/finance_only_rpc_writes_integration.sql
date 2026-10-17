DO $test$
DECLARE t text;
BEGIN
 IF has_function_privilege('authenticated','public.add_cashbox_entry(text,numeric,text,text,text,text,timestamptz)','EXECUTE') THEN RAISE EXCEPTION 'legacy add_cashbox_entry remains callable'; END IF;
 IF has_function_privilege('anon','public.add_cashbox_entry(text,numeric,text,text,text,text,timestamptz)','EXECUTE') THEN RAISE EXCEPTION 'anon can execute legacy cashbox RPC'; END IF;
 IF NOT has_function_privilege('authenticated','public.post_cashbox_entry(text,numeric,text,text,text,timestamptz)','EXECUTE') THEN RAISE EXCEPTION 'cashbox RPC EXECUTE missing'; END IF;
 IF NOT has_function_privilege('authenticated','public.post_invoice_payment(uuid,numeric,text,text,text)','EXECUTE') THEN RAISE EXCEPTION 'invoice payment RPC EXECUTE missing'; END IF;
 IF NOT has_function_privilege('authenticated','public.post_supplier_bill(uuid,text,date,date,numeric,numeric,text)','EXECUTE') THEN RAISE EXCEPTION 'supplier bill RPC EXECUTE missing'; END IF;
 FOREACH t IN ARRAY ARRAY['cashbox_transactions','expenses','payments','supplier_bills','supplier_payments'] LOOP
  IF has_table_privilege('authenticated',format('public.%I',t),'INSERT')
     OR has_table_privilege('authenticated',format('public.%I',t),'UPDATE')
     OR has_table_privilege('authenticated',format('public.%I',t),'DELETE')
     OR has_table_privilege('authenticated',format('public.%I',t),'TRUNCATE')
     OR has_table_privilege('authenticated',format('public.%I',t),'REFERENCES')
     OR has_table_privilege('authenticated',format('public.%I',t),'TRIGGER') THEN
    RAISE EXCEPTION 'authenticated retains direct write/structural privilege on %',t;
  END IF;
  IF has_table_privilege('anon',format('public.%I',t),'INSERT')
     OR has_table_privilege('anon',format('public.%I',t),'UPDATE')
     OR has_table_privilege('anon',format('public.%I',t),'DELETE')
     OR has_table_privilege('anon',format('public.%I',t),'TRUNCATE') THEN
    RAISE EXCEPTION 'anon retains direct mutation privilege on %',t;
  END IF;
 END LOOP;
END
$test$;

SET ROLE authenticated;
DO $test$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['cashbox_transactions','expenses','payments','supplier_bills','supplier_payments'] LOOP
  BEGIN EXECUTE format('INSERT INTO public.%I DEFAULT VALUES',t); RAISE EXCEPTION 'direct INSERT allowed on %',t; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN EXECUTE format('UPDATE public.%I SET id=id WHERE false',t); RAISE EXCEPTION 'direct UPDATE allowed on %',t; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN EXECUTE format('DELETE FROM public.%I WHERE false',t); RAISE EXCEPTION 'direct DELETE allowed on %',t; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
END
$test$;

-- Cashbox RPC: positive, signed amount, server-assigned branch and invalid amount rejection.
SELECT public.post_cashbox_entry('deposit',10,'cash','manual','synthetic test',now());
SELECT public.post_cashbox_entry('withdrawal',2,'cash','manual','synthetic test',now());
DO $test$
BEGIN
 IF (SELECT count(*) FROM public.cashbox_transactions)<>2 THEN RAISE EXCEPTION 'cashbox RPC row count mismatch'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.cashbox_transactions WHERE amount=10 AND branch_id='20000000-0000-0000-0000-000000000001') THEN RAISE EXCEPTION 'deposit missing branch or signed amount'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.cashbox_transactions WHERE amount=-2 AND branch_id='20000000-0000-0000-0000-000000000001') THEN RAISE EXCEPTION 'withdrawal missing branch or signed amount'; END IF;
 BEGIN PERFORM public.post_cashbox_entry('deposit',0,'cash','manual','invalid',now()); RAISE EXCEPTION 'zero cashbox amount accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END
$test$;

-- Invoice payment RPC: overpayment rejection, idempotent retry, payload conflict and branch isolation.
DO $payment_test$
DECLARE first_id uuid; retry_id uuid; msg text; rejected boolean;
BEGIN
 rejected:=false;
 BEGIN PERFORM public.post_invoice_payment('40000000-0000-0000-0000-000000000001',11,'cash','overpay','key-overpay');
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS msg=MESSAGE_TEXT; rejected:=msg LIKE '%exceeds outstanding balance%'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'overpayment was not rejected'; END IF;
 first_id:=public.post_invoice_payment('40000000-0000-0000-0000-000000000001',3,'cash','test','key-valid');
 retry_id:=public.post_invoice_payment('40000000-0000-0000-0000-000000000001',3,'cash','test','key-valid');
 IF first_id IS DISTINCT FROM retry_id THEN RAISE EXCEPTION 'idempotent retry returned different ID'; END IF;
 rejected:=false;
 BEGIN PERFORM public.post_invoice_payment('40000000-0000-0000-0000-000000000001',4,'cash','different','key-valid');
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS msg=MESSAGE_TEXT; rejected:=msg LIKE '%idempotency key reused with different payment request%'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'idempotency key accepted a different payload'; END IF;
 rejected:=false;
 BEGIN PERFORM public.post_invoice_payment('40000000-0000-0000-0000-000000000001',8,'cash','second','key-second');
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS msg=MESSAGE_TEXT; rejected:=msg LIKE '%exceeds outstanding balance%'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'payment exceeding post-payment balance was accepted'; END IF;
END
$payment_test$;

-- Supplier bill RPC: validates active supplier, discount bounds and branch assignment.
SELECT public.post_supplier_bill('30000000-0000-0000-0000-000000000001','BILL-QA',current_date,NULL,20,2,'synthetic test');
DO $test$
DECLARE rejected boolean:=false; msg text;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.supplier_bills WHERE invoice_number='BILL-QA' AND branch_id='20000000-0000-0000-0000-000000000001' AND total_amount=18) THEN RAISE EXCEPTION 'supplier bill did not derive branch or net amount'; END IF;
 BEGIN PERFORM public.post_supplier_bill('30000000-0000-0000-0000-000000000001','BILL-BAD',current_date,NULL,20,21,'invalid'); EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS msg=MESSAGE_TEXT; rejected:=msg LIKE '%discount must be finite and between zero and subtotal%'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'supplier bill accepted discount above subtotal'; END IF;
 rejected:=false;
 BEGIN PERFORM public.post_supplier_bill('ffffffff-ffff-ffff-ffff-ffffffffffff','BILL-MISSING',current_date,NULL,20,0,'invalid'); EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS msg=MESSAGE_TEXT; rejected:=msg LIKE '%active supplier not found%'; END;
 IF NOT rejected THEN RAISE EXCEPTION 'supplier bill accepted missing supplier'; END IF;
END
$test$;
RESET ROLE;

DO $test$
BEGIN
 IF (SELECT count(*) FROM public.payments)<>1 THEN RAISE EXCEPTION 'payment idempotency did not preserve one payment'; END IF;
 IF (SELECT paid_amount FROM public.invoices WHERE id='40000000-0000-0000-0000-000000000001')<>3 THEN RAISE EXCEPTION 'invoice paid amount did not match one payment'; END IF;
 IF (SELECT count(*) FROM public.cashbox_transactions)<>2 THEN RAISE EXCEPTION 'cashbox direct-write guard changed RPC writes'; END IF;
 IF (SELECT count(*) FROM public.supplier_bills)<>1 THEN RAISE EXCEPTION 'supplier bill invalid attempts left rows'; END IF;
END
$test$;
