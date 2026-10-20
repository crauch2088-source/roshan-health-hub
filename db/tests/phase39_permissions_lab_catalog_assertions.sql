-- Phase 39 disposable PostgreSQL 17 assertions; never run against production.
DO $phase39_assertions$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.permissions WHERE code='lab.verify') THEN RAISE EXCEPTION 'missing lab.verify'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.permissions WHERE code='lab_admin.manage') THEN RAISE EXCEPTION 'missing lab_admin.manage'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.permissions WHERE code='partners.manage') THEN RAISE EXCEPTION 'missing partners.manage'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='lab_parameters' AND t.tgname='trg_audit_lab_parameters' AND NOT t.tgisinternal) THEN RAISE EXCEPTION 'missing lab_parameters audit trigger'; END IF;
END
$phase39_assertions$;
