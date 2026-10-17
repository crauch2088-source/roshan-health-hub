CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE TABLE public.users (id uuid PRIMARY KEY, auth_user_id uuid NOT NULL, branch_id uuid, active boolean NOT NULL DEFAULT true);
CREATE TABLE public.patients (id uuid PRIMARY KEY, branch_id uuid);
CREATE TABLE public.visits (id uuid PRIMARY KEY, patient_id uuid, branch_id uuid);
CREATE TABLE public.certificates (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, content text);
CREATE TABLE public.medical_certificates (id uuid PRIMARY KEY, patient_id uuid, diagnosis text);
CREATE TABLE public.patient_discounts (id uuid PRIMARY KEY, patient_id uuid, discount_percent numeric);
CREATE TABLE public.procedure_orders (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, status text);
CREATE TABLE public.procedure_results (id uuid PRIMARY KEY, procedure_order_id uuid, findings text);

CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $function$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT position('|' || p_permission || '|' IN '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0
$function$;
CREATE FUNCTION private.is_super_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT COALESCE(NULLIF(current_setting('test.super_admin', true), '')::boolean, false) $function$;
CREATE FUNCTION private.app_has_branch_access(_branch_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 SELECT COALESCE(private.is_super_admin(),false) OR EXISTS (
   SELECT 1 FROM public.users u WHERE u.auth_user_id=auth.uid() AND COALESCE(u.active,true) AND u.branch_id=_branch_id
 )
$function$;
CREATE FUNCTION private.app_has_patient_branch(_patient_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 SELECT COALESCE(private.is_super_admin(),false) OR EXISTS (
   SELECT 1 FROM public.patients p WHERE p.id=_patient_id AND private.app_has_branch_access(p.branch_id)
 )
$function$;
CREATE FUNCTION private.app_has_attachment_branch_access(_patient_id uuid, _visit_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 SELECT CASE
   WHEN private.is_super_admin() THEN true
   WHEN _patient_id IS NULL AND _visit_id IS NULL THEN false
   ELSE
     (_patient_id IS NULL OR EXISTS (SELECT 1 FROM public.patients p WHERE p.id=_patient_id AND private.app_has_branch_access(p.branch_id)))
     AND
     (_visit_id IS NULL OR EXISTS (SELECT 1 FROM public.visits v LEFT JOIN public.patients p ON p.id=v.patient_id
       WHERE v.id=_visit_id AND private.app_has_branch_access(COALESCE(v.branch_id,p.branch_id))))
 END
$function$;
GRANT EXECUTE ON FUNCTION private.app_has_branch_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_patient_branch(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid,uuid) TO authenticated;

ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY certificates_select ON public.certificates FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('certificates.read')));
CREATE POLICY certificates_insert ON public.certificates FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('certificates.create')));
CREATE POLICY certificates_update ON public.certificates FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('certificates.update'))) WITH CHECK ((SELECT public.app_has_perm('certificates.update')));
CREATE POLICY certificates_delete ON public.certificates FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('certificates.delete')));
CREATE POLICY medical_certificates_select ON public.medical_certificates FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('certificates.read')));
CREATE POLICY medical_certificates_insert ON public.medical_certificates FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('certificates.create')));
CREATE POLICY medical_certificates_update ON public.medical_certificates FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('certificates.update'))) WITH CHECK ((SELECT public.app_has_perm('certificates.update')));
CREATE POLICY medical_certificates_delete ON public.medical_certificates FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('certificates.delete')));
CREATE POLICY patient_discounts_select ON public.patient_discounts FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('patients.read')));
CREATE POLICY patient_discounts_insert ON public.patient_discounts FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY patient_discounts_update ON public.patient_discounts FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit'))) WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY patient_discounts_delete ON public.patient_discounts FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('billing.delete')));
CREATE POLICY procedure_orders_select ON public.procedure_orders FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('procedures.read')));
CREATE POLICY procedure_orders_insert ON public.procedure_orders FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('procedures.create')));
CREATE POLICY procedure_orders_update ON public.procedure_orders FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('procedures.update'))) WITH CHECK ((SELECT public.app_has_perm('procedures.update')));
CREATE POLICY procedure_orders_delete ON public.procedure_orders FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('procedures.delete')));
CREATE POLICY procedure_results_select ON public.procedure_results FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('procedures.read')));
CREATE POLICY procedure_results_insert ON public.procedure_results FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('procedures.create')));
CREATE POLICY procedure_results_update ON public.procedure_results FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('procedures.update'))) WITH CHECK ((SELECT public.app_has_perm('procedures.update')));
CREATE POLICY procedure_results_delete ON public.procedure_results FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('procedures.delete')));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.certificates, public.medical_certificates, public.patient_discounts, public.procedure_orders, public.procedure_results TO authenticated;

INSERT INTO public.users VALUES ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001',true);
INSERT INTO public.patients VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),
 ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.visits VALUES
 ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),
 ('40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.certificates VALUES
 ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','A'),
 ('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','B');
INSERT INTO public.medical_certificates VALUES
 ('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','A'),
 ('60000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','B');
INSERT INTO public.patient_discounts VALUES
 ('70000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',5),
 ('70000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002',10);
INSERT INTO public.procedure_orders VALUES
 ('80000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','ordered'),
 ('80000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','ordered');
INSERT INTO public.procedure_results VALUES
 ('90000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001','A'),
 ('90000000-0000-0000-0000-000000000002','80000000-0000-0000-0000-000000000002','B');

SELECT set_config('test.auth_uid','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.permissions','certificates.read|certificates.create|certificates.update|certificates.delete|billing.read|billing.create|billing.update|billing.edit|billing.delete|patients.read|procedures.read|procedures.create|procedures.update|procedures.delete',false);
SELECT set_config('test.super_admin','false',false);
