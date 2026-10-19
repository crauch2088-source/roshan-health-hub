-- Isolated PostgreSQL 17 integration assertions for Phase 33; all synthetic rows roll back.
BEGIN;
SET LOCAL ROLE service_role;
INSERT INTO public.branches(id,branch_code,branch_name) VALUES ('00000000-0000-0000-0000-000000003301','CI-P33-A','Phase 33 A'),('00000000-0000-0000-0000-000000003302','CI-P33-B','Phase 33 B');
INSERT INTO public.roles(id,name,code) VALUES ('00000000-0000-0000-0000-000000003311','Phase 33 lab reader','phase33_lab_reader'),('00000000-0000-0000-0000-000000003312','Phase 33 no access','phase33_no_access') ON CONFLICT DO NOTHING;
INSERT INTO public.permissions(id,code,name) VALUES ('00000000-0000-0000-0000-000000003321','lab.read','Lab read'),('00000000-0000-0000-0000-000000003322','queue.read','Queue read'),('00000000-0000-0000-0000-000000003323','certificates.read','Certificates read'),('00000000-0000-0000-0000-000000003324','emr.read','EMR read') ON CONFLICT DO NOTHING;
INSERT INTO public.role_permissions(role_id,permission_id) VALUES ('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003321'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003322'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003323'),('00000000-0000-0000-0000-000000003311','00000000-0000-0000-0000-000000003324') ON CONFLICT DO NOTHING;
INSERT INTO public.users(id,auth_user_id,active,deleted_at,branch_id,role_id,full_name) VALUES ('00000000-0000-0000-0000-000000003331','00000000-0000-0000-0000-000000003341',true,NULL,'00000000-0000-0000-0000-000000003301','00000000-0000-0000-0000-000000003311','Phase 33 User A'),('00000000-0000-0000-0000-000000003332','00000000-0000-0000-0000-000000003342',true,NULL,'00000000-0000-0000-0000-000000003302','00000000-0000-0000-0000-000000003312','Phase 33 User B');
INSERT INTO storage.objects(id,bucket_id,name) VALUES ('00000000-0000-0000-0000-000000003351','roshan-lab-reports','00000000-0000-0000-0000-000000003301/lab/own.pdf'),('00000000-0000-0000-0000-000000003352','roshan-lab-reports','00000000-0000-0000-0000-000000003302/lab/other.pdf'),('00000000-0000-0000-0000-000000003353','roshan-medical-certificates','00000000-0000-0000-0000-000000003301/cert/own.pdf'),('00000000-0000-0000-0000-000000003354','roshan-clinical-attachments','00000000-0000-0000-0000-000000003301/visit/own.pdf');
RESET ROLE;
DO $catalog$ DECLARE n integer; BEGIN
SELECT count(*) INTO n FROM pg_catalog.pg_policies WHERE (schemaname='storage' AND tablename='objects' AND policyname LIKE 'phase33_%') OR (schemaname='realtime' AND tablename='messages' AND policyname='phase33_clinical_realtime_select');
IF n<>13 THEN RAISE EXCEPTION 'expected 13 Phase 33 policies, got %',n; END IF;
IF EXISTS(SELECT 1 FROM storage.buckets WHERE id IN ('roshan-lab-reports','roshan-medical-certificates','roshan-clinical-attachments') AND public IS DISTINCT FROM false) THEN RAISE EXCEPTION 'clinical bucket unexpectedly public'; END IF;
END $catalog$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000003341',true);
SELECT set_config('realtime.topic','branch:00000000-0000-0000-0000-000000003301:queue',true);
DO $branch_a$ DECLARE n integer; BEGIN
SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='roshan-lab-reports'; IF n<>1 THEN RAISE EXCEPTION 'cross-branch storage object leaked: expected one report, got %',n; END IF;
SELECT count(*) INTO n FROM storage.objects WHERE name='00000000-0000-0000-0000-000000003302/lab/other.pdf'; IF n<>0 THEN RAISE EXCEPTION 'cross-branch storage object leaked: branch B file visible'; END IF;
IF NOT public.app_has_perm('queue.read') OR NOT private.app_has_branch_access('00000000-0000-0000-0000-000000003301'::uuid) THEN RAISE EXCEPTION 'branch A should be authorized for queue topic'; END IF;
IF private.app_has_branch_access('00000000-0000-0000-0000-000000003302'::uuid) THEN RAISE EXCEPTION 'branch A unexpectedly has branch B access'; END IF;
IF (SELECT public FROM storage.buckets WHERE id='roshan-lab-reports') THEN RAISE EXCEPTION 'lab reports bucket must remain private'; END IF;
END $branch_a$;
RESET ROLE;
ROLLBACK;
