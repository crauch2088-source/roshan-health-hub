begin;

alter table public.visits
  add column if not exists queue_number integer;

alter table public.visits
  add column if not exists queue_date date;

create or replace function public.set_visit_queue_date()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.queue_date := coalesce(new.queue_date, new.visit_date::date, current_date);
  return new;
end;
$$;

drop trigger if exists trg_set_visit_queue_date on public.visits;
create trigger trg_set_visit_queue_date
before insert or update of visit_date on public.visits
for each row
execute function public.set_visit_queue_date();

update public.visits
set queue_date = visit_date::date
where queue_date is null;

drop function if exists public.next_queue_number(date);

create function public.next_queue_number(_visit_date date)
returns integer
language plpgsql
security definer
set search_path = public
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

  select coalesce(max(queue_number), 0) + 1
    into next_number
  from public.visits
  where queue_date = _visit_date
    and deleted_at is null;

  return next_number;
end;
$$;

grant execute on function public.next_queue_number(date) to authenticated;

create unique index if not exists visits_queue_number_day_key
  on public.visits (queue_date, queue_number)
  where deleted_at is null and queue_number is not null;

commit;
