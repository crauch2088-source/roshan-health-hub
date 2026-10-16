CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

CREATE TABLE public.roles (
  id uuid PRIMARY KEY,
  code text NOT NULL,
  name text NOT NULL,
  deleted_at timestamptz
);
CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  auth_user_id uuid,
  full_name text,
  email text,
  phone text,
  role_id uuid REFERENCES public.roles(id),
  active boolean,
  deleted_at timestamptz
);
CREATE TABLE public.permissions (
  id uuid PRIMARY KEY,
  code text NOT NULL
);
CREATE TABLE public.role_permissions (
  role_id uuid NOT NULL REFERENCES public.roles(id),
  permission_id uuid NOT NULL REFERENCES public.permissions(id),
  PRIMARY KEY (role_id, permission_id)
);

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY roles_hidden_from_regular_users ON public.roles FOR SELECT TO authenticated USING (false);
CREATE POLICY users_hidden_without_users_read ON public.users FOR SELECT TO authenticated USING (false);
CREATE POLICY permissions_hidden_from_regular_users ON public.permissions FOR SELECT TO authenticated USING (false);
CREATE POLICY role_permissions_hidden_from_regular_users ON public.role_permissions FOR SELECT TO authenticated USING (false);

GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
GRANT SELECT ON public.roles, public.users, public.permissions, public.role_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
