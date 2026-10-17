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
END $test$; RESET ROLE; ROLLBACK;
