-- Simulate the production Phase36 function and QA helper ACL drift before Phase55.
DO $roles$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticator') THEN CREATE ROLE authenticator NOLOGIN; END IF;
END $roles$;

CREATE OR REPLACE FUNCTION private.app_has_claim_branch(_claim_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT false $function$;

CREATE OR REPLACE FUNCTION private.sync_user_role_text()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$ BEGIN RETURN NEW; END $function$;

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
