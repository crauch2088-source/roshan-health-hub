-- Assertions for the disposable PostgreSQL 17 fixture only.
DO $rename_assertions$
DECLARE v_payload jsonb; v_rows bigint;
BEGIN
 IF current_database()<>'roshan_quarantine' THEN RAISE EXCEPTION 'wrong_database_for_quarantine_assertions'; END IF;
 IF pg_catalog.to_regclass('private.pharmacy_dispense_idempotency') IS NOT NULL THEN RAISE EXCEPTION 'old_relation_name_still_exists'; END IF;
 IF pg_catalog.to_regclass('private.pharmacy_dispense_idempotency_legacy_20261103') IS NULL THEN RAISE EXCEPTION 'legacy_relation_not_renamed'; END IF;
 IF pg_catalog.to_regclass('private.pharmacy_dispense_idempotency_legacy_20261103_pkey') IS NULL THEN RAISE EXCEPTION 'legacy_pk_index_not_renamed'; END IF;
 SELECT pg_catalog.count(*) INTO v_rows FROM private.pharmacy_dispense_idempotency_legacy_20261103;
 SELECT request_payload INTO v_payload FROM private.pharmacy_dispense_idempotency_legacy_20261103;
 IF v_rows<>1 OR v_payload<>'{"fixture":"legacy-row-preservation"}'::jsonb THEN RAISE EXCEPTION 'legacy_data_not_preserved'; END IF;
END
$rename_assertions$;

CREATE TABLE private.pharmacy_dispense_idempotency(
 request_id uuid PRIMARY KEY,actor_id uuid NOT NULL,prescription_id uuid NOT NULL,
 request_payload jsonb NOT NULL,result_payload jsonb,
 created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),completed_at timestamptz
);
DO $replacement_assertions$
BEGIN
 IF pg_catalog.to_regclass('private.pharmacy_dispense_idempotency_pkey') IS NULL
  OR pg_catalog.to_regclass('private.pharmacy_dispense_idempotency_legacy_20261103_pkey') IS NULL THEN
  RAISE EXCEPTION 'replacement_and_legacy_primary_keys_must_coexist';
 END IF;
END
$replacement_assertions$;

-- Full transaction rollback restores stock, ledger and soft-delete state.
BEGIN;
SELECT private.apply_synthetic_cleanup(
 ARRAY['30000000-0000-4000-8000-000000000001'::uuid,'30000000-0000-4000-8000-000000000002'::uuid],
 '40000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001');
DO $inside_rollback$
BEGIN
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000001')<>50 THEN RAISE EXCEPTION 'stock_change_not_visible'; END IF;
 IF (SELECT count(*) FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000001')<>1 THEN RAISE EXCEPTION 'reversal_not_visible'; END IF;
 IF (SELECT count(*) FROM public.prescription_items WHERE deleted_at IS NOT NULL)<>2 THEN RAISE EXCEPTION 'soft_deletes_not_visible'; END IF;
END
$inside_rollback$;
ROLLBACK;
DO $rollback_assertions$
BEGIN
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000001')<>49 THEN RAISE EXCEPTION 'stock_not_rolled_back'; END IF;
 IF EXISTS(SELECT 1 FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'ledger_row_survived_rollback'; END IF;
 IF EXISTS(SELECT 1 FROM public.visits WHERE deleted_at IS NOT NULL)
  OR EXISTS(SELECT 1 FROM public.prescriptions WHERE deleted_at IS NOT NULL)
  OR EXISTS(SELECT 1 FROM public.prescription_items WHERE deleted_at IS NOT NULL)
  OR EXISTS(SELECT 1 FROM public.patient_notes WHERE id IN ('80000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000002') AND deleted_at IS NOT NULL)
  OR EXISTS(SELECT 1 FROM public.visit_annotations WHERE deleted_at IS NOT NULL) THEN
  RAISE EXCEPTION 'soft_delete_survived_rollback';
 END IF;
END
$rollback_assertions$;

-- First call reverses; second call must be a no-op.
SELECT private.apply_synthetic_cleanup(
 ARRAY['30000000-0000-4000-8000-000000000001'::uuid,'30000000-0000-4000-8000-000000000002'::uuid],
 '40000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001');
SELECT private.apply_synthetic_cleanup(
 ARRAY['30000000-0000-4000-8000-000000000001'::uuid,'30000000-0000-4000-8000-000000000002'::uuid],
 '40000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001');

DO $idempotency_assertions$
DECLARE v_preserved timestamptz;
BEGIN
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000001')<>50 THEN RAISE EXCEPTION 'stock_should_equal_50'; END IF;
 IF (SELECT count(*) FROM public.stock_movements WHERE medicine_id='40000000-0000-4000-8000-000000000001'
  AND reference_id='90000000-0000-4000-8000-000000000001' AND movement_type='adjustment' AND quantity=1
  AND branch_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')<>1 THEN RAISE EXCEPTION 'duplicate_or_wrong_branch_reversal'; END IF;
 IF (SELECT count(*) FROM public.visits WHERE deleted_at IS NOT NULL)<>2
  OR (SELECT count(*) FROM public.prescriptions WHERE deleted_at IS NOT NULL)<>2
  OR (SELECT count(*) FROM public.prescription_items WHERE deleted_at IS NOT NULL)<>2
  OR (SELECT count(*) FROM public.patient_notes WHERE id IN ('80000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000002') AND deleted_at IS NOT NULL)<>2
  OR (SELECT count(*) FROM public.visit_annotations WHERE deleted_at IS NOT NULL)<>2 THEN
  RAISE EXCEPTION 'linked_rows_not_soft_deleted';
 END IF;
 IF (SELECT count(*) FROM public.visits)<>4 OR (SELECT count(*) FROM public.prescriptions)<>4
  OR (SELECT count(*) FROM public.prescription_items)<>4 OR (SELECT count(*) FROM public.patient_notes)<>5
  OR (SELECT count(*) FROM public.visit_annotations)<>4 THEN
  RAISE EXCEPTION 'permanent_delete_detected';
 END IF;
 SELECT deleted_at INTO v_preserved FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000004';
 IF v_preserved IS DISTINCT FROM '2026-11-01 00:00:00+00'::timestamptz THEN RAISE EXCEPTION 'existing_deleted_at_changed'; END IF;
END
$idempotency_assertions$;

DO $cross_branch_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000001'::uuid,'30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000002');
  RAISE EXCEPTION 'expected_cross_branch_rejection';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000002')<>49
  OR EXISTS(SELECT 1 FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000002')
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000003') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'cross_branch_rejection_left_side_effects';
 END IF;
END
$cross_branch_assertions$;

DO $null_branch_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000001'::uuid,'30000000-0000-4000-8000-000000000004'::uuid],
   '40000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000004');
  RAISE EXCEPTION 'expected_null_branch_rejection';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000004')<>49
  OR EXISTS(SELECT 1 FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000004')
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000005') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000004') IS NOT NULL THEN
  RAISE EXCEPTION 'null_branch_rejection_left_side_effects';
 END IF;
END
$null_branch_assertions$;

DO $unexpected_stock_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000003');
  RAISE EXCEPTION 'expected_unexpected_stock_rejection';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000003')<>48
  OR EXISTS(SELECT 1 FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000003')
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000003') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'unexpected_stock_rejection_left_side_effects';
 END IF;
END
$unexpected_stock_assertions$;

DO $invalid_target_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(NULL::uuid[],'40000000-0000-4000-8000-000000000004'::uuid,'90000000-0000-4000-8000-000000000005'::uuid);
  RAISE EXCEPTION 'expected_null_patient_array_rejection';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 BEGIN
  PERFORM private.apply_synthetic_cleanup(ARRAY[]::uuid[],'40000000-0000-4000-8000-000000000004'::uuid,'90000000-0000-4000-8000-000000000005'::uuid);
  RAISE EXCEPTION 'expected_empty_patient_array_rejection';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid,'30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000005');
  RAISE EXCEPTION 'expected_duplicate_patient_rejection';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid,'30000000-0000-4000-8000-000000000099'::uuid],
   '40000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000005');
  RAISE EXCEPTION 'expected_missing_patient_rejection';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid],
   NULL::uuid,'90000000-0000-4000-8000-000000000005'::uuid);
  RAISE EXCEPTION 'expected_null_medicine_rejection';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000004',NULL::uuid);
  RAISE EXCEPTION 'expected_null_reference_rejection';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000004')<>49
  OR EXISTS(SELECT 1 FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000005')
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000003') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'invalid_target_rejection_left_side_effects';
 END IF;
END
$invalid_target_assertions$;

-- An existing matching reversal in another branch must fail closed, not be treated as absent.
INSERT INTO public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,notes,branch_id,created_by)
VALUES('40000000-0000-4000-8000-000000000004',NULL,'adjustment',1,
 '90000000-0000-4000-8000-000000000005','prescriptions','wrong-branch synthetic reversal',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',NULL);
DO $wrong_branch_reversal_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000005');
  RAISE EXCEPTION 'expected_wrong_branch_reversal_rejection';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000004')<>49
  OR (SELECT count(*) FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000005')<>1
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000003') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'wrong_branch_reversal_rejection_left_side_effects';
 END IF;
END
$wrong_branch_reversal_assertions$;

-- Duplicate matching adjustment rows are ambiguous and must not be accepted as idempotent.
INSERT INTO public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,notes,branch_id,created_by)
VALUES
 ('40000000-0000-4000-8000-000000000004',NULL,'adjustment',1,'90000000-0000-4000-8000-000000000006','prescriptions','duplicate synthetic reversal A','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',NULL),
 ('40000000-0000-4000-8000-000000000004',NULL,'adjustment',1,'90000000-0000-4000-8000-000000000006','prescriptions','duplicate synthetic reversal B','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',NULL);
DO $duplicate_reversal_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000006');
  RAISE EXCEPTION 'expected_duplicate_reversal_rejection';
 EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000004')<>49
  OR (SELECT count(*) FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000006')<>2
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000003') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'duplicate_reversal_rejection_left_side_effects';
 END IF;
END
$duplicate_reversal_assertions$;

-- A single same-branch reversal with stock still at 49 is inconsistent, not a replayable success.
INSERT INTO public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,notes,branch_id,created_by)
VALUES('40000000-0000-4000-8000-000000000004',NULL,'adjustment',1,
 '90000000-0000-4000-8000-000000000008','prescriptions','same-branch synthetic reversal',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',NULL);
DO $stock_ledger_mismatch_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000008');
  RAISE EXCEPTION 'expected_stock_ledger_mismatch_rejection';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000004')<>49
  OR (SELECT count(*) FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000008')<>1
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000003') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'stock_ledger_mismatch_rejection_left_side_effects';
 END IF;
END
$stock_ledger_mismatch_assertions$;

-- Stock already restored without its matching reversal is also an inconsistent state.
UPDATE public.medicines SET stock_quantity=50 WHERE id='40000000-0000-4000-8000-000000000002';
DO $restored_stock_without_ledger_assertions$
BEGIN
 BEGIN
  PERFORM private.apply_synthetic_cleanup(
   ARRAY['30000000-0000-4000-8000-000000000003'::uuid],
   '40000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000007');
  RAISE EXCEPTION 'expected_restored_stock_without_ledger_rejection';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 IF (SELECT stock_quantity FROM public.medicines WHERE id='40000000-0000-4000-8000-000000000002')<>50
  OR EXISTS(SELECT 1 FROM public.stock_movements WHERE reference_id='90000000-0000-4000-8000-000000000007')
  OR (SELECT deleted_at FROM public.patient_notes WHERE id='80000000-0000-4000-8000-000000000003') IS NOT NULL
  OR (SELECT deleted_at FROM public.visit_annotations WHERE id='81000000-0000-4000-8000-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'restored_stock_without_ledger_rejection_left_side_effects';
 END IF;
END
$restored_stock_without_ledger_assertions$;

DO $final_assertions$
BEGIN
 IF (SELECT count(*) FROM public.patients)<>4 OR (SELECT count(*) FROM public.visits)<>4
  OR (SELECT count(*) FROM public.prescriptions)<>4 OR (SELECT count(*) FROM public.prescription_items)<>4
  OR (SELECT count(*) FROM public.patient_notes)<>5 OR (SELECT count(*) FROM public.visit_annotations)<>4 THEN
  RAISE EXCEPTION 'permanent_delete_detected'; END IF;
 RAISE NOTICE 'PASS: quarantined rename, synthetic idempotency, branch attribution, rollback and soft-delete';
END
$final_assertions$;
