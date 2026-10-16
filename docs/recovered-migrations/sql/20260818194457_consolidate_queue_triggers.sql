-- Consolidate queue-related triggers so there is exactly one source of truth.

-- Remove legacy queue triggers that can compete with the new allocator.
drop trigger if exists trg_set_visit_queue_date on public.visits;
drop trigger if exists trg_set_visit_queue_number on public.visits;
drop trigger if exists on_visit_created on public.visits;

-- The queue allocator now lives only in the private trigger function.
-- The ticket creator also lives privately and derives its display number from visits.
create or replace function private.create_queue_ticket()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.queue_tickets
    (visit_id, patient_id, visit_date, queue_number, status, department_id)
  values
    (new.id,
     new.patient_id,
     coalesce(new.queue_date, (new.visit_date at time zone 'UTC')::date),
     'Q' || new.queue_number::text,
     'waiting',
     new.department_id);

  return new;
end;
$$;

revoke all on function private.create_queue_ticket() from public, anon, authenticated;

create trigger on_visit_created
after insert on public.visits
for each row
execute function private.create_queue_ticket();

-- Move the locked-visit protection trigger implementation out of the exposed API schema.
create or replace function private.prevent_locked_visit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(old.is_locked, false) = true
     and not public.is_super_admin()
  then
    raise exception 'This visit is locked and cannot be modified.';
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function private.prevent_locked_visit_mutation() from public, anon, authenticated;

drop trigger if exists trg_prevent_locked_visit_mutation on public.visits;
create trigger trg_prevent_locked_visit_mutation
before delete or update on public.visits
for each row
execute function private.prevent_locked_visit_mutation();

-- Remove the old exposed trigger helpers now that their triggers are gone.
drop function if exists public.add_to_queue();
drop function if exists public.set_visit_queue_date();
drop function if exists public.set_visit_queue_number();
drop function if exists public.prevent_locked_visit_mutation();

-- Keep legacy visit-number RPCs callable only by signed-in application users.
revoke execute on function public.next_visit_number(date) from public, anon;
grant execute on function public.next_visit_number(date) to authenticated;

-- These authorization helpers are intentionally callable by signed-in users only.
revoke execute on function public.app_has_perm(text) from public, anon;
grant execute on function public.app_has_perm(text) to authenticated;
revoke execute on function public.current_app_user_id() from public, anon;
grant execute on function public.current_app_user_id() to authenticated;
revoke execute on function public.current_role_code() from public, anon;
grant execute on function public.current_role_code() to authenticated;
revoke execute on function public.is_super_admin() from public, anon;
grant execute on function public.is_super_admin() to authenticated;
