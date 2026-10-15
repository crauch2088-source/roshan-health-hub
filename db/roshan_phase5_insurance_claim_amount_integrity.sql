-- Roshan: enforce insurance claim item amount invariants at the database boundary.
-- Review and test on a disposable/staging database before applying to production.
-- This is additive to the existing phase-5 function; it does not alter existing rows.

CREATE OR REPLACE FUNCTION public.create_insurance_claim(
  _patient_insurance_id uuid,
  _invoice_id uuid,
  _items jsonb,
  _notes text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  claim_id uuid;
  uid uuid;
  total numeric := 0;
  item jsonb;
  pi_patient_id uuid;
  invoice_patient_id uuid;
  invoice_branch uuid;
  user_branch uuid;
  item_gross numeric;
  item_covered numeric;
  item_patient numeric;
  item_service_type text;
  item_description text;
BEGIN
  IF NOT public.app_has_perm('insurance.create') THEN
    RAISE EXCEPTION 'not authorised to create insurance claims';
  END IF;

  IF _items IS NULL OR jsonb_typeof(_items) <> 'array' THEN
    RAISE EXCEPTION 'claim items must be a JSON array';
  END IF;

  IF jsonb_array_length(_items) = 0 THEN
    RAISE EXCEPTION 'a claim needs at least one item';
  END IF;

  uid := public.current_app_user_id();

  SELECT pi.patient_id INTO pi_patient_id
  FROM public.patient_insurance pi
  JOIN public.insurance_plans p
    ON p.id = pi.plan_id
   AND p.company_id = pi.company_id
   AND p.active IS TRUE
   AND p.deleted_at IS NULL
  JOIN public.insurance_companies c
    ON c.id = pi.company_id
   AND c.active IS TRUE
   AND c.deleted_at IS NULL
  WHERE pi.id = _patient_insurance_id
    AND pi.deleted_at IS NULL
    AND pi.status = 'active'
    AND pi.start_date <= CURRENT_DATE
    AND (pi.expiry_date IS NULL OR pi.expiry_date >= CURRENT_DATE);

  IF pi_patient_id IS NULL THEN
    RAISE EXCEPTION 'active patient insurance not found';
  END IF;

  SELECT patient_id, branch_id INTO invoice_patient_id, invoice_branch
  FROM public.invoices
  WHERE id = _invoice_id AND deleted_at IS NULL;

  IF invoice_patient_id IS NULL THEN
    RAISE EXCEPTION 'invoice not found';
  END IF;

  IF pi_patient_id <> invoice_patient_id THEN
    RAISE EXCEPTION 'patient insurance does not belong to invoice patient';
  END IF;

  SELECT branch_id INTO user_branch
  FROM public.users
  WHERE id = uid;

  IF NOT public.is_super_admin()
     AND (user_branch IS NULL OR invoice_branch IS DISTINCT FROM user_branch) THEN
    RAISE EXCEPTION 'cross-branch insurance claim access denied';
  END IF;

  -- Validate every item before inserting the parent claim. The function call is
  -- atomic, but validating first makes the intended financial invariant explicit.
  FOR item IN SELECT value FROM jsonb_array_elements(_items) AS x(value)
  LOOP
    IF jsonb_typeof(item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each claim item must be a JSON object';
    END IF;

    IF jsonb_typeof(item->'gross_amount') IS DISTINCT FROM 'number'
       OR jsonb_typeof(item->'covered_amount') IS DISTINCT FROM 'number'
       OR jsonb_typeof(item->'patient_amount') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'claim item amounts must be JSON numbers';
    END IF;

    item_service_type := item->>'service_type';
    item_description := btrim(COALESCE(item->>'description', ''));

    IF item_service_type IS NULL
       OR item_service_type NOT IN ('consultation', 'lab', 'medicine') THEN
      RAISE EXCEPTION 'unsupported insurance claim service type';
    END IF;

    IF item_description = '' THEN
      RAISE EXCEPTION 'claim item description is required';
    END IF;

    BEGIN
      item_gross := (item->>'gross_amount')::numeric;
      item_covered := (item->>'covered_amount')::numeric;
      item_patient := (item->>'patient_amount')::numeric;
    EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
      RAISE EXCEPTION 'invalid claim item amount';
    END;

    -- Reject special numeric values and precision that would be silently
    -- rounded when persisted as monetary amounts.
    IF item_gross::text IN ('NaN', 'Infinity', '-Infinity')
       OR item_covered::text IN ('NaN', 'Infinity', '-Infinity')
       OR item_patient::text IN ('NaN', 'Infinity', '-Infinity') THEN
      RAISE EXCEPTION 'claim item amounts must be finite';
    END IF;

    IF item_gross <= 0 OR item_covered < 0 OR item_patient < 0 THEN
      RAISE EXCEPTION 'claim gross amount must be positive and split amounts non-negative';
    END IF;

    IF item_gross <> round(item_gross, 2)
       OR item_covered <> round(item_covered, 2)
       OR item_patient <> round(item_patient, 2) THEN
      RAISE EXCEPTION 'claim item amounts must have at most two decimal places';
    END IF;

    IF item_covered > item_gross OR item_patient > item_gross THEN
      RAISE EXCEPTION 'claim covered and patient amounts cannot exceed gross amount';
    END IF;

    IF item_covered + item_patient <> item_gross THEN
      RAISE EXCEPTION 'claim item covered and patient amounts must equal gross amount';
    END IF;

    total := total + item_gross;
  END LOOP;

  INSERT INTO public.insurance_claims (
    patient_insurance_id, invoice_id, status, submitted_amount, notes, created_by
  )
  VALUES (_patient_insurance_id, _invoice_id, 'draft', total, _notes, uid)
  RETURNING id INTO claim_id;

  FOR item IN SELECT value FROM jsonb_array_elements(_items) AS x(value)
  LOOP
    INSERT INTO public.insurance_claim_items (
      claim_id, service_type, reference_id, description,
      gross_amount, covered_amount, patient_amount, coverage_rule_id
    )
    VALUES (
      claim_id,
      item->>'service_type',
      NULLIF(item->>'reference_id', '')::uuid,
      btrim(COALESCE(item->>'description', '')),
      (item->>'gross_amount')::numeric,
      (item->>'covered_amount')::numeric,
      (item->>'patient_amount')::numeric,
      NULLIF(item->>'coverage_rule_id', '')::uuid
    );
  END LOOP;

  RETURN claim_id;
END;
$function$;
