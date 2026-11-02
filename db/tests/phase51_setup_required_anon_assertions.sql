-- Disposable PostgreSQL 17 assertions for Phase 51.
-- This file writes one synthetic public.users row inside a transaction and rolls it back.
BEGIN;

DO $phase51_catalog_contract$
DECLARE
  v_function pg_proc%ROWTYPE;
  v_unexpected_grants text[];
BEGIN
  SELECT p.*
    INTO v_function
    FROM pg_proc AS p
   WHERE p.oid = 'public.setup_required()'::regprocedure;

  IF v_function.pronargs <> 0 OR v_function.prorettype <> 'boolean'::regtype THEN
    RAISE EXCEPTION 'public.setup_required() must remain a zero-argument boolean function';
  END IF;
  IF NOT v_function.prosecdef OR v_function.provolatile <> 's' THEN
    RAISE EXCEPTION 'public.setup_required() must be STABLE SECURITY DEFINER';
  END IF;
  IF NOT COALESCE(v_function.proconfig @> ARRAY['search_path=""'], false) THEN
    RAISE EXCEPTION 'public.setup_required() must pin an empty search_path';
  END IF;

  IF NOT has_function_privilege('anon', 'public.setup_required()', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must be able to execute public.setup_required()';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.setup_required()', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated must be able to execute public.setup_required()';
  END IF;
  IF has_function_privilege('anon', 'private.setup_required()', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not be able to execute private.setup_required()';
  END IF;
  IF has_schema_privilege('anon', 'private', 'USAGE') THEN
    RAISE EXCEPTION 'anon must not have USAGE on the private schema';
  END IF;

  SELECT array_agg(DISTINCT COALESCE(grantee.rolname, 'PUBLIC')
                   ORDER BY COALESCE(grantee.rolname, 'PUBLIC'))
    INTO v_unexpected_grants
    FROM pg_proc AS p
    CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS acl
    LEFT JOIN pg_roles AS grantee ON grantee.oid = acl.grantee
   WHERE p.oid = 'public.setup_required()'::regprocedure
     AND acl.privilege_type = 'EXECUTE'
     AND acl.grantee <> p.proowner
     AND COALESCE(grantee.rolname, 'PUBLIC') NOT IN ('anon', 'authenticated');

  IF v_unexpected_grants IS NOT NULL THEN
    RAISE EXCEPTION 'unexpected direct EXECUTE grants on public.setup_required(): %',
      array_to_string(v_unexpected_grants, ', ');
  END IF;
END
$phase51_catalog_contract$;

DO $phase51_empty_fixture$
BEGIN
  IF EXISTS (SELECT 1 FROM public.users) THEN
    RAISE EXCEPTION 'Phase 51 fixture requires the schema-only baseline with an empty public.users table';
  END IF;
END
$phase51_empty_fixture$;

SET LOCAL ROLE anon;
DO $phase51_anon_empty$
DECLARE
  v_required boolean;
BEGIN
  SELECT public.setup_required() INTO v_required;
  IF v_required IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'anon must receive true while public.users is empty';
  END IF;
END
$phase51_anon_empty$;

DO $phase51_private_denied$
DECLARE
  v_denied boolean := false;
BEGIN
  BEGIN
    PERFORM private.setup_required();
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'anon unexpectedly executed private.setup_required()';
  END IF;
END
$phase51_private_denied$;

RESET ROLE;

INSERT INTO public.users (id, full_name, email, role, active)
VALUES (
  '00000000-0000-4000-8000-000000005151'::uuid,
  'Roshan Phase 51 synthetic user',
  'phase51@example.invalid',
  'staff',
  true
);

SET LOCAL ROLE anon;
DO $phase51_anon_nonempty$
DECLARE
  v_required boolean;
BEGIN
  SELECT public.setup_required() INTO v_required;
  IF v_required IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'anon must receive false after a synthetic user row exists';
  END IF;
END
$phase51_anon_nonempty$;

RESET ROLE;
ROLLBACK;
