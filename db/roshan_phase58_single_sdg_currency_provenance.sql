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
