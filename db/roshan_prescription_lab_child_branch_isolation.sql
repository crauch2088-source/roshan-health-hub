-- Parent-branch isolation for prescriptions, prescription items, and lab-order items.
-- Source-only candidate: never apply to live Supabase before migration replay parity review.
REVOKE ALL ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) TO authenticated;
REVOKE ALL ON FUNCTION private.app_has_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_branch_access(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_prescription_parent_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT private.app_has_attachment_branch_access(_patient_id, _visit_id)
    AND (
      _visit_id IS NULL OR _patient_id IS NULL
      OR EXISTS (SELECT 1 FROM public.visits v WHERE v.id=_visit_id AND v.patient_id=_patient_id)
    )
$function$;
REVOKE ALL ON FUNCTION private.app_has_prescription_parent_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_prescription_parent_branch_access(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_prescription_branch_access(_prescription_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.prescriptions p
    WHERE p.id=_prescription_id
      AND private.app_has_prescription_parent_branch_access(p.patient_id, p.visit_id)
  )
$function$;
REVOKE ALL ON FUNCTION private.app_has_prescription_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_prescription_branch_access(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_lab_order_item_branch_access(_order_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.lab_orders lo
    WHERE lo.id=_order_id
      AND private.app_has_branch_access(lo.branch_id)
      AND private.app_has_attachment_branch_access(lo.patient_id, lo.visit_id)
  )
$function$;
REVOKE ALL ON FUNCTION private.app_has_lab_order_item_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_lab_order_item_branch_access(uuid) TO authenticated;

ALTER POLICY prescriptions_select ON public.prescriptions
  USING (
    ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_insert ON public.prescriptions
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_update ON public.prescriptions
  USING (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  )
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_delete ON public.prescriptions
  USING (
    ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );

ALTER POLICY prescription_items_select ON public.prescription_items
  USING (
    ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_insert ON public.prescription_items
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_update ON public.prescription_items
  USING (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  )
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_delete ON public.prescription_items
  USING (
    ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );

ALTER POLICY lab_order_items_select ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.read'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_insert ON public.lab_order_items
  WITH CHECK (
    (SELECT public.app_has_perm('lab.create'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_update ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_delete ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.delete'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );
