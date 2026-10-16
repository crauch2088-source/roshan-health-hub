-- Proposed follow-up migration. Do not apply until the recovered migration sequence
-- is reconciled and these RLS changes pass isolated cross-branch tests.
--
-- The live policies on prescriptions, prescription_items, and lab_order_items check
-- permissions but not the branch of the parent patient/visit/order. These tables have
-- no branch_id of their own, so their policy must derive branch access from the parent.

CREATE OR REPLACE FUNCTION private.app_has_lab_order_branch_access(_order_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.lab_orders AS lo
    LEFT JOIN public.visits AS v ON v.id = lo.visit_id
    LEFT JOIN public.patients AS p ON p.id = lo.patient_id
    WHERE lo.id = _order_id
      AND private.app_has_branch_access(COALESCE(lo.branch_id, v.branch_id, p.branch_id))
  )
$function$;

REVOKE ALL ON FUNCTION private.app_has_lab_order_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_lab_order_branch_access(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_prescription_branch_access(_prescription_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.prescriptions AS p
    WHERE p.id = _prescription_id
      AND private.app_has_attachment_branch_access(p.patient_id, p.visit_id)
  )
$function$;

REVOKE ALL ON FUNCTION private.app_has_prescription_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_prescription_branch_access(uuid) TO authenticated;

ALTER POLICY prescriptions_select ON public.prescriptions
  USING (
    (
      (SELECT public.app_has_perm('pharmacy.read'))
      OR (SELECT public.app_has_perm('emr.read'))
    )
    AND (SELECT private.app_has_attachment_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_insert ON public.prescriptions
  WITH CHECK (
    (
      (SELECT public.app_has_perm('pharmacy.create'))
      OR (SELECT public.app_has_perm('emr.create'))
    )
    AND (SELECT private.app_has_attachment_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_update ON public.prescriptions
  USING (
    (
      (SELECT public.app_has_perm('pharmacy.update'))
      OR (SELECT public.app_has_perm('emr.update'))
    )
    AND (SELECT private.app_has_attachment_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  )
  WITH CHECK (
    (
      (SELECT public.app_has_perm('pharmacy.update'))
      OR (SELECT public.app_has_perm('emr.update'))
    )
    AND (SELECT private.app_has_attachment_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_delete ON public.prescriptions
  USING (
    (
      (SELECT public.app_has_perm('pharmacy.delete'))
      OR (SELECT public.app_has_perm('emr.delete'))
    )
    AND (SELECT private.app_has_attachment_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );

ALTER POLICY prescription_items_select ON public.prescription_items
  USING (
    (
      (SELECT public.app_has_perm('pharmacy.read'))
      OR (SELECT public.app_has_perm('emr.read'))
    )
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_insert ON public.prescription_items
  WITH CHECK (
    (
      (SELECT public.app_has_perm('pharmacy.create'))
      OR (SELECT public.app_has_perm('emr.create'))
    )
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_update ON public.prescription_items
  USING (
    (
      (SELECT public.app_has_perm('pharmacy.update'))
      OR (SELECT public.app_has_perm('emr.update'))
    )
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  )
  WITH CHECK (
    (
      (SELECT public.app_has_perm('pharmacy.update'))
      OR (SELECT public.app_has_perm('emr.update'))
    )
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_delete ON public.prescription_items
  USING (
    (
      (SELECT public.app_has_perm('pharmacy.delete'))
      OR (SELECT public.app_has_perm('emr.delete'))
    )
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );

ALTER POLICY lab_order_items_select ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.read'))
    AND (SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_insert ON public.lab_order_items
  WITH CHECK (
    (SELECT public.app_has_perm('lab.create'))
    AND (SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_update ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_delete ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.delete'))
    AND (SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id))
  );
