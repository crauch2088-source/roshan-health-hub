-- Phase 25: let each authenticated user load only their own app profile and permissions.
-- This avoids RLS deadlock where a user needs users.read/admin.full to read the row
-- that is required to determine whether they have those permissions.
CREATE OR REPLACE FUNCTION public.get_my_app_profile()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid;
  v_full_name text;
  v_email text;
  v_phone text;
  v_role_id uuid;
  v_active boolean;
  v_role_code text;
  v_role_name text;
  v_permissions jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT
    u.id,
    u.full_name,
    u.email,
    u.phone,
    u.role_id,
    u.active,
    r.code,
    r.name
  INTO
    v_user_id,
    v_full_name,
    v_email,
    v_phone,
    v_role_id,
    v_active,
    v_role_code,
    v_role_name
  FROM public.users AS u
  LEFT JOIN public.roles AS r
    ON r.id = u.role_id
   AND r.deleted_at IS NULL
  WHERE u.auth_user_id = auth.uid()
    AND u.deleted_at IS NULL
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_active IS TRUE
     AND v_role_code IS NOT NULL
     AND v_role_code <> 'super_admin'
     AND v_role_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(p.code ORDER BY p.code), '[]'::jsonb)
      INTO v_permissions
    FROM public.role_permissions AS rp
    JOIN public.permissions AS p ON p.id = rp.permission_id
    WHERE rp.role_id = v_role_id;
  END IF;

  RETURN jsonb_build_object(
    'user', jsonb_build_object(
      'id', v_user_id,
      'full_name', v_full_name,
      'email', v_email,
      'phone', v_phone,
      'role_id', v_role_id,
      'active', coalesce(v_active, false),
      'role_code', v_role_code,
      'role_name', v_role_name
    ),
    'permissions', coalesce(v_permissions, '[]'::jsonb)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_app_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_app_profile() TO authenticated;
