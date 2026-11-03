-- Phase 55: reconcile production clinical child-link guard and private helper ACLs.
-- Forward-only function/privilege correction; no table or patient data changes.
BEGIN;

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

REVOKE ALL ON FUNCTION private.phase36_guard_clinical_visit_links() FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.app_has_claim_branch(uuid) FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.sync_user_role_text() FROM PUBLIC, anon, authenticated, service_role, authenticator;

COMMIT;
