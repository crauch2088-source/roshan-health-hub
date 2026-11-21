-- Phase 65 (RHH-04): Version-aware WHO ICD-10 2019 diagnosis persistence
-- Preserves all historical and legacy free-text diagnoses unchanged.
-- Explicitly enforces WHO-ICD-10 (never silently substituting ICD-10-CM).
BEGIN;

ALTER TABLE public.diagnoses
  ADD COLUMN IF NOT EXISTS coding_system text,
  ADD COLUMN IF NOT EXISTS coding_version text,
  ADD COLUMN IF NOT EXISTS coding_label_snapshot text;

DO $phase65_constraints$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'diagnoses_who_icd10_system_check'
  ) THEN
    ALTER TABLE public.diagnoses
      ADD CONSTRAINT diagnoses_who_icd10_system_check
      CHECK (
        coding_system IS NULL
        OR coding_system IN ('WHO-ICD-10', 'WHO-ICD-11')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'diagnoses_coding_version_pair_check'
  ) THEN
    ALTER TABLE public.diagnoses
      ADD CONSTRAINT diagnoses_coding_version_pair_check
      CHECK (
        (coding_system IS NULL AND coding_version IS NULL)
        OR (coding_system IS NOT NULL AND coding_version IS NOT NULL AND length(trim(coding_version)) > 0)
      );
  END IF;
END
$phase65_constraints$;

COMMENT ON COLUMN public.diagnoses.coding_system IS
  'Canonical diagnosis coding system (WHO-ICD-10 recommended; ICD-10-CM substitution prohibited without policy sign-off).';
COMMENT ON COLUMN public.diagnoses.coding_version IS
  'Exact classification release version snapshot (e.g. 2019 for WHO ICD-10 Version 2019).';
COMMENT ON COLUMN public.diagnoses.coding_label_snapshot IS
  'Immutable human-readable label captured at diagnosis entry to preserve historical clinical meaning.';

COMMIT;
