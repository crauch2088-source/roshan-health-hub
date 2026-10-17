-- Source-only RLS hardening for insurance prior authorizations.
-- Apply only after the synthetic PostgreSQL 17 regression and migration review pass.
BEGIN;

CREATE OR REPLACE FUNCTION private.app_has_prior_authorization_branch_access(_patient_insurance_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.patient_insurance AS pi
    WHERE pi.id = _patient_insurance_id
      AND private.app_has_patient_branch(pi.patient_id)
  )
$function$;

REVOKE ALL ON FUNCTION private.app_has_prior_authorization_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_prior_authorization_branch_access(uuid) TO authenticated;

DROP POLICY IF EXISTS insurance_prior_authorizations_sel ON public.insurance_prior_authorizations;
CREATE POLICY insurance_prior_authorizations_sel
  ON public.insurance_prior_authorizations FOR SELECT TO authenticated
  USING (app_has_perm('insurance.read') AND private.app_has_prior_authorization_branch_access(patient_insurance_id));

DROP POLICY IF EXISTS insurance_prior_authorizations_ins ON public.insurance_prior_authorizations;
CREATE POLICY insurance_prior_authorizations_ins
  ON public.insurance_prior_authorizations FOR INSERT TO authenticated
  WITH CHECK (app_has_perm('insurance.create') AND private.app_has_prior_authorization_branch_access(patient_insurance_id));

DROP POLICY IF EXISTS insurance_prior_authorizations_upd ON public.insurance_prior_authorizations;
CREATE POLICY insurance_prior_authorizations_upd
  ON public.insurance_prior_authorizations FOR UPDATE TO authenticated
  USING (app_has_perm('insurance.update') AND private.app_has_prior_authorization_branch_access(patient_insurance_id))
  WITH CHECK (app_has_perm('insurance.update') AND private.app_has_prior_authorization_branch_access(patient_insurance_id));

COMMIT;
