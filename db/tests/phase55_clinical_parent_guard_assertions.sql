-- Phase55 forward reconciliation assertions; caller wraps the fixture in a disposable PostgreSQL 17 database.
BEGIN;
DO $phase55_assertions$
DECLARE
  v_rejected boolean := false;
  v_message text;
  v_original_order uuid;
  v_is_definer boolean;
  v_config text;
BEGIN
  SELECT order_id INTO v_original_order
  FROM public.lab_order_items
  WHERE id='00000000-0000-0000-0000-000000009111';

  BEGIN
    UPDATE public.lab_order_items
       SET order_id='00000000-0000-0000-0000-000000009102'
     WHERE id='00000000-0000-0000-0000-000000009111';
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_message = MESSAGE_TEXT;
    v_rejected := v_message LIKE '%order_id is immutable%';
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'Phase55 failed to restore lab_order_items.order_id immutability';
  END IF;
  IF (SELECT order_id FROM public.lab_order_items WHERE id='00000000-0000-0000-0000-000000009111') IS DISTINCT FROM v_original_order THEN
    RAISE EXCEPTION 'blocked order_id mutation changed the stored parent link';
  END IF;

  UPDATE public.lab_order_items SET value='trigger-still-active'
   WHERE id='00000000-0000-0000-0000-000000009111';
  IF (SELECT value FROM public.lab_order_items WHERE id='00000000-0000-0000-0000-000000009111') <> 'trigger-still-active' THEN
    RAISE EXCEPTION 'revoking direct trigger-function EXECUTE broke trigger execution';
  END IF;

  IF has_function_privilege('anon','private.app_has_claim_branch(uuid)','EXECUTE')
     OR has_function_privilege('authenticated','private.app_has_claim_branch(uuid)','EXECUTE')
     OR has_function_privilege('service_role','private.app_has_claim_branch(uuid)','EXECUTE')
     OR has_function_privilege('authenticator','private.app_has_claim_branch(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'private.app_has_claim_branch remains directly executable by an application role';
  END IF;
  IF has_function_privilege('anon','private.sync_user_role_text()','EXECUTE')
     OR has_function_privilege('authenticated','private.sync_user_role_text()','EXECUTE')
     OR has_function_privilege('service_role','private.sync_user_role_text()','EXECUTE')
     OR has_function_privilege('authenticator','private.sync_user_role_text()','EXECUTE') THEN
    RAISE EXCEPTION 'private.sync_user_role_text remains directly executable by an application role';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.users'::regclass
      AND tgname='trg_sync_user_role_text'
      AND tgfoid='private.sync_user_role_text()'::regprocedure
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'role text synchronization trigger was lost during ACL reconciliation';
  END IF;
  IF has_function_privilege('anon','private.phase36_guard_clinical_visit_links()','EXECUTE')
     OR has_function_privilege('authenticated','private.phase36_guard_clinical_visit_links()','EXECUTE')
     OR has_function_privilege('service_role','private.phase36_guard_clinical_visit_links()','EXECUTE')
     OR has_function_privilege('authenticator','private.phase36_guard_clinical_visit_links()','EXECUTE') THEN
    RAISE EXCEPTION 'private.phase36_guard_clinical_visit_links remains directly executable by an application role';
  END IF;

  SELECT prosecdef,COALESCE(array_to_string(proconfig,','),'')
    INTO v_is_definer,v_config
    FROM pg_proc WHERE oid='private.phase36_guard_clinical_visit_links()'::regprocedure;
  IF NOT v_is_definer OR v_config NOT LIKE '%search_path=""%' THEN
    RAISE EXCEPTION 'Phase55 clinical guard must remain SECURITY DEFINER with an empty search_path';
  END IF;
END $phase55_assertions$;
-- A SECURITY DEFINER caller must still be able to use the private claim helper
-- after direct application-role EXECUTE is revoked.
CREATE OR REPLACE FUNCTION public.phase55_test_claim_helper_definer(_claim_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.app_has_claim_branch(_claim_id)
$function$;
GRANT EXECUTE ON FUNCTION public.phase55_test_claim_helper_definer(uuid) TO authenticated;
SET LOCAL ROLE authenticated;
DO $claim_helper_caller$
BEGIN
  IF public.phase55_test_claim_helper_definer('00000000-0000-0000-0000-000000009199') IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'SECURITY DEFINER caller did not preserve private claim helper behavior';
  END IF;
END
$claim_helper_caller$;
UPDATE public.lab_order_items SET value='trigger-authenticated-role' WHERE id='00000000-0000-0000-0000-000000009111';
RESET ROLE;
DROP FUNCTION public.phase55_test_claim_helper_definer(uuid);
DO $trigger_acl$
BEGIN
  IF (SELECT value FROM public.lab_order_items WHERE id='00000000-0000-0000-0000-000000009111') <> 'trigger-authenticated-role' THEN
    RAISE EXCEPTION 'clinical trigger stopped working after direct EXECUTE was revoked';
  END IF;
END
$trigger_acl$;
ROLLBACK;
