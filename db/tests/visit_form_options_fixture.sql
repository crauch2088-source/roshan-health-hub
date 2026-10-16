CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;

CREATE TABLE public.departments (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  name_ar text,
  active boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz
);
CREATE TABLE public.roles (
  id uuid PRIMARY KEY,
  code text NOT NULL,
  deleted_at timestamptz
);
CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  full_name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz,
  role_id uuid NOT NULL REFERENCES public.roles(id),
  branch_id uuid,
  email text,
  phone text
);

CREATE OR REPLACE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT coalesce(current_setting('test.super_admin', true) = 'true', false)
      OR (coalesce(current_setting('test.visits_create', true) = 'true' AND p_permission = 'visits.create', false))
      OR (coalesce(current_setting('test.admin_full', true) = 'true' AND p_permission = 'admin.full', false));
$$;

CREATE OR REPLACE FUNCTION private.app_has_branch_access(p_branch_id uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT coalesce(current_setting('test.super_admin', true) = 'true', false)
      OR (p_branch_id IS NOT NULL AND p_branch_id::text = current_setting('test.branch_id', true));
$$;

GRANT USAGE ON SCHEMA public TO authenticated, anon;
