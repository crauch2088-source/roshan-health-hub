-- Phase 47: restore branch attribution for visits and their queue tickets.
-- The current single-active-branch deployment permits a safe one-time backfill
-- from the patient branch. With multiple active branches, ambiguous legacy rows
-- remain untouched and fail closed until manually reconciled.
-- PostgreSQL 17 regression tests passed; applied to QA and production on 2026-10-31.
BEGIN;

ALTER TABLE public.queue_tickets
  ADD COLUMN IF NOT EXISTS branch_id uuid;

DO $phase47_single_active_branch_backfill$
DECLARE
  v_active_branches integer;
BEGIN
  SELECT count(*) INTO v_active_branches
  FROM public.branches b
  WHERE b.active IS TRUE
    AND COALESCE(b.is_active, true) IS TRUE
    AND b.deleted_at IS NULL;

  IF v_active_branches = 1 THEN
    UPDATE public.visits AS v
    SET branch_id = p.branch_id
    FROM public.patients AS p
    JOIN public.branches AS b ON b.id = p.branch_id
    WHERE v.patient_id = p.id
      AND v.branch_id IS NULL
      AND p.branch_id IS NOT NULL
      AND b.active IS TRUE
      AND COALESCE(b.is_active, true) IS TRUE
      AND b.deleted_at IS NULL;
  END IF;
END
$phase47_single_active_branch_backfill$;

DO $phase47_queue_preflight$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.queue_tickets AS q
    LEFT JOIN public.visits AS v ON v.id = q.visit_id
    WHERE q.visit_id IS NOT NULL
      AND (v.id IS NULL OR v.deleted_at IS NOT NULL
           OR (q.patient_id IS NOT NULL AND q.patient_id IS DISTINCT FROM v.patient_id))
  ) THEN
    RAISE EXCEPTION
      'Phase 47 blocked: a queue ticket has a missing/deleted visit or a patient/visit mismatch';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.queue_tickets AS q
    JOIN public.visits AS v ON v.id = q.visit_id
    WHERE q.branch_id IS NOT NULL
      AND v.branch_id IS NOT NULL
      AND q.branch_id IS DISTINCT FROM v.branch_id
  ) THEN
    RAISE EXCEPTION
      'Phase 47 blocked: a queue ticket branch differs from its linked visit';
  END IF;
END
$phase47_queue_preflight$;

-- Existing queue tickets inherit the visit's now-authoritative branch.
UPDATE public.queue_tickets AS q
SET branch_id = v.branch_id
FROM public.visits AS v
WHERE q.visit_id = v.id
  AND q.branch_id IS NULL
  AND v.branch_id IS NOT NULL;

DO $phase47_branch_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.queue_tickets'::regclass
      AND conname = 'queue_tickets_branch_id_fkey'
  ) THEN
    ALTER TABLE public.queue_tickets
      ADD CONSTRAINT queue_tickets_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES public.branches(id)
      ON DELETE RESTRICT NOT VALID;
  END IF;
END
$phase47_branch_fk$;

ALTER TABLE public.queue_tickets
  VALIDATE CONSTRAINT queue_tickets_branch_id_fkey;

CREATE INDEX IF NOT EXISTS queue_tickets_branch_visit_date_idx
  ON public.queue_tickets (branch_id, visit_date, status)
  WHERE deleted_at IS NULL;

CREATE OR REPLACE FUNCTION private.phase47_visit_branch_attribution()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_patient_branch uuid;
BEGIN
  SELECT p.branch_id
    INTO v_patient_branch
  FROM public.patients AS p
  WHERE p.id = NEW.patient_id
    AND p.deleted_at IS NULL
  FOR KEY SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'active patient not found for visit branch attribution'
      USING ERRCODE = '23514';
  END IF;

  IF v_patient_branch IS NOT NULL THEN
    IF NEW.branch_id IS NULL THEN
      NEW.branch_id := v_patient_branch;
    ELSIF NEW.branch_id IS DISTINCT FROM v_patient_branch THEN
      RAISE EXCEPTION 'visit branch must match the assigned patient branch'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  IF NEW.branch_id IS NULL THEN
    RAISE EXCEPTION 'visit requires an authoritative branch'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.branches AS b
    WHERE b.id = NEW.branch_id
      AND b.active IS TRUE
      AND COALESCE(b.is_active, true) IS TRUE
      AND b.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'visit branch must be active'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.phase47_visit_branch_attribution()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS phase47_visit_branch_attribution
  ON public.visits;

CREATE TRIGGER phase47_visit_branch_attribution
  BEFORE INSERT OR UPDATE OF patient_id, branch_id
  ON public.visits
  FOR EACH ROW
  EXECUTE FUNCTION private.phase47_visit_branch_attribution();

CREATE OR REPLACE FUNCTION private.phase47_queue_ticket_branch_attribution()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_patient_id uuid;
  v_branch_id uuid;
  v_deleted_at timestamptz;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.visit_id IS NULL AND NEW.visit_id IS NULL THEN
    IF NEW.patient_id IS DISTINCT FROM OLD.patient_id
       OR NEW.branch_id IS DISTINCT FROM OLD.branch_id THEN
      RAISE EXCEPTION 'unlinked legacy queue ticket identity and branch are immutable'
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.visit_id IS NULL THEN
    RAISE EXCEPTION 'queue ticket must be linked to a visit'
      USING ERRCODE = '23514';
  END IF;

  SELECT v.patient_id, v.branch_id, v.deleted_at
    INTO v_patient_id, v_branch_id, v_deleted_at
  FROM public.visits AS v
  WHERE v.id = NEW.visit_id
  FOR KEY SHARE;

  IF NOT FOUND OR v_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'active linked visit not found for queue ticket'
      USING ERRCODE = '23514';
  END IF;

  IF v_branch_id IS NULL THEN
    RAISE EXCEPTION 'linked visit has no authoritative branch'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.patient_id IS NOT NULL AND NEW.patient_id IS DISTINCT FROM v_patient_id THEN
    RAISE EXCEPTION 'queue ticket patient must match linked visit patient'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.branch_id IS NOT NULL AND NEW.branch_id IS DISTINCT FROM v_branch_id THEN
    RAISE EXCEPTION 'queue ticket branch must match linked visit branch'
      USING ERRCODE = '23514';
  END IF;

  NEW.patient_id := v_patient_id;
  NEW.branch_id := v_branch_id;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.phase47_queue_ticket_branch_attribution()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS phase47_queue_ticket_branch_attribution
  ON public.queue_tickets;

CREATE TRIGGER phase47_queue_ticket_branch_attribution
  BEFORE INSERT OR UPDATE OF patient_id, visit_id, branch_id
  ON public.queue_tickets
  FOR EACH ROW
  EXECUTE FUNCTION private.phase47_queue_ticket_branch_attribution();

COMMIT;
