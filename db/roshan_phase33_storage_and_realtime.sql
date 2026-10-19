-- Phase 33 candidate: private clinical Storage buckets and branch-scoped Realtime. Staged only; do not apply to production.
-- Object paths must begin with branch UUID: <branch UUID>/<resource>/<filename>.
BEGIN;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES
('roshan-lab-reports','roshan-lab-reports',false,10485760,ARRAY['application/pdf']::text[]),
('roshan-medical-certificates','roshan-medical-certificates',false,10485760,ARRAY['application/pdf']::text[]),
('roshan-clinical-attachments','roshan-clinical-attachments',false,20971520,ARRAY['application/pdf','image/jpeg','image/png','image/webp']::text[])
ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,public=false,file_size_limit=EXCLUDED.file_size_limit,allowed_mime_types=EXCLUDED.allowed_mime_types;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
DO $storage_policies$
DECLARE cfg record; act text; perm text; pol text; expr text; cmd text;
BEGIN
FOR cfg IN SELECT * FROM (VALUES
('roshan-lab-reports','phase33_lab_reports','lab.read','lab.update','lab.update','lab.delete'),
('roshan-medical-certificates','phase33_certificates','certificates.read','certificates.create','certificates.update','certificates.delete'),
('roshan-clinical-attachments','phase33_attachments','emr.read','emr.create','emr.update','emr.delete')
) AS x(bucket_id,prefix,read_perm,insert_perm,update_perm,delete_perm) LOOP
  FOREACH act IN ARRAY ARRAY['select','insert','update','delete'] LOOP
    perm := CASE act WHEN 'select' THEN cfg.read_perm WHEN 'insert' THEN cfg.insert_perm WHEN 'update' THEN cfg.update_perm ELSE cfg.delete_perm END;
    IF cfg.bucket_id='roshan-clinical-attachments' AND act='insert' THEN perm := 'emr.create'; END IF;
    pol := cfg.prefix || '_' || act;
    expr := format('bucket_id = %L AND public.app_has_perm(%L) AND EXISTS (SELECT 1 FROM public.branches b WHERE b.id::text = split_part(storage.objects.name, ''/'', 1) AND private.app_has_branch_access(b.id))',cfg.bucket_id,perm);
    IF cfg.bucket_id='roshan-clinical-attachments' AND act='insert' THEN
      expr := format('bucket_id = %L AND (public.app_has_perm(''emr.create'') OR public.app_has_perm(''emr.update'')) AND EXISTS (SELECT 1 FROM public.branches b WHERE b.id::text = split_part(storage.objects.name, ''/'', 1) AND private.app_has_branch_access(b.id))',cfg.bucket_id);
    END IF;
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects',pol);
    IF act='select' OR act='delete' THEN
      cmd := format('CREATE POLICY %I ON storage.objects FOR %s TO authenticated USING (%s)',pol,upper(act),expr);
    ELSIF act='insert' THEN
      cmd := format('CREATE POLICY %I ON storage.objects FOR INSERT TO authenticated WITH CHECK (%s)',pol,expr);
    ELSE
      cmd := format('CREATE POLICY %I ON storage.objects FOR UPDATE TO authenticated USING (%s) WITH CHECK (%s)',pol,expr,expr);
    END IF;
    EXECUTE cmd;
  END LOOP;
END LOOP;
END $storage_policies$;
-- Private Broadcast/Presence channels; browser clients can receive but cannot publish arbitrary clinical events.
ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS phase33_clinical_realtime_select ON realtime.messages;
CREATE POLICY phase33_clinical_realtime_select ON realtime.messages FOR SELECT TO authenticated USING(
(split_part(realtime.topic(),':',1)='branch' AND split_part(realtime.topic(),':',3)='queue' AND public.app_has_perm('queue.read') AND EXISTS(SELECT 1 FROM public.branches b WHERE b.id::text=split_part(realtime.topic(),':',2) AND private.app_has_branch_access(b.id)))
OR
(split_part(realtime.topic(),':',1)='branch' AND split_part(realtime.topic(),':',3)='lab' AND public.app_has_perm('lab.read') AND EXISTS(SELECT 1 FROM public.branches b WHERE b.id::text=split_part(realtime.topic(),':',2) AND private.app_has_branch_access(b.id))));
DO $publication$ BEGIN
IF EXISTS(SELECT 1 FROM pg_catalog.pg_publication WHERE pubname='supabase_realtime') THEN
IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='queue_tickets') THEN EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.queue_tickets'; END IF;
IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='lab_orders') THEN EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.lab_orders'; END IF;
END IF; END $publication$;
COMMIT;
