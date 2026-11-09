-- Phase 59 behavioral assertions: persisted currency and ledger integrity are fail-closed.
SELECT pg_catalog.set_config('test.allow_perm', 'on', false);
SELECT pg_catalog.set_config('test.allow_branch', 'on', false);

DO $phase59$
DECLARE
  v_status record;
  v_state text;
  v_count integer;
BEGIN
  -- Legacy NULL provenance is visible for diagnosis but never receipt-complete.
  SELECT * INTO v_status
  FROM public.get_invoice_payment_receipt_status_v2(
    ARRAY['59000000-0000-0000-0000-000000000002'::uuid]
  );
  IF NOT FOUND
     OR v_status.payment_currency_code IS NOT NULL
     OR v_status.invoice_currency_code IS NOT NULL
     OR v_status.ledger_currency_code IS NOT NULL
     OR v_status.currency_matches IS DISTINCT FROM false
     OR v_status.ledger_matches IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'legacy NULL currency provenance was not reported fail-closed';
  END IF;

  -- A new, unreversed SDG payment must agree across invoice, payment and cashbox.
  INSERT INTO public.invoices (id, branch_id)
  VALUES (
    '59000000-0000-0000-0000-000000000010',
    '59000000-0000-0000-0000-000000000099'
  );
  INSERT INTO public.payments (id, invoice_id, amount, branch_id)
  VALUES (
    '59000000-0000-0000-0000-000000000011',
    '59000000-0000-0000-0000-000000000010',
    75,
    '59000000-0000-0000-0000-000000000099'
  );
  INSERT INTO public.cashbox_transactions (
    id, source_type, source_id, branch_id, amount
  ) VALUES (
    '59000000-0000-0000-0000-000000000012',
    'payment',
    '59000000-0000-0000-0000-000000000011',
    '59000000-0000-0000-0000-000000000099',
    75
  );

  SELECT * INTO v_status
  FROM public.get_invoice_payment_receipt_status_v2(
    ARRAY['59000000-0000-0000-0000-000000000011'::uuid]
  );
  IF NOT FOUND
     OR v_status.ledger_found IS DISTINCT FROM true
     OR v_status.ledger_matches IS DISTINCT FROM true
     OR v_status.currency_matches IS DISTINCT FROM true
     OR v_status.payment_currency_code IS DISTINCT FROM 'SDG'
     OR v_status.invoice_currency_code IS DISTINCT FROM 'SDG'
     OR v_status.ledger_currency_code IS DISTINCT FROM 'SDG' THEN
    RAISE EXCEPTION 'valid SDG payment provenance was not accepted';
  END IF;

  -- A reversed payment requires a matching, separately persisted SDG reversal.
  INSERT INTO public.invoices (id, branch_id)
  VALUES (
    '59000000-0000-0000-0000-000000000020',
    '59000000-0000-0000-0000-000000000099'
  );
  INSERT INTO public.payments (id, invoice_id, amount, branch_id)
  VALUES (
    '59000000-0000-0000-0000-000000000021',
    '59000000-0000-0000-0000-000000000020',
    100,
    '59000000-0000-0000-0000-000000000099'
  );
  INSERT INTO public.cashbox_transactions (
    id, source_type, source_id, branch_id, amount
  ) VALUES (
    '59000000-0000-0000-0000-000000000022',
    'payment',
    '59000000-0000-0000-0000-000000000021',
    '59000000-0000-0000-0000-000000000099',
    100
  );
  INSERT INTO public.cashbox_transactions (
    id, source_type, reversal_of, branch_id, amount
  ) VALUES (
    '59000000-0000-0000-0000-000000000023',
    'reversal',
    '59000000-0000-0000-0000-000000000022',
    '59000000-0000-0000-0000-000000000099',
    -100
  );
  PERFORM pg_catalog.set_config('roshan.cashbox_write', 'on', true);
  UPDATE public.cashbox_transactions
  SET is_reversed = true, reversal_reason = 'test reversal'
  WHERE id = '59000000-0000-0000-0000-000000000022';
  PERFORM pg_catalog.set_config('roshan.cashbox_write', 'off', true);
  UPDATE public.payments
  SET deleted_at = pg_catalog.now()
  WHERE id = '59000000-0000-0000-0000-000000000021';

  SELECT * INTO v_status
  FROM public.get_invoice_payment_receipt_status_v2(
    ARRAY['59000000-0000-0000-0000-000000000021'::uuid]
  );
  IF NOT FOUND
     OR v_status.ledger_matches IS DISTINCT FROM true
     OR v_status.ledger_is_reversed IS DISTINCT FROM true
     OR v_status.currency_matches IS DISTINCT FROM true
     OR v_status.reversal_currency_code IS DISTINCT FROM 'SDG'
     OR v_status.reversal_at IS NULL THEN
    RAISE EXCEPTION 'valid SDG reversal provenance was not accepted';
  END IF;

  -- A payment without a cashbox source must not be marked receipt-complete.
  INSERT INTO public.invoices (id, branch_id)
  VALUES (
    '59000000-0000-0000-0000-000000000030',
    '59000000-0000-0000-0000-000000000099'
  );
  INSERT INTO public.payments (id, invoice_id, amount, branch_id)
  VALUES (
    '59000000-0000-0000-0000-000000000031',
    '59000000-0000-0000-0000-000000000030',
    25,
    '59000000-0000-0000-0000-000000000099'
  );
  SELECT * INTO v_status
  FROM public.get_invoice_payment_receipt_status_v2(
    ARRAY['59000000-0000-0000-0000-000000000031'::uuid]
  );
  IF NOT FOUND OR v_status.ledger_found OR v_status.ledger_matches THEN
    RAISE EXCEPTION 'payment without a cashbox ledger was accepted';
  END IF;

  -- Duplicate source rows are ambiguous and must fail closed.
  INSERT INTO public.cashbox_transactions (
    id, source_type, source_id, branch_id, amount
  ) VALUES (
    '59000000-0000-0000-0000-000000000013',
    'payment',
    '59000000-0000-0000-0000-000000000011',
    '59000000-0000-0000-0000-000000000099',
    75
  );
  SELECT * INTO v_status
  FROM public.get_invoice_payment_receipt_status_v2(
    ARRAY['59000000-0000-0000-0000-000000000011'::uuid]
  );
  IF NOT FOUND OR v_status.ledger_found OR v_status.ledger_matches OR v_status.currency_matches THEN
    RAISE EXCEPTION 'duplicate cashbox source rows were not rejected';
  END IF;

  -- Branch isolation and authorization are enforced inside the SECURITY DEFINER RPC.
  PERFORM pg_catalog.set_config('test.allow_branch', 'off', true);
  SELECT pg_catalog.count(*) INTO v_count
  FROM public.get_invoice_payment_receipt_status_v2(
    ARRAY['59000000-0000-0000-0000-000000000011'::uuid]
  );
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'receipt status leaked across branch access boundary';
  END IF;
  PERFORM pg_catalog.set_config('test.allow_branch', 'on', true);

  PERFORM pg_catalog.set_config('test.allow_perm', 'off', true);
  v_state := NULL;
  BEGIN
    PERFORM * FROM public.get_invoice_payment_receipt_status_v2(
      ARRAY['59000000-0000-0000-0000-000000000011'::uuid]
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '42501' THEN
    RAISE EXCEPTION 'receipt status RPC did not reject missing permissions (got %)', v_state;
  END IF;
  PERFORM pg_catalog.set_config('test.allow_perm', 'on', true);

  IF has_function_privilege('anon', 'public.get_invoice_payment_receipt_status_v2(uuid[])', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon unexpectedly has receipt status RPC execute';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.get_invoice_payment_receipt_status_v2(uuid[])', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated lacks receipt status RPC execute';
  END IF;
END;
$phase59$;

SELECT 'PASS: Phase 59 persisted receipt currency provenance and fail-closed behavior' AS result;
