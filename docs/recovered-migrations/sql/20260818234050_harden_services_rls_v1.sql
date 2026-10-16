DROP POLICY IF EXISTS optimized_auth_policy_services ON public.services;
CREATE POLICY services_select ON public.services FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('settings.read')));
CREATE POLICY services_insert ON public.services FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('settings.create')));
CREATE POLICY services_update ON public.services FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('settings.update'))) WITH CHECK ((SELECT public.app_has_perm('settings.update')));
CREATE POLICY services_delete ON public.services FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('settings.delete')));
