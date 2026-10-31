-- Disposable PostgreSQL 17 E2E: expiry -> dispense -> invoice -> visit completion.
-- Replayed after canonical v112 baseline and Phases 34/46/47/48/49/50.
BEGIN;
SET LOCAL ROLE service_role;

INSERT INTO public.branches(id,branch_code,branch_name,active)
VALUES('00000000-0000-0000-0000-000000004001','CI-PHARM-50','CI Pharmacy 50',true);
INSERT INTO public.roles(id,name,code) VALUES
 ('00000000-0000-0000-0000-000000004011','CI pharmacist','ci_phase50_pharmacist'),
 ('00000000-0000-0000-0000-000000004012','CI doctor','ci_phase50_doctor');
INSERT INTO public.permissions(id,code,name) VALUES
 ('00000000-0000-0000-0000-000000004021','pharmacy.update','Pharmacy update'),
 ('00000000-0000-0000-0000-000000004022','billing.create','Billing create'),
 ('00000000-0000-0000-0000-000000004023','visits.update','Visits update'),
 ('00000000-0000-0000-0000-000000004024','visits.create','Visits create')
ON CONFLICT(code) DO NOTHING;
INSERT INTO public.role_permissions(role_id,permission_id)
SELECT '00000000-0000-0000-0000-000000004011'::uuid,p.id FROM public.permissions p
WHERE p.code IN ('pharmacy.update','billing.create')
AND NOT EXISTS(SELECT 1 FROM public.role_permissions rp WHERE rp.role_id='00000000-0000-0000-0000-000000004011'::uuid AND rp.permission_id=p.id);
INSERT INTO public.role_permissions(role_id,permission_id)
SELECT '00000000-0000-0000-0000-000000004012'::uuid,p.id FROM public.permissions p
WHERE p.code IN ('visits.update','visits.create')
AND NOT EXISTS(SELECT 1 FROM public.role_permissions rp WHERE rp.role_id='00000000-0000-0000-0000-000000004012'::uuid AND rp.permission_id=p.id);
INSERT INTO auth.users(id) VALUES
 ('00000000-0000-0000-0000-000000004031'),
 ('00000000-0000-0000-0000-000000004032')
ON CONFLICT DO NOTHING;
INSERT INTO public.users(id,auth_user_id,active,branch_id,role_id,full_name) VALUES
 ('00000000-0000-0000-0000-000000004041','00000000-0000-0000-0000-000000004031',true,'00000000-0000-0000-0000-000000004001','00000000-0000-0000-0000-000000004011','CI Pharmacist'),
 ('00000000-0000-0000-0000-000000004042','00000000-0000-0000-0000-000000004032',true,'00000000-0000-0000-0000-000000004001','00000000-0000-0000-0000-000000004012','CI Doctor');
INSERT INTO public.patients(id,branch_id,mrn,full_name,gender) VALUES
 ('00000000-0000-0000-0000-000000004051','00000000-0000-0000-0000-000000004001','CI-PHARM-50-001','Synthetic E2E Patient','unknown');
INSERT INTO public.visits(id,branch_id,patient_id,status,consultation_fee) VALUES
 ('00000000-0000-0000-0000-000000004061','00000000-0000-0000-0000-000000004001','00000000-0000-0000-0000-000000004051','in_progress',25.00);
INSERT INTO public.queue_tickets(id,visit_id,patient_id,branch_id,status)
SELECT '00000000-0000-0000-0000-000000004071','00000000-0000-0000-0000-000000004061',
 '00000000-0000-0000-0000-000000004051','00000000-0000-0000-0000-000000004001','in_progress'
WHERE NOT EXISTS(SELECT 1 FROM public.queue_tickets WHERE visit_id='00000000-0000-0000-0000-000000004061' AND deleted_at IS NULL);
UPDATE public.queue_tickets SET status='in_progress',branch_id='00000000-0000-0000-0000-000000004001'
WHERE visit_id='00000000-0000-0000-0000-000000004061' AND deleted_at IS NULL;

INSERT INTO public.medicines(id,generic_name,name,selling_price,stock_quantity,reorder_level,active,is_active) VALUES
 ('00000000-0000-0000-0000-000000004081','CI active medicine','CI active medicine',1.25,11,1,true,true),
 ('00000000-0000-0000-0000-000000004082','CI expired-only medicine','CI expired-only medicine',2.00,1,1,true,true);
INSERT INTO public.pharmacy_inventory(id,medicine_id,batch_number,expiry_date,quantity,quantity_received,quantity_remaining,branch_id) VALUES
 ('00000000-0000-0000-0000-000000004091','00000000-0000-0000-0000-000000004081','VALID-NEAR',CURRENT_DATE+20,1,1,1,'00000000-0000-0000-0000-000000004001'),
 ('00000000-0000-0000-0000-000000004092','00000000-0000-0000-0000-000000004081','VALID-LATER',CURRENT_DATE+60,1,1,1,'00000000-0000-0000-0000-000000004001'),
 ('00000000-0000-0000-0000-000000004093','00000000-0000-0000-0000-000000004081','EXPIRED',CURRENT_DATE-1,9,9,9,'00000000-0000-0000-0000-000000004001'),
 ('00000000-0000-0000-0000-000000004094','00000000-0000-0000-0000-000000004082','EXPIRED-ONLY',CURRENT_DATE-1,1,1,1,'00000000-0000-0000-0000-000000004001');
INSERT INTO public.prescriptions(id,patient_id,visit_id,prescribed_by,created_by,status,is_external,branch_id) VALUES
 ('00000000-0000-0000-0000-000000004101','00000000-0000-0000-0000-000000004051','00000000-0000-0000-0000-000000004061','00000000-0000-0000-0000-000000004042','00000000-0000-0000-0000-000000004042','pending',false,'00000000-0000-0000-0000-000000004001'),
 ('00000000-0000-0000-0000-000000004102','00000000-0000-0000-0000-000000004051','00000000-0000-0000-0000-000000004061','00000000-0000-0000-0000-000000004042','00000000-0000-0000-0000-000000004042','pending',false,'00000000-0000-0000-0000-000000004001');
INSERT INTO public.prescription_items(id,prescription_id,medicine_id,medication_name,quantity,dosage,frequency,duration) VALUES
 ('00000000-0000-0000-0000-000000004111','00000000-0000-0000-0000-000000004101','00000000-0000-0000-0000-000000004081','CI active medicine',2,'1 tablet','BID','1 day'),
 ('00000000-0000-0000-0000-000000004112','00000000-0000-0000-0000-000000004102','00000000-0000-0000-0000-000000004082','CI expired-only medicine',1,'1 tablet','OD','1 day');

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000004031',true);

DO $pharmacy$
DECLARE v_first jsonb; v_retry jsonb; v_new_key_rejected boolean:=false; v_expired_rejected boolean:=false;
BEGIN
 SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) ORDER BY r.item_id,r.batch_id) INTO v_first
 FROM public.atomic_pharmacy_dispense('00000000-0000-0000-0000-000000004101',false,'00000000-0000-0000-0000-000000004121') r;
 SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) ORDER BY r.item_id,r.batch_id) INTO v_retry
 FROM public.atomic_pharmacy_dispense('00000000-0000-0000-0000-000000004101',false,'00000000-0000-0000-0000-000000004121') r;
 IF v_first IS DISTINCT FROM v_retry OR pg_catalog.jsonb_array_length(v_first)<>2 THEN
   RAISE EXCEPTION 'idempotent retry did not replay the exact two FEFO batch movements';
 END IF;
 IF (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='00000000-0000-0000-0000-000000004091')<>0
 OR (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='00000000-0000-0000-0000-000000004092')<>0
 OR (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='00000000-0000-0000-0000-000000004093')<>9 THEN
   RAISE EXCEPTION 'FEFO consumed the wrong batch or touched expired stock';
 END IF;
 IF (SELECT count(*) FROM public.stock_movements WHERE reference_id='00000000-0000-0000-0000-000000004101' AND reference_table='prescriptions' AND movement_type='dispense')<>2 THEN
   RAISE EXCEPTION 'idempotent retry duplicated stock movements';
 END IF;
 IF (SELECT count(*) FROM public.invoice_items WHERE item_type='pharmacy' AND item_id='00000000-0000-0000-0000-000000004081' AND deleted_at IS NULL)<>1 THEN
   RAISE EXCEPTION 'idempotent retry duplicated pharmacy invoice line';
 END IF;
 BEGIN
   PERFORM * FROM public.atomic_pharmacy_dispense('00000000-0000-0000-0000-000000004101',false,'00000000-0000-0000-0000-000000004122');
 EXCEPTION WHEN OTHERS THEN v_new_key_rejected:=true; END;
 IF NOT v_new_key_rejected THEN RAISE EXCEPTION 'second request key dispensed an already-dispensed prescription'; END IF;
 BEGIN
   PERFORM * FROM public.atomic_pharmacy_dispense('00000000-0000-0000-0000-000000004102',false,'00000000-0000-0000-0000-000000004123');
 EXCEPTION WHEN OTHERS THEN v_expired_rejected:=true; END;
 IF NOT v_expired_rejected THEN RAISE EXCEPTION 'expired-only medicine was dispensed'; END IF;
 IF (SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id='00000000-0000-0000-0000-000000004094')<>1
 OR (SELECT status FROM public.prescriptions WHERE id='00000000-0000-0000-0000-000000004102')<>'pending'
 OR EXISTS(SELECT 1 FROM public.stock_movements WHERE reference_id='00000000-0000-0000-0000-000000004102' AND movement_type='dispense') THEN
   RAISE EXCEPTION 'expired-stock rejection did not roll back every write';
 END IF;
END;
$pharmacy$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000004032',true);
DO $completion$
DECLARE v_first jsonb; v_second jsonb; v_invoice uuid; v_count integer; v_total numeric; v_visit_at timestamptz; v_queue_at timestamptz;
BEGIN
 v_first:=public.complete_clinical_visit_and_bill('00000000-0000-0000-0000-000000004061');
 v_second:=public.complete_clinical_visit_and_bill('00000000-0000-0000-0000-000000004061');
 IF v_first->>'invoice_id' IS NULL OR v_second->>'invoice_id' IS DISTINCT FROM v_first->>'invoice_id' THEN
   RAISE EXCEPTION 'visit completion retry did not return the same primary invoice';
 END IF;
 v_invoice:=(v_first->>'invoice_id')::uuid;
 SELECT count(*),coalesce(sum(total_price),0) INTO v_count,v_total FROM public.invoice_items WHERE invoice_id=v_invoice AND deleted_at IS NULL;
 IF v_count<>2 OR v_total<>27.50 THEN RAISE EXCEPTION 'consultation and pharmacy invoice totals did not reconcile'; END IF;
 SELECT completed_at INTO v_visit_at FROM public.visits WHERE id='00000000-0000-0000-0000-000000004061';
 SELECT completed_at INTO v_queue_at FROM public.queue_tickets WHERE visit_id='00000000-0000-0000-0000-000000004061' AND deleted_at IS NULL LIMIT 1;
 IF (SELECT status FROM public.visits WHERE id='00000000-0000-0000-0000-000000004061')<>'completed'
 OR (SELECT status FROM public.queue_tickets WHERE visit_id='00000000-0000-0000-0000-000000004061' AND deleted_at IS NULL LIMIT 1)<>'completed'
 OR v_visit_at IS NULL OR v_visit_at IS DISTINCT FROM v_queue_at THEN
   RAISE EXCEPTION 'visit and queue completion states/timestamps are inconsistent';
 END IF;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=v_invoice AND item_type='consultation' AND deleted_at IS NULL)<>1 THEN
   RAISE EXCEPTION 'consultation invoice line duplicated on completion retry';
 END IF;
END;
$completion$;

DO $additional_guards$
DECLARE v_expiry_rejected boolean:=false; v_stock_edit_rejected boolean:=false; v_error text;
BEGIN
  BEGIN
    PERFORM public.fn_receive_pharmacy_batch_atomic(
      '00000000-0000-0000-0000-000000004081',1,'NO-EXPIRY',
      NULL,NULL,1.00,1.25,NULL,NULL,'ci-no-expiry-guard'
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    v_expiry_rejected := (v_error='pharmacy_batch_expiry_required');
  END;
  IF NOT v_expiry_rejected THEN RAISE EXCEPTION 'batch receipt without expiry was not rejected'; END IF;

  BEGIN
    UPDATE public.medicines SET stock_quantity=stock_quantity+100
    WHERE id='00000000-0000-0000-0000-000000004081';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    v_stock_edit_rejected := (v_error='medicine_stock_is_rpc_managed');
  END;
  IF NOT v_stock_edit_rejected THEN RAISE EXCEPTION 'direct medicine stock edit bypassed batch RPCs'; END IF;

  IF has_table_privilege('authenticated','public.pharmacy_inventory','INSERT')
     OR has_table_privilege('authenticated','public.pharmacy_inventory','UPDATE')
     OR has_table_privilege('authenticated','public.pharmacy_inventory','DELETE') THEN
    RAISE EXCEPTION 'authenticated can directly mutate pharmacy_inventory';
  END IF;
END;
$additional_guards$;

DO $privileges$
BEGIN
 IF NOT has_function_privilege('authenticated','public.atomic_pharmacy_dispense(uuid,boolean,uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'authenticated cannot execute atomic pharmacy dispense';
 END IF;
 IF has_function_privilege('anon','public.atomic_pharmacy_dispense(uuid,boolean,uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'anon can execute atomic pharmacy dispense';
 END IF;
 IF has_table_privilege('authenticated','public.pharmacy_inventory','INSERT')
 OR has_table_privilege('authenticated','public.pharmacy_inventory','UPDATE')
 OR has_table_privilege('authenticated','public.pharmacy_inventory','DELETE')
 OR has_table_privilege('authenticated','public.stock_movements','INSERT')
 OR has_table_privilege('authenticated','public.stock_movements','UPDATE')
 OR has_table_privilege('authenticated','public.stock_movements','DELETE') THEN
   RAISE EXCEPTION 'authenticated can directly mutate stock movement ledger';
 END IF;
END;
$privileges$;
ROLLBACK;
