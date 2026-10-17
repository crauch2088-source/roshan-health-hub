-- PostgreSQL 17 regression for non-finite expense amounts.
-- Run after finance_only_rpc_writes_fixture.sql and roshan_post_expense_finite_amount.sql.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',true);
SELECT set_config('test.permissions','accounting.create',true);
SELECT set_config('test.super_admin','false',true);

DO $test$
DECLARE
  rejected boolean;
  expense_id uuid;
  actual_amount numeric;
  actual_branch uuid;
  before_count integer;
  after_count integer;
BEGIN
  SELECT count(*) INTO before_count FROM public.expenses;

  rejected := false;
  BEGIN
    PERFORM public.post_expense('other', 'NaN'::numeric, 'invalid NaN');
  EXCEPTION WHEN invalid_parameter_value THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'NaN expense amount was accepted'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.post_expense('other', 'Infinity'::numeric, 'invalid positive infinity');
  EXCEPTION WHEN invalid_parameter_value THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'positive infinity expense amount was accepted'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.post_expense('other', '-Infinity'::numeric, 'invalid negative infinity');
  EXCEPTION WHEN invalid_parameter_value THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'negative infinity expense amount was accepted'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.post_expense('other', 0, 'invalid zero');
  EXCEPTION WHEN invalid_parameter_value THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'zero expense amount was accepted'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.post_expense('other', -1, 'invalid negative');
  EXCEPTION WHEN invalid_parameter_value THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'negative expense amount was accepted'; END IF;

  rejected := false;
  BEGIN
    PERFORM public.post_expense('other', 17.251, 'invalid over-precision amount');
  EXCEPTION WHEN invalid_parameter_value THEN rejected := true;
  END;
  IF NOT rejected THEN RAISE EXCEPTION 'over-precision expense amount was accepted'; END IF;

  expense_id := public.post_expense('utilities', 17.25, 'valid regression expense');
  SELECT amount, branch_id INTO actual_amount, actual_branch
    FROM public.expenses WHERE id = expense_id;
  IF actual_amount IS DISTINCT FROM 17.25::numeric THEN
    RAISE EXCEPTION 'valid expense amount mismatch: %', actual_amount;
  END IF;
  IF actual_branch IS DISTINCT FROM '20000000-0000-0000-0000-000000000001'::uuid THEN
    RAISE EXCEPTION 'valid expense branch mismatch: %', actual_branch;
  END IF;

  SELECT count(*) INTO after_count FROM public.expenses;
  IF after_count <> before_count + 1 THEN
    RAISE EXCEPTION 'invalid expense attempts wrote rows: before %, after %', before_count, after_count;
  END IF;
END
$test$;

RESET ROLE;
ROLLBACK;
