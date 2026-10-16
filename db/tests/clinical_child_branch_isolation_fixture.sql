CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  auth_user_id uuid,
  branch_id uuid,
  active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.patients (
  id uuid PRIMARY KEY,
  branch_id uuid
);
CREATE TABLE public.visits (
  id uuid PRIMARY KEY,
  patient_id uuid,
  branch_id uuid
);
CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid,
  visit_id uuid,
  notes text
);
CREATE TABLE public.prescription_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id uuid,
  medication_name text
);
CREATE TABLE public.lab_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid,
  visit_id uuid,
  branch_id uuid
);
CREATE TABLE public.lab_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid,
  status text
);

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $function$;
CREATE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT position('|' || p_permission || '|' IN
    '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0
$function$;
CREATE FUNCTION private.is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT COALESCE(NULLIF(current_setting('test.super_admin', true), '')::boolean, false) $function$;
CREATE FUNCTION private.app_has_branch_access(_branch_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(),false)
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_user_id=auth.uid()
        AND COALESCE(u.active,true)=true
        AND u.branch_id=_branch_id
    )
$function$;
CREATE FUNCTION private.app_has_attachment_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN private.is_super_admin() THEN true
    WHEN _patient_id IS NULL AND _visit_id IS NULL THEN false
    ELSE
      (
        _patient_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.patients AS p
          WHERE p.id = _patient_id AND private.app_has_branch_access(p.branch_id)
        )
      )
      AND
      (
        _visit_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.visits AS v
          LEFT JOIN public.patients AS p ON p.id = v.patient_id
          WHERE v.id = _visit_id
            AND private.app_has_branch_access(COALESCE(v.branch_id, p.branch_id))
        )
      )
  END
$function$;

GRANT EXECUTE ON FUNCTION private.app_has_branch_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid,uuid) TO authenticated;

ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY prescriptions_select ON public.prescriptions FOR SELECT TO authenticated
  USING ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')));
CREATE POLICY prescriptions_insert ON public.prescriptions FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')));
CREATE POLICY prescriptions_update ON public.prescriptions FOR UPDATE TO authenticated
  USING ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
  WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')));
CREATE POLICY prescriptions_delete ON public.prescriptions FOR DELETE TO authenticated
  USING ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')));

CREATE POLICY prescription_items_select ON public.prescription_items FOR SELECT TO authenticated
  USING ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')));
CREATE POLICY prescription_items_insert ON public.prescription_items FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')));
CREATE POLICY prescription_items_update ON public.prescription_items FOR UPDATE TO authenticated
  USING ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
  WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')));
CREATE POLICY prescription_items_delete ON public.prescription_items FOR DELETE TO authenticated
  USING ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')));

CREATE POLICY lab_order_items_select ON public.lab_order_items FOR SELECT TO authenticated
  USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_order_items_insert ON public.lab_order_items FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.app_has_perm('lab.create')));
CREATE POLICY lab_order_items_update ON public.lab_order_items FOR UPDATE TO authenticated
  USING ((SELECT public.app_has_perm('lab.update')))
  WITH CHECK ((SELECT public.app_has_perm('lab.update')));
CREATE POLICY lab_order_items_delete ON public.lab_order_items FOR DELETE TO authenticated
  USING ((SELECT public.app_has_perm('lab.delete')));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.prescriptions, public.prescription_items, public.lab_order_items TO authenticated;

