-- Phase 45: retry-safe atomic visit and queue-ticket completion.
-- Candidate migration: validate through isolated PostgreSQL 17 CI before release.
BEGIN;

CREATE OR REPLACE FUNCTION public.complete_visit_atomic(p_visit_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid;
  v_status text;
  v_completed_at timestamptz;
BEGIN
  IF NOT public.app_has_perm('visits.update') THEN
    RAISE EXCEPTION 'visit update permission required' USING ERRCODE = '42501';
  END IF;
  IF p_visit_id IS NULL THEN
    RAISE EXCEPTION 'visit is required' USING ERRCODE = '22023';
  END IF;
  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;

  SELECT v.status, v.completed_at
    INTO v_status, v_completed_at
  FROM public.visits AS v
  WHERE v.id = p_visit_id AND v.deleted_at IS NULL
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'visit not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.app_has_visit_branch_access(p_visit_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_status = 'cancelled' THEN
    RAISE EXCEPTION 'cancelled visit cannot be completed' USING ERRCODE = '22023';
  END IF;

  IF v_status = 'completed' THEN
    -- A completed visit must already have its authoritative timestamp. Fail
    -- closed rather than mutating a possibly locked visit or inventing one.
    IF v_completed_at IS NULL THEN
      RAISE EXCEPTION 'completed visit missing completion timestamp; manual repair required'
        USING ERRCODE = '22023';
    END IF;

    -- Idempotent retry repairs active tickets without rewriting the visit row.
    UPDATE public.queue_tickets AS ticket
    SET status = 'completed',
        completed_at = v_completed_at,
        updated_by = v_user_id
    WHERE ticket.visit_id = p_visit_id
      AND ticket.deleted_at IS NULL
      AND ticket.status IN ('waiting', 'called', 'in_progress');
    RETURN;
  END IF;

  -- A first completion uses one server-side timestamp for the visit and every
  -- linked queue ticket; stale ticket timestamps must not survive completion.
  v_completed_at := pg_catalog.now();
  UPDATE public.visits
  SET status = 'completed',
      completed_at = v_completed_at,
      updated_by = v_user_id,
      updated_at = pg_catalog.now()
  WHERE id = p_visit_id AND deleted_at IS NULL;

  UPDATE public.queue_tickets AS ticket
  SET status = 'completed',
      completed_at = v_completed_at,
      updated_by = v_user_id
  WHERE ticket.visit_id = p_visit_id
    AND ticket.deleted_at IS NULL
    AND ticket.status IN ('waiting', 'called', 'in_progress');
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_visit_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_visit_atomic(uuid) TO authenticated;

COMMIT;
