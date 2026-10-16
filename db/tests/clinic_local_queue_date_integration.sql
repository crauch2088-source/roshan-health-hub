DO $$
DECLARE
  v_id uuid;
  actual_queue_date date;
  actual_ticket_date date;
  actual_ticket_count integer;
BEGIN
  -- Clinic-local midnight in Sudan: 2026-10-16 00:00 +02 = 2026-10-15 22:00 UTC.
  -- No queue_date is supplied, so this verifies the database fallback.
  INSERT INTO public.visits (patient_id, visit_date)
  VALUES ('00000000-0000-0000-0000-000000000123', '2026-10-15 22:00:00+00')
  RETURNING id, queue_date INTO v_id, actual_queue_date;

  IF actual_queue_date IS DISTINCT FROM DATE '2026-10-16' THEN
    RAISE EXCEPTION 'Expected clinic queue_date 2026-10-16, got %', actual_queue_date;
  END IF;

  SELECT count(*), min(visit_date)
    INTO actual_ticket_count, actual_ticket_date
  FROM public.queue_tickets
  WHERE visit_id = v_id;

  IF actual_ticket_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one queue ticket, got %', actual_ticket_count;
  END IF;

  IF actual_ticket_date IS DISTINCT FROM DATE '2026-10-16' THEN
    RAISE EXCEPTION 'Expected queue ticket date 2026-10-16, got %', actual_ticket_date;
  END IF;

  INSERT INTO public.visits (patient_id, visit_date, queue_date)
  VALUES ('00000000-0000-0000-0000-000000000124', '2026-10-15 22:00:00+00', DATE '2026-10-16')
  RETURNING id, queue_date INTO v_id, actual_queue_date;

  IF actual_queue_date IS DISTINCT FROM DATE '2026-10-16' THEN
    RAISE EXCEPTION 'Explicit clinic queue_date was not preserved: %', actual_queue_date;
  END IF;

  SELECT count(*), min(visit_date)
    INTO actual_ticket_count, actual_ticket_date
  FROM public.queue_tickets
  WHERE visit_id = v_id;

  IF actual_ticket_count <> 1 OR actual_ticket_date IS DISTINCT FROM DATE '2026-10-16' THEN
    RAISE EXCEPTION 'Explicit queue date did not produce exactly one correctly dated ticket';
  END IF;
END;
$$;
