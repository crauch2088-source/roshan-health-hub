-- Phase 58: immutable single-currency SDG provenance for posted financial records.
-- Candidate only. Do not apply to hosted QA or Production without a separately approved rollout.
-- Existing rows intentionally remain NULL; no historical currency is inferred or backfilled.
BEGIN;

CREATE SCHEMA IF NOT EXISTS private;

DO $$
DECLARE
  v_table text;
  v_tables text[] := ARRAY[
    'invoices',
    'payments',
    'cashbox_transactions',
    'expenses',
    'supplier_bills',
    'supplier_payments',
    'pharmacy_inventory'
  ];
  v_constraint text;
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS currency_code text', v_table);
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN currency_code SET DEFAULT %L', v_table, 'SDG');

    v_constraint := 'ck_' || v_table || '_currency_sdg';
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = v_constraint
        AND conrelid = format('public.%I', v_table)::regclass
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (currency_code IS NULL OR currency_code = %L)',
        v_table, v_constraint, 'SDG'
      );
    END IF;

    EXECUTE format(
      'COMMENT ON COLUMN public.%I.currency_code IS %L',
      v_table,
      'Immutable SDG provenance for new financial records. NULL is retained only for legacy rows pending separately approved evidence-backed reconciliation; never infer it from mutable settings.'
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION private.enforce_roshan_sdg_currency()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_parent_currency text;
  v_validate_source boolean := false;
BEGIN
  IF NEW.currency_code IS NULL AND TG_OP = 'INSERT' THEN
    RAISE EXCEPTION 'currency_code is required for new financial records'
      USING ERRCODE = '22023';
  END IF;

  IF NEW.currency_code IS NOT NULL AND NEW.currency_code <> 'SDG' THEN
    RAISE EXCEPTION 'Roshan supports SDG only'
      USING ERRCODE = '22023';
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.currency_code IS DISTINCT FROM OLD.currency_code THEN
    RAISE EXCEPTION 'posted financial currency_code is immutable'
      USING ERRCODE = '22023';
  END IF;

  -- A default on the child row is not proof that its source record has a known
  -- currency. Validate source links on insert and whenever a source reference changes.
  IF TG_OP = 'INSERT' THEN
    v_validate_source := true;
  ELSIF TG_TABLE_NAME = 'payments' THEN
    v_validate_source := NEW.invoice_id IS DISTINCT FROM OLD.invoice_id;
  ELSIF TG_TABLE_NAME = 'supplier_payments' THEN
    v_validate_source := NEW.supplier_bill_id IS DISTINCT FROM OLD.supplier_bill_id;
  ELSIF TG_TABLE_NAME = 'cashbox_transactions' THEN
    v_validate_source :=
      NEW.source_type IS DISTINCT FROM OLD.source_type
      OR NEW.source_id IS DISTINCT FROM OLD.source_id
      OR NEW.reversal_of IS DISTINCT FROM OLD.reversal_of;
  END IF;

  IF v_validate_source THEN
    IF TG_TABLE_NAME = 'payments' THEN
      SELECT i.currency_code INTO v_parent_currency
      FROM public.invoices AS i
      WHERE i.id = NEW.invoice_id
      FOR KEY SHARE;

      IF NOT FOUND OR v_parent_currency IS DISTINCT FROM NEW.currency_code THEN
        RAISE EXCEPTION 'invoice currency provenance is missing or inconsistent'
          USING ERRCODE = '23514';
      END IF;
    ELSIF TG_TABLE_NAME = 'supplier_payments' THEN
      IF NEW.supplier_bill_id IS NOT NULL THEN
        SELECT b.currency_code INTO v_parent_currency
        FROM public.supplier_bills AS b
        WHERE b.id = NEW.supplier_bill_id
        FOR KEY SHARE;

        IF NOT FOUND OR v_parent_currency IS DISTINCT FROM NEW.currency_code THEN
          RAISE EXCEPTION 'supplier bill currency provenance is missing or inconsistent'
            USING ERRCODE = '23514';
        END IF;
      END IF;
    ELSIF TG_TABLE_NAME = 'cashbox_transactions' THEN
      IF NEW.source_type = 'reversal' AND NEW.reversal_of IS NULL THEN
        RAISE EXCEPTION 'cashbox reversal must reference its original ledger row'
          USING ERRCODE = '23514';
      END IF;

      IF NEW.reversal_of IS NOT NULL THEN
        SELECT c.currency_code INTO v_parent_currency
        FROM public.cashbox_transactions AS c
        WHERE c.id = NEW.reversal_of
        FOR KEY SHARE;

        IF NOT FOUND OR v_parent_currency IS DISTINCT FROM NEW.currency_code THEN
          RAISE EXCEPTION 'reversal currency provenance is missing or inconsistent'
            USING ERRCODE = '23514';
        END IF;
      ELSIF NEW.source_type = 'payment' THEN
        SELECT p.currency_code INTO v_parent_currency
        FROM public.payments AS p
        WHERE p.id = NEW.source_id
        FOR KEY SHARE;

        IF NOT FOUND OR v_parent_currency IS DISTINCT FROM NEW.currency_code THEN
          RAISE EXCEPTION 'source payment currency provenance is missing or inconsistent'
            USING ERRCODE = '23514';
        END IF;
      ELSIF NEW.source_type = 'expense' THEN
        SELECT e.currency_code INTO v_parent_currency
        FROM public.expenses AS e
        WHERE e.id = NEW.source_id
        FOR KEY SHARE;

        IF NOT FOUND OR v_parent_currency IS DISTINCT FROM NEW.currency_code THEN
          RAISE EXCEPTION 'source expense currency provenance is missing or inconsistent'
            USING ERRCODE = '23514';
        END IF;
      ELSIF NEW.source_type = 'supplier_payment' THEN
        SELECT sp.currency_code INTO v_parent_currency
        FROM public.supplier_payments AS sp
        WHERE sp.id = NEW.source_id
        FOR KEY SHARE;

        IF NOT FOUND OR v_parent_currency IS DISTINCT FROM NEW.currency_code THEN
          RAISE EXCEPTION 'source supplier payment currency provenance is missing or inconsistent'
            USING ERRCODE = '23514';
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.enforce_roshan_sdg_currency() FROM PUBLIC;

DO $$
DECLARE
  v_table text;
  v_tables text[] := ARRAY[
    'invoices',
    'payments',
    'cashbox_transactions',
    'expenses',
    'supplier_bills',
    'supplier_payments',
    'pharmacy_inventory'
  ];
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_sdg_currency ON public.%I', v_table, v_table);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_sdg_currency
       BEFORE INSERT OR UPDATE ON public.%I
       FOR EACH ROW EXECUTE FUNCTION private.enforce_roshan_sdg_currency()',
      v_table, v_table
    );
  END LOOP;
END;
$$;

COMMIT;
