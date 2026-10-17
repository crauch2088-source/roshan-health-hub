-- Enforce policy/plan validity when calculating coverage estimates.
-- Apply only after reviewing the reconciled insurance migration history.
CREATE OR REPLACE FUNCTION public.fn_calculate_insurance_coverage(
  _patient_insurance_id uuid,
  _service_type text,
  _reference_id uuid,
  _generic_name text,
  _gross_amount numeric
)
RETURNS TABLE (
  covered_amount numeric,
  patient_amount numeric,
  requires_prior_auth boolean,
  excluded boolean,
  coverage_rule_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_plan_id uuid;
  v_policy_company_id uuid;
  v_patient_id uuid;
  v_policy_status text;
  v_policy_start date;
  v_policy_expiry date;
  v_patient_branch uuid;
  v_user_branch uuid;
  v_plan_company_id uuid;
  v_plan_default numeric := 0;
  v_plan_requires_prior_auth boolean := false;
  v_rule_id uuid;
  v_rule_percent numeric;
  v_rule_fixed numeric;
  v_rule_requires_prior_auth boolean;
  v_rule_excluded boolean;
  v_covered numeric := 0;
  v_requires_prior_auth boolean := false;
  v_excluded boolean := false;
BEGIN
  IF NOT COALESCE(private.app_has_perm('insurance.read'), false) THEN
    RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
  END IF;

  IF _gross_amount IS NULL
     OR _gross_amount::text IN ('NaN', 'Infinity', '-Infinity')
     OR _gross_amount < 0 THEN
    RAISE EXCEPTION 'gross amount must be finite and non-negative'
      USING ERRCODE = '22023';
  END IF;

  IF _service_type IS NULL
     OR _service_type NOT IN ('consultation', 'lab', 'medicine') THEN
    RAISE EXCEPTION 'unsupported insurance coverage service type'
      USING ERRCODE = '22023';
  END IF;

  IF _gross_amount <> round(_gross_amount, 2) THEN
    RAISE EXCEPTION 'gross amount must have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  -- A policy is usable only during its validity window and while active.
  SELECT pi.plan_id, pi.company_id, pi.patient_id, pi.status, pi.start_date, pi.expiry_date
    INTO v_plan_id, v_policy_company_id, v_patient_id, v_policy_status, v_policy_start, v_policy_expiry
    FROM public.patient_insurance pi
   WHERE pi.id = _patient_insurance_id
     AND pi.deleted_at IS NULL;

  IF NOT FOUND THEN
    covered_amount := 0;
    patient_amount := _gross_amount;
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  IF NOT COALESCE(private.is_super_admin(), false) THEN
    SELECT p.branch_id
      INTO v_patient_branch
      FROM public.patients p
     WHERE p.id = v_patient_id
       AND p.deleted_at IS NULL;

    SELECT u.branch_id
      INTO v_user_branch
      FROM public.users u
     WHERE u.auth_user_id = auth.uid()
       AND COALESCE(u.active, true) = true
       AND u.deleted_at IS NULL
     LIMIT 1;

    IF v_patient_branch IS NULL
       OR v_user_branch IS NULL
       OR v_patient_branch IS DISTINCT FROM v_user_branch THEN
      RAISE EXCEPTION 'cross-branch insurance coverage access denied'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF v_policy_status IS DISTINCT FROM 'active'
     OR v_policy_start > CURRENT_DATE
     OR (v_policy_expiry IS NOT NULL AND v_policy_expiry < CURRENT_DATE) THEN
    covered_amount := 0;
    patient_amount := _gross_amount;
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Require the plan and company to be active, and require the selected plan
  -- to belong to the company recorded on this patient's policy.
  SELECT p.company_id, p.default_coverage_percent, p.requires_prior_auth
    INTO v_plan_company_id, v_plan_default, v_plan_requires_prior_auth
    FROM public.insurance_plans p
    JOIN public.insurance_companies c
      ON c.id = p.company_id
     AND c.active IS TRUE
     AND c.deleted_at IS NULL
   WHERE p.id = v_plan_id
     AND p.company_id = v_policy_company_id
     AND p.active IS TRUE
     AND p.deleted_at IS NULL;

  IF NOT FOUND OR v_plan_company_id IS DISTINCT FROM v_policy_company_id THEN
    covered_amount := 0;
    patient_amount := _gross_amount;
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 1) Most-specific service/reference rule.
  IF _reference_id IS NOT NULL THEN
    SELECT r.id, r.coverage_percent, r.fixed_amount,
           r.requires_prior_auth, r.excluded
      INTO v_rule_id, v_rule_percent, v_rule_fixed,
           v_rule_requires_prior_auth, v_rule_excluded
      FROM public.insurance_coverage_rules r
     WHERE r.plan_id = v_plan_id
       AND r.service_type = _service_type
       AND r.reference_id = _reference_id
       AND r.deleted_at IS NULL
     LIMIT 1;
  END IF;

  -- 2) Generic-name medicine rule.
  IF v_rule_id IS NULL
     AND _service_type = 'medicine'
     AND NULLIF(btrim(_generic_name), '') IS NOT NULL THEN
    SELECT r.id, r.coverage_percent, r.fixed_amount,
           r.requires_prior_auth, r.excluded
      INTO v_rule_id, v_rule_percent, v_rule_fixed,
           v_rule_requires_prior_auth, v_rule_excluded
      FROM public.insurance_coverage_rules r
     WHERE r.plan_id = v_plan_id
       AND r.service_type = 'medicine'
       AND r.generic_name IS NOT NULL
       AND lower(r.generic_name) = lower(btrim(_generic_name))
       AND r.reference_id IS NULL
       AND r.deleted_at IS NULL
     LIMIT 1;
  END IF;

  -- 3) Plan-wide default for the service type.
  IF v_rule_id IS NULL THEN
    SELECT r.id, r.coverage_percent, r.fixed_amount,
           r.requires_prior_auth, r.excluded
      INTO v_rule_id, v_rule_percent, v_rule_fixed,
           v_rule_requires_prior_auth, v_rule_excluded
      FROM public.insurance_coverage_rules r
     WHERE r.plan_id = v_plan_id
       AND r.service_type = _service_type
       AND r.reference_id IS NULL
       AND r.generic_name IS NULL
       AND r.deleted_at IS NULL
     LIMIT 1;
  END IF;

  IF v_rule_id IS NOT NULL THEN
    v_requires_prior_auth := COALESCE(v_rule_requires_prior_auth, false);
    IF COALESCE(v_rule_excluded, false) THEN
      v_excluded := true;
      v_covered := 0;
    ELSIF v_rule_fixed IS NOT NULL THEN
      IF v_rule_fixed::text IN ('NaN', 'Infinity', '-Infinity') OR v_rule_fixed < 0 THEN
        RAISE EXCEPTION 'fixed insurance coverage must be finite and non-negative';
      END IF;
      v_covered := LEAST(v_rule_fixed, _gross_amount);
    ELSE
      v_covered := ROUND(_gross_amount * COALESCE(v_rule_percent, 0) / 100, 2);
    END IF;
  ELSE
    v_requires_prior_auth := COALESCE(v_plan_requires_prior_auth, false);
    v_covered := ROUND(_gross_amount * COALESCE(v_plan_default, 0) / 100, 2);
  END IF;

  v_covered := GREATEST(0, LEAST(v_covered, _gross_amount));
  covered_amount := v_covered;
  patient_amount := _gross_amount - v_covered;
  requires_prior_auth := v_requires_prior_auth;
  excluded := v_excluded;
  coverage_rule_id := v_rule_id;
  RETURN NEXT;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_calculate_insurance_coverage(uuid, text, uuid, text, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_calculate_insurance_coverage(uuid, text, uuid, text, numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_calculate_insurance_coverage(uuid, text, uuid, text, numeric) TO authenticated;

