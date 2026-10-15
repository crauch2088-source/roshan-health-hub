SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.perms','visits.create,pharmacy.update,billing.create',false);
SELECT set_config('test.super_admin','false',false);

INSERT INTO public.users (id,branch_id) VALUES
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.patients (id,branch_id) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.visits (id,patient_id,consultation_fee,branch_id) VALUES
 ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',30,'20000000-0000-0000-0000-000000000001'),
 ('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002',30,'20000000-0000-0000-0000-000000000002');
INSERT INTO public.medicines (id,name,selling_price,stock_quantity,active) VALUES
 ('70000000-0000-0000-0000-000000000001','Amoxicillin',4.50,10,true),
 ('70000000-0000-0000-0000-000000000002','Paracetamol',2.00,20,true);
INSERT INTO public.pharmacy_inventory
 (id,medicine_id,batch_number,expiry_date,quantity,quantity_remaining,branch_id) VALUES
 ('80000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','AMX-A',CURRENT_DATE + 180,10,10,'20000000-0000-0000-0000-000000000001'),
 ('80000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000002','PCM-A',CURRENT_DATE + 180,20,20,'20000000-0000-0000-0000-000000000001');
INSERT INTO public.prescriptions (id,patient_id,visit_id,status,is_external) VALUES
 ('90000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','pending',false),
 ('90000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','pending',false),
 ('90000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000002','pending',false),
 ('90000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','pending',false);
INSERT INTO public.prescription_items
 (id,prescription_id,medicine_id,medication_name,quantity,dosage,frequency,duration) VALUES
 ('91000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','Amoxicillin',2,'500 mg','BID','5 days'),
 ('91000000-0000-0000-0000-000000000002','90000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000002','Paracetamol',3,'500 mg','TID','3 days'),
 ('91000000-0000-0000-0000-000000000003','90000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000001','Amoxicillin',1,'500 mg','BID','5 days'),
 ('91000000-0000-0000-0000-000000000004','90000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000001','Amoxicillin',1,'500 mg','BID','5 days'),
 ('91000000-0000-0000-0000-000000000005','90000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000001','Amoxicillin',1,'500 mg','BID','5 days');

DO $$
DECLARE v_invoice uuid;
BEGIN
 v_invoice := public.create_visit_consultation_invoice_atomic(
  '50000000-0000-0000-0000-000000000001', CURRENT_DATE
 );
 IF NOT EXISTS (SELECT 1 FROM public.invoices WHERE id=v_invoice AND is_primary IS TRUE AND net_amount=30) THEN
   RAISE EXCEPTION 'consultation invoice was not created';
 END IF;

 PERFORM * FROM public.fn_dispense_prescription_with_invoice(
  '90000000-0000-0000-0000-000000000001', false
 );

 IF NOT EXISTS (
   SELECT 1 FROM public.invoices
    WHERE id=v_invoice AND is_primary IS TRUE AND subtotal=45
      AND total_amount=45 AND net_amount=45 AND paid_amount=0
 ) THEN RAISE EXCEPTION 'dispensed medicines were not added to the consolidated invoice'; END IF;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=v_invoice AND deleted_at IS NULL) <> 3 THEN
   RAISE EXCEPTION 'consultation and each dispensed medicine must be separate invoice lines';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.invoice_items WHERE invoice_id=v_invoice AND item_type='pharmacy'
   AND item_id='70000000-0000-0000-0000-000000000001' AND quantity=2 AND unit_price=4.50 AND total_price=9.00) THEN
   RAISE EXCEPTION 'medicine invoice line did not use catalog price and actual dispensed quantity';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.invoice_items WHERE invoice_id=v_invoice AND item_type='pharmacy'
   AND item_id='70000000-0000-0000-0000-000000000002' AND quantity=3 AND unit_price=2.00 AND total_price=6.00) THEN
   RAISE EXCEPTION 'second medicine invoice line is missing or mispriced';
 END IF;
 IF (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='80000000-0000-0000-0000-000000000001') <> 8
   OR (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='80000000-0000-0000-0000-000000000002') <> 17 THEN
   RAISE EXCEPTION 'FEFO stock was not decremented correctly';
 END IF;
 IF (SELECT status FROM public.prescriptions WHERE id='90000000-0000-0000-0000-000000000001') <> 'dispensed' THEN
   RAISE EXCEPTION 'prescription status was not updated';
 END IF;

 -- Retrying the same dispense must not double-decrement stock or add invoice lines.
 BEGIN
   PERFORM * FROM public.fn_dispense_prescription_with_invoice('90000000-0000-0000-0000-000000000001',false);
   RAISE EXCEPTION 'test failed: duplicate dispense unexpectedly succeeded';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='test failed: duplicate dispense unexpectedly succeeded' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=v_invoice AND deleted_at IS NULL) <> 3 THEN
   RAISE EXCEPTION 'duplicate dispense created duplicate charges';
 END IF;
END;
$$;

-- Paid primary invoice: default append must roll back stock; deliberate secondary invoice may proceed.
UPDATE public.invoices SET paid_amount=45,status='paid',payment_status='paid'
 WHERE visit_id='50000000-0000-0000-0000-000000000001' AND is_primary IS TRUE;
DO $$
DECLARE v_stock numeric;
BEGIN
 SELECT quantity_remaining INTO v_stock FROM public.pharmacy_inventory WHERE id='80000000-0000-0000-0000-000000000001';
 BEGIN
   PERFORM * FROM public.fn_dispense_prescription_with_invoice('90000000-0000-0000-0000-000000000002',false);
   RAISE EXCEPTION 'test failed: paid primary invoice accepted a default append';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='test failed: paid primary invoice accepted a default append' THEN RAISE; END IF;
 END;
 IF (SELECT status FROM public.prescriptions WHERE id='90000000-0000-0000-0000-000000000002') <> 'pending' THEN
   RAISE EXCEPTION 'failed invoice append did not roll back prescription status';
 END IF;
 IF (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='80000000-0000-0000-0000-000000000001') <> v_stock THEN
   RAISE EXCEPTION 'failed invoice append did not roll back stock';
 END IF;
 PERFORM * FROM public.fn_dispense_prescription_with_invoice('90000000-0000-0000-0000-000000000002',true);
 IF NOT EXISTS (
   SELECT 1 FROM public.invoices WHERE visit_id='50000000-0000-0000-0000-000000000001'
     AND is_primary IS FALSE AND subtotal=4.50 AND net_amount=4.50
 ) THEN RAISE EXCEPTION 'explicit separate pharmacy invoice was not created'; END IF;
 IF NOT EXISTS (
   SELECT 1 FROM public.invoices WHERE visit_id='50000000-0000-0000-0000-000000000001'
     AND is_primary IS TRUE AND subtotal=45 AND paid_amount=45
 ) THEN RAISE EXCEPTION 'paid primary invoice was changed by separate dispense'; END IF;
END;
$$;

-- Cross-branch dispense is denied and leaves stock and invoice state unchanged.
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.perms','pharmacy.update,billing.create',false);
DO $$
DECLARE v_stock numeric;
BEGIN
 SELECT quantity_remaining INTO v_stock FROM public.pharmacy_inventory WHERE id='80000000-0000-0000-0000-000000000001';
 BEGIN
   PERFORM * FROM public.fn_dispense_prescription_with_invoice('90000000-0000-0000-0000-000000000004',false);
   RAISE EXCEPTION 'test failed: cross-branch dispense unexpectedly succeeded';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='test failed: cross-branch dispense unexpectedly succeeded' THEN RAISE; END IF;
 END;
 IF (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='80000000-0000-0000-0000-000000000001') <> v_stock THEN
   RAISE EXCEPTION 'cross-branch denial changed stock';
 END IF;
END;
$$;

DO $$
BEGIN
 IF NOT has_function_privilege('authenticated','public.fn_dispense_prescription_with_invoice(uuid,boolean)','EXECUTE') THEN
   RAISE EXCEPTION 'authenticated cannot execute dispense-and-invoice RPC';
 END IF;
 IF has_function_privilege('anon','public.fn_dispense_prescription_with_invoice(uuid,boolean)','EXECUTE') THEN
   RAISE EXCEPTION 'anon can execute dispense-and-invoice RPC';
 END IF;
 IF has_function_privilege('authenticated','public.fn_dispense_prescription(uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'legacy dispense RPC remains executable and bypasses pharmacy invoicing';
 END IF;
END;
$$;
SELECT 'pharmacy dispense + invoice integration tests passed' AS result;
