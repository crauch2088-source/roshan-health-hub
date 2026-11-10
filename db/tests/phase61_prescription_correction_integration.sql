-- Phase 61: disposable PostgreSQL 17 behavior, role, branch, audit and no-side-effect tests.
DO $phase61_catalog$
DECLARE v_count integer; v_config text[];
BEGIN
  SELECT count(*) INTO v_count
  FROM public.role_permissions rp
  JOIN public.roles r ON r.id=rp.role_id
  JOIN public.permissions p ON p.id=rp.permission_id
  WHERE (p.code='pharmacy.correction.request' AND r.code='pharmacist')
     OR (p.code='prescriptions.correction.resolve' AND r.code='doctor');
  IF v_count <> 2 THEN RAISE EXCEPTION 'dedicated correction permissions are not assigned only to pharmacist and doctor'; END IF;

  IF NOT (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='public.prescription_item_correction_requests'::regclass)
     OR NOT (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='public.prescription_item_correction_events'::regclass) THEN
    RAISE EXCEPTION 'correction request/event tables must enable and force RLS';
  END IF;

  IF has_table_privilege('authenticated','public.prescription_item_correction_requests','INSERT')
     OR has_table_privilege('authenticated','public.prescription_item_correction_requests','UPDATE')
     OR has_table_privilege('authenticated','public.prescription_item_correction_requests','DELETE')
     OR has_table_privilege('authenticated','public.prescription_item_correction_events','INSERT')
     OR has_table_privilege('authenticated','public.prescription_item_correction_events','UPDATE')
     OR has_table_privilege('authenticated','public.prescription_item_correction_events','DELETE')
     OR has_table_privilege('service_role','public.prescription_item_correction_requests','INSERT')
     OR has_table_privilege('service_role','public.prescription_item_correction_events','INSERT') THEN
    RAISE EXCEPTION 'application/service roles must not have direct correction-table writes';
  END IF;

  SELECT proconfig INTO v_config FROM pg_proc WHERE oid='public.request_prescription_item_correction(uuid,text)'::regprocedure;
  IF v_config IS NULL OR NOT ('search_path=""'=ANY(v_config)) THEN RAISE EXCEPTION 'request RPC must use empty search_path'; END IF;
  SELECT proconfig INTO v_config FROM pg_proc WHERE oid='public.resolve_prescription_item_correction(uuid,text,jsonb,text)'::regprocedure;
  IF v_config IS NULL OR NOT ('search_path=""'=ANY(v_config)) THEN RAISE EXCEPTION 'resolve RPC must use empty search_path'; END IF;

  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.request_prescription_item_correction(uuid,text)'::regprocedure)
     OR NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.resolve_prescription_item_correction(uuid,text,jsonb,text)'::regprocedure) THEN
    RAISE EXCEPTION 'correction RPCs must be SECURITY DEFINER';
  END IF;

  IF has_function_privilege('anon','public.request_prescription_item_correction(uuid,text)','EXECUTE')
     OR has_function_privilege('service_role','public.request_prescription_item_correction(uuid,text)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.request_prescription_item_correction(uuid,text)','EXECUTE')
     OR has_function_privilege('anon','public.resolve_prescription_item_correction(uuid,text,jsonb,text)','EXECUTE')
     OR has_function_privilege('service_role','public.resolve_prescription_item_correction(uuid,text,jsonb,text)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.resolve_prescription_item_correction(uuid,text,jsonb,text)','EXECUTE') THEN
    RAISE EXCEPTION 'correction RPC EXECUTE grants are incorrect';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.prescription_item_correction_events'::regclass AND tgname='prescription_item_correction_events_no_update_delete' AND NOT tgisinternal)
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.prescription_item_correction_events'::regclass AND tgname='prescription_item_correction_events_no_truncate' AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'correction event append-only guards are missing';
  END IF;
END;
$phase61_catalog$;

CREATE TEMP TABLE phase61_side_effect_baseline AS
SELECT
  (SELECT count(*) FROM public.pharmacy_inventory) AS inventory_count,
  (SELECT count(*) FROM public.stock_movements) AS stock_movement_count,
  (SELECT count(*) FROM public.invoices) AS invoice_count,
  (SELECT count(*) FROM public.invoice_items) AS invoice_item_count,
  (SELECT count(*) FROM public.payments) AS payment_count,
  (SELECT count(*) FROM public.cashbox_transactions) AS cashbox_count;

-- Pharmacist A creates a request; retry returns the same pending request without a second event.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
SELECT set_config('request.jwt.claim.role','authenticated',false);
DO $phase61_request$
DECLARE v_first uuid; v_retry uuid; v_count integer;
BEGIN
  v_first := public.request_prescription_item_correction('61800000-0000-0000-0000-000000000001','The saved item is not linked to a verified catalogue medicine.');
  v_retry := public.request_prescription_item_correction('61800000-0000-0000-0000-000000000001','A repeated request with a different note must not replace the first reason.');
  IF v_first IS DISTINCT FROM v_retry THEN RAISE EXCEPTION 'duplicate request retry did not return the existing request'; END IF;
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_requests WHERE prescription_item_id='61800000-0000-0000-0000-000000000001' AND status='pending';
  IF v_count <> 1 THEN RAISE EXCEPTION 'duplicate pending request was created'; END IF;
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_events WHERE request_id=v_first AND event_type='requested';
  IF v_count <> 1 THEN RAISE EXCEPTION 'duplicate retry appended another request event'; END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_requests) <> 1 THEN RAISE EXCEPTION 'pharmacist cannot read own branch request'; END IF;
END;
$phase61_request$;

-- Wrong-branch pharmacist, ordinary Admin, external/cancelled/dispensed/deleted/linked items fail closed.
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000004',false);
DO $phase61_wrong_branch$
DECLARE v_denied boolean;
BEGIN
  v_denied := false;
  BEGIN PERFORM public.request_prescription_item_correction('61800000-0000-0000-0000-000000000001','Wrong branch must not request this item.'); EXCEPTION WHEN OTHERS THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'wrong-branch pharmacist created a correction request'; END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_requests) <> 0 THEN RAISE EXCEPTION 'wrong-branch pharmacist can read correction requests'; END IF;
END;
$phase61_wrong_branch$;

SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000005',false);
DO $phase61_admin$
DECLARE v_denied boolean;
BEGIN
  IF public.app_has_perm('pharmacy.correction.request') OR public.app_has_perm('prescriptions.correction.resolve') THEN
    RAISE EXCEPTION 'ordinary Admin unexpectedly received correction permissions';
  END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_requests) <> 0 THEN RAISE EXCEPTION 'ordinary Admin can read correction requests'; END IF;
  v_denied := false;
  BEGIN PERFORM public.request_prescription_item_correction('61800000-0000-0000-0000-000000000002','Admin must not request correction.'); EXCEPTION WHEN OTHERS THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'ordinary Admin created a correction request'; END IF;
END;
$phase61_admin$;
RESET ROLE;

-- Reject invalid prescription/item states at the authoritative RPC boundary.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61_invalid_items$
DECLARE v_item uuid; v_denied boolean;
BEGIN
  FOREACH v_item IN ARRAY ARRAY[
    '61800000-0000-0000-0000-000000000003'::uuid,
    '61800000-0000-0000-0000-000000000004'::uuid,
    '61800000-0000-0000-0000-000000000005'::uuid,
    '61800000-0000-0000-0000-000000000006'::uuid,
    '61800000-0000-0000-0000-000000000012'::uuid,
    '61800000-0000-0000-0000-000000000013'::uuid
  ] LOOP
    v_denied := false;
    BEGIN
      PERFORM public.request_prescription_item_correction(v_item,'This invalid parent/item state must be rejected.');
    EXCEPTION WHEN OTHERS THEN
      v_denied := true;
    END;
    IF NOT v_denied THEN RAISE EXCEPTION 'invalid item state unexpectedly accepted: %',v_item; END IF;
  END LOOP;
END;
$phase61_invalid_items$;
RESET ROLE;

-- The responsible doctor can see and replace only the requested item. The second free-text item stays blocked.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000002',false);
DO $phase61_replace$
DECLARE v_request uuid; v_result record; v_count integer; v_new_item uuid;
BEGIN
  SELECT id INTO v_request FROM public.prescription_item_correction_requests WHERE prescription_item_id='61800000-000000000001';
  IF v_request IS NULL THEN RAISE EXCEPTION 'request missing for responsible doctor'; END IF;
  SELECT * INTO v_result FROM public.resolve_prescription_item_correction(
    v_request,'replace_item',
    '{"medicine_id":"61600000-0000-0000-0000-000000000001","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"instructions":"After food","dosage_form":"capsule","route":"oral"}'::jsonb,
    NULL
  );
  v_new_item := v_result.corrected_item_id;
  IF v_result.status IS DISTINCT FROM 'resolved' OR v_new_item IS NULL THEN RAISE EXCEPTION 'replacement did not resolve request'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE id='61800000-0000-0000-0000-000000000001' AND deleted_at IS NOT NULL) THEN RAISE EXCEPTION 'original item history was not retained as soft-deleted'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE id=v_new_item AND prescription_id='61700000-0000-0000-0000-000000000001' AND medicine_id='61600000-0000-0000-0000-000000000001' AND medication_name='Amoxicillin 500 mg' AND unit_price=12.50 AND quantity=10) THEN RAISE EXCEPTION 'replacement item was not derived from the active catalogue'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE id='61800000-0000-0000-0000-000000000002' AND deleted_at IS NULL AND medicine_id IS NULL) THEN RAISE EXCEPTION 'partial correction silently removed or linked another unrequested item'; END IF;
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_events WHERE request_id=v_request;
  IF v_count <> 2 THEN RAISE EXCEPTION 'request and replacement events are not both present'; END IF;
END;
$phase61_replace$;
RESET ROLE;

-- Rejection changes request/event state only; original clinical item remains unchanged and pending.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61_reject_request$
DECLARE v_request uuid;
BEGIN
  v_request := public.request_prescription_item_correction('61800000-0000-0000-0000-000000000007','Please clarify the intended medicine before dispensing.');
END;
$phase61_reject_request$;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000002',false);
DO $phase61_reject$
DECLARE v_request uuid; v_result record;
BEGIN
  SELECT id INTO v_request FROM public.prescription_item_correction_requests WHERE prescription_item_id='61800000-0000-0000-0000-000000000007';
  SELECT * INTO v_result FROM public.resolve_prescription_item_correction(v_request,'reject',NULL,'The supplied free-text name is clinically ambiguous; please issue a corrected order.');
  IF v_result.status IS DISTINCT FROM 'rejected' THEN RAISE EXCEPTION 'request rejection status is incorrect'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE id='61700000-0000-0000-0000-000000000006' AND status='pending') THEN RAISE EXCEPTION 'rejection changed the prescription state'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE id='61800000-0000-0000-0000-000000000007' AND deleted_at IS NULL AND medicine_id IS NULL) THEN RAISE EXCEPTION 'rejection changed the original item'; END IF;
END;
$phase61_reject$;
RESET ROLE;

-- Cancel-and-reissue is atomic, retains the old order, and does not bill or dispense.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61_reissue_request$
BEGIN
  PERFORM public.request_prescription_item_correction('61800000-0000-0000-0000-000000000008','The prescription needs a fully corrected catalogue-linked order.');
END;
$phase61_reissue_request$;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000002',false);
DO $phase61_reissue$
DECLARE v_request uuid; v_result record;
BEGIN
  SELECT id INTO v_request FROM public.prescription_item_correction_requests WHERE prescription_item_id='61800000-000000-0000-000000000008';
  SELECT * INTO v_result FROM public.resolve_prescription_item_correction(
    v_request,'cancel_and_reissue',
    '[{"medicine_id":"61600000-0000-0000-0000-000000000001","medication_name":"Amoxicillin 500 mg","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"instructions":"After food","dosage_form":"capsule","route":"oral"}]'::jsonb,
    'Original order replaced after pharmacist clarification.'
  );
  IF v_result.status IS DISTINCT FROM 'resolved' OR v_result.replacement_prescription_id IS NULL THEN RAISE EXCEPTION 'cancel-and-reissue did not resolve'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE id='61700000-0000-0000-0000-000000000007' AND status='cancelled') THEN RAISE EXCEPTION 'original prescription was not cancelled'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE id=v_result.replacement_prescription_id AND status='pending' AND branch_id='61100000-0000-0000-0000-000000000001') THEN RAISE EXCEPTION 'replacement prescription was not created in the original branch'; END IF;
  IF EXISTS (SELECT 1 FROM public.prescription_items WHERE prescription_id=v_result.replacement_prescription_id AND medicine_id IS NULL AND deleted_at IS NULL) THEN RAISE EXCEPTION 'replacement order contains an unlinked item'; END IF;
END;
$phase61_reissue$;
RESET ROLE;

-- Super Admin explicit bypass is retained for a cross-branch remediation.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000006',false);
DO $phase61_super_admin$
DECLARE v_request uuid; v_result record;
BEGIN
  v_request := public.request_prescription_item_correction('61800000-0000-0000-0000-000000000011','Super Admin remediation request for a second branch.');
  SELECT * INTO v_result FROM public.resolve_prescription_item_correction(v_request,'reject',NULL,'Super Admin recorded the exception for manual prescriber follow-up.');
  IF v_result.status IS DISTINCT FROM 'rejected' THEN RAISE EXCEPTION 'Super Admin explicit bypass failed'; END IF;
END;
$phase61_super_admin$;
RESET ROLE;

-- Final: correction operations must not create stock, invoice, payment or cashbox side effects.
DO $phase61_no_side_effects$
DECLARE v_before record; v_after record;
BEGIN
  SELECT * INTO v_before FROM phase61_side_effect_baseline;
  SELECT
    (SELECT count(*) FROM public.pharmacy_inventory),
    (SELECT count(*) FROM public.stock_movements),
    (SELECT count(*) FROM public.invoices),
    (SELECT count(*) FROM public.invoice_items),
    (SELECT count(*) FROM public.payments),
    (SELECT count(*) FROM public.cashbox_transactions)
  INTO v_after;
  IF v_after IS DISTINCT FROM v_before THEN
    RAISE EXCEPTION 'correction workflow changed inventory, stock movement or financial tables';
  END IF;
END;
$phase61_no_side_effects$;
