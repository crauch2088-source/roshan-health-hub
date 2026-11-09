-- Phase 58 assertions: SDG-only new records, immutable posted currency, no inferred legacy backfill.
DO $$
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
    EXECUTE format('INSERT INTO public.%I (id, note) VALUES ($1, %L) RETURNING currency_code', v_table, 'new')
      INTO v_currency USING v_new_id;
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
    IF (v_table <> 'cashbox_transactions' AND v_state IS DISTINCT FROM '22023')
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
    IF (v_table <> 'cashbox_transactions' AND v_state IS DISTINCT FROM '22023')
       OR (v_table = 'cashbox_transactions' AND v_state NOT IN ('22023','55000')) THEN
      RAISE EXCEPTION 'currency change on % was not rejected (got %)', v_table, v_state;
    END IF;
  END LOOP;
END;
$$;

DO $$
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
$$;

SELECT 'PASS: Phase 58 SDG currency provenance, legacy NULL preservation, and immutability' AS result;
