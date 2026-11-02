-- Phase 52 catalog and authorization assertions; schema-only PG17 fixture.
BEGIN;

DO $phase52_catalog_contract$
DECLARE
  v_function pg_proc%ROWTYPE;
  v_has_public_execute boolean;
BEGIN
  SELECT p.* INTO v_function
    FROM pg_catalog.pg_proc p
   WHERE p.oid = 'public.get_reporting_analytics(date,date,uuid)'::regprocedure;

  IF v_function.prorettype <> 'jsonb'::regtype OR v_function.pronargs <> 3 THEN
    RAISE EXCEPTION 'Phase 52 reporting RPC signature/return type drifted';
  END IF;
  IF v_function.prosecdef OR v_function.provolatile <> 's' THEN
    RAISE EXCEPTION 'Phase 52 reporting RPC must be STABLE SECURITY INVOKER';
  END IF;
  IF NOT COALESCE(v_function.proconfig @> ARRAY['search_path=""'], false) THEN
    RAISE EXCEPTION 'Phase 52 reporting RPC must pin an empty search_path';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.get_reporting_analytics(date,date,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated must execute Phase 52 reporting RPC';
  END IF;
  IF has_function_privilege('anon', 'public.get_reporting_analytics(date,date,uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.get_reporting_analytics(date,date,uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon/service_role must not execute Phase 52 reporting RPC';
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM pg_catalog.pg_proc p
      CROSS JOIN LATERAL pg_catalog.aclexplode(
        COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))
      ) acl
     WHERE p.oid = v_function.oid
       AND acl.grantee = 0
       AND acl.privilege_type = 'EXECUTE'
  ) INTO v_has_public_execute;
  IF v_has_public_execute THEN
    RAISE EXCEPTION 'PUBLIC must not have direct EXECUTE on Phase 52 reporting RPC';
  END IF;

  IF NOT has_function_privilege('authenticated', 'private.app_has_perm(text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'private.app_has_branch_access(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated must retain execute access to reviewed permission/branch helpers';
  END IF;
END
$phase52_catalog_contract$;

SET LOCAL ROLE anon;
DO $phase52_anon_denied$
DECLARE
  v_denied boolean := false;
BEGIN
  BEGIN
    PERFORM public.get_reporting_analytics(CURRENT_DATE, CURRENT_DATE, NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'anon unexpectedly executed Phase 52 reporting RPC';
  END IF;
END
$phase52_anon_denied$;
RESET ROLE;

SET LOCAL ROLE authenticated;
DO $phase52_unauthenticated_denied$
DECLARE
  v_denied boolean := false;
BEGIN
  BEGIN
    PERFORM public.get_reporting_analytics(CURRENT_DATE, CURRENT_DATE, NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'authenticated request without a valid app user unexpectedly read reports';
  END IF;
END
$phase52_unauthenticated_denied$;
RESET ROLE;

ROLLBACK;
