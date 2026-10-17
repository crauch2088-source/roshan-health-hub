-- Reject silent rounding and prove invoice, payment, and ledger values stay identical.
BEGIN; SET LOCAL ROLE authenticated;
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
SELECT set_config('test.permissions','payments.create',true);
SELECT set_config('test.super_admin','false',true);
DO $test$ DECLARE inv uuid:='50000000-0000-0000-0000-000000000001'; rejected boolean; before_payments integer; before_ledger integer; pay_id uuid; duplicate_id uuid; p_amount numeric; l_amount numeric; paid numeric;
BEGIN
 rejected:=false; BEGIN PERFORM public.post_invoice_payment(inv,1.001,'cash','over-precision','bad-precision'); RAISE EXCEPTION 'test failed: over-precision payment accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'over-precision invoice payment was not rejected'; END IF;
 rejected:=false; BEGIN PERFORM public.post_invoice_payment(inv,'NaN'::numeric,'cash','NaN','bad-nan'); RAISE EXCEPTION 'test failed: NaN payment accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'NaN invoice payment was not rejected'; END IF;
 IF (SELECT count(*) FROM public.payments)<>0 OR (SELECT count(*) FROM public.cashbox_transactions)<>0 OR (SELECT paid_amount FROM public.invoices WHERE id=inv)<>0 THEN RAISE EXCEPTION 'invalid invoice payments caused side effects'; END IF;
 pay_id:=public.post_invoice_payment(inv,1.01,'cash','valid','valid-idempotency-key');
 duplicate_id:=public.post_invoice_payment(inv,1.01,'cash','valid','valid-idempotency-key');
 IF pay_id IS DISTINCT FROM duplicate_id THEN RAISE EXCEPTION 'idempotent retry returned a different payment id'; END IF;
 SELECT amount INTO p_amount FROM public.payments WHERE id=pay_id; SELECT amount INTO l_amount FROM public.cashbox_transactions WHERE source_type='payment' AND source_id=pay_id; SELECT paid_amount INTO paid FROM public.invoices WHERE id=inv;
 IF p_amount IS DISTINCT FROM 1.01::numeric OR l_amount IS DISTINCT FROM p_amount OR paid IS DISTINCT FROM p_amount THEN RAISE EXCEPTION 'payment/ledger/invoice mismatch: %, %, %',p_amount,l_amount,paid; END IF;
 IF (SELECT count(*) FROM public.payments)<>1 OR (SELECT count(*) FROM public.cashbox_transactions)<>1 THEN RAISE EXCEPTION 'idempotent retry duplicated payment/ledger rows'; END IF;
END $test$; RESET ROLE; ROLLBACK;
