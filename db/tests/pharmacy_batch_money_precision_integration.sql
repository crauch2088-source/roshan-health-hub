-- Reject purchase/selling prices that would be rounded in batch storage or diverge from medicine master values.
BEGIN; SET LOCAL ROLE authenticated;
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
SELECT set_config('test.permissions','pharmacy.update',true); SELECT set_config('test.super_admin','false',true);
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

  IF (SELECT count(*) FROM public.pharmacy_inventory) <> 0
     OR (SELECT count(*) FROM public.stock_movements) <> 0
     OR (SELECT stock_quantity FROM public.medicines WHERE id='30000000-0000-0000-0000-000000000001') <> 0
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
  IF stock <> 3 THEN
    RAISE EXCEPTION 'idempotent receipt stock total expected 3, got %', stock;
  END IF;
  IF (SELECT count(*) FROM public.pharmacy_inventory WHERE idempotency_key='receive-idempotency-1') <> 1 THEN
    RAISE EXCEPTION 'idempotent receipt expected one keyed batch, got %',
      (SELECT count(*) FROM public.pharmacy_inventory WHERE idempotency_key='receive-idempotency-1');
  END IF;
  IF (SELECT count(*) FROM public.stock_movements) <> 1 THEN
    RAISE EXCEPTION 'idempotent receipt expected one stock movement, got %',
      (SELECT count(*) FROM public.stock_movements);
  END IF;
END $idempotency$;


DO $receipt_guards$
DECLARE rejected boolean;
BEGIN
  IF NOT has_function_privilege('authenticated','public.fn_receive_pharmacy_batch_atomic(uuid,numeric,text,date,date,numeric,numeric,uuid,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'test failed: authenticated cannot execute the guarded atomic receipt RPC';
  END IF;
  IF has_function_privilege('anon','public.fn_receive_pharmacy_batch_atomic(uuid,numeric,text,date,date,numeric,numeric,uuid,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'test failed: anonymous role can execute the guarded atomic receipt RPC';
  END IF;
  IF has_function_privilege('authenticated','public.fn_receive_pharmacy_batch(uuid,numeric,text,date,date,numeric,numeric,uuid,text)','EXECUTE') THEN
    RAISE EXCEPTION 'test failed: legacy non-idempotent receive RPC remains callable by authenticated';
  END IF;
  IF has_table_privilege('authenticated','public.stock_movements','INSERT') THEN
    RAISE EXCEPTION 'test failed: authenticated can directly insert stock movements';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stock_movements' AND cmd IN ('INSERT','ALL')) THEN
    RAISE EXCEPTION 'test failed: direct stock-movement insert policy remains';
  END IF;

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
  batch_id := public.fn_receive_pharmacy_batch_atomic(
    '30000000-0000-0000-0000-000000000001',1,'SUPERADMIN-SINGLE-BRANCH',NULL,NULL,1.00,2.50,NULL,NULL,'guard-superadmin-single-active-branch'
  );
  IF NOT EXISTS (
    SELECT 1 FROM public.pharmacy_inventory
     WHERE id=batch_id AND branch_id='20000000-0000-0000-0000-000000000001'
  ) THEN
    RAISE EXCEPTION 'global super-admin receipt was not assigned to the sole active branch';
  END IF;

  UPDATE public.branches SET active=true,is_active=true WHERE id='20000000-0000-0000-0000-000000000002';
  rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '30000000-0000-0000-0000-000000000001',1,'SUPERADMIN-AMBIGUOUS-BRANCH',NULL,NULL,1.00,2.50,NULL,NULL,'guard-superadmin-ambiguous-branches'
    );
    RAISE EXCEPTION 'test failed: global super-admin received stock with multiple active branches and no target';
  EXCEPTION WHEN SQLSTATE '42501' THEN rejected := true;
  END;
  UPDATE public.branches SET active=false,is_active=false WHERE id='20000000-0000-0000-0000-000000000002';
  IF NOT rejected THEN RAISE EXCEPTION 'ambiguous super-admin branch context was not rejected'; END IF;
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
