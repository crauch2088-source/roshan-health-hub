CREATE SCHEMA private;

CREATE TABLE public.visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL,
  visit_date timestamptz NOT NULL,
  queue_date date,
  queue_number integer,
  visit_number text,
  department_id uuid,
  deleted_at timestamptz
);

CREATE TABLE public.queue_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id uuid NOT NULL,
  patient_id uuid NOT NULL,
  visit_date date NOT NULL,
  queue_number text NOT NULL,
  status text NOT NULL,
  department_id uuid
);

CREATE UNIQUE INDEX visits_visit_number_day_key ON public.visits (visit_date, visit_number);

CREATE FUNCTION private.ensure_visit_queue() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  d date;
  next_number integer;
BEGIN
  d := coalesce(new.queue_date, (new.visit_date AT TIME ZONE 'UTC')::date, current_date);
  new.queue_date := d;
  IF new.queue_number IS NULL THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('roshan.queue.' || d::text, 0));
    SELECT coalesce(max(v.queue_number), 0) + 1 INTO next_number
    FROM public.visits v WHERE v.queue_date = d;
    new.queue_number := next_number;
  END IF;
  new.visit_number := new.queue_number::text;
  RETURN new;
END;
$function$;

CREATE FUNCTION private.create_queue_ticket() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.queue_tickets
    (visit_id, patient_id, visit_date, queue_number, status, department_id)
  VALUES
    (new.id, new.patient_id,
     coalesce(new.queue_date, (new.visit_date AT TIME ZONE 'UTC')::date),
     'Q' || new.queue_number::text, 'waiting', new.department_id);
  RETURN new;
END;
$function$;

CREATE TRIGGER trg_visits_ensure_queue
BEFORE INSERT ON public.visits
FOR EACH ROW EXECUTE FUNCTION private.ensure_visit_queue();

CREATE TRIGGER on_visit_created
AFTER INSERT ON public.visits
FOR EACH ROW EXECUTE FUNCTION private.create_queue_ticket();
