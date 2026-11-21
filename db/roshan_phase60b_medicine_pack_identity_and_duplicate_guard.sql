-- Phase 60B (RHH-07): Physical-pack identity dimensions and exact-identity duplicate guard.
-- Forward-only, additive migration on public.medicines.
-- Preserves all historical prescriptions and dispensing records untouched.
-- IMPORTANT: GTIN/barcode is a catalogue identifier only; it NEVER proves manufacturer authenticity
-- and NEVER replaces pharmacist physical-pack inspection/acceptance.
BEGIN;

ALTER TABLE public.medicines
  ADD COLUMN IF NOT EXISTS manufacturer_name text,
  ADD COLUMN IF NOT EXISTS pack_size numeric(10, 2),
  ADD COLUMN IF NOT EXISTS dispensing_unit text,
  ADD COLUMN IF NOT EXISTS gtin_barcode text,
  ADD COLUMN IF NOT EXISTS route text;

DO $phase60b_constraints$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'medicines_pack_size_positive_check'
  ) THEN
    ALTER TABLE public.medicines
      ADD CONSTRAINT medicines_pack_size_positive_check
      CHECK (pack_size IS NULL OR pack_size > 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'medicines_gtin_barcode_format_check'
  ) THEN
    ALTER TABLE public.medicines
      ADD CONSTRAINT medicines_gtin_barcode_format_check
      CHECK (gtin_barcode IS NULL OR gtin_barcode ~ '^[0-9]{8,14}$');
  END IF;
END
$phase60b_constraints$;

-- Exact normalized identity key across all distinct clinical & pack dimensions.
-- Medicines sharing a name but differing in strength, dosage form, route, pack_size,
-- or dispensing_unit produce distinct keys and are NEVER collapsed.
CREATE OR REPLACE FUNCTION private.normalize_medicine_identity_key(
  p_generic_name text,
  p_brand_name text,
  p_strength text,
  p_dosage_form text,
  p_route text,
  p_pack_size numeric,
  p_dispensing_unit text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
  SELECT concat_ws(
    '|',
    lower(trim(COALESCE(p_generic_name, ''))),
    lower(trim(COALESCE(p_brand_name, ''))),
    lower(trim(COALESCE(p_strength, ''))),
    lower(trim(COALESCE(p_dosage_form, ''))),
    lower(trim(COALESCE(p_route, ''))),
    COALESCE(trim(to_char(p_pack_size, 'FM999999990.##')), ''),
    lower(trim(COALESCE(p_dispensing_unit, '')))
  )
$function$;

REVOKE ALL ON FUNCTION private.normalize_medicine_identity_key(text, text, text, text, text, numeric, text)
  FROM PUBLIC, anon, authenticated;

-- Unique active GTIN when provided (scoped to non-deleted active catalogue rows).
CREATE UNIQUE INDEX IF NOT EXISTS idx_medicines_active_gtin_unique
  ON public.medicines (gtin_barcode)
  WHERE gtin_barcode IS NOT NULL AND deleted_at IS NULL AND COALESCE(active, true) = true;

-- Unique exact normalized identity when all core identity dimensions are populated.
CREATE UNIQUE INDEX IF NOT EXISTS idx_medicines_active_exact_identity_unique
  ON public.medicines (
    private.normalize_medicine_identity_key(
      generic_name,
      brand_name,
      strength,
      dosage_form,
      route,
      pack_size,
      dispensing_unit
    )
  )
  WHERE deleted_at IS NULL
    AND COALESCE(active, true) = true
    AND length(trim(COALESCE(generic_name, ''))) > 0
    AND length(trim(COALESCE(brand_name, ''))) > 0
    AND length(trim(COALESCE(strength, ''))) > 0
    AND length(trim(COALESCE(dosage_form, ''))) > 0
    AND length(trim(COALESCE(dispensing_unit, ''))) > 0
    AND pack_size IS NOT NULL;

COMMENT ON COLUMN public.medicines.gtin_barcode IS
  'GS1 GTIN-8/12/13/14 catalogue barcode identifier only. Does NOT verify regulatory or manufacturer authenticity.';
COMMENT ON COLUMN public.medicines.pack_size IS
  'Explicit commercial pack size in base dispensing units (> 0); never inferred from free-text unit.';

COMMIT;
