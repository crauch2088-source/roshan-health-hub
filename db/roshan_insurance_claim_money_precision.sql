-- Preserve the live branch/permission/ledger contracts while rejecting silent numeric(14,2) rounding.
BEGIN;

CREATE OR REPLACE FUNCTION public.update_insurance_claim_status(
  _claim_id uuid,
  _new_status text,
  _approved_amount numeric DEFAULT NULL::numeric,
  _notes text DEFAULT NULL::text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  claim public.insurance_claims;
  uid uuid;
BEGIN
  IF NOT public.app_has_perm('insurance.update') THEN
    RAISE EXCEPTION 'not authorised to update insurance claims';
  END IF;

  SELECT * INTO claim FROM public.insurance_claims
   WHERE id = _claim_id AND deleted_at IS NULL FOR UPDATE;
  IF claim.id IS NULL THEN RAISE EXCEPTION 'claim not found'; END IF;
  IF NOT public.is_super_admin() AND NOT private.app_has_claim_branch(_claim_id) THEN
    RAISE EXCEPTION 'cross-branch insurance claim access denied';
  END IF;

  IF (claim.status, _new_status) NOT IN (
    ('draft','submitted'), ('submitted','under_review'),
    ('under_review','approved'), ('under_review','partially_approved'),
    ('under_review','rejected'), ('approved','paid'), ('partially_approved','paid')
  ) THEN
    RAISE EXCEPTION 'invalid claim status transition: % -> %', claim.status, _new_status;
  END IF;

  IF _new_status IN ('approved','partially_approved') AND _approved_amount IS NULL THEN
    RAISE EXCEPTION 'approved_amount is required when approving a claim';
  END IF;

  IF _new_status IN ('approved','partially_approved') AND (
       _approved_amount::text IN ('NaN','Infinity','-Infinity')
       OR _approved_amount < 0
       OR _approved_amount > claim.submitted_amount
       OR _approved_amount <> round(_approved_amount, 2)
  ) THEN
    RAISE EXCEPTION 'approved amount must be finite, within submitted amount, and have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  uid := public.current_app_user_id();
  UPDATE public.insurance_claims
     SET status = _new_status,
         approved_amount = CASE WHEN _new_status IN ('approved','partially_approved') THEN _approved_amount ELSE approved_amount END,
         submitted_at = CASE WHEN _new_status = 'submitted' THEN now() ELSE submitted_at END,
         decided_at = CASE WHEN _new_status IN ('approved','partially_approved','rejected') THEN now() ELSE decided_at END,
         notes = COALESCE(_notes, notes),
         updated_by = uid,
         updated_at = now()
   WHERE id = _claim_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.post_insurance_claim_payment(
  _claim_id uuid,
  _amount numeric,
  _method text DEFAULT 'bank'::text,
  _reference text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  claim public.insurance_claims;
  pay_id uuid;
  uid uuid;
  outstanding numeric;
  new_paid numeric;
  claim_branch uuid;
BEGIN
  IF NOT public.app_has_perm('insurance.update') THEN
    RAISE EXCEPTION 'not authorised to record insurance payments';
  END IF;

  IF _amount IS NULL
     OR _amount::text IN ('NaN','Infinity','-Infinity')
     OR _amount <= 0
     OR _amount <> round(_amount, 2) THEN
    RAISE EXCEPTION 'payment amount must be finite, positive, and have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  SELECT c.* INTO claim
    FROM public.insurance_claims AS c
    JOIN public.invoices AS i ON i.id = c.invoice_id
   WHERE c.id = _claim_id AND c.deleted_at IS NULL
   FOR UPDATE OF c;
  IF claim.id IS NULL THEN RAISE EXCEPTION 'claim not found'; END IF;

  SELECT i.branch_id INTO claim_branch FROM public.invoices AS i WHERE i.id = claim.invoice_id;
  IF NOT public.is_super_admin() AND NOT private.app_has_claim_branch(_claim_id) THEN
    RAISE EXCEPTION 'cross-branch insurance claim access denied';
  END IF;
  IF claim.status NOT IN ('approved','partially_approved','paid') THEN
    RAISE EXCEPTION 'claim must be approved before recording a payment (current status: %)', claim.status;
  END IF;

  outstanding := GREATEST(COALESCE(claim.approved_amount, 0) - COALESCE(claim.paid_amount, 0), 0);
  IF _amount > outstanding THEN
    RAISE EXCEPTION 'payment (%) exceeds outstanding approved balance (%)', _amount, outstanding;
  END IF;

  uid := public.current_app_user_id();
  INSERT INTO public.insurance_claim_payments(claim_id, amount, payment_method, reference, created_by)
  VALUES (_claim_id, _amount, COALESCE(_method, 'bank'), _reference, uid)
  RETURNING id INTO pay_id;

  SELECT COALESCE(SUM(amount), 0) INTO new_paid
    FROM public.insurance_claim_payments WHERE claim_id = _claim_id AND deleted_at IS NULL;
  UPDATE public.insurance_claims
     SET paid_amount = new_paid,
         status = CASE WHEN new_paid >= COALESCE(approved_amount, 0) AND approved_amount IS NOT NULL THEN 'paid' ELSE status END,
         paid_at = CASE WHEN new_paid >= COALESCE(approved_amount, 0) AND approved_amount IS NOT NULL THEN now() ELSE paid_at END,
         updated_by = uid, updated_at = now()
   WHERE id = _claim_id;

  PERFORM public.fn_ledger_post(
    'income', abs(_amount), COALESCE(_method, 'bank'), 'insurance_settlement',
    'Insurance claim payment — ' || claim.claim_number, 'insurance_claim_payment', pay_id, now(), claim_branch
  );
  RETURN pay_id;
END;
$function$;

COMMIT;
