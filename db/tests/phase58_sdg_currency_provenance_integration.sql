-- Phase 58 assertions: SDG-only new records, immutable posted currency, no inferred legacy backfill.
DO $phase58$
BEGIN
  IF has_function_privilege('test_writer', 'private.enforce_roshan_sdg_currency()', 'EXECUTE') THEN
    RAISE EXCEPTION 'test_writer unexpectedly has direct EXECUTE on the private trigger function';
  END IF;
END;
$phase58$;

-- A restricted writer can insert through a table grant even though it cannot
-- call the private trigger function directly and has no USAGE on private.
SET ROLE test_writer;
INSERT INTO public.invoices (id, note)
VALUES ('58000000-0000-0000-0000-000000000099', 'restricted-writer');
RESET ROLE;

DO $phase58$
DECLARE
  v_currency text;
BEGIN
  SELECT currency_code INTO v_currency
  FROM public.invoices
  WHERE id = '58000000-0000-0000-0000-000000000099';
  IF v_currency IS DISTINCT FROM 'SDG' THEN
    RAISE EXCEPTION 'trigger did not enforce SDG for restricted writer';
  END IF;
END;
$phase58$;

INSERT INTO public.invoices (id, note)
VALUES ('58000000-0000-0000-0000-000000000101', 'new SDG invoice');
INSERT INTO public.supplier_bills (id, note)
VALUES ('58000000-0000-0000-0000-000000000111', 'new SDG supplier bill');

DO $phase58$
DECLARE
  v_table text;
  v_tables text[] := ARRAY[
    'invoices','payments','cashbox_transactions','expenses',
    'supplier_bills','supplier_payments','pharmacy_inventory'
  ];
  v_currency text;
  v_id uuid;
  v_new_id uuid;
  v_state text;
  v_legacy_id uuid;
  v_index integer := 0;
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    v_index := v_index + 1;
    v_legacy_id := ('58000000-0000-0000-0000-' || lpad(v_index::text, 12, '0'))::uuid;

    EXECUTE format('SELECT currency_code FROM public.%I WHERE id = $1', v_table)
      INTO v_currency USING v_legacy_id;
    IF v_currency IS NOT NULL THEN
      RAISE EXCEPTION 'legacy % row was unexpectedly backfilled: %', v_table, v_currency;
    END IF;

    v_new_id := gen_random_uuid();
    IF v_table = 'payments' THEN
      EXECUTE format(
        'INSERT INTO public.%I (id, note, invoice_id) VALUES ($1, %L, $2) RETURNING currency_code',
        v_table, 'new'
      ) INTO v_currency USING v_new_id, '58000000-0000-0000-0000-000000000101'::uuid;
    ELSIF v_table = 'supplier_payments' THEN
      EXECUTE format(
        'INSERT INTO public.%I (id, note, supplier_bill_id) VALUES ($1, %L, $2) RETURNING currency_code',
        v_table, 'new'
      ) INTO v_currency USING v_new_id, '58000000-0000-0000-0000-000000000111'::uuid;
    ELSE
      EXECUTE format('INSERT INTO public.%I (id, note) VALUES ($1, %L) RETURNING currency_code', v_table, 'new')
        INTO v_currency USING v_new_id;
    END IF;
    IF v_currency IS DISTINCT FROM 'SDG' THEN
      RAISE EXCEPTION 'new % row did not receive SDG: %', v_table, v_currency;
    END IF;

    v_id := gen_random_uuid();
    v_state := NULL;
    BEGIN
      EXECUTE format('INSERT INTO public.%I (id, note, currency_code) VALUES ($1, %L, NULL)', v_table, 'explicit-null')
        USING v_id;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS DISTINCT FROM '22023' THEN
      RAISE EXCEPTION 'explicit NULL insert on % was not rejected with 22023 (got %)', v_table, v_state;
    END IF;

    v_id := gen_random_uuid();
    v_state := NULL;
    BEGIN
      EXECUTE format('INSERT INTO public.%I (id, note, currency_code) VALUES ($1, %L, %L)', v_table, 'foreign-currency', 'USD')
        USING v_id;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS DISTINCT FROM '22023' THEN
      RAISE EXCEPTION 'non-SDG insert on % was not rejected with 22023 (got %)', v_table, v_state;
    END IF;

    -- This candidate never assigns currency to legacy rows. A future backfill requires a separate approved migration.
    v_state := NULL;
    BEGIN
      EXECUTE format('UPDATE public.%I SET currency_code = %L WHERE id = $1', v_table, 'SDG')
        USING v_legacy_id;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS NULL OR (v_table <> 'cashbox_transactions' AND v_state <> '22023')
       OR (v_table = 'cashbox_transactions' AND v_state NOT IN ('22023','55000')) THEN
      RAISE EXCEPTION 'legacy currency assignment on % was not blocked (got %)', v_table, v_state;
    END IF;

    -- A populated SDG value cannot be cleared or changed. The existing cashbox
    -- immutability trigger may reject first; that stricter boundary is preserved.
    v_state := NULL;
    BEGIN
      EXECUTE format('UPDATE public.%I SET currency_code = NULL WHERE id = $1', v_table)
        USING v_new_id;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS NULL
       OR (v_table <> 'cashbox_transactions' AND v_state <> '22023')
       OR (v_table = 'cashbox_transactions' AND v_state NOT IN ('22023','55000')) THEN
      RAISE EXCEPTION 'currency clear on % was not rejected (got %)', v_table, v_state;
    END IF;

    v_state := NULL;
    BEGIN
      EXECUTE format('UPDATE public.%I SET currency_code = %L WHERE id = $1', v_table, 'USD')
        USING v_new_id;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS NULL
       OR (v_table <> 'cashbox_transactions' AND v_state <> '22023')
       OR (v_table = 'cashbox_transactions' AND v_state NOT IN ('22023','55000')) THEN
      RAISE EXCEPTION 'currency change on % was not rejected (got %)', v_table, v_state;
    END IF;
  END LOOP;
END;
$phase58$;

DO $phase58$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name IN (
      'invoices','payments','cashbox_transactions','expenses',
      'supplier_bills','supplier_payments','pharmacy_inventory'
    )
    AND column_name = 'currency_code'
    AND column_default LIKE '%SDG%';
  IF v_count <> 7 THEN
    RAISE EXCEPTION 'expected SDG defaults on all 7 financial tables; found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_trigger
  WHERE NOT tgisinternal
    AND tgname IN (
      'trg_invoices_sdg_currency','trg_payments_sdg_currency',
      'trg_cashbox_transactions_sdg_currency','trg_expenses_sdg_currency',
      'trg_supplier_bills_sdg_currency','trg_supplier_payments_sdg_currency',
      'trg_pharmacy_inventory_sdg_currency'
    );
  IF v_count <> 7 THEN
    RAISE EXCEPTION 'expected 7 SDG immutability triggers; found %', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE NOT tgisinternal AND tgname = 'trg_cashbox_immutable'
  ) THEN
    RAISE EXCEPTION 'existing cashbox immutability boundary was not preserved';
  END IF;
END;
$phase58$;

SELECT 'PASS: Phase 58 SDG currency provenance, legacy NULL preservation, and immutability' AS result;


-- A new payment must inherit a known SDG invoice, not merely its own column default.
INSERT INTO public.payments (id, invoice_id, note)
VALUES (
  '58000000-0000-0000-0000-000000000102',
  '58000000-0000-0000-0000-000000000101',
  'new SDG payment'
);
DO $phase58$
DECLARE
  v_state text;
BEGIN
  IF (SELECT currency_code FROM public.payments WHERE id = '58000000-0000-0000-0000-000000000102') IS DISTINCT FROM 'SDG' THEN
    RAISE EXCEPTION 'payment did not persist SDG';
  END IF;

  BEGIN
    INSERT INTO public.payments (id, invoice_id, note)
    VALUES (
      '58000000-0000-0000-0000-000000000103',
      '58000000-0000-0000-0000-000000000001',
      'payment against legacy unknown-currency invoice'
    );
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'payment against legacy unknown-currency invoice was not rejected';
  END IF;
END;
$phase58$;

-- Supplier payments linked to a bill must inherit the bill's persisted SDG provenance.
INSERT INTO public.supplier_payments (id, supplier_bill_id, note)
VALUES (
  '58000000-0000-0000-0000-000000000112',
  '58000000-0000-0000-0000-000000000111',
  'new SDG supplier payment'
);
DO $phase58$
DECLARE
  v_state text;
BEGIN
  IF (SELECT currency_code FROM public.supplier_payments WHERE id = '58000000-0000-0000-0000-000000000112') IS DISTINCT FROM 'SDG' THEN
    RAISE EXCEPTION 'supplier payment did not persist SDG';
  END IF;

  BEGIN
    INSERT INTO public.supplier_payments (id, supplier_bill_id, note)
    VALUES (
      '58000000-0000-0000-0000-000000000113',
      '58000000-0000-0000-0000-000000000005',
      'payment against legacy unknown-currency supplier bill'
    );
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'supplier payment against legacy unknown-currency bill was not rejected';
  END IF;
END;
$phase58$;

-- Source-linked cashbox rows and reversals must carry the source's persisted currency.
INSERT INTO public.cashbox_transactions (id, source_type, source_id)
VALUES (
  '58000000-0000-0000-0000-000000000121',
  'payment',
  '58000000-0000-0000-0000-000000000102'
);
INSERT INTO public.cashbox_transactions (id, reversal_of)
VALUES (
  '58000000-0000-0000-0000-000000000122',
  '58000000-0000-0000-0000-000000000121'
);
DO $phase58$
DECLARE
  v_state text;
BEGIN
  BEGIN
    INSERT INTO public.cashbox_transactions (id, source_type, source_id)
    VALUES (
      '58000000-0000-0000-0000-000000000123',
      'payment',
      '58000000-0000-0000-0000-000000000002'
    );
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'cashbox ledger accepted a payment with unknown currency provenance';
  END IF;

  v_state := NULL;
  BEGIN
    INSERT INTO public.cashbox_transactions (id, reversal_of)
    VALUES (
      '58000000-0000-0000-0000-000000000124',
      '58000000-0000-0000-0000-000000000003'
    );
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'cashbox reversal accepted an original row with unknown currency provenance';
  END IF;
END;
$phase58$;


INSERT INTO public.expenses (id, note)
VALUES ('58000000-0000-0000-0000-000000000131', 'new SDG expense');
INSERT INTO public.cashbox_transactions (id, source_type, source_id)
VALUES (
  '58000000-0000-0000-0000-000000000132',
  'expense',
  '58000000-0000-0000-0000-000000000131'
);
INSERT INTO public.cashbox_transactions (id, source_type, source_id)
VALUES (
  '58000000-0000-0000-0000-000000000133',
  'supplier_payment',
  '58000000-0000-0000-0000-000000000112'
);
DO $phase58$
DECLARE
  v_state text;
BEGIN
  BEGIN
    INSERT INTO public.cashbox_transactions (id, source_type, source_id)
    VALUES (
      '58000000-0000-0000-0000-000000000134',
      'expense',
      '58000000-0000-0000-0000-000000000004'
    );
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'cashbox ledger accepted an expense with unknown currency provenance';
  END IF;

  v_state := NULL;
  BEGIN
    INSERT INTO public.cashbox_transactions (id, source_type, source_id)
    VALUES (
      '58000000-0000-0000-0000-000000000135',
      'supplier_payment',
      '58000000-0000-0000-0000-000000000006'
    );
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'cashbox ledger accepted a supplier payment with unknown currency provenance';
  END IF;
END;
$phase58$;


-- Changing a source link after insert must not bypass the persisted-currency guard.
DO $phase58$
DECLARE
  v_state text;
BEGIN
  BEGIN
    UPDATE public.payments
    SET invoice_id = '58000000-0000-0000-0000-000000000001'
    WHERE id = '58000000-0000-0000-0000-000000000102';
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'payment source could be changed to a legacy NULL-currency invoice (got %)', v_state;
  END IF;

  v_state := NULL;
  BEGIN
    UPDATE public.supplier_payments
    SET supplier_bill_id = '58000000-0000-0000-0000-000000000005'
    WHERE id = '58000000-0000-0000-0000-000000000112';
  EXCEPTION WHEN check_violation THEN
    v_state := SQLSTATE;
  END;
  IF v_state IS DISTINCT FROM '23514' THEN
    RAISE EXCEPTION 'supplier payment source could be changed to a legacy NULL-currency bill (got %)', v_state;
  END IF;
END;
$phase58$;
