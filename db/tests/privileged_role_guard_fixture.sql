-- Disposable PostgreSQL fixture for db/roshan_security_privileged_role_guard.sql.
-- No production data or credentials are used.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE TABLE public.roles (
  id uuid PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL DEFAULT ''
);
CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  role_id uuid,
  auth_user_id uuid,
  full_name text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.role_permissions (
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  PRIMARY KEY (role_id, permission_id)
);

CREATE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $function$
  SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid
$function$;

CREATE FUNCTION auth.role()
RETURNS text
LANGUAGE sql
STABLE
AS $function$
  SELECT NULLIF(current_setting('test.auth_role', true), '')
$function$;

CREATE FUNCTION private.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $function$
  SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false)
$function$;

CREATE FUNCTION public.bootstrap_super_admin(text, text, text)
RETURNS uuid LANGUAGE sql AS $function$ SELECT NULL::uuid $function$;
CREATE FUNCTION public.bootstrap_super_admin(uuid, text, text)
RETURNS uuid LANGUAGE sql AS $function$ SELECT NULL::uuid $function$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.roles, public.users, public.role_permissions TO anon, authenticated;

INSERT INTO public.roles(id, code, name) VALUES
 ('10000000-0000-0000-0000-000000000001', 'admin', 'Admin'),
 ('10000000-0000-0000-0000-000000000002', 'super_admin', 'Super Admin'),
 ('10000000-0000-0000-0000-000000000003', 'staff', 'Staff');
INSERT INTO public.users(id, role_id, auth_user_id, full_name, active) VALUES
 ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Admin user', true),
 ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 'Root user', true),
 ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', 'Staff user', true);
INSERT INTO public.role_permissions(role_id, permission_id) VALUES
 ('10000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000002');
