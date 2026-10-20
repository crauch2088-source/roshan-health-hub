-- Isolated PostgreSQL 17 integration assertions for Phase 33; all synthetic rows roll back.
BEGIN;
SET LOCAL ROLE service_role;
INSERT INTO public.branches(id,branch_code,branch_name) VALUES ('00000000-0000-0000-0000-000000003301','CI-P33-A','Phase 33 A'),('00000000-0000-0000-0000-000000003302','CI-P33-B','Phase 33 B');
INSERT INTO public.roles(id,name,code) VALUES ('00000000-0000-0000-0000-000000003311','Phase 33 lab reader','phase33_lab_reader'),('00000000-0000-0000-0000-000000003312','Phase 33 no access','phase33_no_access') ON CONFLICT DO NOTHING;
INSERT INTO public.permissions(id,code,name) VALUES ('00000000-0000-0000-0000-000000003321','lab.read','Lab read'),('00000000-0000-0000-0000-000000003322','queue.read','Queue read'),('00000000-0000-0000-0000-000000003323','certificates.read','Certificates read'),('00000000-0000-0000-0000-000000003324','emr.read','EMR read'),('00000000-0000-0000-0000-000000003325','lab.verify','Lab verify'),('00000000-0000-0000-0000-000000003326','lab.update','Lab update'),('00000000-0000-0000-0000-000000003327','visits.read','Visit read') ON CONFLICT DO NOTHING;
INSERT INTO public.role_permissions(role_id,permission_id) VALUES ('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003321'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003322'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003323'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003324'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003325'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003326'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003327') ON CONFLICT DO NOTHING;
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-000000003341'),('00000000-0000-0000-0000-000000003342') ON CONFLICT DO NOTHING;
INSERT INTO public.users(id,auth_user_id,active,deleted_at,branch_id,role_id,full_name) VALUES ('00000000-0000-0000-0000-000000003331','00000000-0000-0000-0000-000000003341',true,NULL,'00000000-0000-0000-0000-000000003301','00000000-0000-0000-0000-000000003311','Phase 33 User A'),('00000000-0000-0000-0000-000000003332','00000000-0000-0000-0000-000000003342',true,NULL,'00000000-0000-0000-0000-000000003302','00000000-0000-0000-0000-000000003312','Phase 33 User B');
INSERT INTO storage.objects(id,bucket_id,name) VALUES ('00000000-0000-0000-0000-000000003351','roshan-lab-reports','00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003361/own.pdf'),('00000000-0000-0000-0000-000000003352','roshan-lab-reports','00000000-0000-0000-0000-000000003302/lab-reports/00000000-0000-0000-0000-000000003362/other.pdf'),('00000000-0000-0000-0000-000000003353','roshan-medical-certificates','00000000-0000-0000-0000-000000003301/medical-certificates/00000000-0000-0000-0000-000000003363/own.pdf'),('00000000-0000-0000-0000-000000003354','roshan-clinical-attachments','00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003364/own.pdf');

INSERT INTO public.patients(id,branch_id,mrn,full_name,gender) VALUES ('00000000-0000-0000-0000-000000003365','00000000-0000-0000-0000-000000003301','CI-P34-001','Phase 34 Synthetic Patient','unknown');
INSERT INTO public.lab_tests(id,name,active,is_active) VALUES ('00000000-0000-0000-0000-000000003366','Phase 34 Synthetic Test',true,true);
INSERT INTO public.lab_parameters(id,test_id,name,data_type,active,is_active) VALUES ('00000000-0000-0000-0000-000000003367','00000000-0000-0000-0000-000000003366','Phase 34 Value','numeric',true,true);
INSERT INTO public.lab_orders(id,patient_id,branch_id,status) VALUES ('00000000-0000-0000-0000-000000003368','00000000-0000-0000-0000-000000003365','00000000-0000-0000-0000-000000003301','completed');
INSERT INTO public.lab_order_items(id,order_id,test_id,status) VALUES ('00000000-0000-0000-0000-000000003369','00000000-0000-0000-0000-000000003368','00000000-0000-0000-0000-000000003366','completed');
INSERT INTO public.lab_results(id,order_item_id,parameter_id,result_value,numeric_value) VALUES ('00000000-0000-0000-0000-000000003370','00000000-0000-0000-0000-000000003369','00000000-0000-0000-0000-000000003367','5',5);
INSERT INTO public.audit_logs(id,table_name,record_id,action) VALUES ('00000000-0000-0000-0000-000000003371','phase34_ci','00000000-0000-0000-0000-000000003368','TEST');

RESET ROLE;
DO $catalog$ DECLARE n integer; BEGIN
SELECT count(*) INTO n FROM pg_catalog.pg_policies WHERE (schemaname='storage' AND tablename='objects' AND policyname LIKE 'phase33_%') OR (schemaname='realtime' AND tablename='messages' AND policyname LIKE 'phase33_clinical_realtime_%');
IF n<>18 THEN RAISE EXCEPTION 'expected 18 Phase 33 policies, got %',n; END IF;
IF EXISTS(SELECT 1 FROM storage.buckets WHERE id IN ('roshan-lab-reports','roshan-medical-certificates','roshan-clinical-attachments') AND public IS DISTINCT FROM false) THEN RAISE EXCEPTION 'clinical bucket unexpectedly public'; END IF;
IF has_table_privilege('authenticated','public.audit_logs','UPDATE') OR has_table_privilege('authenticated','public.audit_logs','DELETE') OR has_table_privilege('authenticated','public.audit_logs','TRUNCATE') OR has_table_privilege('anon','public.audit_logs','UPDATE') OR has_table_privilege('anon','public.audit_logs','DELETE') OR has_table_privilege('anon','public.audit_logs','TRUNCATE') THEN RAISE EXCEPTION 'anon/authenticated retains audit mutation privileges'; END IF;
END $catalog$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000003341',true);
SELECT set_config('realtime.topic','branch:00000000-0000-0000-0000-000000003301:queue',true);
DO $branch_a$ DECLARE n integer; BEGIN
SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='roshan-lab-reports'; IF n<>1 THEN RAISE EXCEPTION 'cross-branch storage object leaked: expected one report, got %',n; END IF;
SELECT count(*) INTO n FROM storage.objects WHERE name='00000000-0000-0000-0000-000000003302/lab-reports/00000000-0000-0000-0000-000000003362/other.pdf'; IF n<>0 THEN RAISE EXCEPTION 'cross-branch storage object leaked: branch B file visible'; END IF;
IF NOT public.app_has_perm('queue.read') OR NOT private.app_has_branch_access('00000000-0000-0000-0000-000000003301'::uuid) THEN RAISE EXCEPTION 'branch A should be authorized for queue topic'; END IF;
IF NOT private.phase33_realtime_topic_access('branch:00000000-0000-0000-0000-000000003301:queue') OR NOT private.phase33_realtime_topic_access('branch:00000000-0000-0000-0000-000000003301:visits') THEN RAISE EXCEPTION 'same-branch queue/visit topics should be authorized'; END IF;
IF private.phase33_realtime_topic_access('branch:00000000-0000-0000-0000-000000003302:lab') THEN RAISE EXCEPTION 'cross-branch lab topic unexpectedly authorized'; END IF;
IF private.app_has_branch_access('00000000-0000-0000-0000-000000003302'::uuid) THEN RAISE EXCEPTION 'branch A unexpectedly has branch B access'; END IF;
IF (SELECT public FROM storage.buckets WHERE id='roshan-lab-reports') THEN RAISE EXCEPTION 'lab reports bucket must remain private'; END IF;
END $branch_a$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000003341',true);
DO $direct_verify_block$ BEGIN BEGIN UPDATE public.lab_orders SET status='verified' WHERE id='00000000-0000-0000-0000-000000003368'; IF FOUND THEN RAISE EXCEPTION 'direct verification unexpectedly changed a lab order'; END IF; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $direct_verify_block$;
SELECT public.verify_lab_order('00000000-0000-0000-0000-000000003368');
DO $verified_state$ DECLARE v_status text; v_by uuid; v_at timestamptz; v_item_status text; v_result_by uuid; BEGIN
SELECT status,verified_by,verified_at INTO v_status,v_by,v_at FROM public.lab_orders WHERE id='00000000-0000-0000-0000-000000003368';
IF v_status <> 'verified' OR v_by <> '00000000-0000-0000-0000-000000003331'::uuid OR v_at IS NULL THEN RAISE EXCEPTION 'verify_lab_order did not atomically mark the order'; END IF;
SELECT status INTO v_item_status FROM public.lab_order_items WHERE id='00000000-0000-0000-0000-000000003369'; IF v_item_status <> 'verified' THEN RAISE EXCEPTION 'lab item not verified atomically'; END IF;
SELECT verified_by INTO v_result_by FROM public.lab_results WHERE id='00000000-0000-0000-0000-000000003370'; IF v_result_by <> '00000000-0000-0000-0000-000000003331'::uuid THEN RAISE EXCEPTION 'lab result verifier not recorded'; END IF;
BEGIN UPDATE public.lab_results SET result_value='999' WHERE id='00000000-0000-0000-0000-000000003370'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; IF (SELECT result_value FROM public.lab_results WHERE id='00000000-0000-0000-0000-000000003370') <> '5' THEN RAISE EXCEPTION 'verified result was modified directly'; END IF;
BEGIN UPDATE public.lab_order_items SET status='completed' WHERE id='00000000-0000-0000-0000-000000003369'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; IF (SELECT status FROM public.lab_order_items WHERE id='00000000-0000-0000-0000-000000003369') <> 'verified' THEN RAISE EXCEPTION 'verified lab item was modified directly'; END IF;
END $verified_state$;
RESET ROLE;
DO $audit_immutable$ DECLARE v_blocked boolean; BEGIN
v_blocked := false; BEGIN UPDATE public.audit_logs SET action='MUTATED' WHERE id='00000000-0000-0000-0000-000000003371'; EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END; IF NOT v_blocked THEN RAISE EXCEPTION 'audit log UPDATE was not blocked by append-only trigger'; END IF;
v_blocked := false; BEGIN DELETE FROM public.audit_logs WHERE id='00000000-0000-0000-0000-000000003371'; EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END; IF NOT v_blocked THEN RAISE EXCEPTION 'audit log DELETE was not blocked by append-only trigger'; END IF;
  v_blocked := false;
  BEGIN EXECUTE 'TRUNCATE TABLE public.audit_logs'; EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'audit log TRUNCATE was not blocked by append-only trigger'; END IF;
IF NOT EXISTS (SELECT 1 FROM public.audit_logs WHERE id='00000000-0000-0000-0000-000000003371' AND action='TEST') THEN RAISE EXCEPTION 'audit row changed or disappeared'; END IF;
END $audit_immutable$;

ROLLBACK;
