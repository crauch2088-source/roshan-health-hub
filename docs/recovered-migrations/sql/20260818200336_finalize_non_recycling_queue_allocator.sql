-- Final queue allocator: visit.queue_number is the authoritative sequence.
-- It is monotonic for a day, including soft-deleted visits, so numbers are never reused.
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

  if new.queue_number is null then
    perform pg_advisory_xact_lock(
      hashtextextended('roshan.queue.' || d::text, 0)
    );

    select coalesce(max(v.queue_number), 0) + 1
      into next_number
    from public.visits v
    where v.queue_date = d;

    new.queue_number := next_number;
  end if;

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

  select coalesce(max(v.queue_number), 0) + 1
    into next_number
  from public.visits v
  where v.queue_date = _visit_date;

  return next_number;
end;
$$;
