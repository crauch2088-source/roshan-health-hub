-- Disposable PostgreSQL 17 fixture only. Never run against Supabase.
DO $guard$
BEGIN
  IF current_database() <> 'roshan_quarantine' THEN RAISE EXCEPTION 'wrong_database_for_quarantine_fixture'; END IF;
  IF current_setting('server_version_num')::integer < 170000 OR current_setting('server_version_num')::integer >= 180000 THEN
    RAISE EXCEPTION 'postgresql_17_required';
  END IF;
END
$guard$;
CREATE SCHEMA private;
CREATE TABLE private.pharmacy_dispense_idempotency (
  request_id uuid PRIMARY KEY, actor_id uuid NOT NULL, request_payload jsonb NOT NULL
);
INSERT INTO private.pharmacy_dispense_idempotency VALUES (
 '10000000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000099',
 '{"fixture":"legacy-row-preservation"}'::jsonb
);
CREATE TABLE public.patients(id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz);
CREATE TABLE public.medicines(id uuid PRIMARY KEY, stock_quantity integer NOT NULL, updated_at timestamptz NOT NULL DEFAULT pg_catalog.now());
CREATE TABLE public.stock_movements(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, medicine_id uuid NOT NULL, batch_id uuid,
 movement_type text NOT NULL, quantity integer NOT NULL, reference_id uuid NOT NULL,
 reference_table text NOT NULL, notes text, branch_id uuid NOT NULL, created_by uuid,
 created_at timestamptz NOT NULL DEFAULT pg_catalog.now()
);
CREATE TABLE public.visits(id uuid PRIMARY KEY, patient_id uuid NOT NULL, deleted_at timestamptz);
CREATE TABLE public.prescriptions(id uuid PRIMARY KEY, patient_id uuid NOT NULL, visit_id uuid, deleted_at timestamptz);
CREATE TABLE public.prescription_items(id uuid PRIMARY KEY, prescription_id uuid NOT NULL, deleted_at timestamptz);
CREATE TABLE public.patient_notes(id uuid PRIMARY KEY, patient_id uuid NOT NULL, deleted_at timestamptz);
CREATE TABLE public.visit_annotations(id uuid PRIMARY KEY, visit_id uuid NOT NULL, deleted_at timestamptz);

INSERT INTO public.patients(id,branch_id) VALUES
 ('30000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
 ('30000000-0000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
 ('30000000-0000-4000-8000-000000000003','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
 ('30000000-0000-4000-8000-000000000004',NULL);
INSERT INTO public.medicines(id,stock_quantity) VALUES
 ('40000000-0000-4000-8000-000000000001',49),
 ('40000000-0000-4000-8000-000000000002',49),
 ('40000000-0000-4000-8000-000000000003',48),
 ('40000000-0000-4000-8000-000000000004',49);
INSERT INTO public.visits(id,patient_id) VALUES
 ('50000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001'),
 ('50000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002'),
 ('50000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000003'),
 ('50000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000004');
INSERT INTO public.prescriptions(id,patient_id,visit_id) VALUES
 ('60000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001'),
 ('60000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000002'),
 ('60000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000003','50000000-0000-4000-8000-000000000003'),
 ('60000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000004','50000000-0000-4000-8000-000000000004');
INSERT INTO public.prescription_items(id,prescription_id) VALUES
 ('70000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001'),
 ('70000000-0000-4000-8000-000000000002','60000000-0000-4000-8000-000000000002'),
 ('70000000-0000-4000-8000-000000000003','60000000-0000-4000-8000-000000000003'),
 ('70000000-0000-4000-8000-000000000004','60000000-0000-4000-8000-000000000004');
INSERT INTO public.patient_notes(id,patient_id,deleted_at) VALUES
 ('80000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001',NULL),
 ('80000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002',NULL),
 ('80000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000003',NULL),
 ('80000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000001','2026-11-01 00:00:00+00'),
 ('80000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000004',NULL);
INSERT INTO public.visit_annotations(id,visit_id) VALUES
 ('81000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001'),
 ('81000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000002'),
 ('81000000-0000-4000-8000-000000000003','50000000-0000-4000-8000-000000000003'),
 ('81000000-0000-4000-8000-000000000004','50000000-0000-4000-8000-000000000004');

-- Test-only parameterized equivalent. It adds an explicit same-branch guard;
-- it is not canonical migration SQL and does not execute the redacted artifact.
CREATE FUNCTION private.apply_synthetic_cleanup(p_patient_ids uuid[],p_medicine_id uuid,p_reference_id uuid)
RETURNS void LANGUAGE plpgsql SET search_path TO ''
AS $function$
DECLARE
 v_patient_count bigint; v_unique_count bigint; v_branch_count bigint; v_null_branch_count bigint; v_branch_text text;
 v_branch uuid; v_stock integer; v_has_reversal boolean; v_reversal_count bigint; v_reversal_branch_text text; r record; v_predicate text; v_sql text;
BEGIN
 IF p_patient_ids IS NULL OR pg_catalog.cardinality(p_patient_ids)=0 OR p_medicine_id IS NULL OR p_reference_id IS NULL THEN
  RAISE EXCEPTION 'invalid_synthetic_cleanup_arguments' USING ERRCODE='22023';
 END IF;
 SELECT pg_catalog.count(*),pg_catalog.count(DISTINCT branch_id),pg_catalog.min(branch_id::text),
  pg_catalog.count(*) FILTER (WHERE branch_id IS NULL)
 INTO v_patient_count,v_branch_count,v_branch_text,v_null_branch_count
 FROM public.patients WHERE id=ANY(p_patient_ids) AND deleted_at IS NULL;
 SELECT pg_catalog.count(DISTINCT patient_id) INTO v_unique_count
 FROM pg_catalog.unnest(p_patient_ids) AS input(patient_id);
 IF v_patient_count<>pg_catalog.cardinality(p_patient_ids)
    OR v_unique_count<>pg_catalog.cardinality(p_patient_ids)
    OR v_null_branch_count<>0 OR v_branch_count<>1 OR v_branch_text IS NULL THEN
  RAISE EXCEPTION 'cleanup_targets_cross_branch_or_missing' USING ERRCODE='42501';
 END IF;
 v_branch:=v_branch_text::uuid;
 SELECT m.stock_quantity INTO v_stock FROM public.medicines AS m WHERE m.id=p_medicine_id FOR UPDATE;
 IF NOT FOUND OR v_stock IS NULL THEN RAISE EXCEPTION 'synthetic_medicine_stock_not_found' USING ERRCODE='22023'; END IF;
 SELECT pg_catalog.count(*),pg_catalog.min(sm.branch_id::text)
 INTO v_reversal_count,v_reversal_branch_text
 FROM public.stock_movements sm
 WHERE sm.medicine_id=p_medicine_id AND sm.reference_id=p_reference_id
  AND sm.reference_table='prescriptions' AND sm.movement_type='adjustment'
  AND sm.quantity=1;
 IF v_reversal_count>1 THEN
  RAISE EXCEPTION 'synthetic_reversal_ledger_ambiguous' USING ERRCODE='23514';
 END IF;
 IF v_reversal_count=1 AND v_reversal_branch_text IS DISTINCT FROM v_branch::text THEN
  RAISE EXCEPTION 'synthetic_reversal_branch_mismatch' USING ERRCODE='42501';
 END IF;
 v_has_reversal := v_reversal_count=1;
 IF v_stock=49 AND NOT v_has_reversal THEN
  UPDATE public.medicines SET stock_quantity=50,updated_at=pg_catalog.now() WHERE id=p_medicine_id;
  INSERT INTO public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,notes,branch_id,created_by)
  VALUES(p_medicine_id,NULL,'adjustment',1,p_reference_id,'prescriptions',
   'Synthetic reversal fixture: restored one unledgered dispense.',v_branch,NULL);
 ELSIF v_stock=50 AND v_has_reversal THEN
  NULL;
 ELSE
  RAISE EXCEPTION 'unexpected_synthetic_stock_state' USING ERRCODE='22023';
 END IF;
 FOR r IN
  SELECT c.relname AS table_name,
   pg_catalog.bool_or(a.attname='patient_id') AS has_patient,
   pg_catalog.bool_or(a.attname='visit_id') AS has_visit,
   pg_catalog.bool_or(a.attname='prescription_id') AS has_prescription
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
  WHERE n.nspname='public' AND c.relkind IN ('r','p')
   AND a.attname IN ('deleted_at','patient_id','visit_id','prescription_id')
  GROUP BY c.relname
  HAVING pg_catalog.bool_or(a.attname='deleted_at')
   AND (pg_catalog.bool_or(a.attname='patient_id') OR pg_catalog.bool_or(a.attname='visit_id') OR pg_catalog.bool_or(a.attname='prescription_id'))
 LOOP
  v_predicate:='';
  IF r.has_patient THEN v_predicate:='patient_id = ANY ($1)'; END IF;
  IF r.has_visit THEN
   v_predicate:=v_predicate||CASE WHEN v_predicate<>'' THEN ' OR ' ELSE '' END||
    'visit_id IN (SELECT id FROM public.visits WHERE patient_id = ANY ($1))';
  END IF;
  IF r.has_prescription THEN
   v_predicate:=v_predicate||CASE WHEN v_predicate<>'' THEN ' OR ' ELSE '' END||
    'prescription_id IN (SELECT id FROM public.prescriptions WHERE patient_id = ANY ($1))';
  END IF;
  v_sql:=pg_catalog.format(
   'UPDATE public.%I SET deleted_at=COALESCE(deleted_at,pg_catalog.now()) WHERE (%s) AND deleted_at IS NULL',
   r.table_name,v_predicate
  );
  EXECUTE v_sql USING p_patient_ids;
 END LOOP;
END;
$function$;
