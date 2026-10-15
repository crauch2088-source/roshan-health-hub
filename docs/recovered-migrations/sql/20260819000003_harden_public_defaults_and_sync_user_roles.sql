-- Harden future public-schema exposure: keep existing grants intact, but do not
-- automatically expose newly-created tables/functions/sequences through the Data API.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE USAGE, SELECT ON SEQUENCES FROM anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- `users.role_id` is the authoritative RBAC relation. Keep the legacy
-- `users.role` text column synchronized so it cannot drift from role_id.
CREATE OR REPLACE FUNCTION private.sync_user_role_text()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.role_id IS NOT NULL THEN
    SELECT r.code
      INTO NEW.role
      FROM public.roles AS r
     WHERE r.id = NEW.role_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_role_text ON public.users;
CREATE TRIGGER trg_sync_user_role_text
BEFORE INSERT OR UPDATE OF role_id ON public.users
FOR EACH ROW
EXECUTE FUNCTION private.sync_user_role_text();

-- Bring existing records into the same canonical state.
UPDATE public.users AS u
   SET role = r.code
  FROM public.roles AS r
 WHERE r.id = u.role_id
   AND r.code IS NOT NULL
   AND u.role IS DISTINCT FROM r.code;

COMMENT ON COLUMN public.users.role IS
  'Legacy compatibility field. Authoritative RBAC is role_id -> roles.code; this value is synchronized automatically.';
