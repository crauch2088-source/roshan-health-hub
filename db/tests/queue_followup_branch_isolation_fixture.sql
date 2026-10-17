CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE TABLE public.users (id uuid PRIMARY KEY, auth_user_id uuid NOT NULL, branch_id uuid, active boolean NOT NULL DEFAULT true);
CREATE TABLE public.patients (id uuid PRIMARY KEY, branch_id uuid);
CREATE TABLE public.visits (id uuid PRIMARY KEY, patient_id uuid, branch_id uuid);
CREATE TABLE public.followups (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, notes text);
CREATE TABLE public.queue_tickets (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, status text);

CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $function$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT position('|' || p_permission || '|' IN '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0 $function$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT COALESCE(NULLIF(current_setting('test.super_admin', true), '')::boolean,false) $function$;
CREATE FUNCTION private.app_has_branch_access(_branch_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT EXISTS (SELECT 1 FROM public.users u WHERE u.auth_user_id=auth.uid() AND COALESCE(u.active,true) AND u.branch_id=_branch_id) $function$;
CREATE FUNCTION private.app_has_attachment_branch_access(_patient_id uuid, _visit_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 SELECT CASE
   WHEN public.is_super_admin() THEN true
   WHEN _patient_id IS NULL AND _visit_id IS NULL THEN false
   ELSE
     (_patient_id IS NULL OR EXISTS (SELECT 1 FROM public.patients p WHERE p.id=_patient_id AND private.app_has_branch_access(p.branch_id)))
     AND (_visit_id IS NULL OR EXISTS (SELECT 1 FROM public.visits v LEFT JOIN public.patients p ON p.id=v.patient_id
       WHERE v.id=_visit_id AND private.app_has_branch_access(COALESCE(v.branch_id,p.branch_id))))
 END
$function$;
GRANT EXECUTE ON FUNCTION private.app_has_branch_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid,uuid) TO authenticated;

ALTER TABLE public.followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY followups_select ON public.followups FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('followups.read')));
CREATE POLICY followups_insert ON public.followups FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('followups.create')));
CREATE POLICY followups_update ON public.followups FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('followups.update'))) WITH CHECK ((SELECT public.app_has_perm('followups.update')));
CREATE POLICY followups_delete ON public.followups FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('followups.delete')));
CREATE POLICY queue_tickets_sel ON public.queue_tickets FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('queue.read')));
CREATE POLICY queue_tickets_ins ON public.queue_tickets FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('queue.create')));
CREATE POLICY queue_tickets_upd ON public.queue_tickets FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('queue.update'))) WITH CHECK ((SELECT public.app_has_perm('queue.update')));
CREATE POLICY queue_tickets_del ON public.queue_tickets FOR DELETE TO authenticated USING ((SELECT public.is_super_admin()));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.followups, public.queue_tickets TO authenticated;

INSERT INTO public.users VALUES ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001',true);
INSERT INTO public.patients VALUES ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.visits VALUES ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),('40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.followups VALUES ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','A'),('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','B');
INSERT INTO public.queue_tickets VALUES ('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','waiting'),('60000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','waiting');
SELECT set_config('test.auth_uid','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.permissions','followups.read|followups.create|followups.update|followups.delete|queue.read|queue.create|queue.update',false);
SELECT set_config('test.super_admin','false',false);
