do $$ begin
  if exists (select reversal_of from public.cashbox_transactions where reversal_of is not null group by reversal_of having count(*) > 1) then
    raise exception 'Cannot add unique reversal index: duplicate reversal_of values already exist';
  end if;
end $$;
create unique index if not exists uq_cashbox_reversal_of on public.cashbox_transactions (reversal_of) where reversal_of is not null;
create or replace function public.reverse_cashbox_entry(_transaction_id uuid, _reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare orig public.cashbox_transactions; new_id uuid; uid uuid; bid uuid;
begin
  if not public.app_has_perm('cashbox.update') and not public.is_super_admin() then raise exception 'not authorised to reverse cashbox entries'; end if;
  if _reason is null or btrim(_reason) = '' then raise exception 'a reversal reason is required'; end if;
  select * into orig from public.cashbox_transactions where id = _transaction_id for update;
  if orig.id is null then raise exception 'transaction not found'; end if;
  if orig.is_reversed then raise exception 'transaction already reversed'; end if;
  if orig.reversal_of is not null then raise exception 'a reversal entry cannot itself be reversed'; end if;
  uid := public.current_app_user_id();
  select branch_id into bid from public.users where id = uid;
  if not public.is_super_admin() and (bid is null or orig.branch_id is distinct from bid) then raise exception 'cross-branch cashbox access denied'; end if;
  insert into public.cashbox_transactions (branch_id, transaction_type, amount, payment_method, category, description, source_type, transaction_date, created_by, reversal_of, reversal_reason)
  values (orig.branch_id, 'adjustment', -orig.amount, orig.payment_method, orig.category, coalesce(orig.description, '') || ' — reversal: ' || _reason, 'reversal', now(), uid, orig.id, _reason) returning id into new_id;
  perform pg_catalog.set_config('roshan.cashbox_write', 'on', true);
  update public.cashbox_transactions set is_reversed = true, reversal_reason = _reason where id = orig.id;
  perform pg_catalog.set_config('roshan.cashbox_write', 'off', true);
  return new_id;
end $$;
