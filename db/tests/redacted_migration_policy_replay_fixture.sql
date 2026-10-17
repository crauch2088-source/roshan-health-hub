-- Isolated PostgreSQL 17 fixture for the replay-safe policy portion only.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY, email text NOT NULL);
CREATE TABLE public.users (id uuid PRIMARY KEY, auth_user_id uuid);
CREATE TABLE public.patients (id uuid PRIMARY KEY, label text NOT NULL);
CREATE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT p_permission IN ('patients.read','patients.create','patients.update','patients.delete')
$function$;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
CREATE POLICY optimized_auth_policy_patients ON public.patients
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.patients TO authenticated;
INSERT INTO auth.users (id,email) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','replay-admin@example.invalid');
INSERT INTO public.users (id,auth_user_id) VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',NULL);
INSERT INTO public.patients (id,label) VALUES ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','existing fixture patient');
