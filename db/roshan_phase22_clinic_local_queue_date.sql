-- Phase 22: keep queue dates aligned with the clinic's local calendar.
-- Sudan's clinic-local midnight is 22:00 UTC on the previous date.
-- The UI supplies queue_date explicitly; these database fallbacks also protect
-- other callers that create visits without that field.

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
    WHERE v.queue_date = d;

    new.queue_number := next_number;
  END IF;

  new.visit_number := new.queue_number::text;
  RETURN new;
END;
$function$;

CREATE OR REPLACE FUNCTION private.create_queue_ticket()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.queue_tickets
    (visit_id, patient_id, visit_date, queue_number, status, department_id)
  VALUES
    (
      new.id,
      new.patient_id,
      coalesce(
        new.queue_date,
        (new.visit_date AT TIME ZONE 'Africa/Khartoum')::date
      ),
      'Q' || new.queue_number::text,
      'waiting',
      new.department_id
    );

  RETURN new;
END;
$function$;
