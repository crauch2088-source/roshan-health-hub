-- Phase 51: expose only the boolean bootstrap status to anonymous clients.
-- Candidate only. Run in disposable PostgreSQL 17 and review before any live application.
-- The private setup helper and its existing ACL are intentionally unchanged.
BEGIN;

CREATE OR REPLACE FUNCTION public.setup_required()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.setup_required()
$function$;

REVOKE ALL ON FUNCTION public.setup_required()
  FROM PUBLIC, anon, authenticated, service_role, authenticator, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.setup_required() TO anon, authenticated;

COMMENT ON FUNCTION public.setup_required() IS
  'Boolean-only public bootstrap status; exposes no user rows, counts, or identity details.';

COMMIT;
