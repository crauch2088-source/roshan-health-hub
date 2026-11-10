-- Phase 61 integration. Run only in the disposable PostgreSQL 17 fixture.
INSERT INTO public.branches(id) VALUES
 ('20000000-0000-0000-0000-000000000001'),('20000000-0000-0000-0000-000000000002');
INSERT INTO public.users(id,branch_id) VALUES
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'), -- pharmacist A
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001'), -- prescriber A
 ('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001'), -- other doctor A
 ('10000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001'), -- admin A
 ('10000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000002'); -- super-admin B
INSERT INTO public.patients(id,branch_id) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.visits(id,patient_id,branch_id,status) VALUES
 ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','in_progress'),
 ('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','in_progress');
INSERT INTO public.medicines(id,name,generic_name,selling_price,active,is_active) VALUES
 ('50000000-0000-0000-0000-000000000001','Amoxicillin 500 mg','Amoxicillin',12.50,true,true),
 ('50000000-0000-0000-0000-000000000002','Inactive medicine','Inactive',2.00,true,false);
INSERT INTO public.prescriptions(id,patient_id,visit_id,prescribed_by,doctor_id,branch_id,status,is_external,created_by) VALUES
 ('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','pending',false,'10000000-0000-0000-0000-000000000002'),
 ('60000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','pending',true,'10000000-0000-0000-0000-000000000002'),
 ('60000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','cancelled',false,'10000000-0000-0000-0000-000000000002'),
 ('60000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','dispensed',false,'10000000-0000-0000-0000-000000000002'),
 ('60000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','pending',false,'10000000-0000-0000-0000-000000000002');
INSERT INTO public.prescription_items(id,prescription_id,medicine_id,medication_name,quantity,dose,dosage,frequency,duration,instructions,dosage_form,route,unit_price,is_dispensed) VALUES
 ('70000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001',NULL,'Unlinked Amoxicillin',10,'500 mg','500 mg','BID','5 days','After food','capsule','oral',0,false),
 ('70000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','Linked medicine',2,'1 tablet','1 tablet','OD','2 days',NULL,'tablet','oral',12.50,false),
 ('70000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000002',NULL,'External free text',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,false),
 ('70000000-0000-0000-0000-000000000004','60000000-0000-0000-0000-000000000003',NULL,'Cancelled free text',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,false),
 ('70000000-0000-0000-0000-000000000005','60000000-0000-0000-0000-000000000004',NULL,'Dispensed free text',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,true),
 ('70000000-0000-0000-0000-000000000006','60000000-0000-0000-0000-000000000005',NULL,'Wrong branch free text',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,false);
INSERT INTO public.prescription_items(id,prescription_id,medicine_id,medication_name,quantity) VALUES
 ('70000000-0000-0000-0000-000000000007','60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','Deleted item',1);
UPDATE public.prescription_items SET deleted_at=now() WHERE id='70000000-0000-0000-0000-000000000007';

SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.permissions','pharmacy.update,pharmacy.read',false);
SELECT set_config('test.super_admin','false',false);
DO $request$
DECLARE v_id uuid; v_retry uuid; v_conflict boolean:=false; v_denied boolean:=false;
BEGIN
 SELECT request_id INTO v_id FROM public.create_prescription_correction_request(
  '60000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001',
  'unlinked_free_text','Please link the intended catalogue medicine','80000000-0000-0000-0000-000000000001');
 SELECT request_id INTO v_retry FROM public.create_prescription_correction_request(
  '60000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001',
  'unlinked_free_text','Please link the intended catalogue medicine','80000000-0000-0000-0000-000000000001');
 IF v_id IS DISTINCT FROM v_retry THEN RAISE EXCEPTION 'same-key retry did not return the original request'; END IF;
 BEGIN
  PERFORM public.create_prescription_correction_request(
   '60000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001',
   'unlinked_free_text','Duplicate','80000000-0000-0000-0000-000000000002');
 EXCEPTION WHEN OTHERS THEN v_conflict:=true;
 END;
 IF NOT v_conflict THEN RAISE EXCEPTION 'duplicate open request was accepted'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.prescription_correction_requests WHERE id=v_id AND status='open'
   AND branch_id='20000000-0000-0000-0000-000000000001'
   AND patient_id='30000000-0000-0000-0000-000000000001'
   AND prescriber_id='10000000-0000-0000-0000-000000000002'
   AND requested_by='10000000-0000-0000-0000-000000000001'
   AND item_snapshot->>'medication_name'='Unlinked Amoxicillin') THEN
   RAISE EXCEPTION 'request did not persist server-derived linkage and snapshot';
 END IF;
 BEGIN
  PERFORM public.create_prescription_correction_request(
   '60000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000003',
   'unlinked_free_text','external','80000000-0000-0000-0000-000000000003');
 EXCEPTION WHEN OTHERS THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'external prescription correction request was accepted'; END IF;
 IF (SELECT count(*) FROM public.prescription_correction_requests)<>1 THEN RAISE EXCEPTION 'denied request created a row'; END IF;
END
$request$;

-- Pharmacist can read the branch request; another branch cannot.
SET LOCAL ROLE authenticated;
DO $pharmacy_read$
BEGIN
 IF (SELECT count(*) FROM public.prescription_correction_requests)<>1 THEN RAISE EXCEPTION 'same-branch pharmacist cannot read request'; END IF;
END
$pharmacy_read$;
RESET ROLE;

-- A pharmacist cannot resolve a clinical correction.
DO $pharmacist_resolve$
DECLARE v_denied boolean:=false;
BEGIN
 BEGIN
  PERFORM public.resolve_prescription_correction_request(
   (SELECT id FROM public.prescription_correction_requests LIMIT 1),'replace_item',
   '50000000-0000-0000-0000-000000000001',NULL);
 EXCEPTION WHEN OTHERS THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'pharmacist resolved a clinical correction'; END IF;
END
$pharmacist_resolve$;

-- Other doctor and administrator have emr.update but cannot resolve another author's prescription.
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000003',false);
SELECT set_config('test.permissions','emr.update,emr.read',false);
DO $other_doctor$
DECLARE v_denied boolean:=false;
BEGIN
 BEGIN PERFORM public.resolve_prescription_correction_request(
   (SELECT id FROM public.prescription_correction_requests LIMIT 1),'replace_item',
   '50000000-0000-0000-0000-000000000001',NULL);
 EXCEPTION WHEN OTHERS THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'other same-branch doctor resolved request'; END IF;
END
$other_doctor$;
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000004',false);
SELECT set_config('test.permissions','emr.update,emr.create,pharmacy.update',false);
DO $admin$
DECLARE v_denied boolean:=false;
BEGIN
 BEGIN PERFORM public.resolve_prescription_correction_request(
   (SELECT id FROM public.prescription_correction_requests LIMIT 1),'replace_item',
   '50000000-0000-0000-0000-000000000001',NULL);
 EXCEPTION WHEN OTHERS THEN v_denied:=true; END;
 IF NOT v_denied THEN RAISE EXCEPTION 'admin without authorship resolved request'; END IF;
END
$admin$;

-- Original prescriber can replace exactly one item; regimen remains unchanged.
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.permissions','emr.update,emr.create,emr.read',false);
DO $prescriber$
DECLARE v_result record;
BEGIN
 SELECT * INTO v_result FROM public.resolve_prescription_correction_request(
  (SELECT id FROM public.prescription_correction_requests LIMIT 1),'replace_item',
  '50000000-0000-0000-0000-000000000001',NULL);
 IF v_result.status<>'resolved' THEN RAISE EXCEPTION 'prescriber replacement did not resolve request'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.prescription_items WHERE id='70000000-0000-0000-0000-000000000001'
   AND medicine_id='50000000-0000-0000-0000-000000000001'
   AND medication_name='Amoxicillin 500 mg' AND unit_price=12.50
   AND quantity=10 AND dose='500 mg' AND frequency='BID' AND duration='5 days') THEN
   RAISE EXCEPTION 'replacement did not preserve regimen or derive catalogue identity';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.prescription_correction_events
   WHERE event_type='item_replaced' AND before_snapshot->>'medicine_id' IS NULL
   AND after_snapshot->>'medicine_id'='50000000-0000-0000-0000-000000000001') THEN
   RAISE EXCEPTION 'replacement event did not preserve before/after snapshots';
 END IF;
 IF (SELECT status FROM public.prescriptions WHERE id='60000000-0000-0000-0000-000000000001')<>'pending' THEN
   RAISE EXCEPTION 'item replacement changed parent prescription status';
 END IF;
END
$prescriber$;

-- Correction actions must not touch stock or financial tables.
DO $no_side_effects$
BEGIN
 IF (SELECT count(*) FROM public.pharmacy_inventory)<>0
 OR (SELECT count(*) FROM public.stock_movements)<>0
 OR (SELECT count(*) FROM public.invoices)<>0
 OR (SELECT count(*) FROM public.invoice_items)<>0
 OR (SELECT count(*) FROM public.payments)<>0
 OR (SELECT count(*) FROM public.cashbox_transactions)<>0 THEN
   RAISE EXCEPTION 'correction workflow created inventory or financial side effects';
 END IF;
END
$no_side_effects$;

DO $acl$
BEGIN
 IF has_table_privilege('authenticated','public.prescription_correction_requests','INSERT')
 OR has_table_privilege('authenticated','public.prescription_correction_requests','UPDATE')
 OR has_table_privilege('authenticated','public.prescription_correction_requests','DELETE')
 OR has_table_privilege('authenticated','public.prescription_correction_events','INSERT')
 OR has_table_privilege('authenticated','public.prescription_correction_events','UPDATE')
 OR has_table_privilege('authenticated','public.prescription_correction_events','DELETE') THEN
  RAISE EXCEPTION 'authenticated retained direct writes on correction tables';
 END IF;
 IF has_function_privilege('anon','public.create_prescription_correction_request(uuid,uuid,text,text,uuid)','EXECUTE')
 OR has_function_privilege('anon','public.resolve_prescription_correction_request(uuid,text,uuid,jsonb)','EXECUTE')
 OR has_function_privilege('anon','public.reject_prescription_correction_request(uuid,text)','EXECUTE') THEN
  RAISE EXCEPTION 'anon retained correction RPC EXECUTE';
 END IF;
END
$acl$;
SELECT 'Phase 61 correction integration passed' AS result;
