-- Regression for insurance approval/payment values silently rounded by numeric(14,2).
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
SELECT set_config('test.has_perm','true',true);
SELECT set_config('test.super_admin','true',true);

DO $test$
DECLARE
  claim_id uuid := '30000000-0000-0000-0000-000000000001';
  rejected boolean;
  before_payments integer;
  before_ledger integer;
  actual_approved numeric;
  actual_paid numeric;
  payment_id uuid;
  payment_amount numeric;
  ledger_amount numeric;
BEGIN
  PERFORM public.update_insurance_claim_status(claim_id, 'submitted', NULL, NULL);
  PERFORM public.update_insurance_claim_status(claim_id, 'under_review', NULL, NULL);

  rejected := false;
  BEGIN
    PERFORM public.update_insurance_claim_status(claim_id, 'approved', 99.991, NULL);
    RAISE EXCEPTION 'test failed: over-precision approved amount was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'over-precision approval was not rejected'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.update_insurance_claim_status(claim_id, 'approved', 'NaN'::numeric, NULL);
    RAISE EXCEPTION 'test failed: NaN approved amount was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'NaN approval was not rejected'; END IF;

  IF (SELECT status FROM public.insurance_claims WHERE id=claim_id) <> 'under_review'
     OR (SELECT approved_amount FROM public.insurance_claims WHERE id=claim_id) IS NOT NULL THEN
    RAISE EXCEPTION 'invalid approval attempts mutated the claim';
  END IF;

  PERFORM public.update_insurance_claim_status(claim_id, 'approved', 99.99, 'valid two-decimal approval');
  SELECT approved_amount INTO actual_approved FROM public.insurance_claims WHERE id=claim_id;
  IF actual_approved IS DISTINCT FROM 99.99::numeric THEN RAISE EXCEPTION 'valid approved amount mismatch: %', actual_approved; END IF;

  SELECT count(*) INTO before_payments FROM public.insurance_claim_payments;
  SELECT count(*) INTO before_ledger FROM public.test_ledger_posts;
  rejected := false;
  BEGIN
    PERFORM public.post_insurance_claim_payment(claim_id, 1.001, 'bank', 'over-precision');
    RAISE EXCEPTION 'test failed: over-precision payment was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'over-precision payment was not rejected'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.post_insurance_claim_payment(claim_id, 'NaN'::numeric, 'bank', 'invalid NaN');
    RAISE EXCEPTION 'test failed: NaN payment was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'NaN payment was not rejected'; END IF;

  IF (SELECT count(*) FROM public.insurance_claim_payments) <> before_payments
     OR (SELECT count(*) FROM public.test_ledger_posts) <> before_ledger THEN
    RAISE EXCEPTION 'invalid payment attempts wrote payment or ledger rows';
  END IF;
  IF (SELECT paid_amount FROM public.insurance_claims WHERE id=claim_id) <> 0 THEN
    RAISE EXCEPTION 'invalid payment attempts changed paid_amount';
  END IF;

  payment_id := public.post_insurance_claim_payment(claim_id, 1.01, 'bank', 'valid two-decimal payment');
  SELECT amount INTO payment_amount FROM public.insurance_claim_payments WHERE id=payment_id;
  SELECT amount INTO ledger_amount FROM public.test_ledger_posts WHERE source_id=payment_id AND source_type='insurance_claim_payment';
  SELECT paid_amount INTO actual_paid FROM public.insurance_claims WHERE id=claim_id;
  IF payment_amount IS DISTINCT FROM 1.01::numeric THEN RAISE EXCEPTION 'payment amount mismatch: %', payment_amount; END IF;
  IF ledger_amount IS DISTINCT FROM payment_amount THEN RAISE EXCEPTION 'ledger/payment mismatch: ledger %, payment %', ledger_amount, payment_amount; END IF;
  IF actual_paid IS DISTINCT FROM 1.01::numeric THEN RAISE EXCEPTION 'claim paid_amount mismatch: %', actual_paid; END IF;
END
$test$;

RESET ROLE;
ROLLBACK;
