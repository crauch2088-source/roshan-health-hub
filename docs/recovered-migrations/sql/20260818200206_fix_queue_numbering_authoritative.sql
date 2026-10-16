-- ROSHAN: authoritative, non-recycling daily queue numbering
-- Queue numbers are allocated from queue_tickets history, not random UI values
-- and are never reused after a ticket is cancelled/deleted.

create or replace function private.ensure_visit_queue()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  d date;
  next_number integer;
begin
  d := coalesce(new.queue_date, (new.visit_date at time zone 'UTC')::date, current_date);
  new.queue_date := d;

  -- The queue_tickets table is the authoritative history of issued numbers.
  -- We deliberately include cancelled/deleted tickets so a number is never reused.
  if new.queue_number is null then
    perform pg_advisory_xact_lock(
      hashtextextended('roshan.queue.' || d::text, 0)
    );

    select coalesce(
      max(nullif(regexp_replace(q.queue_number, '[^0-9]', '', 'g'), '')::integer),
      0
    ) + 1
      into next_number
    from public.queue_tickets q
    where q.visit_date = d;

    new.queue_number := next_number;
  end if;

  -- visit_number is a legacy compatibility field only.
  new.visit_number := new.queue_number::text;

  return new;
end;
$$;

create or replace function public.next_queue_number(_visit_date date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_number integer;
begin
  if _visit_date is null then
    raise exception 'visit_date is required';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('roshan.queue.' || _visit_date::text, 0)
  );

  select coalesce(
    max(nullif(regexp_replace(q.queue_number, '[^0-9]', '', 'g'), '')::integer),
    0
  ) + 1
    into next_number
  from public.queue_tickets q
  where q.visit_date = _visit_date;

  return next_number;
end;
$$;

-- Repair the legacy records created with random visit_number values.
-- Only records with a real queue_number are changed; historical rows without
-- an authoritative queue number are left untouched.
update public.visits
set visit_number = queue_number::text
where queue_number is not null
  and visit_number is distinct from queue_number::text;

-- Ensure the current day's existing tickets are internally consistent.
update public.queue_tickets q
set queue_number = 'Q' || v.queue_number::text,
    visit_date = coalesce(v.queue_date, (v.visit_date at time zone 'UTC')::date),
    patient_id = v.patient_id,
    department_id = v.department_id
from public.visits v
where q.visit_id = v.id
  and v.queue_number is not null
  and (
    q.queue_number is distinct from 'Q' || v.queue_number::text
    or q.patient_id is distinct from v.patient_id
    or q.department_id is distinct from v.department_id
  );
