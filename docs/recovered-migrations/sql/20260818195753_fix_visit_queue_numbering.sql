-- Fix ROSHAN visit/queue numbering: one authoritative daily sequence in visits.queue_number.
-- visit_number is kept as a compatibility/display field and mirrors queue_number.

create or replace function private.ensure_visit_queue()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  d date;
  next_number integer;
begin
  d := coalesce(new.queue_date, (new.visit_date at time zone 'UTC')::date, current_date);
  new.queue_date := d;

  if new.queue_number is null then
    perform pg_advisory_xact_lock(hashtextextended('roshan.queue.' || d::text, 0));

    select coalesce(max(v.queue_number), 0) + 1
      into next_number
    from public.visits v
    where v.queue_date = d
      and v.deleted_at is null;

    new.queue_number := next_number;
  end if;

  -- Legacy compatibility: the UI historically displayed visit_number as Qxxxx.
  -- It must never be random; it mirrors the authoritative queue_number.
  new.visit_number := new.queue_number::text;

  return new;
end;
$function$;

-- Repair existing active visits deterministically by creation order for each day.
with numbered as (
  select id,
         row_number() over (partition by queue_date order by created_at, id) as rn
  from public.visits
  where deleted_at is null
)
update public.visits v
set queue_number = n.rn,
    visit_number = n.rn::text
from numbered n
where v.id = n.id;

-- Ensure every active visit has a corresponding queue ticket.
insert into public.queue_tickets
  (visit_id, patient_id, visit_date, queue_number, status, department_id)
select v.id,
       v.patient_id,
       v.queue_date,
       'Q' || v.queue_number::text,
       case when v.status = 'waiting' then 'waiting' else coalesce(v.status, 'waiting') end,
       v.department_id
from public.visits v
where v.deleted_at is null
  and v.queue_number is not null
  and not exists (
    select 1 from public.queue_tickets q where q.visit_id = v.id
  );

-- Remove the old application-level random-number assumption by documenting the source of truth.
comment on column public.visits.queue_number is 'Authoritative daily queue sequence. Assigned by private.ensure_visit_queue().';
comment on column public.visits.visit_number is 'Legacy compatibility/display field. Mirrors queue_number as text.';
