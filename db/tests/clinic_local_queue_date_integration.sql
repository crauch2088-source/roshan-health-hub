DO $$
DECLARE
  v_id uuid;
  actual_queue_date date;
  actual_ticket_date date;
  actual_ticket_count integer;
  actual_queue_number integer;
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

  -- Legacy rows have the right clinic-local visit_date but a stale queue_date.
  -- Soft-deleted rows still reserve numbers under the existing unique index.
  ALTER TABLE public.visits DISABLE TRIGGER trg_visits_ensure_queue;
  ALTER TABLE public.visits DISABLE TRIGGER on_visit_created;

  INSERT INTO public.visits
    (patient_id, visit_date, queue_date, queue_number, visit_number, deleted_at)
  SELECT
    '00000000-0000-0000-0000-000000000123',
    TIMESTAMPTZ '2026-10-16 22:00:00+00',
    DATE '2026-10-16',
    n,
    n::text,
    now()
  FROM generate_series(1, 7) AS n;

  ALTER TABLE public.visits ENABLE TRIGGER trg_visits_ensure_queue;
  ALTER TABLE public.visits ENABLE TRIGGER on_visit_created;

  INSERT INTO public.visits (patient_id, visit_date, queue_date)
  VALUES (
    '00000000-0000-0000-0000-000000000124',
    TIMESTAMPTZ '2026-10-16 22:00:00+00',
    DATE '2026-10-17'
  )
  RETURNING id, queue_number INTO v_id, actual_queue_number;

  IF actual_queue_number IS DISTINCT FROM 8 THEN
    RAISE EXCEPTION 'Expected legacy-safe queue number 8, got %', actual_queue_number;
  END IF;

  SELECT count(*), min(visit_date)
    INTO actual_ticket_count, actual_ticket_date
  FROM public.queue_tickets
  WHERE visit_id = v_id;

  IF actual_ticket_count <> 1 OR actual_ticket_date IS DISTINCT FROM DATE '2026-10-17' THEN
    RAISE EXCEPTION 'Legacy-safe visit should create exactly one ticket dated 2026-10-17';
  END IF;

END;$$;
