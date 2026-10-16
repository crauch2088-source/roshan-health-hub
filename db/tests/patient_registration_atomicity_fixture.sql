CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  branch_id uuid,
  active boolean DEFAULT true,
  deleted_at timestamptz
);
CREATE TABLE public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id uuid,
  mrn varchar UNIQUE,
  full_name varchar NOT NULL,
  gender varchar NOT NULL,
  date_of_birth date,
  phone varchar,
  national_id text,
  created_by uuid,
  registered_by uuid,
  updated_by uuid,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz,
  deleted_by uuid
);
CREATE FUNCTION public.next_mrn()
RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $$ SELECT 'RMC999999'::text $$;
GRANT INSERT ON public.patients TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_mrn() TO authenticated;

CREATE FUNCTION public.app_has_perm(_code text)
RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT COALESCE(current_setting('test.allow_create', true) = 'true', false) $$;
CREATE FUNCTION public.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;
CREATE FUNCTION public.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE
AS $$ SELECT false $$;
