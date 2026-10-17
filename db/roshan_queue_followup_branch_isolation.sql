-- Parent-branch authorization for queue tickets and follow-ups.
-- Source-only: do not apply to production until migration replay parity is resolved.
CREATE OR REPLACE FUNCTION private.app_has_patient_visit_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.app_has_attachment_branch_access(_patient_id, _visit_id)
    AND (
      _visit_id IS NULL
      OR _patient_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.visits AS v
        WHERE v.id = _visit_id AND v.patient_id = _patient_id
      )
    )
$function$;
REVOKE ALL ON FUNCTION private.app_has_patient_visit_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_patient_visit_branch_access(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) TO authenticated;

ALTER POLICY followups_select ON public.followups
  USING ((SELECT public.app_has_perm('followups.read'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));
ALTER POLICY followups_insert ON public.followups
  WITH CHECK ((SELECT public.app_has_perm('followups.create'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));
ALTER POLICY followups_update ON public.followups
  USING ((SELECT public.app_has_perm('followups.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('followups.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));
ALTER POLICY followups_delete ON public.followups
  USING ((SELECT public.app_has_perm('followups.delete'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));

ALTER POLICY queue_tickets_sel ON public.queue_tickets
  USING ((SELECT public.app_has_perm('queue.read'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));
ALTER POLICY queue_tickets_ins ON public.queue_tickets
  WITH CHECK ((SELECT public.app_has_perm('queue.create'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));
ALTER POLICY queue_tickets_upd ON public.queue_tickets
  USING ((SELECT public.app_has_perm('queue.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('queue.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));
ALTER POLICY queue_tickets_del ON public.queue_tickets
  USING ((SELECT public.is_super_admin())
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));
