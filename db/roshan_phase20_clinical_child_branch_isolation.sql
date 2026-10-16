-- Proposed follow-up migration. Do not apply until the recovered migration sequence
-- is reconciled and these RLS changes pass isolated cross-branch tests.
--
-- The live policies on prescriptions, prescription_items, and lab_order_items check
-- permissions but not the branch of the parent patient/visit/order. These tables have
-- no branch_id of their own, so their policy must derive branch access from the parent.

-- A lab order's visit, when supplied, must belong to the same patient_id.
-- This is a linkage-integrity invariant; branch assignment remains controlled by
-- lab_orders.branch_id to preserve the explicit lab-order branch context.
CREATE OR REPLACE FUNCTION private.lab_order_parent_ids_match(_patient_id uuid, _visit_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN _visit_id IS NULL THEN true
    ELSE EXISTS (
      SELECT 1
      FROM public.visits AS v
      WHERE v.id = _visit_id
        AND (_patient_id IS NULL OR v.patient_id = _patient_id)
    )
  END
$function$;

REVOKE ALL ON FUNCTION private.lab_order_parent_ids_match(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.lab_order_parent_ids_match(uuid, uuid) TO authenticated;

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
      AND private.lab_order_parent_ids_match(lo.patient_id, lo.visit_id)
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

-- Keep the existing lab-order branch context, but prevent a lab order from
-- being linked to a visit that belongs to a different patient.
ALTER POLICY lab_orders_select ON public.lab_orders
  USING (
    (SELECT public.app_has_perm('lab.read'))
    AND (SELECT private.app_has_branch_access(lab_orders.branch_id))
    AND (SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id))
  );
ALTER POLICY lab_orders_insert ON public.lab_orders
  WITH CHECK (
    (SELECT public.app_has_perm('lab.create'))
    AND (SELECT private.app_has_branch_access(lab_orders.branch_id))
    AND (SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id))
  );
ALTER POLICY lab_orders_update ON public.lab_orders
  USING (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_branch_access(lab_orders.branch_id))
    AND (SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_branch_access(lab_orders.branch_id))
    AND (SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id))
  );
ALTER POLICY lab_orders_delete ON public.lab_orders
  USING (
    (SELECT public.app_has_perm('lab.delete'))
    AND (SELECT private.app_has_branch_access(lab_orders.branch_id))
    AND (SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id))
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

CREATE OR REPLACE FUNCTION private.app_has_prior_authorization_branch(_patient_insurance_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false)
    OR EXISTS (
      SELECT 1
      FROM public.patient_insurance AS pi
      WHERE pi.id = _patient_insurance_id
        AND private.app_has_patient_branch(pi.patient_id)
    )
$function$;

REVOKE ALL ON FUNCTION private.app_has_prior_authorization_branch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_prior_authorization_branch(uuid) TO authenticated;

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

ALTER POLICY insurance_prior_authorizations_sel ON public.insurance_prior_authorizations
  USING (
    (SELECT public.app_has_perm('insurance.read'))
    AND (SELECT private.app_has_prior_authorization_branch(insurance_prior_authorizations.patient_insurance_id))
  );
ALTER POLICY insurance_prior_authorizations_ins ON public.insurance_prior_authorizations
  WITH CHECK (
    (SELECT public.app_has_perm('insurance.create'))
    AND (SELECT private.app_has_prior_authorization_branch(insurance_prior_authorizations.patient_insurance_id))
  );
ALTER POLICY insurance_prior_authorizations_upd ON public.insurance_prior_authorizations
  USING (
    (SELECT public.app_has_perm('insurance.update'))
    AND (SELECT private.app_has_prior_authorization_branch(insurance_prior_authorizations.patient_insurance_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('insurance.update'))
    AND (SELECT private.app_has_prior_authorization_branch(insurance_prior_authorizations.patient_insurance_id))
  );
