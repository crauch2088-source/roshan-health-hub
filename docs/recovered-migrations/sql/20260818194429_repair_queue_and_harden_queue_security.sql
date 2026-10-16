-- ROSHAN queue integrity repair

-- 1) Ensure queue date is always derived from the visit date.
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

-- The frontend needs this RPC; anonymous clients must never be able to call it.
revoke execute on function public.next_queue_number(date) from public, anon;
grant execute on function public.next_queue_number(date) to authenticated;

-- 2) Database-side fallback: every visit gets a queue date, and if a caller
--    does not provide a queue number, PostgreSQL allocates one atomically.
create schema if not exists private;

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

  return new;
end;
$$;

revoke all on function private.ensure_visit_queue() from public, anon, authenticated;

drop trigger if exists trg_visits_ensure_queue on public.visits;
create trigger trg_visits_ensure_queue
before insert on public.visits
for each row
execute function private.ensure_visit_queue();

-- 3) Queue tickets must NEVER trust a queue number supplied by the client.
--    They derive it from the authoritative visits.queue_number.
create or replace function private.sync_queue_ticket_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  q integer;
  d date;
  p uuid;
  dept uuid;
begin
  if new.visit_id is null then
    raise exception 'queue ticket requires visit_id';
  end if;

  select v.queue_number,
         v.queue_date,
         v.patient_id,
         v.department_id
    into q, d, p, dept
  from public.visits v
  where v.id = new.visit_id;

  if q is null then
    raise exception 'visit % has no queue number', new.visit_id;
  end if;

  new.queue_number := 'Q' || q::text;
  new.visit_date := coalesce(new.visit_date, d, current_date);
  new.patient_id := coalesce(new.patient_id, p);
  new.department_id := coalesce(new.department_id, dept);

  return new;
end;
$$;

revoke all on function private.sync_queue_ticket_number() from public, anon, authenticated;

drop trigger if exists trg_queue_ticket_sync_number on public.queue_tickets;
create trigger trg_queue_ticket_sync_number
before insert or update of visit_id, queue_number on public.queue_tickets
for each row
execute function private.sync_queue_ticket_number();

-- 4) Repair existing queue tickets that were incorrectly copied from visit_number.
update public.queue_tickets qt
set queue_number = 'Q' || v.queue_number::text,
    visit_date = coalesce(v.queue_date, qt.visit_date),
    patient_id = coalesce(qt.patient_id, v.patient_id),
    department_id = coalesce(qt.department_id, v.department_id)
from public.visits v
where qt.visit_id = v.id
  and v.queue_number is not null
  and qt.queue_number is distinct from ('Q' || v.queue_number::text);

-- 5) Enforce one queue position per day. Keep the existing canonical index
--    and remove its duplicate.
drop index if exists public.visits_queue_number_day_key;
create unique index if not exists uq_visits_queue_date_number
  on public.visits (queue_date, queue_number)
  where queue_number is not null;

-- 6) Faster queue lookup.
create index if not exists idx_visits_queue_day
  on public.visits (queue_date, queue_number)
  where deleted_at is null;

create index if not exists idx_queue_tickets_visit_id
  on public.queue_tickets (visit_id);

-- 7) Replace deprecated auth.role() checks on these two tables with the
--    native target-role mechanism. Existing application authorization remains
--    at the RLS layer used by the project.
drop policy if exists optimized_auth_policy_visits on public.visits;
create policy optimized_auth_policy_visits
on public.visits
for all
to authenticated
using (true)
with check (true);

drop policy if exists optimized_auth_policy_queue_tickets on public.queue_tickets;
create policy optimized_auth_policy_queue_tickets
on public.queue_tickets
for all
to authenticated
using (true)
with check (true);
