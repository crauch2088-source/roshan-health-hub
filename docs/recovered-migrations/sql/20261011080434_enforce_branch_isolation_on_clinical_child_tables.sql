CREATE OR REPLACE FUNCTION private.app_has_visit_branch_access(_visit_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.visits AS v
    LEFT JOIN public.patients AS p ON p.id = v.patient_id
    WHERE v.id = _visit_id
      AND private.app_has_branch_access(COALESCE(v.branch_id, p.branch_id))
  )
$function$;

CREATE OR REPLACE FUNCTION private.app_has_lab_result_branch_access(_order_item_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.lab_order_items AS loi
    JOIN public.lab_orders AS lo ON lo.id = loi.order_id
    LEFT JOIN public.visits AS v ON v.id = lo.visit_id
    LEFT JOIN public.patients AS p ON p.id = lo.patient_id
    WHERE loi.id = _order_item_id
      AND private.app_has_branch_access(COALESCE(lo.branch_id, v.branch_id, p.branch_id))
  )
$function$;

CREATE OR REPLACE FUNCTION private.app_has_attachment_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN private.is_super_admin() THEN true
    WHEN _patient_id IS NULL AND _visit_id IS NULL THEN false
    ELSE
      (
        _patient_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.patients AS p
          WHERE p.id = _patient_id
            AND private.app_has_branch_access(p.branch_id)
        )
      )
      AND
      (
        _visit_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM public.visits AS v
          LEFT JOIN public.patients AS p ON p.id = v.patient_id
          WHERE v.id = _visit_id
            AND private.app_has_branch_access(COALESCE(v.branch_id, p.branch_id))
        )
      )
  END
$function$;

REVOKE ALL ON FUNCTION private.app_has_visit_branch_access(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.app_has_lab_result_branch_access(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_visit_branch_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_lab_result_branch_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) TO authenticated;

ALTER POLICY clinical_notes_select ON public.clinical_notes
  USING ((SELECT public.app_has_perm('emr.read')) AND (SELECT private.app_has_visit_branch_access(clinical_notes.visit_id)));
ALTER POLICY clinical_notes_insert ON public.clinical_notes
  WITH CHECK ((SELECT public.app_has_perm('emr.create')) AND (SELECT private.app_has_visit_branch_access(clinical_notes.visit_id)));
ALTER POLICY clinical_notes_update ON public.clinical_notes
  USING ((SELECT public.app_has_perm('emr.update')) AND (SELECT private.app_has_visit_branch_access(clinical_notes.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('emr.update')) AND (SELECT private.app_has_visit_branch_access(clinical_notes.visit_id)));
ALTER POLICY clinical_notes_delete ON public.clinical_notes
  USING ((SELECT public.app_has_perm('emr.delete')) AND (SELECT private.app_has_visit_branch_access(clinical_notes.visit_id)));

ALTER POLICY diagnoses_select ON public.diagnoses
  USING ((SELECT public.app_has_perm('emr.read')) AND (SELECT private.app_has_visit_branch_access(diagnoses.visit_id)));
ALTER POLICY diagnoses_insert ON public.diagnoses
  WITH CHECK ((SELECT public.app_has_perm('emr.create')) AND (SELECT private.app_has_visit_branch_access(diagnoses.visit_id)));
ALTER POLICY diagnoses_update ON public.diagnoses
  USING ((SELECT public.app_has_perm('emr.update')) AND (SELECT private.app_has_visit_branch_access(diagnoses.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('emr.update')) AND (SELECT private.app_has_visit_branch_access(diagnoses.visit_id)));
ALTER POLICY diagnoses_delete ON public.diagnoses
  USING ((SELECT public.app_has_perm('emr.delete')) AND (SELECT private.app_has_visit_branch_access(diagnoses.visit_id)));

ALTER POLICY vitals_select ON public.vitals
  USING ((SELECT public.app_has_perm('emr.read')) AND (SELECT private.app_has_visit_branch_access(vitals.visit_id)));
ALTER POLICY vitals_insert ON public.vitals
  WITH CHECK ((SELECT public.app_has_perm('emr.create')) AND (SELECT private.app_has_visit_branch_access(vitals.visit_id)));
ALTER POLICY vitals_update ON public.vitals
  USING ((SELECT public.app_has_perm('emr.update')) AND (SELECT private.app_has_visit_branch_access(vitals.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('emr.update')) AND (SELECT private.app_has_visit_branch_access(vitals.visit_id)));
ALTER POLICY vitals_delete ON public.vitals
  USING ((SELECT public.app_has_perm('emr.delete')) AND (SELECT private.app_has_visit_branch_access(vitals.visit_id)));

ALTER POLICY lab_results_select ON public.lab_results
  USING ((SELECT public.app_has_perm('lab.read')) AND (SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id)));
ALTER POLICY lab_results_insert ON public.lab_results
  WITH CHECK ((SELECT public.app_has_perm('lab.create')) AND (SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id)));
ALTER POLICY lab_results_update ON public.lab_results
  USING ((SELECT public.app_has_perm('lab.update')) AND (SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id)))
  WITH CHECK ((SELECT public.app_has_perm('lab.update')) AND (SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id)));
ALTER POLICY lab_results_delete ON public.lab_results
  USING ((SELECT public.app_has_perm('lab.delete')) AND (SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id)));

ALTER POLICY attachments_select ON public.attachments
  USING ((SELECT public.app_has_perm('attachments.read')) AND (SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id)));
ALTER POLICY attachments_insert ON public.attachments
  WITH CHECK ((SELECT public.app_has_perm('attachments.create')) AND (SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id)));
ALTER POLICY attachments_update ON public.attachments
  USING ((SELECT public.app_has_perm('attachments.update')) AND (SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('attachments.update')) AND (SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id)));
ALTER POLICY attachments_delete ON public.attachments
  USING ((SELECT public.app_has_perm('attachments.delete')) AND (SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id)));
