create or replace function public.next_visit_number(_visit_date date)
returns text
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
    hashtextextended('roshan.visit.' || _visit_date::text, 0)
  );

  select coalesce(
    max(case
      when visit_number ~ '^[0-9]+$' then visit_number::integer
      else null
    end), 0
  ) + 1
  into next_number
  from public.visits
  where visit_date = _visit_date
    and deleted_at is null;

  return lpad(next_number::text, 3, '0');
end;
$$;

grant execute on function public.next_visit_number(date) to authenticated;
