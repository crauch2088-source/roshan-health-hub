-- Reject purchase/selling prices that would be rounded in batch storage or diverge from medicine master values.
BEGIN; SET LOCAL ROLE authenticated;
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
SELECT set_config('test.permissions','pharmacy.update',true); SELECT set_config('test.super_admin','false',true);
DO $test$ DECLARE rejected boolean; batch_id uuid; batch_purchase numeric; batch_selling numeric; master_cost numeric; master_selling numeric; stock integer;
BEGIN
 rejected:=false; BEGIN PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',5,NULL,NULL,NULL,1.001,2.50); RAISE EXCEPTION 'test failed: over-precision purchase price accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'over-precision purchase price was not rejected'; END IF;
 rejected:=false; BEGIN PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',5,NULL,NULL,NULL,1.00,2.501); RAISE EXCEPTION 'test failed: over-precision selling price accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'over-precision selling price was not rejected'; END IF;
 rejected:=false; BEGIN PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000002',5,NULL,NULL,NULL,1.00,NULL); RAISE EXCEPTION 'test failed: over-precision master selling price accepted'; EXCEPTION WHEN SQLSTATE '22023' THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'over-precision master selling price was not rejected'; END IF;
 IF (SELECT count(*) FROM public.pharmacy_inventory)<>0 OR (SELECT count(*) FROM public.stock_movements)<>0 OR (SELECT sum(stock_quantity) FROM public.medicines)<>0 THEN RAISE EXCEPTION 'invalid batch attempts wrote inventory/stock movement or changed stock'; END IF;
 batch_id:=public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',5,'BATCH-OK',NULL,NULL,1.25,2.50);
 SELECT purchase_price,selling_price INTO batch_purchase,batch_selling FROM public.pharmacy_inventory WHERE id=batch_id;
 SELECT cost_price,selling_price,stock_quantity INTO master_cost,master_selling,stock FROM public.medicines WHERE id='30000000-0000-0000-0000-000000000001';
 IF batch_purchase IS DISTINCT FROM 1.25::numeric OR batch_selling IS DISTINCT FROM 2.50::numeric OR master_cost IS DISTINCT FROM batch_purchase OR master_selling IS DISTINCT FROM batch_selling OR stock<>5 THEN RAISE EXCEPTION 'batch/master price or stock mismatch'; END IF;
 IF (SELECT count(*) FROM public.stock_movements)<>1 THEN RAISE EXCEPTION 'valid batch should create exactly one stock movement'; END IF;
END $test$;

DO $idempotency$
DECLARE
  batch_id uuid;
  retry_id uuid;
  rejected boolean;
  stock integer;
BEGIN
  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',5,NULL,NULL,NULL,1.001,2.50,NULL,NULL,'bad-purchase-precision'
    );
    RAISE EXCEPTION 'test failed: atomic RPC accepted over-precision purchase price';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'atomic RPC did not reject over-precision purchase price'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',5,NULL,NULL,NULL,1.00,2.501,NULL,NULL,'bad-selling-precision'
    );
    RAISE EXCEPTION 'test failed: atomic RPC accepted over-precision selling price';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'atomic RPC did not reject over-precision selling price'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000002',5,NULL,NULL,NULL,1.00,NULL,NULL,NULL,'bad-master-price'
    );
    RAISE EXCEPTION 'test failed: atomic RPC accepted over-precision master selling price';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'atomic RPC did not reject over-precision master selling price'; END IF;

  IF (SELECT count(*) FROM public.pharmacy_inventory) <> 1
     OR (SELECT count(*) FROM public.stock_movements) <> 1
     OR (SELECT stock_quantity FROM public.medicines WHERE id='30000000-0000-0000-0000-000000000001') <> 5
     OR (SELECT stock_quantity FROM public.medicines WHERE id='30000000-0000-0000-0000-000000000002') <> 0 THEN
    RAISE EXCEPTION 'invalid atomic batch attempts changed inventory or stock';
  END IF;

  batch_id := public.fn_receive_pharmacy_batch_atomic(
    '30000000-0000-0000-0000-000000000001',3,'BATCH-IDEMPOTENT',NULL,NULL,1.25,2.50,NULL,'INV-RECEIVE-1','receive-idempotency-1'
  );
  retry_id := public.fn_receive_pharmacy_batch_atomic(
    '30000000-0000-0000-0000-000000000001',3,'BATCH-IDEMPOTENT',NULL,NULL,1.25,2.50,NULL,'INV-RECEIVE-1','receive-idempotency-1'
  );
  IF batch_id IS DISTINCT FROM retry_id THEN RAISE EXCEPTION 'idempotent retry returned a different batch id'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',4,'BATCH-IDEMPOTENT',NULL,NULL,1.25,2.50,NULL,'INV-RECEIVE-1','receive-idempotency-1'
    );
    RAISE EXCEPTION 'test failed: reused idempotency key accepted a different quantity';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'idempotency key payload mismatch was not rejected'; END IF;

  SELECT stock_quantity INTO stock FROM public.medicines WHERE id='30000000-0000-0000-0000-000000000001';
  IF stock <> 8
     OR (SELECT count(*) FROM public.pharmacy_inventory WHERE idempotency_key='receive-idempotency-1') <> 1
     OR (SELECT count(*) FROM public.stock_movements) <> 2 THEN
    RAISE EXCEPTION 'idempotent receipt duplicated stock, batch, or stock movement';
  END IF;
END $idempotency$;


DO $receipt_guards$
DECLARE rejected boolean;
BEGIN
  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'EXPIRED-BATCH',current_date-1,current_date-30,1.00,2.50,NULL,NULL,'guard-expired-batch'
    );
    RAISE EXCEPTION 'test failed: expired pharmacy batch was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'expired batch guard did not reject the request'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'FUTURE-MANUFACTURE',current_date+30,current_date+1,1.00,2.50,NULL,NULL,'guard-future-manufacture'
    );
    RAISE EXCEPTION 'test failed: future manufacture date was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'future manufacture guard did not reject the request'; END IF;

  UPDATE public.medicines SET active=false WHERE id='30000000-0000-0000-0000-000000000001';
  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'INACTIVE-MEDICINE',NULL,NULL,1.00,2.50,NULL,NULL,'guard-inactive-medicine'
    );
    RAISE EXCEPTION 'test failed: inactive medicine was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  UPDATE public.medicines SET active=true WHERE id='30000000-0000-0000-0000-000000000001';
  IF NOT rejected THEN RAISE EXCEPTION 'inactive medicine guard did not reject the request'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'INACTIVE-SUPPLIER',NULL,NULL,1.00,2.50,'40000000-0000-0000-0000-000000000001',NULL,'guard-inactive-supplier'
    );
    RAISE EXCEPTION 'test failed: inactive supplier was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'inactive supplier guard did not reject the request'; END IF;

  UPDATE public.users SET active=false WHERE id='10000000-0000-0000-0000-000000000001';
  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'INACTIVE-USER',NULL,NULL,1.00,2.50,NULL,NULL,'guard-inactive-user'
    );
    RAISE EXCEPTION 'test failed: inactive application user was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN rejected := true;
  END;
  UPDATE public.users SET active=true WHERE id='10000000-0000-0000-0000-000000000001';
  IF NOT rejected THEN RAISE EXCEPTION 'inactive user guard did not reject the request'; END IF;

  PERFORM set_config('test.user_id','10000000-0000-0000-0000-000000000002',true);
  PERFORM set_config('test.super_admin','true',true);
  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'UNASSIGNED-SUPERADMIN',NULL,NULL,1.00,2.50,NULL,NULL,'guard-unassigned-superadmin'
    );
    RAISE EXCEPTION 'test failed: unassigned super-admin created an orphan batch';
  EXCEPTION WHEN SQLSTATE '42501' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'unassigned super-admin guard did not reject the request'; END IF;
  PERFORM set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
  PERFORM set_config('test.super_admin','false',true);

  UPDATE public.medicines SET stock_quantity=2147483647 WHERE id='30000000-0000-0000-0000-000000000001';
  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'OVERFLOW-BATCH',NULL,NULL,1.00,2.50,NULL,NULL,'guard-stock-overflow'
    );
    RAISE EXCEPTION 'test failed: integer stock overflow was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'stock overflow guard did not reject the request'; END IF;
  IF (SELECT count(*) FROM public.pharmacy_inventory)<>2
     OR (SELECT count(*) FROM public.stock_movements)<>2
     OR (SELECT stock_quantity FROM public.medicines WHERE id='30000000-0000-0000-0000-000000000001')<>2147483647 THEN
    RAISE EXCEPTION 'rejected receipt changed inventory, ledger, or stock total';
  END IF;
END $receipt_guards$;

RESET ROLE; ROLLBACK;
