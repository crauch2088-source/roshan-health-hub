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

  IF NOT EXISTS (
    SELECT 1 FROM public.role_permissions rp
    JOIN public.roles r ON r.id=rp.role_id
    JOIN public.permissions p ON p.id=rp.permission_id
    WHERE r.code='doctor' AND p.code='prescriptions.create'
  ) THEN
    RAISE EXCEPTION 'doctor is missing the dedicated prescription-authoring permission';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.role_permissions rp
    JOIN public.roles r ON r.id=rp.role_id
    JOIN public.permissions p ON p.id=rp.permission_id
    WHERE r.code IN ('admin','super_admin','pharmacist') AND p.code='prescriptions.create'
  ) THEN
    RAISE EXCEPTION 'Admin or pharmacist unexpectedly received prescription-authoring permission';
  END IF;

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
     OR has_table_privilege('service_role','public.prescription_item_correction_events','INSERT')
     OR has_table_privilege('authenticator','public.prescription_item_correction_requests','INSERT')
     OR has_table_privilege('authenticator','public.prescription_item_correction_requests','UPDATE')
     OR has_table_privilege('authenticator','public.prescription_item_correction_requests','DELETE')
     OR has_table_privilege('authenticator','public.prescription_item_correction_requests','TRUNCATE')
     OR has_table_privilege('authenticator','public.prescription_item_correction_events','INSERT')
     OR has_table_privilege('authenticator','public.prescription_item_correction_events','UPDATE')
     OR has_table_privilege('authenticator','public.prescription_item_correction_events','DELETE')
     OR has_table_privilege('authenticator','public.prescription_item_correction_events','TRUNCATE') THEN
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

  v_count := 0;
  BEGIN
    PERFORM public.create_prescription_atomic(
      '61700000-0000-0000-0000-000000000001',
      false,
      '[{"medicine_id":"61600000-0000-0000-0000-000000000001","medication_name":"Amoxicillin 500 mg","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"dosage_form":"capsule","route":"oral"}]'::jsonb
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_count := 1;
  END;
  IF v_count <> 1 THEN RAISE EXCEPTION 'pharmacist with pharmacy.create can still author a prescription'; END IF;
END;
$phase61_request$;

-- An unrelated same-branch doctor has the role-level permission but not this visit's authority.
RESET ROLE;
SELECT set_config(
  'phase61.primary_request_id',
  (SELECT id::text FROM public.prescription_item_correction_requests
   WHERE prescription_item_id = '61800000-0000-0000-0000-000000000001'),
  false
);
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000003',false);
DO $phase61_unassigned_doctor$
DECLARE v_denied boolean; v_request_id uuid := current_setting('phase61.primary_request_id')::uuid;
BEGIN
  IF NOT public.app_has_perm('prescriptions.correction.resolve') THEN
    RAISE EXCEPTION 'fixture doctor is missing the dedicated role permission';
  END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_requests) <> 0 THEN
    RAISE EXCEPTION 'unassigned doctor can read another prescribers correction request';
  END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_events) <> 0 THEN
    RAISE EXCEPTION 'unassigned doctor can read another prescribers correction events';
  END IF;
  v_denied := false;
  BEGIN
    PERFORM public.resolve_prescription_item_correction(
      v_request_id,'reject',NULL,'An unrelated doctor must not resolve this request.'
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'unassigned doctor resolved a correction request';
  END IF;
END;
$phase61_unassigned_doctor$;

-- A doctor assigned to another branch must also be unable to read or resolve the request.
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000007',false);
DO $phase61_wrong_branch_doctor$
DECLARE v_denied boolean; v_request_id uuid := current_setting('phase61.primary_request_id')::uuid;
BEGIN
  IF (SELECT count(*) FROM public.prescription_item_correction_requests) <> 0 THEN
    RAISE EXCEPTION 'wrong-branch doctor can read another branch correction request';
  END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_events) <> 0 THEN
    RAISE EXCEPTION 'wrong-branch doctor can read another branch correction events';
  END IF;
  v_denied := false;
  BEGIN
    PERFORM public.resolve_prescription_item_correction(
      v_request_id,'reject',NULL,'A doctor from another branch must not resolve this request.'
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'wrong-branch doctor resolved a correction request';
  END IF;
END;
$phase61_wrong_branch_doctor$;

-- Wrong-branch pharmacist, ordinary Admin, external/cancelled/dispensed/deleted/linked items fail closed.
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000004',false);
DO $phase61_wrong_branch$
DECLARE v_denied boolean;
BEGIN
  v_denied := false;
  BEGIN PERFORM public.request_prescription_item_correction('61800000-0000-0000-0000-000000000001','Wrong branch must not request this item.'); EXCEPTION WHEN OTHERS THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'wrong-branch pharmacist created a correction request'; END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_requests) <> 0 THEN RAISE EXCEPTION 'wrong-branch pharmacist can read correction requests'; END IF;
  IF (SELECT count(*) FROM public.prescription_item_correction_events) <> 0 THEN RAISE EXCEPTION 'wrong-branch pharmacist can read correction events'; END IF;
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
  IF (SELECT count(*) FROM public.prescription_item_correction_events) <> 0 THEN RAISE EXCEPTION 'ordinary Admin can read correction events'; END IF;
  v_denied := false;
  BEGIN PERFORM public.request_prescription_item_correction('61800000-0000-0000-0000-000000000002','Admin must not request correction.'); EXCEPTION WHEN OTHERS THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'ordinary Admin created a correction request'; END IF;

  v_denied := false;
  BEGIN
    PERFORM public.create_prescription_atomic(
      '61700000-0000-0000-0000-000000000001',
      false,
      '[{"medicine_id":"61600000-0000-0000-0000-000000000001","medication_name":"Amoxicillin 500 mg","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"dosage_form":"capsule","route":"oral"}]'::jsonb
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Admin with emr.create can still author a prescription'; END IF;
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
  IF NOT public.app_has_perm('prescriptions.correction.resolve') THEN
    RAISE EXCEPTION 'responsible doctor lacks the dedicated correction permission';
  END IF;
  IF NOT private.app_can_resolve_prescription_item_correction('61700000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'responsible doctor is not recognized by the branch-bound resolver scope';
  END IF;
  SELECT id INTO v_request FROM public.prescription_item_correction_requests WHERE prescription_item_id='61800000-0000-0000-0000-000000000001';
  IF v_request IS NULL THEN RAISE EXCEPTION 'request missing for responsible doctor'; END IF;
  SELECT * INTO v_result FROM public.resolve_prescription_item_correction(
    v_request,'replace_item',
    '{"medicine_id":"61600000-0000-0000-0000-000000000001","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"instructions":"After food","dosage_form":"capsule","route":"oral"}'::jsonb,
    NULL
  );
  v_new_item := v_result.corrected_item_id;
  IF v_result.status IS DISTINCT FROM 'resolved' OR v_new_item IS NULL THEN RAISE EXCEPTION 'replacement did not resolve request'; END IF;
  SELECT count(*) INTO v_count FROM public.prescription_item_correction_events WHERE request_id=v_request;
  IF v_count <> 2 THEN RAISE EXCEPTION 'request and replacement events are not both present'; END IF;
END;
$phase61_replace$;
RESET ROLE;

-- Verify retained soft-deleted history as the database owner; authenticated RLS intentionally hides it.
DO $phase61_replace_history$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.prescription_items
    WHERE id = '61800000-0000-0000-0000-000000000001'
      AND deleted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'original item history was not retained as soft-deleted';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.prescription_item_correction_requests AS r
    JOIN public.prescription_items AS pi ON pi.id = r.corrected_item_id
    WHERE r.prescription_item_id = '61800000-0000-0000-0000-000000000001'
      AND r.status = 'resolved'
      AND pi.prescription_id = '61700000-0000-0000-0000-000000000001'
      AND pi.medicine_id = '61600000-0000-0000-0000-000000000001'
      AND pi.medication_name = 'Amoxicillin 500 mg'
      AND pi.unit_price = 12.50
      AND pi.quantity = 10
      AND pi.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'replacement item was not derived from the active catalogue';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.prescription_items
    WHERE id = '61800000-0000-0000-0000-000000000002'
      AND deleted_at IS NULL
      AND medicine_id IS NULL
  ) THEN
    RAISE EXCEPTION 'partial correction silently removed or linked another unrequested item';
  END IF;
END;
$phase61_replace_history$;

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
END;
$phase61_reject$;
RESET ROLE;

-- Verify rejection's no-mutation guarantee outside the clinician's RLS read scope.
DO $phase61_reject_state$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.prescriptions
    WHERE id = '61700000-0000-0000-0000-000000000006'
      AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'rejection changed the prescription state';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_items
    WHERE id = '61800000-0000-0000-0000-000000000007'
      AND deleted_at IS NULL
      AND medicine_id IS NULL
  ) THEN
    RAISE EXCEPTION 'rejection changed the original item';
  END IF;
END;
$phase61_reject_state$;

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
  SELECT id INTO v_request FROM public.prescription_item_correction_requests WHERE prescription_item_id='61800000-0000-0000-0000-000000000008';
  SELECT * INTO v_result FROM public.resolve_prescription_item_correction(
    v_request,'cancel_and_reissue',
    '[{"medicine_id":"61600000-0000-0000-0000-000000000001","medication_name":"Amoxicillin 500 mg","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"instructions":"After food","dosage_form":"capsule","route":"oral"}]'::jsonb,
    'Original order replaced after pharmacist clarification.'
  );
  IF v_result.status IS DISTINCT FROM 'resolved' OR v_result.replacement_prescription_id IS NULL THEN RAISE EXCEPTION 'cancel-and-reissue did not resolve'; END IF;
END;
$phase61_reissue$;
RESET ROLE;

-- Verify the replacement prescription and catalogue links as the database owner.
DO $phase61_reissue_state$
DECLARE v_replacement_id uuid;
BEGIN
  SELECT replacement_prescription_id
    INTO v_replacement_id
  FROM public.prescription_item_correction_requests
  WHERE prescription_item_id = '61800000-0000-0000-0000-000000000008'
    AND status = 'resolved';

  IF v_replacement_id IS NULL THEN
    RAISE EXCEPTION 'cancel-and-reissue replacement id was not persisted';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescriptions
    WHERE id = '61700000-0000-0000-0000-000000000007'
      AND status = 'cancelled'
  ) THEN
    RAISE EXCEPTION 'original prescription was not cancelled';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescriptions
    WHERE id = v_replacement_id
      AND status = 'pending'
      AND branch_id = '61100000-0000-0000-0000-000000000001'
  ) THEN
    RAISE EXCEPTION 'replacement prescription was not created in the original branch';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.prescription_items
    WHERE prescription_id = v_replacement_id
      AND medicine_id IS NULL
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'replacement order contains an unlinked item';
  END IF;
END;
$phase61_reissue_state$;

-- Pharmacy inventory authority is not clinical prescription-authoring authority.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
SELECT set_config('request.jwt.claim.role','authenticated',false);
DO $phase61_pharmacist_prescription_scope$
DECLARE v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.create') OR public.app_has_perm('emr.create') THEN
    RAISE EXCEPTION 'fixture pharmacist does not model the live pharmacy-only permission scope';
  END IF;

  BEGIN
    PERFORM public.create_prescription_atomic(
      '61500000-0000-0000-0000-000000000001',
      false,
      '[{"medication_name":"Unauthorized internal order","quantity":1}]'::jsonb
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'pharmacist created an internal prescription through the SECURITY DEFINER RPC';
  END IF;

  v_denied := false;
  BEGIN
    PERFORM public.create_prescription_atomic(
      '61500000-0000-0000-0000-000000000001',
      true,
      '[{"medication_name":"Unauthorized external prescription","quantity":1}]'::jsonb
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'pharmacist created a prescription through the clinical authoring RPC';
  END IF;

  v_denied := false;
  BEGIN
    PERFORM public.create_prescription_atomic(
      '61500000-0000-0000-0000-000000000001',
      NULL,
      '[{"medication_name":"Ambiguous prescription type","quantity":1}]'::jsonb
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'pharmacist bypassed the clinical authoring role gate';
  END IF;
END;
$phase61_pharmacist_prescription_scope$;
RESET ROLE;

-- An authorized doctor reaches payload validation and must provide an explicit prescription type.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000002',false);
DO $phase61_doctor_explicit_type$
DECLARE v_denied boolean := false;
BEGIN
  BEGIN
    PERFORM public.create_prescription_atomic(
      '61500000-0000-0000-0000-000000000001',
      NULL,
      '[{"medication_name":"Ambiguous prescription type","quantity":1}]'::jsonb
    );
  EXCEPTION WHEN SQLSTATE '22023' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'prescription authoring accepted an implicit external/internal type';
  END IF;
END;
$phase61_doctor_explicit_type$;
RESET ROLE;

-- Admin has broad EMR and pharmacy permissions in the live role matrix, but not clinical prescribing authority.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000005',false);
SELECT set_config('request.jwt.claim.role','authenticated',false);
DO $phase61_admin_prescription_scope$
DECLARE v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('emr.create')
     OR NOT public.app_has_perm('pharmacy.create')
     OR public.app_has_perm('prescriptions.create') THEN
    RAISE EXCEPTION 'fixture Admin does not model the live broad-but-nonclinical permission scope';
  END IF;

  BEGIN
    PERFORM public.create_prescription_atomic(
      '61500000-0000-0000-0000-000000000001',
      false,
      '[{"medication_name":"Unauthorized Admin order","quantity":1}]'::jsonb
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'ordinary Admin created a clinical prescription through the SECURITY DEFINER RPC';
  END IF;
END;
$phase61_admin_prescription_scope$;
RESET ROLE;

-- A missing catalogue price must fail closed rather than silently becoming a zero-price item.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61_unpriced_request$
BEGIN
  PERFORM public.request_prescription_item_correction(
    '61800000-0000-0000-0000-000000000014',
    'The catalogue item has no configured selling price; request clinical review.'
  );
END;
$phase61_unpriced_request$;
RESET ROLE;
UPDATE public.medicines
SET selling_price = NULL
WHERE id = '61600000-0000-0000-0000-000000000001';

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000002',false);
DO $phase61_unpriced_replacement$
DECLARE v_request uuid; v_denied boolean := false;
BEGIN
  SELECT id INTO v_request
  FROM public.prescription_item_correction_requests
  WHERE prescription_item_id = '61800000-0000-0000-0000-000000000014';

  BEGIN
    PERFORM * FROM public.resolve_prescription_item_correction(
      v_request,
      'replace_item',
      '{"medicine_id":"61600000-0000-0000-0000-000000000001","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"dosage_form":"capsule","route":"oral"}'::jsonb,
      'Do not accept an unpriced catalogue medicine.'
    );
  EXCEPTION WHEN SQLSTATE '23514' THEN
    v_denied := true;
  END;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'unpriced catalogue medicine was silently converted to a zero-price prescription item';
  END IF;
END;
$phase61_unpriced_replacement$;
RESET ROLE;

DO $phase61_unpriced_state$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.prescription_item_correction_requests
    WHERE prescription_item_id = '61800000-0000-0000-0000-000000000014'
      AND status = 'pending'
      AND corrected_item_id IS NULL
  ) THEN
    RAISE EXCEPTION 'unpriced replacement attempt changed the correction request';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.prescription_items
    WHERE id = '61800000-0000-0000-0000-000000000014'
      AND deleted_at IS NULL
      AND medicine_id IS NULL
  ) THEN
    RAISE EXCEPTION 'unpriced replacement attempt mutated the original prescription item';
  END IF;
END;
$phase61_unpriced_state$;

-- Cancel-and-reissue must also reject an unpriced catalogue item before creating a replacement order.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000002',false);
DO $phase61_unpriced_reissue$
DECLARE v_request uuid; v_denied boolean := false;
BEGIN
  SELECT id INTO v_request
  FROM public.prescription_item_correction_requests
  WHERE prescription_item_id = '61800000-0000-0000-0000-000000000014'
    AND status = 'pending';

  BEGIN
    PERFORM * FROM public.resolve_prescription_item_correction(
      v_request,
      'cancel_and_reissue',
      '[{"medicine_id":"61600000-0000-0000-0000-000000000001","dose":"500 mg","frequency":"BID","duration":"5 days","quantity":10,"instructions":"After food","dosage_form":"capsule","route":"oral"}]'::jsonb,
      'Do not issue a replacement order from an unpriced catalogue item.'
    );
  EXCEPTION WHEN SQLSTATE '23514' THEN
    v_denied := true;
  END;

  IF NOT v_denied THEN
    RAISE EXCEPTION 'cancel-and-reissue accepted an unpriced catalogue medicine';
  END IF;
END;
$phase61_unpriced_reissue$;
RESET ROLE;

DO $phase61_unpriced_reissue_state$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.prescriptions
    WHERE id = '61700000-0000-0000-0000-000000000008'
      AND status = 'pending'
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'unpriced cancel-and-reissue changed the original prescription';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_item_correction_requests
    WHERE prescription_item_id = '61800000-0000-0000-0000-000000000014'
      AND status = 'pending'
      AND replacement_prescription_id IS NULL
  ) THEN
    RAISE EXCEPTION 'unpriced cancel-and-reissue changed the correction request';
  END IF;
END;
$phase61_unpriced_reissue_state$;

UPDATE public.medicines
SET selling_price = 12.50
WHERE id = '61600000-0000-0000-0000-000000000001';

-- Super Admin cannot inherit clinical write authority; administrative read access remains separate.
-- A real pharmacist in branch B creates the request; Super Admin in branch A must not resolve it.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000004',false);
SELECT set_config(
  'phase61.super_admin_request_id',
  public.request_prescription_item_correction(
    '61800000-0000-0000-0000-000000000011',
    'Synthetic pharmacist request for a second-branch prescriber review.'
  )::text,
  false
);
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000006',false);
DO $phase61_super_admin_no_clinical$
DECLARE
  v_denied boolean := false;
  v_request_id uuid := current_setting('phase61.super_admin_request_id')::uuid;
BEGIN
  IF NOT public.is_super_admin() OR NOT public.app_has_perm('prescriptions.create') THEN
    RAISE EXCEPTION 'fixture no longer demonstrates the global Super Admin permission bypass';
  END IF;
  IF private.app_has_role_permission(ARRAY['doctor','legacy_gp','legacy_specialist','legacy_dentist'], 'prescriptions.create')
     OR private.app_has_role_permission(ARRAY['doctor','legacy_gp','legacy_specialist','legacy_dentist'], 'prescriptions.correction.resolve')
     OR private.app_has_role_permission(ARRAY['pharmacist','legacy_pharmacist'], 'pharmacy.correction.request') THEN
    RAISE EXCEPTION 'Super Admin unexpectedly satisfies an explicit clinical or pharmacy role permission';
  END IF;

  BEGIN
    PERFORM public.request_prescription_item_correction(
      '61800000-0000-0000-0000-000000000011',
      'Super Admin must not create a pharmacist correction request.'
    );
  EXCEPTION WHEN OTHERS THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Super Admin created a pharmacist correction request'; END IF;

  v_denied := false;
  BEGIN
    PERFORM * FROM public.resolve_prescription_item_correction(
      v_request_id,'reject',NULL,'Super Admin must not resolve a clinical correction.'
    );
  EXCEPTION WHEN OTHERS THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Super Admin resolved a clinical correction request'; END IF;

  v_denied := false;
  BEGIN
    PERFORM public.create_prescription_atomic(
      '61500000-0000-0000-0000-000000000002',
      false,
      '[{"medicine_id":"61600000-0000-0000-0000-000000000001","medication_name":"Amoxicillin 500 mg","quantity":1}]'::jsonb
    );
  EXCEPTION WHEN OTHERS THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Super Admin created a clinical prescription'; END IF;
END;
$phase61_super_admin_no_clinical$;
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


-- Dispensing is a pharmacist-only write operation even when Admin/Super Admin hold broad permissions.
DO $phase61b_dispense_acl$
BEGIN
  IF has_function_privilege('authenticated','private.fn_dispense_prescription_with_invoice_unchecked(uuid,boolean)','EXECUTE')
     OR has_function_privilege('service_role','private.fn_dispense_prescription_with_invoice_unchecked(uuid,boolean)','EXECUTE') THEN
    RAISE EXCEPTION 'unchecked pharmacy dispense RPC is directly executable';
  END IF;
  IF NOT has_function_privilege('authenticated','public.fn_dispense_prescription_with_invoice(uuid,boolean)','EXECUTE')
     OR has_function_privilege('anon','public.fn_dispense_prescription_with_invoice(uuid,boolean)','EXECUTE')
     OR has_function_privilege('service_role','public.fn_dispense_prescription_with_invoice(uuid,boolean)','EXECUTE') THEN
    RAISE EXCEPTION 'public pharmacy dispense wrapper grants are incorrect';
  END IF;
  IF has_function_privilege('authenticated','public.fn_dispense_prescription(uuid)','EXECUTE')
     OR has_function_privilege('authenticator','public.fn_dispense_prescription(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'legacy non-invoice dispense RPC remains executable';
  END IF;
END;
$phase61b_dispense_acl$;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000005',false);
DO $phase61b_admin_cannot_dispense$
DECLARE v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update') OR NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'admin fixture must have broad pharmacy and billing permissions';
  END IF;
  BEGIN
    PERFORM * FROM public.fn_dispense_prescription_with_invoice(
      'ffffffff-ffff-ffff-ffff-ffffffffffff',false
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Admin bypassed the pharmacist-only dispense role gate'; END IF;
END;
$phase61b_admin_cannot_dispense$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000006',false);
DO $phase61b_super_admin_cannot_dispense$
DECLARE v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update') OR NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'Super Admin fixture must demonstrate global permission bypass';
  END IF;
  BEGIN
    PERFORM * FROM public.fn_dispense_prescription_with_invoice(
      'ffffffff-ffff-ffff-ffff-ffffffffffff',false
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Super Admin bypassed the pharmacist-only dispense role gate'; END IF;
END;
$phase61b_super_admin_cannot_dispense$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61b_pharmacist_can_reach_dispense$
DECLARE v_expected boolean := false;
BEGIN
  BEGIN
    PERFORM * FROM public.fn_dispense_prescription_with_invoice(
      'ffffffff-ffff-ffff-ffff-ffffffffffff',false
    );
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'prescription_not_pending' THEN
      v_expected := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_expected THEN
    RAISE EXCEPTION 'pharmacist did not pass the role gate to the existing dispense workflow';
  END IF;
END;
$phase61b_pharmacist_can_reach_dispense$;
RESET ROLE;


-- The idempotent atomic RPC must reject non-pharmacists before payload validation or idempotency work.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000005',false);
DO $phase61c_admin_atomic_dispense_denied$
DECLARE v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update') OR NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'admin fixture must retain broad pharmacy and billing permission bits';
  END IF;
  BEGIN
    PERFORM * FROM public.atomic_pharmacy_dispense(
      NULL::uuid,false,'ffffffff-ffff-ffff-ffff-fffffffffff1'
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'Admin reached atomic pharmacy dispense without pharmacist role';
  END IF;
END;
$phase61c_admin_atomic_dispense_denied$;
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000006',false);
DO $phase61c_super_admin_atomic_dispense_denied$
DECLARE v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update') OR NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'Super Admin fixture must demonstrate global permission bypass';
  END IF;
  BEGIN
    PERFORM * FROM public.atomic_pharmacy_dispense(
      NULL::uuid,false,'ffffffff-ffff-ffff-ffff-fffffffffff2'
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'Super Admin reached atomic pharmacy dispense without pharmacist role';
  END IF;
END;
$phase61c_super_admin_atomic_dispense_denied$;
RESET ROLE;


-- A pharmacist role is not sufficient if either required permission bit is missing.
-- These temporary permission removals run only in the disposable PostgreSQL 17 fixture.
DELETE FROM public.role_permissions rp
USING public.roles r, public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.code = 'pharmacist'
  AND p.code = 'billing.create';

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61c_pharmacist_missing_billing_permission_denied$
DECLARE v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update') OR public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'fixture must isolate the missing billing.create permission';
  END IF;
  BEGIN
    PERFORM * FROM public.atomic_pharmacy_dispense(
      NULL::uuid,false,'ffffffff-ffff-ffff-ffff-fffffffffff5'
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'pharmacist reached atomic dispense without billing.create';
  END IF;
END;
$phase61c_pharmacist_missing_billing_permission_denied$;
RESET ROLE;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code = 'billing.create'
WHERE r.code = 'pharmacist'
ON CONFLICT DO NOTHING;

DELETE FROM public.role_permissions rp
USING public.roles r, public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.code = 'pharmacist'
  AND p.code = 'pharmacy.update';

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61c_pharmacist_missing_pharmacy_permission_denied$
DECLARE v_denied boolean := false;
BEGIN
  IF public.app_has_perm('pharmacy.update') OR NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'fixture must isolate the missing pharmacy.update permission';
  END IF;
  BEGIN
    PERFORM * FROM public.atomic_pharmacy_dispense(
      NULL::uuid,false,'ffffffff-ffff-ffff-ffff-fffffffffff6'
    );
  EXCEPTION WHEN SQLSTATE '42501' THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'pharmacist reached atomic dispense without pharmacy.update';
  END IF;
END;
$phase61c_pharmacist_missing_pharmacy_permission_denied$;
RESET ROLE;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code = 'pharmacy.update'
WHERE r.code = 'pharmacist'
ON CONFLICT DO NOTHING;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61c_pharmacist_reaches_atomic_validation$
DECLARE v_invalid boolean := false;
BEGIN
  BEGIN
    PERFORM * FROM public.atomic_pharmacy_dispense(
      NULL::uuid,false,'ffffffff-ffff-ffff-ffff-fffffffffff3'
    );
  EXCEPTION WHEN SQLSTATE '22023' THEN
    v_invalid := true;
  END;
  IF NOT v_invalid THEN
    RAISE EXCEPTION 'Pharmacist did not pass role gate to atomic dispense input validation';
  END IF;
END;
$phase61c_pharmacist_reaches_atomic_validation$;
RESET ROLE;

DO $phase61c_atomic_dispense_acl$
BEGIN
  IF has_function_privilege('anon','private.atomic_pharmacy_dispense_unchecked(uuid,boolean,uuid)','EXECUTE')
     OR has_function_privilege('authenticated','private.atomic_pharmacy_dispense_unchecked(uuid,boolean,uuid)','EXECUTE')
     OR has_function_privilege('service_role','private.atomic_pharmacy_dispense_unchecked(uuid,boolean,uuid)','EXECUTE')
     OR has_function_privilege('authenticator','private.atomic_pharmacy_dispense_unchecked(uuid,boolean,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'unchecked atomic pharmacy dispense RPC is directly executable by an API role';
  END IF;
  IF NOT has_function_privilege('authenticated','public.atomic_pharmacy_dispense(uuid,boolean,uuid)','EXECUTE')
     OR has_function_privilege('anon','public.atomic_pharmacy_dispense(uuid,boolean,uuid)','EXECUTE')
     OR has_function_privilege('service_role','public.atomic_pharmacy_dispense(uuid,boolean,uuid)','EXECUTE')
     OR has_function_privilege('authenticator','public.atomic_pharmacy_dispense(uuid,boolean,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'public atomic pharmacy dispense wrapper grants are incorrect';
  END IF;
END;
$phase61c_atomic_dispense_acl$;

-- SECURITY DEFINER boundaries must retain an empty search_path after the move/wrap.
DO $phase61c_security_definer_hardening$
DECLARE
  v_wrapper record;
  v_wrapper_source text;
  v_unchecked record;
  v_helper record;
BEGIN
  SELECT p.prosecdef, p.proconfig
    INTO v_wrapper
    FROM pg_proc p
   WHERE p.oid = to_regprocedure('public.atomic_pharmacy_dispense(uuid,boolean,uuid)');
  IF v_wrapper.prosecdef IS DISTINCT FROM true
     OR NOT (COALESCE(v_wrapper.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']) THEN
    RAISE EXCEPTION 'public atomic pharmacy dispense wrapper must be SECURITY DEFINER with empty search_path';
  END IF;

  SELECT p.prosrc INTO v_wrapper_source
    FROM pg_proc p
   WHERE p.oid = to_regprocedure('public.atomic_pharmacy_dispense(uuid,boolean,uuid)');
  IF v_wrapper_source IS NULL
     OR position('legacy_pharmacist' IN v_wrapper_source) > 0
     OR position('ARRAY[''pharmacist'']' IN v_wrapper_source) = 0 THEN
    RAISE EXCEPTION 'atomic dispense wrapper must allow only the canonical pharmacist role; legacy roles must fail closed';
  END IF;

  SELECT p.prosecdef, p.proconfig
    INTO v_unchecked
    FROM pg_proc p
   WHERE p.oid = to_regprocedure('private.atomic_pharmacy_dispense_unchecked(uuid,boolean,uuid)');
  IF v_unchecked.prosecdef IS DISTINCT FROM true
     OR NOT (COALESCE(v_unchecked.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']) THEN
    RAISE EXCEPTION 'private unchecked atomic pharmacy dispense must preserve SECURITY DEFINER with empty search_path';
  END IF;

  SELECT p.prosecdef, p.proconfig
    INTO v_helper
    FROM pg_proc p
   WHERE p.oid = to_regprocedure('private.app_has_role_permission(text[],text)');
  IF v_helper.prosecdef IS DISTINCT FROM true
     OR NOT (COALESCE(v_helper.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']) THEN
    RAISE EXCEPTION 'Phase 61B role helper must be SECURITY DEFINER with empty search_path';
  END IF;
END;
$phase61c_security_definer_hardening$;

-- Rejected Admin/Super Admin calls must stop before the idempotency ledger is touched.
DO $phase61c_rejected_admin_no_idempotency$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM private.pharmacy_dispense_idempotency
    WHERE request_id IN (
      'ffffffff-ffff-ffff-ffff-fffffffffff1'::uuid,
      'ffffffff-ffff-ffff-ffff-fffffffffff2'::uuid,
      'ffffffff-ffff-ffff-ffff-fffffffffff5'::uuid,
      'ffffffff-ffff-ffff-ffff-fffffffffff6'::uuid
    )
  ) THEN
    RAISE EXCEPTION 'a rejected non-pharmacist created an idempotency row';
  END IF;
END;
$phase61c_rejected_admin_no_idempotency$;

-- A canonical pharmacist must complete the active atomic wrapper, not merely reach validation.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
DO $phase61c_pharmacist_atomic_dispense_success$
DECLARE
  v_first jsonb;
  v_retry jsonb;
BEGIN
  SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) ORDER BY r.item_id,r.batch_id)
    INTO v_first
    FROM public.atomic_pharmacy_dispense(
      '61700000-0000-0000-0000-000000000013',
      false,
      'ffffffff-ffff-ffff-ffff-fffffffffff4'
    ) AS r;

  SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) ORDER BY r.item_id,r.batch_id)
    INTO v_retry
    FROM public.atomic_pharmacy_dispense(
      '61700000-0000-0000-0000-000000000013',
      false,
      'ffffffff-ffff-ffff-ffff-fffffffffff4'
    ) AS r;

  IF v_first IS NULL OR pg_catalog.jsonb_array_length(v_first) <> 1 THEN
    RAISE EXCEPTION 'canonical pharmacist could not complete one-item atomic dispense';
  END IF;
  IF v_first IS DISTINCT FROM v_retry THEN
    RAISE EXCEPTION 'idempotent retry changed the successful atomic dispense result';
  END IF;
  IF COALESCE((v_first->0->>'quantity_dispensed')::numeric, -1) <> 2 THEN
    RAISE EXCEPTION 'atomic dispense wrapper returned unexpected quantity: %',
      v_first->0->>'quantity_dispensed';
  END IF;
  IF v_first->0->>'batch_number' IS DISTINCT FROM 'PHASE61C-VALID' THEN
    RAISE EXCEPTION 'atomic dispense wrapper returned unexpected batch: %',
      v_first->0->>'batch_number';
  END IF;
END;
$phase61c_pharmacist_atomic_dispense_success$;
RESET ROLE;

DO $phase61c_pharmacist_atomic_dispense_effects$
BEGIN
  IF (SELECT quantity_remaining FROM public.pharmacy_inventory
      WHERE id='61900000-0000-0000-0000-000000000001') <> 8 THEN
    RAISE EXCEPTION 'successful atomic dispense did not decrement the selected batch exactly once';
  END IF;
  IF (SELECT count(*) FROM public.stock_movements
      WHERE reference_id='61700000-0000-0000-0000-000000000013'
        AND reference_table='prescriptions'
        AND movement_type='dispense') <> 1 THEN
    RAISE EXCEPTION 'successful atomic dispense did not create exactly one stock movement';
  END IF;
  IF (SELECT count(*) FROM public.invoice_items
      WHERE item_type='pharmacy'
        AND item_id='61600000-0000-0000-0000-000000000001'
        AND deleted_at IS NULL) <> 1 THEN
    RAISE EXCEPTION 'successful atomic dispense did not create exactly one pharmacy invoice line';
  END IF;
  IF (SELECT count(*) FROM private.pharmacy_dispense_idempotency
      WHERE request_id='ffffffff-ffff-ffff-ffff-fffffffffff4'
        AND result_payload IS NOT NULL) <> 1 THEN
    RAISE EXCEPTION 'successful atomic dispense did not persist one idempotency result';
  END IF;
END;
$phase61c_pharmacist_atomic_dispense_effects$;

