-- ROSHAN: make queue_number authoritative and independent from visit_number.

-- 1. Assign the next daily queue number inside the INSERT transaction.
--    This avoids races between the client RPC call and the actual INSERT.
CREATE OR REPLACE FUNCTION public.set_visit_queue_number()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  NEW.queue_number := public.next_queue_number(NEW.queue_date);
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_set_visit_queue_number ON public.visits;

CREATE TRIGGER trg_set_visit_queue_number
BEFORE INSERT ON public.visits
FOR EACH ROW
EXECUTE FUNCTION public.set_visit_queue_number();

-- 2. Queue tickets must use the real queue_number, never visit_number.
CREATE OR REPLACE FUNCTION public.add_to_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO public.queue_tickets
    (visit_id, patient_id, visit_date, queue_number, status)
  VALUES
    (NEW.id, NEW.patient_id, NEW.visit_date, 'Q' || NEW.queue_number::text, 'waiting');

  RETURN NEW;
END;
$function$;

-- 3. Protect the invariant: one queue number per queue date.
CREATE UNIQUE INDEX IF NOT EXISTS uq_visits_queue_date_number
ON public.visits (queue_date, queue_number)
WHERE deleted_at IS NULL AND queue_number IS NOT NULL;

-- 4. Repair today's currently active visit created before the trigger fix.
--    There is currently one active visit today, so it becomes Q001.
WITH numbered AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY queue_date
      ORDER BY created_at, id
    )::integer AS new_queue_number
  FROM public.visits
  WHERE deleted_at IS NULL
    AND queue_date = current_date
    AND queue_number IS NULL
)
UPDATE public.visits v
SET queue_number = numbered.new_queue_number
FROM numbered
WHERE v.id = numbered.id;

-- 5. Synchronize queue tickets for active visits repaired above.
UPDATE public.queue_tickets qt
SET queue_number = 'Q' || v.queue_number::text
FROM public.visits v
WHERE qt.visit_id = v.id
  AND v.deleted_at IS NULL
  AND v.queue_number IS NOT NULL
  AND qt.status = 'waiting';
