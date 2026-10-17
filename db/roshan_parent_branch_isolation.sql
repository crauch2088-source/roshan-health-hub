-- Focused parent-branch isolation for child tables without branch_id.
-- This source migration is not production-applied; migration replay parity is a release gate.
REVOKE ALL ON FUNCTION private.app_has_patient_branch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_patient_branch(uuid) TO authenticated;
REVOKE ALL ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_procedure_order_branch_access(_order_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.procedure_orders AS po
    WHERE po.id = _order_id
      AND private.app_has_attachment_branch_access(po.patient_id, po.visit_id)
  )
$function$;
REVOKE ALL ON FUNCTION private.app_has_procedure_order_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_procedure_order_branch_access(uuid) TO authenticated;

ALTER POLICY certificates_select ON public.certificates
  USING (
    (SELECT public.app_has_perm('certificates.read'))
    AND (SELECT private.app_has_attachment_branch_access(certificates.patient_id, certificates.visit_id))
  );
ALTER POLICY certificates_insert ON public.certificates
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.create'))
    AND (SELECT private.app_has_attachment_branch_access(certificates.patient_id, certificates.visit_id))
  );
ALTER POLICY certificates_update ON public.certificates
  USING (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_attachment_branch_access(certificates.patient_id, certificates.visit_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_attachment_branch_access(certificates.patient_id, certificates.visit_id))
  );
ALTER POLICY certificates_delete ON public.certificates
  USING (
    (SELECT public.app_has_perm('certificates.delete'))
    AND (SELECT private.app_has_attachment_branch_access(certificates.patient_id, certificates.visit_id))
  );

ALTER POLICY medical_certificates_select ON public.medical_certificates
  USING (
    (SELECT public.app_has_perm('certificates.read'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );
ALTER POLICY medical_certificates_insert ON public.medical_certificates
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.create'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );
ALTER POLICY medical_certificates_update ON public.medical_certificates
  USING (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );
ALTER POLICY medical_certificates_delete ON public.medical_certificates
  USING (
    (SELECT public.app_has_perm('certificates.delete'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );

ALTER POLICY patient_discounts_select ON public.patient_discounts
  USING (
    (
      (SELECT public.app_has_perm('billing.read'))
      OR (SELECT public.app_has_perm('patients.read'))
    )
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );
ALTER POLICY patient_discounts_insert ON public.patient_discounts
  WITH CHECK (
    (SELECT public.app_has_perm('billing.create'))
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );
ALTER POLICY patient_discounts_update ON public.patient_discounts
  USING (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  )
  WITH CHECK (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );
ALTER POLICY patient_discounts_delete ON public.patient_discounts
  USING (
    (SELECT public.app_has_perm('billing.delete'))
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );

ALTER POLICY procedure_orders_select ON public.procedure_orders
  USING (
    (SELECT public.app_has_perm('procedures.read'))
    AND (SELECT private.app_has_attachment_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );
ALTER POLICY procedure_orders_insert ON public.procedure_orders
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.create'))
    AND (SELECT private.app_has_attachment_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );
ALTER POLICY procedure_orders_update ON public.procedure_orders
  USING (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_attachment_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_attachment_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );
ALTER POLICY procedure_orders_delete ON public.procedure_orders
  USING (
    (SELECT public.app_has_perm('procedures.delete'))
    AND (SELECT private.app_has_attachment_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );

ALTER POLICY procedure_results_select ON public.procedure_results
  USING (
    (SELECT public.app_has_perm('procedures.read'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );
ALTER POLICY procedure_results_insert ON public.procedure_results
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.create'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );
ALTER POLICY procedure_results_update ON public.procedure_results
  USING (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );
ALTER POLICY procedure_results_delete ON public.procedure_results
  USING (
    (SELECT public.app_has_perm('procedures.delete'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );
