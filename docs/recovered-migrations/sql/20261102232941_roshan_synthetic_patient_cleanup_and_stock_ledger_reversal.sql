-- QUARANTINED RECOVERY ARTIFACT — NOT EXECUTABLE.
-- Recovered from production ledger version 20261102232941.
-- Original ledger statement SHA-256: e826d4947a497e61fcdde5b87ae4e1a8789523fa2979db048f6960b119e04c75
-- Original statement size: 3285 bytes; 9 UUID occurrences across 4 distinct literals were redacted.
-- Placeholders are intentionally invalid UUIDs. This file is not byte-identical and MUST NOT be replayed.
-- No patient or financial rows were read to prepare this public, redacted artifact.

DO $remediate$
DECLARE
  v_branch uuid;
  v_stock integer;
  v_has_reversal boolean;
  r record;
  v_predicate text;
  v_sql text;
BEGIN
  SELECT p.branch_id INTO v_branch FROM public.patients p
   WHERE p.id='[REDACTED_SYNTHETIC_UUID_01]'::uuid;
  IF v_branch IS NULL THEN RAISE EXCEPTION 'Expected synthetic patient/branch not found'; END IF;

  SELECT m.stock_quantity INTO v_stock FROM public.medicines m
   WHERE m.id='[REDACTED_SYNTHETIC_UUID_02]'::uuid FOR UPDATE;
  IF v_stock IS NULL THEN RAISE EXCEPTION 'Expected medicine stock row not found'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.stock_movements sm
     WHERE sm.medicine_id='[REDACTED_SYNTHETIC_UUID_02]'::uuid
       AND sm.reference_id='[REDACTED_SYNTHETIC_UUID_03]'::uuid
       AND sm.reference_table='prescriptions'
       AND sm.movement_type='adjustment' AND sm.quantity=1
  ) INTO v_has_reversal;

  IF v_stock=49 AND NOT v_has_reversal THEN
    UPDATE public.medicines SET stock_quantity=50,updated_at=pg_catalog.now()
     WHERE id='[REDACTED_SYNTHETIC_UUID_02]'::uuid;
    INSERT INTO public.stock_movements
      (medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,notes,branch_id,created_by)
    VALUES
      ('[REDACTED_SYNTHETIC_UUID_02]'::uuid,NULL,'adjustment',1,
       '[REDACTED_SYNTHETIC_UUID_03]'::uuid,'prescriptions',
       'Reversal of unledgered synthetic dispense; restored from audited 50-to-49 decrement.',
       v_branch,NULL);
  ELSIF v_stock=50 AND v_has_reversal THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'Unexpected stock state (stock %, reversal %); refusing inferred correction',v_stock,v_has_reversal;
  END IF;

  FOR r IN
    SELECT c.relname AS table_name,
      bool_or(a.attname='patient_id') AS has_patient,
      bool_or(a.attname='visit_id') AS has_visit,
      bool_or(a.attname='prescription_id') AS has_prescription
    FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
    WHERE n.nspname='public' AND c.relkind IN ('r','p')
      AND a.attname IN ('deleted_at','patient_id','visit_id','prescription_id')
    GROUP BY c.relname
    HAVING bool_or(a.attname='deleted_at')
       AND (bool_or(a.attname='patient_id') OR bool_or(a.attname='visit_id') OR bool_or(a.attname='prescription_id'))
  LOOP
    v_predicate := '';
    IF r.has_patient THEN v_predicate := 'patient_id = ANY ($1)'; END IF;
    IF r.has_visit THEN
      v_predicate := v_predicate || CASE WHEN v_predicate<>'' THEN ' OR ' ELSE '' END ||
        'visit_id IN (SELECT id FROM public.visits WHERE patient_id = ANY ($1))';
    END IF;
    IF r.has_prescription THEN
      v_predicate := v_predicate || CASE WHEN v_predicate<>'' THEN ' OR ' ELSE '' END ||
        'prescription_id IN (SELECT id FROM public.prescriptions WHERE patient_id = ANY ($1))';
    END IF;
    v_sql := pg_catalog.format(
      'UPDATE public.%I SET deleted_at=COALESCE(deleted_at,pg_catalog.now()) WHERE (%s) AND deleted_at IS NULL',
      r.table_name,v_predicate
    );
    EXECUTE v_sql USING ARRAY[
      '[REDACTED_SYNTHETIC_UUID_04]'::uuid,
      '[REDACTED_SYNTHETIC_UUID_01]'::uuid
    ];
  END LOOP;
END
$remediate$;
