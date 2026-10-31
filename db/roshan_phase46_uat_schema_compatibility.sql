-- Phase 46: close the live UAT schema gaps for clinical allergies and pharmacy branch attribution.
-- Candidate only. Review and run through isolated PostgreSQL 17 CI before any live apply.
-- Safe forward migration: additive columns, validated backfill, constrained branch attribution.
BEGIN;

ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS allergies text,
  ADD COLUMN IF NOT EXISTS chronic_conditions text;

ALTER TABLE public.prescriptions
  ADD COLUMN IF NOT EXISTS branch_id uuid;

COMMENT ON COLUMN public.patients.allergies IS
  'Free-text allergy summary reviewed by clinicians; NULL means not recorded, not no known allergies.';
COMMENT ON COLUMN public.patients.chronic_conditions IS
  'Free-text chronic-condition summary reviewed by clinicians; NULL means not recorded.';
COMMENT ON COLUMN public.prescriptions.branch_id IS
  'Authoritative branch copied from the linked visit; set and validated by Phase 46 trigger.';

-- Fail closed instead of silently assigning a branch to malformed historical prescriptions.
DO $phase46_preflight$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.prescriptions AS p
    LEFT JOIN public.visits AS v ON v.id = p.visit_id
    WHERE p.visit_id IS NOT NULL
      AND (v.id IS NULL OR p.patient_id IS DISTINCT FROM v.patient_id)
  ) THEN
    RAISE EXCEPTION
      'Phase 46 blocked: a prescription has a missing visit or a patient/visit mismatch; reconcile these rows before migration';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.prescriptions AS p
    JOIN public.visits AS v ON v.id = p.visit_id
    WHERE p.branch_id IS NOT NULL
      AND p.branch_id IS DISTINCT FROM v.branch_id
  ) THEN
    RAISE EXCEPTION
      'Phase 46 blocked: a prescription branch differs from its linked visit; reconcile these rows before migration';
  END IF;
END
$phase46_preflight$;

-- Backfill only from the authoritative visit. Legacy prescriptions without a visit
-- remain NULL and are not guessed or assigned to the current user's branch.
UPDATE public.prescriptions AS p
SET branch_id = v.branch_id
FROM public.visits AS v
WHERE p.visit_id = v.id
  AND p.patient_id = v.patient_id
  AND p.branch_id IS NULL
  AND v.branch_id IS NOT NULL;

DO $phase46_branch_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.prescriptions'::regclass
      AND conname = 'prescriptions_branch_id_fkey'
  ) THEN
    ALTER TABLE public.prescriptions
      ADD CONSTRAINT prescriptions_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.branches(id)
      ON DELETE RESTRICT NOT VALID;
  END IF;
END
$phase46_branch_fk$;

ALTER TABLE public.prescriptions
  VALIDATE CONSTRAINT prescriptions_branch_id_fkey;

CREATE INDEX IF NOT EXISTS prescriptions_branch_status_created_at_idx
  ON public.prescriptions (branch_id, status, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE OR REPLACE FUNCTION private.phase46_prescription_branch_attribution()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_patient_id uuid;
  v_branch_id uuid;
  v_deleted_at timestamptz;
BEGIN
  -- Preserve updates to legacy, unlinked rows, but never let them acquire an
  -- arbitrary branch or change patient identity without an authoritative visit.
  IF TG_OP = 'UPDATE' AND OLD.visit_id IS NULL AND NEW.visit_id IS NULL THEN
    IF NEW.patient_id IS DISTINCT FROM OLD.patient_id THEN
      RAISE EXCEPTION 'unlinked legacy prescription patient_id is immutable'
        USING ERRCODE = '23514';
    END IF;
    IF NEW.branch_id IS DISTINCT FROM OLD.branch_id THEN
      RAISE EXCEPTION 'unlinked legacy prescription cannot be assigned an arbitrary branch'
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.visit_id IS NULL THEN
    RAISE EXCEPTION 'prescription must be linked to a visit for branch attribution'
      USING ERRCODE = '23514';
  END IF;

  SELECT v.patient_id, v.branch_id, v.deleted_at
    INTO v_patient_id, v_branch_id, v_deleted_at
  FROM public.visits AS v
  WHERE v.id = NEW.visit_id
  FOR KEY SHARE;

  IF NOT FOUND OR v_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'active linked visit not found for prescription'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.patient_id IS DISTINCT FROM v_patient_id THEN
    RAISE EXCEPTION 'prescription patient must match linked visit patient'
      USING ERRCODE = '23514';
  END IF;

  IF v_branch_id IS NULL THEN
    RAISE EXCEPTION 'linked visit has no authoritative branch'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.branch_id IS NOT NULL AND NEW.branch_id IS DISTINCT FROM v_branch_id THEN
    RAISE EXCEPTION 'prescription branch must match linked visit branch'
      USING ERRCODE = '23514';
  END IF;

  NEW.branch_id := v_branch_id;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.phase46_prescription_branch_attribution()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS phase46_prescription_branch_attribution
  ON public.prescriptions;

CREATE TRIGGER phase46_prescription_branch_attribution
  BEFORE INSERT OR UPDATE OF patient_id, visit_id, branch_id
  ON public.prescriptions
  FOR EACH ROW
  EXECUTE FUNCTION private.phase46_prescription_branch_attribution();

COMMIT;
