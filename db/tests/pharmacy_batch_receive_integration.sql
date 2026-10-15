SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.has_perm','true',false);
SELECT set_config('test.super_admin','false',false);
SELECT set_config('test.fail_movement','false',false);
INSERT INTO public.users (id,branch_id) VALUES
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
INSERT INTO public.medicines (id,name,active,stock_quantity,cost_price,selling_price) VALUES
 ('30000000-0000-0000-0000-000000000001','Amoxicillin',true,0,1.00,2.50),
 ('30000000-0000-0000-0000-000000000002','Inactive medicine',false,0,1.00,2.50);
INSERT INTO public.suppliers (id,active) VALUES
 ('40000000-0000-0000-0000-000000000001',true),
 ('40000000-0000-0000-0000-000000000002',false);

DO $test$
DECLARE
  v_batch uuid;
  v_rejected boolean;
  v_qty numeric;
  v_price numeric;
  v_batches_before bigint;
BEGIN
  v_batch := public.fn_receive_pharmacy_batch(
    '30000000-0000-0000-0000-000000000001',10,'LOT-A',
    CURRENT_DATE+365,CURRENT_DATE-30,1.25,2.75,
    '40000000-0000-0000-0000-000000000001','INV-RECEIVE-1'
  );
  IF NOT EXISTS (
    SELECT 1 FROM public.pharmacy_inventory
    WHERE id=v_batch AND quantity_received=10 AND quantity_remaining=10
      AND branch_id='20000000-0000-0000-0000-000000000001'
      AND batch_number='LOT-A' AND supplier_id='40000000-0000-0000-0000-000000000001'
  ) THEN RAISE EXCEPTION 'valid batch was not persisted correctly'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.medicines
    WHERE id='30000000-0000-0000-0000-000000000001'
      AND stock_quantity=10 AND cost_price=1.25 AND selling_price=2.75
  ) THEN RAISE EXCEPTION 'medicine stock/prices were not synchronized'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.stock_movements
    WHERE batch_id=v_batch AND movement_type='purchase' AND quantity=10
      AND branch_id='20000000-0000-0000-0000-000000000001'
  ) THEN RAISE EXCEPTION 'purchase stock movement missing'; END IF;
  IF has_table_privilege('authenticated','public.stock_movements','INSERT') THEN
    RAISE EXCEPTION 'authenticated can still write stock movements directly';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stock_movements' AND policyname='stock_movements_insert') THEN
    RAISE EXCEPTION 'direct stock movement insert policy still exists';
  END IF;

  FOREACH v_qty IN ARRAY ARRAY['NaN'::numeric,'Infinity'::numeric,1.5::numeric,0::numeric,(-1)::numeric] LOOP
    v_rejected := false;
    BEGIN
      PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',v_qty);
    EXCEPTION WHEN OTHERS THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'invalid quantity accepted: %',v_qty; END IF;
  END LOOP;

  FOREACH v_price IN ARRAY ARRAY['NaN'::numeric,'Infinity'::numeric,(-1)::numeric,1.234::numeric] LOOP
    v_rejected := false;
    BEGIN
      PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',1,NULL,NULL,NULL,v_price);
    EXCEPTION WHEN OTHERS THEN v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'invalid purchase price accepted: %',v_price; END IF;
  END LOOP;

  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',1,NULL,NULL,NULL,0,'Infinity');
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'infinite selling price accepted'; END IF;

  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',1,NULL,CURRENT_DATE-1,CURRENT_DATE,0);
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'manufacture after expiry accepted'; END IF;

  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',1,NULL,CURRENT_DATE-1,NULL,0);
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'expired batch accepted'; END IF;

  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',1,NULL,NULL,CURRENT_DATE+1,0);
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'future manufacture date accepted'; END IF;

  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000002',1);
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'inactive medicine accepted'; END IF;

  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',1,NULL,NULL,NULL,0,NULL,'40000000-0000-0000-0000-000000000002');
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'inactive supplier accepted'; END IF;

  PERFORM set_config('test.has_perm','false',false);
  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',1);
  EXCEPTION WHEN SQLSTATE '42501' THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'missing pharmacy.update permission accepted'; END IF;
  PERFORM set_config('test.has_perm','true',false);

  UPDATE public.medicines SET stock_quantity=2147483640 WHERE id='30000000-0000-0000-0000-000000000001';
  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',10);
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'integer stock overflow accepted'; END IF;
  UPDATE public.medicines SET stock_quantity=10 WHERE id='30000000-0000-0000-0000-000000000001';

  SELECT count(*) INTO v_batches_before FROM public.pharmacy_inventory;
  PERFORM set_config('test.fail_movement','true',false);
  v_rejected := false;
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch('30000000-0000-0000-0000-000000000001',3,'ROLLBACK-LOT');
  EXCEPTION WHEN OTHERS THEN v_rejected := true;
  END;
  PERFORM set_config('test.fail_movement','false',false);
  IF NOT v_rejected THEN RAISE EXCEPTION 'injected stock movement failure did not abort receive'; END IF;
  IF (SELECT count(*) FROM public.pharmacy_inventory) <> v_batches_before THEN
    RAISE EXCEPTION 'batch insert survived failed stock movement';
  END IF;
  IF (SELECT stock_quantity FROM public.medicines WHERE id='30000000-0000-0000-0000-000000000001') <> 10 THEN
    RAISE EXCEPTION 'medicine stock update survived failed stock movement';
  END IF;
END;
$test$;
