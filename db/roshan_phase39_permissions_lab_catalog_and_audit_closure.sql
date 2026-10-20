-- Phase 39: permissions, qualitative lab values, and audit coverage.
-- Source tracks live migration 20261020232033; stored live SQL bytes are not exposed by the ledger API.
BEGIN;
INSERT INTO public.permissions (code, name, module, action)
VALUES ('lab.verify','Verify laboratory results','lab','verify'),('lab_admin.manage','Manage laboratory catalogue','lab_admin','manage'),('partners.manage','Manage partners','partners','manage')
ON CONFLICT (code) DO NOTHING;
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id,p.id FROM public.roles r JOIN public.permissions p ON p.code='lab.verify'
WHERE r.code IN ('doctor','lab_tech') ON CONFLICT DO NOTHING;
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id,p.id FROM public.roles r JOIN public.permissions p ON p.code IN ('lab_admin.manage','partners.manage')
WHERE r.code IN ('admin','super_admin') ON CONFLICT DO NOTHING;
UPDATE public.lab_parameters SET data_type='text' WHERE code IN ('MP_RESULT','UPT_RESULT');
DO $phase39_audit$
DECLARE table_name text; trigger_name text;
BEGIN
 FOREACH table_name IN ARRAY ARRAY['lab_tests','lab_parameters','lab_reference_ranges','medicines','appointments','followups','attachments']
 LOOP
  IF to_regclass(format('public.%I',table_name)) IS NOT NULL THEN
   trigger_name := 'trg_audit_'||table_name;
   IF NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=table_name AND t.tgname=trigger_name AND NOT t.tgisinternal) THEN
    EXECUTE format('CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()',trigger_name,table_name);
   END IF;
  END IF;
 END LOOP;
END
$phase39_audit$;
DO $phase39_role_codes$
DECLARE r record; candidate text; base_candidate text; suffix integer;
BEGIN
 FOR r IN SELECT id,name FROM public.roles WHERE code IS NULL AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.role_id=roles.id) ORDER BY id
 LOOP
  base_candidate := 'legacy_'||trim(both '_' FROM regexp_replace(lower(coalesce(r.name,'role')),'[^a-z0-9]+','_','g'));
  IF base_candidate='legacy_' THEN base_candidate:='legacy_role'; END IF;
  candidate:=base_candidate; suffix:=1;
  WHILE EXISTS (SELECT 1 FROM public.roles x WHERE x.code=candidate) LOOP candidate:=base_candidate||'_'||suffix::text; suffix:=suffix+1; END LOOP;
  UPDATE public.roles SET code=candidate WHERE id=r.id;
 END LOOP;
END
$phase39_role_codes$;
COMMIT;
