-- Phase 24: expose only the minimal visit-form directory to authorized visit creators.
-- Avoid broadening SELECT access to public.users, which contains staff contact/account data.
CREATE OR REPLACE FUNCTION public.get_visit_form_options()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_departments jsonb;
  v_doctors jsonb;
BEGIN
  IF NOT public.app_has_perm('visits.create') THEN
    RAISE EXCEPTION 'visit creation permission required' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('id', d.id, 'name', d.name, 'name_ar', d.name_ar)
      ORDER BY coalesce(d.name_ar, d.name), d.id
    ),
    '[]'::jsonb
  )
  INTO v_departments
  FROM public.departments AS d
  WHERE d.active IS TRUE
    AND d.is_active IS TRUE
    AND d.deleted_at IS NULL;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('id', u.id, 'full_name', u.full_name)
      ORDER BY u.full_name, u.id
    ),
    '[]'::jsonb
  )
  INTO v_doctors
  FROM public.users AS u
  JOIN public.roles AS r ON r.id = u.role_id
  WHERE u.active IS TRUE
    AND u.deleted_at IS NULL
    AND r.deleted_at IS NULL
    AND r.code = ANY (ARRAY['gp', 'dentist', 'specialist', 'doctor', 'physician']::text[])
    AND private.app_has_branch_access(u.branch_id);

  RETURN jsonb_build_object(
    'departments', v_departments,
    'doctors', v_doctors
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_visit_form_options() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_visit_form_options() TO authenticated;
