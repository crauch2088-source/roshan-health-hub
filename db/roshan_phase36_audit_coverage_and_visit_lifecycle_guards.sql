-- Phase 36: targeted audit coverage, immutable clinical parent links, cancelled-visit guards and realtime.
BEGIN;

DO $phase36_audit$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['insurance_prior_authorizations','medical_certificates','patient_discounts'] LOOP
    IF to_regclass(format('public.%I', t)) IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM pg_trigger tr
      WHERE tr.tgrelid = to_regclass(format('public.%I', t))
        AND NOT tr.tgisinternal
        AND tr.tgfoid = 'public.audit_row_change()'::regprocedure
    ) THEN
      EXECUTE format('DROP TRIGGER IF EXISTS phase36_audit_row_change ON public.%I', t);
      EXECUTE format('CREATE TRIGGER phase36_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_row_change()', t);
    END IF;
  END LOOP;
END
$phase36_audit$;

CREATE OR REPLACE FUNCTION private.phase36_guard_clinical_visit_links()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_visit_id uuid;
  v_status text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF (to_jsonb(NEW) ? 'patient_id') AND (to_jsonb(OLD) ? 'patient_id')
       AND (to_jsonb(NEW)->>'patient_id') IS DISTINCT FROM (to_jsonb(OLD)->>'patient_id') THEN
      RAISE EXCEPTION 'patient_id is immutable for clinical child records' USING ERRCODE = '23514';
    END IF;
    IF (to_jsonb(NEW) ? 'visit_id') AND (to_jsonb(OLD) ? 'visit_id')
       AND (to_jsonb(NEW)->>'visit_id') IS DISTINCT FROM (to_jsonb(OLD)->>'visit_id') THEN
      RAISE EXCEPTION 'visit_id is immutable for clinical child records' USING ERRCODE = '23514';
    END IF;
    IF TG_TABLE_NAME = 'lab_order_items'
       AND (to_jsonb(NEW)->>'order_id') IS DISTINCT FROM (to_jsonb(OLD)->>'order_id') THEN
      RAISE EXCEPTION 'order_id is immutable for clinical child records' USING ERRCODE = '23514';
    END IF;
  END IF;

  IF to_jsonb(NEW) ? 'visit_id' THEN
    BEGIN v_visit_id := NULLIF(to_jsonb(NEW)->>'visit_id','')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN v_visit_id := NULL;
    END;
  ELSIF TG_TABLE_NAME = 'lab_order_items' AND to_jsonb(NEW) ? 'order_id' THEN
    SELECT lo.visit_id INTO v_visit_id
    FROM public.lab_orders lo
    WHERE lo.id = NULLIF(to_jsonb(NEW)->>'order_id','')::uuid;
  END IF;

  IF v_visit_id IS NOT NULL THEN
    SELECT v.status INTO v_status FROM public.visits v WHERE v.id = v_visit_id;
    IF v_status = 'cancelled' THEN
      RAISE EXCEPTION 'Cannot write clinical child records for a cancelled visit' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END
$function$;

REVOKE ALL ON FUNCTION private.phase36_guard_clinical_visit_links() FROM PUBLIC, anon, authenticated;

DO $phase36_guards$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['lab_orders','prescriptions','medical_certificates','lab_order_items','prescription_items'] LOOP
    IF to_regclass(format('public.%I',t)) IS NOT NULL THEN
      EXECUTE format('DROP TRIGGER IF EXISTS phase36_visit_link_guard ON public.%I',t);
      EXECUTE format('CREATE TRIGGER phase36_visit_link_guard BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION private.phase36_guard_clinical_visit_links()',t);
    END IF;
  END LOOP;
END
$phase36_guards$;

DO $phase36_realtime$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      IF to_regclass('public.prescriptions') IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='prescriptions'
      ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.prescriptions; END IF;
      IF to_regclass('public.invoices') IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='invoices'
      ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.invoices; END IF;
    EXCEPTION WHEN duplicate_object OR insufficient_privilege THEN NULL;
    END;
  END IF;
END
$phase36_realtime$;

COMMIT;
