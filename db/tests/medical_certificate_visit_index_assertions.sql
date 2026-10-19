-- Run after db/roshan_phase32_medical_certificate_visit_index.sql on disposable PostgreSQL 17.
DO $test$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index AS i
    WHERE i.indexrelid = to_regclass('public.medical_certificates_visit_id_idx')
      AND i.indrelid = to_regclass('public.medical_certificates')
      AND i.indisvalid
      AND i.indisready
      AND NOT i.indisunique
      AND pg_catalog.pg_get_indexdef(i.indexrelid) ILIKE '%(visit_id)%'
  ) THEN
    RAISE EXCEPTION 'medical_certificates visit_id index missing, invalid, or attached to wrong table';
  END IF;
END
$test$;
