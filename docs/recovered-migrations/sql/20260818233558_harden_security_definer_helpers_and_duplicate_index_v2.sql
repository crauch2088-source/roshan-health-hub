BEGIN;

ALTER TABLE public.role_permissions
  DROP CONSTRAINT IF EXISTS role_permissions_role_permission_unique;

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.id FROM public.users AS u
  WHERE u.auth_user_id = auth.uid() AND COALESCE(u.active, true) = true
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION private.current_role_code()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT r.code FROM public.users AS u
  JOIN public.roles AS r ON r.id = u.role_id
  WHERE u.auth_user_id = auth.uid() AND COALESCE(u.active, true) = true
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION private.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT COALESCE((SELECT private.current_role_code()) = 'super_admin', false)
$$;

CREATE OR REPLACE FUNCTION private.app_has_perm(_code text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT (SELECT private.is_super_admin()) OR EXISTS (
    SELECT 1
    FROM public.users AS u
    JOIN public.role_permissions AS rp ON rp.role_id = u.role_id
    JOIN public.permissions AS p ON p.id = rp.permission_id
    WHERE u.auth_user_id = auth.uid()
      AND COALESCE(u.active, true) = true
      AND p.code = _code
  )
$$;

CREATE OR REPLACE FUNCTION private.setup_required()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT NOT EXISTS (SELECT 1 FROM public.users)
$$;

CREATE OR REPLACE FUNCTION private.next_visit_number(_visit_date date)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE next_number integer;
BEGIN
  IF _visit_date IS NULL THEN RAISE EXCEPTION 'visit_date is required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('roshan.visit.' || _visit_date::text, 0));
  SELECT COALESCE(MAX(CASE WHEN v.visit_number ~ '^[0-9]+$' THEN v.visit_number::integer END), 0) + 1
    INTO next_number
    FROM public.visits AS v
   WHERE v.visit_date = _visit_date AND v.deleted_at IS NULL;
  RETURN lpad(next_number::text, 3, '0');
END;
$$;

CREATE OR REPLACE FUNCTION private.next_queue_number(_visit_date date)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE next_number integer;
BEGIN
  IF _visit_date IS NULL THEN RAISE EXCEPTION 'visit_date is required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('roshan.queue.' || _visit_date::text, 0));
  SELECT COALESCE(MAX(v.queue_number), 0) + 1 INTO next_number
    FROM public.visits AS v WHERE v.queue_date = _visit_date;
  RETURN next_number;
END;
$$;

CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$ SELECT private.current_app_user_id() $$;
CREATE OR REPLACE FUNCTION public.current_role_code()
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$ SELECT private.current_role_code() $$;
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$ SELECT private.is_super_admin() $$;
CREATE OR REPLACE FUNCTION public.app_has_perm(_code text)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$ SELECT private.app_has_perm(_code) $$;
CREATE OR REPLACE FUNCTION public.setup_required()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$ SELECT private.setup_required() $$;
CREATE OR REPLACE FUNCTION public.next_visit_number(_visit_date date)
RETURNS text LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.next_visit_number(_visit_date) $$;
CREATE OR REPLACE FUNCTION public.next_queue_number(_visit_date date)
RETURNS integer LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.next_queue_number(_visit_date) $$;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.current_app_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_role_code() TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_super_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_perm(text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.setup_required() TO authenticated;
GRANT EXECUTE ON FUNCTION private.next_visit_number(date) TO authenticated;
GRANT EXECUTE ON FUNCTION private.next_queue_number(date) TO authenticated;

REVOKE ALL ON FUNCTION public.current_app_user_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_role_code() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_super_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_has_perm(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.setup_required() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.next_visit_number(date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.next_queue_number(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_role_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_has_perm(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.setup_required() TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_visit_number(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_queue_number(date) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
