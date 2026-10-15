-- Integration tests for db/roshan_phase6_atomic_pharmacy_stock_receipt.sql.
SELECT set_config('test.user_id', '10000000-0000-0000-0000-000000000001', false);
SELECT set_config('test.has_perm', 'true', false);
SELECT set_config('test.super_admin', 'false', false);

INSERT INTO public.users (id, branch_id)
VALUES ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001');
INSERT INTO public.medicines (id, stock_quantity)
VALUES ('30000000-0000-0000-0000-000000000001', 5);
INSERT INTO public.suppliers (id, active)
VALUES ('40000000-0000-0000-0000-000000000001', true);

DO $$
DECLARE
  v_batch uuid;
BEGIN
  v_batch := public.receive_pharmacy_stock(
    '30000000-0000-0000-0000-000000000001',
    10,
    '40000000-0000-0000-0000-000000000001',
    'BATCH-TEST-01',
    2.50,
    3.75,
    DATE '2026-01-01',
    DATE '2027-01-01',
    'TEST-INVOICE-01'
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.pharmacy_inventory
    WHERE id = v_batch AND quantity_received = 10 AND quantity_remaining = 10
      AND branch_id = '20000000-0000-0000-0000-000000000001'
  ) THEN
    RAISE EXCEPTION 'batch was not created with expected quantity and branch';
  END IF;
  IF (SELECT stock_quantity FROM public.medicines
      WHERE id = '30000000-0000-0000-0000-000000000001') <> 15 THEN
    RAISE EXCEPTION 'aggregate medicine stock was not incremented atomically';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.stock_movements
    WHERE batch_id = v_batch AND movement_type = 'purchase' AND quantity = 10
  ) THEN
    RAISE EXCEPTION 'purchase movement was not recorded';
  END IF;
END;
$$;

-- Invalid numeric special values and expired batches must be rejected.
DO $$
BEGIN
  BEGIN
    PERFORM public.receive_pharmacy_stock(
      '30000000-0000-0000-0000-000000000001', 1,
      NULL, 'BATCH-NAN-PRICE', 'NaN'::numeric, 3.00,
      DATE '2026-01-01', DATE '2027-01-01', NULL
    );
    RAISE EXCEPTION 'test failed: NaN purchase price was accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'test failed: NaN purchase price was accepted' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%price%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.receive_pharmacy_stock(
      '30000000-0000-0000-0000-000000000001', 1,
      NULL, 'BATCH-EXPIRED', 1.00, 3.00,
      DATE '2024-01-01', CURRENT_DATE - 1, NULL
    );
    RAISE EXCEPTION 'test failed: expired batch was accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'test failed: expired batch was accepted' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%expired%' THEN RAISE; END IF;
  END;

  IF (SELECT stock_quantity FROM public.medicines
      WHERE id = '30000000-0000-0000-0000-000000000001') <> 15 THEN
    RAISE EXCEPTION 'invalid price or expired batch changed aggregate stock';
  END IF;
  IF (SELECT count(*) FROM public.pharmacy_inventory) <> 1 THEN
    RAISE EXCEPTION 'invalid price or expired batch left a batch row';
  END IF;
END;
$$;

-- Fractional quantities must be rejected without changing any stock rows.
DO $$
BEGIN
  BEGIN
    PERFORM public.receive_pharmacy_stock(
      '30000000-0000-0000-0000-000000000001', 1.5
    );
    RAISE EXCEPTION 'test failed: fractional quantity was accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'test failed: fractional quantity was accepted' THEN RAISE; END IF;
  END;
  IF (SELECT stock_quantity FROM public.medicines
      WHERE id = '30000000-0000-0000-0000-000000000001') <> 15 THEN
    RAISE EXCEPTION 'fractional quantity changed aggregate stock';
  END IF;
END;
$$;

-- A caller without the application permission must be rejected.
SELECT set_config('test.has_perm', 'false', false);
DO $$
BEGIN
  BEGIN
    PERFORM public.receive_pharmacy_stock(
      '30000000-0000-0000-0000-000000000001', 2
    );
    RAISE EXCEPTION 'test failed: unauthorized receipt was accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'test failed: unauthorized receipt was accepted' THEN RAISE; END IF;
  END;
END;
$$;
SELECT set_config('test.has_perm', 'true', false);

-- An unconfigured non-super-admin branch must be rejected.
UPDATE public.users
SET branch_id = NULL
WHERE id = '10000000-0000-0000-0000-000000000001';
DO $$
BEGIN
  BEGIN
    PERFORM public.receive_pharmacy_stock(
      '30000000-0000-0000-0000-000000000001', 2
    );
    RAISE EXCEPTION 'test failed: missing branch was accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'test failed: missing branch was accepted' THEN RAISE; END IF;
  END;
END;
$$;
UPDATE public.users
SET branch_id = '20000000-0000-0000-0000-000000000001'
WHERE id = '10000000-0000-0000-0000-000000000001';

-- Inject a failure after batch insert and stock increment; transaction must roll back.
CREATE FUNCTION public.test_fail_stock_movement()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF COALESCE(current_setting('test.fail_movement', true) = 'true', false) THEN
    RAISE EXCEPTION 'injected movement failure';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER test_fail_stock_movement
BEFORE INSERT ON public.stock_movements
FOR EACH ROW EXECUTE FUNCTION public.test_fail_stock_movement();
SELECT set_config('test.fail_movement', 'true', false);

DO $$
BEGIN
  BEGIN
    PERFORM public.receive_pharmacy_stock(
      '30000000-0000-0000-0000-000000000001', 4
    );
    RAISE EXCEPTION 'test failed: injected failure was not raised';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'test failed: injected failure was not raised' THEN RAISE; END IF;
    IF SQLERRM <> 'injected movement failure' THEN RAISE; END IF;
  END;

  IF (SELECT stock_quantity FROM public.medicines
      WHERE id = '30000000-0000-0000-0000-000000000001') <> 15 THEN
    RAISE EXCEPTION 'failed receipt did not roll back aggregate stock';
  END IF;
  IF (SELECT count(*) FROM public.pharmacy_inventory) <> 1 THEN
    RAISE EXCEPTION 'failed receipt left a partial batch';
  END IF;
  IF (SELECT count(*) FROM public.stock_movements) <> 1 THEN
    RAISE EXCEPTION 'failed receipt left an incomplete movement ledger';
  END IF;
END;
$$;
SELECT set_config('test.fail_movement', 'false', false);

-- Execute privileges must be explicitly granted only to the authenticated role.
DO $$
BEGIN
  IF NOT has_function_privilege(
    'authenticated',
    'public.receive_pharmacy_stock(uuid,numeric,uuid,text,numeric,numeric,date,date,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated role cannot execute stock receipt RPC';
  END IF;
  IF has_function_privilege(
    'anon',
    'public.receive_pharmacy_stock(uuid,numeric,uuid,text,numeric,numeric,date,date,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'anon role can execute stock receipt RPC';
  END IF;
END;
$$;

SELECT 'atomic stock receipt integration tests passed' AS result;
