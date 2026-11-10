-- Behavioral integration tests for the auditable prescription correction workflow.
-- Runs only on the disposable PostgreSQL 17 CI database.
BEGIN;

DO $create_orders$
DECLARE
  v_rx uuid;
  v_item uuid;
  v_linked uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',false,
    '[{"medication_name":"Custom topical item","dose":"Apply thin layer","frequency":"BID","duration":"5 days","quantity":1,"dosage_form":"Cream","route":"Topical"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  PERFORM set_config('test.rx_replace',v_rx::text,true);
  PERFORM set_config('test.item_replace',v_item::text,true);

  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',false,
    '[{"medication_name":"Custom oral item","dose":"250 mg","frequency":"BID","duration":"5 days","quantity":10,"dosage_form":"Capsule","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  PERFORM set_config('test.rx_reject',v_rx::text,true);
  PERFORM set_config('test.item_reject',v_item::text,true);

  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',false,
    '[{"medication_name":"Unlinked first item","dose":"250 mg","frequency":"BID","duration":"5 days","quantity":10,"dosage_form":"Capsule","route":"Oral"},{"medicine_id":"95000000-0000-0000-0000-000000000002","medication_name":"spoofed","dose":"500 mg","frequency":"TID","duration":"3 days","quantity":9,"dosage_form":"Tablet","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  SELECT id INTO v_linked FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id='95000000-0000-0000-0000-000000000002' AND deleted_at IS NULL;
  PERFORM set_config('test.rx_reissue',v_rx::text,true);
  PERFORM set_config('test.item_reissue',v_item::text,true);
  PERFORM set_config('test.item_reissue_linked',v_linked::text,true);

  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',true,
    '[{"medication_name":"External free text","dose":"10 mg","frequency":"OD","duration":"3 days","quantity":3,"dosage_form":"Tablet","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  PERFORM set_config('test.rx_external',v_rx::text,true);
  PERFORM set_config('test.item_external',v_item::text,true);

  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',false,
    '[{"medication_name":"Cancelled free text","dose":"10 mg","frequency":"OD","duration":"3 days","quantity":3,"dosage_form":"Tablet","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  UPDATE public.prescriptions SET status='cancelled' WHERE id=v_rx;
  PERFORM set_config('test.rx_cancelled',v_rx::text,true);
  PERFORM set_config('test.item_cancelled',v_item::text,true);

  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',false,
    '[{"medication_name":"Dispensed free text","dose":"10 mg","frequency":"OD","duration":"3 days","quantity":3,"dosage_form":"Tablet","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  UPDATE public.prescriptions SET status='dispensed',dispensed_at=now() WHERE id=v_rx;
  PERFORM set_config('test.rx_dispensed',v_rx::text,true);
  PERFORM set_config('test.item_dispensed',v_item::text,true);

  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',false,
    '[{"medication_name":"Deleted free text","dose":"10 mg","frequency":"OD","duration":"3 days","quantity":3,"dosage_form":"Tablet","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  UPDATE public.prescriptions SET deleted_at=now() WHERE id=v_rx;
  PERFORM set_config('test.rx_deleted',v_rx::text,true);
  PERFORM set_config('test.item_deleted',v_item::text,true);

  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000003',true);
  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000002',false,
    '[{"medication_name":"Wrong branch free text","dose":"10 mg","frequency":"OD","duration":"3 days","quantity":3,"dosage_form":"Tablet","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  PERFORM set_config('test.rx_branch_b',v_rx::text,true);
  PERFORM set_config('test.item_branch_b',v_item::text,true);

  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
  v_rx := public.create_prescription_atomic(
    '94000000-0000-0000-0000-000000000001',false,
    '[{"medication_name":"Stale snapshot free text","dose":"10 mg","frequency":"OD","duration":"3 days","quantity":3,"dosage_form":"Tablet","route":"Oral"}]'::jsonb
  );
  SELECT id INTO v_item FROM public.prescription_items WHERE prescription_id=v_rx AND medicine_id IS NULL AND deleted_at IS NULL;
  PERFORM set_config('test.rx_stale',v_rx::text,true);
  PERFORM set_config('test.item_stale',v_item::text,true);
END
$create_orders$;

-- Pharmacist request creation and idempotent retry.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000004',true);
DO $request_and_duplicate$
DECLARE v_first uuid; v_second uuid; v_item uuid;
BEGIN
  v_item := current_setting('test.item_replace')::uuid;
  v_first := public.request_prescription_item_correction(v_item,'Catalogue link is missing; please identify the intended medicine.');
  v_second := public.request_prescription_item_correction(v_item,'Retry after a simulated network timeout.');
  IF v_first IS DISTINCT FROM v_second THEN RAISE EXCEPTION 'duplicate request did not return the existing pending request'; END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_events WHERE request_id=v_first AND event_type='requested') <> 1 THEN
    RAISE EXCEPTION 'duplicate request created a duplicate audit event';
  END IF;
  PERFORM set_config('test.req_replace',v_first::text,true);
END
$request_and_duplicate$;

DO $other_requests$
DECLARE v_id uuid;
BEGIN
  v_id := public.request_prescription_item_correction(current_setting('test.item_reject')::uuid,'Please verify this free-text item before dispensing.');
  PERFORM set_config('test.req_reject',v_id::text,true);
  v_id := public.request_prescription_item_correction(current_setting('test.item_reissue')::uuid,'Please correct this unlinked medicine and confirm the full order.');
  PERFORM set_config('test.req_reissue',v_id::text,true);
  v_id := public.request_prescription_item_correction(current_setting('test.item_stale')::uuid,'Please verify this unlinked medicine after review.');
  PERFORM set_config('test.req_stale',v_id::text,true);
END
$other_requests$;

-- Same-branch responsible doctor can read; unrelated and wrong-branch doctors cannot.
DO $rls_responsible_doctor$
DECLARE v_count integer;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_requests WHERE id=current_setting('test.req_replace')::uuid;
  IF v_count <> 1 THEN RAISE EXCEPTION 'responsible doctor cannot read correction request'; END IF;
END
$rls_responsible_doctor$;

DO $rls_unrelated_doctor$
DECLARE v_count integer;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000002',true);
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_requests WHERE id=current_setting('test.req_replace')::uuid;
  IF v_count <> 0 THEN RAISE EXCEPTION 'unrelated doctor in the same branch can read correction request'; END IF;
END
$rls_unrelated_doctor$;

DO $rls_wrong_branch_doctor$
DECLARE v_count integer;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000003',true);
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_requests WHERE id=current_setting('test.req_replace')::uuid;
  IF v_count <> 0 THEN RAISE EXCEPTION 'wrong-branch doctor can read correction request'; END IF;
END
$rls_wrong_branch_doctor$;

DO $rls_admin_and_super_admin$
DECLARE v_count integer;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000006',true);
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_requests WHERE id=current_setting('test.req_replace')::uuid;
  IF v_count <> 0 THEN RAISE EXCEPTION 'ordinary Admin received implicit clinical correction visibility'; END IF;
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000007',true);
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_requests WHERE id=current_setting('test.req_replace')::uuid;
  IF v_count <> 1 THEN RAISE EXCEPTION 'Super Admin explicit bypass did not expose correction request'; END IF;
END
$rls_admin_and_super_admin$;

RESET ROLE;

-- Invalid request states and wrong-branch requests fail closed.
DO $invalid_requests$
DECLARE v_failed boolean; v_sub uuid; v_item uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000004',true);
  FOREACH v_item IN ARRAY ARRAY[
    current_setting('test.item_external')::uuid,
    current_setting('test.item_cancelled')::uuid,
    current_setting('test.item_dispensed')::uuid,
    current_setting('test.item_deleted')::uuid,
    current_setting('test.item_branch_b')::uuid
  ] LOOP
    v_failed := false;
    BEGIN
      PERFORM public.request_prescription_item_correction(v_item,'This invalid state must be rejected safely.');
    EXCEPTION WHEN OTHERS THEN v_failed := true;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION 'request accepted external/cancelled/dispensed/deleted/wrong branch item %',v_item; END IF;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000006',true);
  v_failed := false;
  BEGIN
    PERFORM public.request_prescription_item_correction(current_setting('test.item_replace')::uuid,'Admin must not create correction requests.');
  EXCEPTION WHEN OTHERS THEN v_failed := true;
  END;
  IF NOT v_failed THEN RAISE EXCEPTION 'ordinary Admin created a pharmacist correction request'; END IF;
END
$invalid_requests$;

-- Direct browser writes are denied; read-only access is explicit.
DO $privileges$
BEGIN
  IF has_table_privilege('authenticated','public.prescription_item_correction_requests','INSERT')
     OR has_table_privilege('authenticated','public.prescription_item_correction_requests','UPDATE')
     OR has_table_privilege('authenticated','public.prescription_item_correction_requests','DELETE')
     OR has_table_privilege('authenticated','public.prescription_item_correction_events','INSERT')
     OR has_table_privilege('authenticated','public.prescription_item_correction_events','UPDATE')
     OR has_table_privilege('authenticated','public.prescription_item_correction_events','DELETE') THEN
    RAISE EXCEPTION 'authenticated has direct correction request/event DML';
  END IF;
  IF NOT has_table_privilege('authenticated','public.prescription_item_correction_requests','SELECT')
     OR NOT has_table_privilege('authenticated','public.prescription_item_correction_events','SELECT') THEN
    RAISE EXCEPTION 'authenticated lacks explicit correction request/event SELECT';
  END IF;
  IF has_function_privilege('anon','public.request_prescription_item_correction(uuid,text)','EXECUTE')
     OR has_function_privilege('anon','public.resolve_prescription_item_correction(uuid,text,jsonb,text)','EXECUTE') THEN
    RAISE EXCEPTION 'anon can execute prescription correction RPCs';
  END IF;
END
$privileges$;

-- Replace one exact item with an explicitly selected active catalogue medicine.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
DO $replace_item$
DECLARE v_request uuid := current_setting('test.req_replace')::uuid; v_result uuid;
BEGIN
  v_result := public.resolve_prescription_item_correction(
    v_request,'replace_item',
    jsonb_build_object(
      'medicine_id','95000000-0000-0000-0000-000000000001',
      'dose','500 mg','frequency','TID','duration','5 days','quantity',15,
      'instructions','After food','dosage_form','Capsule','route','Oral'
    ),NULL
  );
  IF v_result IS DISTINCT FROM v_request THEN RAISE EXCEPTION 'replace_item returned an unexpected request id'; END IF;
END
$replace_item$;
RESET ROLE;

DO $replace_assertions$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_items
    WHERE id=current_setting('test.item_replace')::uuid
      AND medicine_id='95000000-0000-0000-0000-000000000001'
      AND medication_name='Amoxicillin 500 mg'
      AND unit_price=12.50 AND dose='500 mg' AND dosage='500 mg'
      AND frequency='TID' AND duration='5 days' AND quantity=15
      AND dosage_form='Capsule' AND route='Oral'
  ) THEN RAISE EXCEPTION 'replacement item was not updated from the explicit active catalogue selection'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_item_correction_requests
    WHERE id=current_setting('test.req_replace')::uuid AND status='resolved'
      AND disposition='replace_item' AND resolved_by='91000000-0000-0000-0000-000000000001'
  ) THEN RAISE EXCEPTION 'replace request was not resolved with actor/disposition evidence'; END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_events WHERE request_id=current_setting('test.req_replace')::uuid) <> 2 THEN
    RAISE EXCEPTION 'replace request must have exactly request and resolution events';
  END IF;
END
$replace_assertions$;

-- An unrelated doctor cannot resolve another doctor's request.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000002',true);
DO $unrelated_resolver$
DECLARE v_failed boolean := false;
BEGIN
  BEGIN
    PERFORM public.resolve_prescription_item_correction(
      current_setting('test.req_reject')::uuid,'reject',NULL,'Unrelated doctor attempt to reject this request.'
    );
  EXCEPTION WHEN OTHERS THEN v_failed := true;
  END;
  IF NOT v_failed THEN RAISE EXCEPTION 'unrelated doctor resolved a correction request'; END IF;
END
$unrelated_resolver$;
RESET ROLE;

-- Rejecting a request leaves the original prescription and item unchanged.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
DO $reject_item$
BEGIN
  PERFORM public.resolve_prescription_item_correction(
    current_setting('test.req_reject')::uuid,'reject',NULL,'The intended medicine cannot be safely identified from the note.'
  );
END
$reject_item$;
RESET ROLE;

DO $reject_assertions$
BEGIN
  IF (SELECT status FROM public.prescriptions WHERE id=current_setting('test.rx_reject')::uuid) <> 'pending' THEN
    RAISE EXCEPTION 'rejection changed the original prescription status';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE id=current_setting('test.item_reject')::uuid AND medicine_id IS NULL AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'rejection changed the original unlinked item';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_item_correction_requests WHERE id=current_setting('test.req_reject')::uuid AND status='rejected' AND disposition='reject') THEN
    RAISE EXCEPTION 'rejection disposition not recorded';
  END IF;
END
$reject_assertions$;

-- Cancel-and-reissue preserves the old order and creates a complete replacement atomically.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
DO $reissue$
DECLARE v_result uuid; v_new_rx uuid; v_req uuid := current_setting('test.req_reissue')::uuid;
BEGIN
  PERFORM public.resolve_prescription_item_correction(
    v_req,'cancel_and_reissue',
    jsonb_build_array(
      jsonb_build_object('source_item_id',current_setting('test.item_reissue')::uuid,'medicine_id','95000000-0000-0000-0000-000000000001','dose','250 mg','frequency','BID','duration','5 days','quantity',10,'dosage_form','Capsule','route','Oral','instructions','Complete replacement'),
      jsonb_build_object('source_item_id',current_setting('test.item_reissue_linked')::uuid,'medicine_id','95000000-0000-0000-0000-000000000002','dose','500 mg','frequency','TID','duration','3 days','quantity',9,'dosage_form','Tablet','route','Oral','instructions','Preserved and confirmed')
    ),'Replace the complete pending order with a corrected catalogue-linked order.'
  );
  SELECT replacement_prescription_id INTO v_new_rx FROM public.prescription_item_correction_requests WHERE id=v_req;
  IF v_new_rx IS NULL THEN RAISE EXCEPTION 'cancel_and_reissue did not record the replacement prescription'; END IF;
  PERFORM set_config('test.rx_reissued',v_new_rx::text,true);
END
$reissue$;
RESET ROLE;

DO $reissue_assertions$
BEGIN
  IF (SELECT status FROM public.prescriptions WHERE id=current_setting('test.rx_reissue')::uuid) <> 'cancelled' THEN
    RAISE EXCEPTION 'original prescription was not cancelled';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE id=current_setting('test.rx_reissued')::uuid AND status='pending' AND is_external IS FALSE AND prescription_type='internal') THEN
    RAISE EXCEPTION 'replacement prescription is not a pending internal order';
  END IF;
  IF (SELECT count(*) FROM public.prescription_items WHERE prescription_id=current_setting('test.rx_reissued')::uuid AND deleted_at IS NULL) <> 2
     OR EXISTS (SELECT 1 FROM public.prescription_items WHERE prescription_id=current_setting('test.rx_reissued')::uuid AND deleted_at IS NULL AND medicine_id IS NULL) THEN
    RAISE EXCEPTION 'replacement order omitted or retained an unlinked item';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE id=current_setting('test.item_reissue')::uuid AND medicine_id IS NULL) THEN
    RAISE EXCEPTION 'original item history was overwritten during cancel-and-reissue';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_item_correction_requests WHERE id=current_setting('test.req_reissue')::uuid AND status='resolved' AND disposition='cancel_and_reissue') THEN
    RAISE EXCEPTION 'cancel-and-reissue disposition not recorded';
  END IF;
END
$reissue_assertions$;

-- A stale item snapshot must not be resolved.
UPDATE public.prescription_items SET dose='changed after request' WHERE id=current_setting('test.item_stale')::uuid;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','90000000-0000-0000-0000-000000000001',true);
DO $stale_snapshot$
DECLARE v_failed boolean := false;
BEGIN
  BEGIN
    PERFORM public.resolve_prescription_item_correction(
      current_setting('test.req_stale')::uuid,'replace_item',
      jsonb_build_object('medicine_id','95000000-0000-0000-0000-000000000001','dose','10 mg','frequency','OD','duration','3 days','quantity',3,'dosage_form','Tablet','route','Oral'),NULL
    );
  EXCEPTION WHEN OTHERS THEN v_failed := true;
  END;
  IF NOT v_failed THEN RAISE EXCEPTION 'stale correction snapshot was accepted'; END IF;
END
$stale_snapshot$;
RESET ROLE;

-- Request/reject/replace/reissue never creates inventory or financial side effects.
DO $no_financial_or_stock_side_effects$
BEGIN
  IF (SELECT count(*) FROM public.stock_movements) <> 0
     OR (SELECT count(*) FROM public.invoices) <> 0
     OR (SELECT count(*) FROM public.invoice_items) <> 0
     OR (SELECT count(*) FROM public.payments) <> 0
     OR (SELECT count(*) FROM public.cashbox_transactions) <> 0 THEN
    RAISE EXCEPTION 'correction workflow created stock, invoice, payment or cashbox rows';
  END IF;
END
$no_financial_or_stock_side_effects$;

ROLLBACK;
