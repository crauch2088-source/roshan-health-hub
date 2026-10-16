INSERT INTO public.roles (id, code, name, deleted_at) VALUES
  ('10000000-0000-0000-0000-000000000001', 'receptionist', 'Reception', null),
  ('10000000-0000-0000-0000-000000000002', 'super_admin', 'Super Admin', null);

INSERT INTO public.permissions (id, code) VALUES
  ('20000000-0000-0000-0000-000000000001', 'patients.read'),
  ('20000000-0000-0000-0000-000000000002', 'visits.create');

INSERT INTO public.role_permissions (role_id, permission_id) VALUES
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002');

INSERT INTO public.users (id, auth_user_id, full_name, email, phone, role_id, active, deleted_at) VALUES
  ('30000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Reception Test', 'reception@example.invalid', '000', '10000000-0000-0000-0000-000000000001', true, null),
  ('30000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', 'Admin Test', 'admin@example.invalid', '111', '10000000-0000-0000-0000-000000000002', true, null),
  ('30000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000003', 'Inactive Test', 'inactive@example.invalid', '222', '10000000-0000-0000-0000-000000000001', false, null),
  ('30000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000004', 'Deleted Test', 'deleted@example.invalid', '333', '10000000-0000-0000-0000-000000000001', true, now());

SELECT set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000001', false);
SET ROLE authenticated;

DO $test$
DECLARE
  profile jsonb;
BEGIN
  IF (SELECT count(*) FROM public.users) <> 0 OR (SELECT count(*) FROM public.role_permissions) <> 0 THEN
    RAISE EXCEPTION 'fixture RLS should hide profile and permission tables from ordinary authenticated users';
  END IF;

  profile := public.get_my_app_profile();
  IF profile IS NULL THEN
    RAISE EXCEPTION 'authenticated receptionist must be able to load their own profile';
  END IF;
  IF profile #>> '{user,role_code}' <> 'receptionist' THEN
    RAISE EXCEPTION 'profile role code was not returned';
  END IF;
  IF profile #>> '{user,id}' <> '30000000-0000-0000-0000-000000000001' THEN
    RAISE EXCEPTION 'RPC returned a different user profile';
  END IF;
  IF jsonb_array_length(profile->'permissions') <> 2 THEN
    RAISE EXCEPTION 'only the receptionist role permissions should be returned';
  END IF;
  IF profile::text LIKE '%Admin Test%' OR profile::text LIKE '%admin@example.invalid%' OR profile::text LIKE '%Inactive Test%' OR profile::text LIKE '%Deleted Test%' THEN
    RAISE EXCEPTION 'RPC leaked another user profile';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000002', false);
  profile := public.get_my_app_profile();
  IF profile #>> '{user,role_code}' <> 'super_admin' THEN
    RAISE EXCEPTION 'super admin profile did not load';
  END IF;
  IF jsonb_array_length(profile->'permissions') <> 0 THEN
    RAISE EXCEPTION 'super admin permissions should continue to be handled by the application wildcard';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', '', false);
  IF public.get_my_app_profile() IS NOT NULL THEN
    RAISE EXCEPTION 'unauthenticated call should return NULL';
  END IF;

  IF has_function_privilege('anon', 'public.get_my_app_profile()', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute the profile RPC';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.get_my_app_profile()', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated must execute the profile RPC';
  END IF;
END;
$test$;
RESET ROLE;
