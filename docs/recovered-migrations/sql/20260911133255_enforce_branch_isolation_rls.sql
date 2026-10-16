create or replace function private.app_has_branch_access(_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(private.is_super_admin(), false)
    or exists (
      select 1
      from public.users u
      where u.auth_user_id = auth.uid()
        and coalesce(u.active, true) = true
        and u.branch_id = _branch_id
    )
$$;

do $$
declare
  r record;
  q text;
  w text;
begin
  for r in
    select tablename, policyname, cmd, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'appointments','cashbox_transactions','expenses','invoices','lab_orders',
        'patients','payments','pharmacy_inventory','stock_movements',
        'supplier_bills','supplier_payments','users','visits'
      )
  loop
    q := case when r.qual is null then null
              else '(' || r.qual || ') and (select private.app_has_branch_access(branch_id))' end;
    w := case when r.with_check is null then null
              else '(' || r.with_check || ') and (select private.app_has_branch_access(branch_id))' end;

    if q is not null and w is not null then
      execute format('alter policy %I on public.%I using (%s) with check (%s)', r.policyname, r.tablename, q, w);
    elsif q is not null then
      execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, q);
    elsif w is not null then
      execute format('alter policy %I on public.%I with check (%s)', r.policyname, r.tablename, w);
    end if;
  end loop;
end $$;
