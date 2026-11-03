BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
SELECT set_config('test.permissions','cashbox.update',true);
SELECT set_config('test.super_admin','false',true);
DO $test$
DECLARE v_rejected boolean; v_error text; v_reversal_id uuid; v_original public.cashbox_transactions; v_payment public.payments; v_invoice public.invoices; v_reversal public.cashbox_transactions;
BEGIN
  IF has_function_privilege('anon','public.reverse_invoice_payment(uuid,text)','EXECUTE') THEN
    RAISE EXCEPTION 'anonymous role can execute invoice payment reversal';
  END IF;
  IF NOT has_function_privilege('authenticated','public.reverse_invoice_payment(uuid,text)','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated role cannot execute invoice payment reversal';
  END IF;
  v_rejected := false;
  BEGIN
    PERFORM public.reverse_cashbox_entry('70000000-0000-0000-0000-000000000001','generic payment reversal');
  EXCEPTION WHEN SQLSTATE '22023' THEN GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT; v_rejected := v_error LIKE '%source-specific payment reversal%'; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'generic cashbox reversal accepted an invoice payment'; END IF;
  IF (SELECT deleted_at FROM public.payments WHERE id='60000000-0000-0000-0000-000000000001') IS NOT NULL
     OR (SELECT paid_amount FROM public.invoices WHERE id='50000000-0000-0000-0000-000000000001') <> 50
     OR (SELECT is_reversed FROM public.cashbox_transactions WHERE id='70000000-0000-0000-0000-000000000001') THEN RAISE EXCEPTION 'blocked generic reversal caused side effects'; END IF;
  FOREACH v_reversal_id IN ARRAY ARRAY['70000000-0000-0000-0000-000000000004'::uuid,'70000000-0000-0000-0000-000000000005'::uuid] LOOP
    v_rejected := false;
    BEGIN PERFORM public.reverse_cashbox_entry(v_reversal_id,'generic source payment reversal');
    EXCEPTION WHEN SQLSTATE '22023' THEN GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT; v_rejected := v_error LIKE '%source-specific payment reversal%'; END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'generic cashbox reversal accepted a source payment: %',v_reversal_id; END IF;
  END LOOP;
  PERFORM set_config('test.user_id','10000000-0000-0000-0000-000000000002',true);
  v_rejected := false;
  BEGIN PERFORM public.reverse_invoice_payment('60000000-0000-0000-0000-000000000001','branch mismatch');
  EXCEPTION WHEN SQLSTATE '42501' THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'cross-branch invoice payment reversal was accepted'; END IF;
  IF (SELECT deleted_at FROM public.payments WHERE id='60000000-0000-0000-0000-000000000001') IS NOT NULL THEN RAISE EXCEPTION 'cross-branch reversal soft-deleted the payment'; END IF;
  PERFORM set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
  v_rejected := false;
  BEGIN PERFORM public.reverse_invoice_payment('60000000-0000-0000-0000-000000000004','branchless invoice payment');
  EXCEPTION WHEN SQLSTATE '42501' THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'branchless invoice payment reversal was accepted'; END IF;
  IF (SELECT deleted_at FROM public.payments WHERE id='60000000-0000-0000-0000-000000000004') IS NOT NULL
     OR (SELECT is_reversed FROM public.cashbox_transactions WHERE id='70000000-0000-0000-0000-000000000007')
     OR EXISTS(SELECT 1 FROM public.cashbox_transactions WHERE reversal_of='70000000-0000-0000-0000-000000000007') THEN
    RAISE EXCEPTION 'branchless invoice reversal left side effects';
  END IF;
  v_reversal_id := public.reverse_invoice_payment('60000000-0000-0000-0000-000000000001','duplicate bank settlement');
  SELECT * INTO v_payment FROM public.payments WHERE id='60000000-0000-0000-0000-000000000001';
  SELECT * INTO v_invoice FROM public.invoices WHERE id='50000000-0000-0000-0000-000000000001';
  SELECT * INTO v_original FROM public.cashbox_transactions WHERE id='70000000-0000-0000-0000-000000000001';
  SELECT * INTO v_reversal FROM public.cashbox_transactions WHERE id=v_reversal_id;
  IF v_payment.deleted_at IS NULL OR v_payment.deleted_by IS DISTINCT FROM '10000000-0000-0000-0000-000000000001'::uuid THEN RAISE EXCEPTION 'payment was not soft-deleted with actor attribution'; END IF;
  IF v_invoice.paid_amount <> 10 OR v_invoice.status <> 'partial' OR v_invoice.payment_status <> 'partial' THEN RAISE EXCEPTION 'invoice paid balance/status did not recompute after reversal'; END IF;
  IF NOT v_original.is_reversed OR v_original.reversal_reason <> 'duplicate bank settlement' THEN RAISE EXCEPTION 'original immutable ledger row was not marked reversed'; END IF;
  IF v_reversal.reversal_of IS DISTINCT FROM v_original.id OR v_reversal.amount <> -40 OR v_reversal.source_type <> 'reversal' OR v_reversal.reversal_reason <> 'duplicate bank settlement' THEN RAISE EXCEPTION 'reversal ledger row is not correctly linked or valued'; END IF;
  v_rejected := false;
  BEGIN PERFORM public.reverse_invoice_payment('60000000-0000-0000-0000-000000000001','second attempt');
  EXCEPTION WHEN SQLSTATE '22023' THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'duplicate invoice payment reversal was accepted'; END IF;
  IF (SELECT count(*) FROM public.cashbox_transactions WHERE reversal_of='70000000-0000-0000-0000-000000000001') <> 1 THEN RAISE EXCEPTION 'duplicate invoice payment reversal ledger row was created'; END IF;
  v_reversal_id := public.reverse_cashbox_entry('70000000-0000-0000-0000-000000000003','office supplies correction');
  IF NOT (SELECT is_reversed FROM public.cashbox_transactions WHERE id='70000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION 'generic non-payment cashbox reversal failed'; END IF;
  IF (SELECT amount FROM public.cashbox_transactions WHERE id=v_reversal_id) <> 5 THEN RAISE EXCEPTION 'generic expense reversal amount is incorrect'; END IF;
END
$test$;
ROLLBACK;
