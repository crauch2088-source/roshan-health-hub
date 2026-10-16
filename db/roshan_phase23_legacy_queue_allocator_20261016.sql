-- Phase 23: account for pre-fix visits whose stored queue_date is one day early.
-- Legacy rows can have the clinic-local date in visit_date but the prior
-- UTC-derived queue_date, so the allocator must consider both date representations.
CREATE OR REPLACE FUNCTION private.ensure_visit_queue()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  d date;
  next_number integer;
BEGIN
  d := coalesce(
    new.queue_date,
    (new.visit_date AT TIME ZONE 'Africa/Khartoum')::date,
    current_date
  );
  new.queue_date := d;

  IF new.queue_number IS NULL THEN
    PERFORM pg_advisory_xact_lock(
      hashtextextended('roshan.queue.' || d::text, 0)
    );

    SELECT coalesce(max(v.queue_number), 0) + 1
      INTO next_number
    FROM public.visits v
    WHERE v.queue_date = d
       OR (v.visit_date AT TIME ZONE 'Africa/Khartoum')::date = d;

    new.queue_number := next_number;
  END IF;

  new.visit_number := new.queue_number::text;
  RETURN new;
END;
$function$;
