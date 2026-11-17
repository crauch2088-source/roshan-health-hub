-- Phase 61D: every advisor-reported correction-workflow FK has a valid single-column btree index.
DO $phase61d_fk_indexes$
DECLARE
  v_missing text[];
BEGIN
  WITH expected(index_name, relation_oid, column_name) AS (
    VALUES
      ('pirc_requests_replacement_prescription_id_idx', 'public.prescription_item_correction_requests'::regclass, 'replacement_prescription_id'),
      ('pirc_requests_corrected_item_id_idx', 'public.prescription_item_correction_requests'::regclass, 'corrected_item_id'),
      ('pirc_requests_patient_id_idx', 'public.prescription_item_correction_requests'::regclass, 'patient_id'),
      ('pirc_requests_requested_by_idx', 'public.prescription_item_correction_requests'::regclass, 'requested_by'),
      ('pirc_requests_resolved_by_idx', 'public.prescription_item_correction_requests'::regclass, 'resolved_by'),
      ('pirc_requests_visit_id_idx', 'public.prescription_item_correction_requests'::regclass, 'visit_id'),
      ('pirc_events_actor_id_idx', 'public.prescription_item_correction_events'::regclass, 'actor_id')
  )
  SELECT array_agg(e.index_name ORDER BY e.index_name)
    INTO v_missing
    FROM expected AS e
   WHERE NOT EXISTS (
     SELECT 1
       FROM pg_index AS i
       JOIN pg_class AS idx ON idx.oid = i.indexrelid
       JOIN pg_am AS am ON am.oid = idx.relam
       JOIN pg_attribute AS a
         ON a.attrelid = i.indrelid
        AND a.attnum = i.indkey[0]
      WHERE i.indrelid = e.relation_oid
        AND idx.relname = e.index_name
        AND am.amname = 'btree'
        AND i.indisvalid
        AND i.indisready
        AND NOT i.indisunique
        AND i.indpred IS NULL
        AND i.indnatts = 1
        AND i.indnkeyatts = 1
        AND a.attname = e.column_name
   );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Phase 61D correction FK indexes missing or invalid: %', array_to_string(v_missing, ', ');
  END IF;
END;
$phase61d_fk_indexes$;
