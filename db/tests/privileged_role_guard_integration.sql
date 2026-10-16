-- The guard is tested as an authenticated non-super-admin, a super-admin,
-- and a trusted database/migration context. All mutations are fixture-only.
SELECT set_config('test.auth_uid', '30000000-0000-0000-0000-000000000001', false);
SELECT set_config('test.auth_role', 'authenticated', false);
SELECT set_config('test.super_admin', 'false', false);
SET ROLE authenticated;

DO $non_admin$
BEGIN
  BEGIN
    INSERT INTO public.users(id, role_id, full_name)
    VALUES ('20000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000002', 'Escalation');
    RAISE EXCEPTION 'non-super-admin INSERT into super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.users SET role_id='10000000-0000-0000-0000-000000000002'
    WHERE id='20000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'non-super-admin UPDATE to super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.users SET active=false WHERE id='20000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'non-super-admin modification of super_admin account unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    DELETE FROM public.users WHERE id='20000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'non-super-admin DELETE of super_admin account unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.roles(id, code, name)
    VALUES ('10000000-0000-0000-0000-000000000011', 'super_admin', 'Forged');
    RAISE EXCEPTION 'non-super-admin creation of super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.roles SET code='super_admin'
    WHERE id='10000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'non-super-admin rename into super_admin unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.roles SET name='Tampered' WHERE id='10000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'non-super-admin edit of super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    DELETE FROM public.roles WHERE id='10000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'non-super-admin deletion of super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.role_permissions(role_id, permission_id)
    VALUES ('10000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000003');
    RAISE EXCEPTION 'non-super-admin grant to super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.role_permissions SET role_id='10000000-0000-0000-0000-000000000002'
    WHERE role_id='10000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'non-super-admin move into super_admin permissions unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.role_permissions SET permission_id='40000000-0000-0000-0000-000000000003'
    WHERE role_id='10000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'non-super-admin edit of super_admin permissions unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    DELETE FROM public.role_permissions WHERE role_id='10000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'non-super-admin deletion of super_admin permissions unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- Ordinary-role administration remains possible through the existing RLS layer.
  INSERT INTO public.users(id, role_id, full_name)
  VALUES ('20000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000003', 'Regular');
  UPDATE public.users SET full_name='Regular updated'
  WHERE id='20000000-0000-0000-0000-000000000012';
  DELETE FROM public.users WHERE id='20000000-0000-0000-0000-000000000012';

  INSERT INTO public.roles(id, code, name)
  VALUES ('10000000-0000-0000-0000-000000000012', 'billing_operator', 'Billing Operator');
  UPDATE public.roles SET name='Billing Operator Updated'
  WHERE id='10000000-0000-0000-0000-000000000012';
  DELETE FROM public.roles WHERE id='10000000-0000-0000-0000-000000000012';

  INSERT INTO public.role_permissions(role_id, permission_id)
  VALUES ('10000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000004');
  UPDATE public.role_permissions SET permission_id='40000000-0000-0000-0000-000000000005'
  WHERE role_id='10000000-0000-0000-0000-000000000003'
    AND permission_id='40000000-0000-0000-0000-000000000004';
  DELETE FROM public.role_permissions
  WHERE role_id='10000000-0000-0000-0000-000000000003'
    AND permission_id='40000000-0000-0000-0000-000000000005';
END
$non_admin$;

-- A true super-admin may maintain the protected role, user, and permissions.
SELECT set_config('test.super_admin', 'true', false);
UPDATE public.roles SET name='Super Admin Verified'
WHERE id='10000000-0000-0000-0000-000000000002';
UPDATE public.users SET active=false WHERE id='20000000-0000-0000-0000-000000000002';
UPDATE public.role_permissions SET permission_id='40000000-0000-0000-0000-000000000009'
WHERE role_id='10000000-0000-0000-0000-000000000002';
RESET ROLE;

-- Anonymous JWTs have no auth.uid(), but are NOT a trusted migration/service context.
-- Grant table DML in this disposable fixture so the guard itself must reject escalation.
SELECT set_config('test.auth_uid', '', false);
SELECT set_config('test.auth_role', 'anon', false);
SELECT set_config('test.super_admin', 'false', false);
SET ROLE anon;

DO $anon$
BEGIN
  BEGIN
    INSERT INTO public.users(id, role_id, full_name)
    VALUES ('20000000-0000-0000-0000-000000000021', '10000000-0000-0000-0000-000000000002', 'Anonymous escalation');
    RAISE EXCEPTION 'anonymous INSERT into super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.users SET role_id='10000000-0000-0000-0000-000000000002'
    WHERE id='20000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'anonymous UPDATE into super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.roles SET name='Anonymous tampered'
    WHERE id='10000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'anonymous edit of super_admin role unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.role_permissions(role_id, permission_id)
    VALUES ('10000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000021');
    RAISE EXCEPTION 'anonymous grant to super_admin permissions unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END
$anon$;
RESET ROLE;

-- Trusted migration context is allowed to maintain protected rows.
SELECT set_config('test.auth_role', '', false);
SELECT set_config('test.auth_uid', '', false);
SELECT set_config('test.super_admin', 'false', false);
UPDATE public.roles SET name='Trusted context verified'
WHERE id='10000000-0000-0000-0000-000000000002';

DO $assert$
BEGIN
  IF (SELECT count(*) FROM public.roles WHERE code='super_admin') <> 1 THEN
    RAISE EXCEPTION 'protected super_admin role was lost';
  END IF;
  IF (SELECT name FROM public.roles WHERE code='super_admin') <> 'Trusted context verified' THEN
    RAISE EXCEPTION 'trusted context could not maintain protected role';
  END IF;
  IF (SELECT role_id FROM public.users WHERE id='20000000-0000-0000-0000-000000000002')
       <> '10000000-0000-0000-0000-000000000002' THEN
    RAISE EXCEPTION 'super_admin user role unexpectedly changed';
  END IF;
END
$assert$;
