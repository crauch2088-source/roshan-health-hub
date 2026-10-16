CREATE OR REPLACE FUNCTION public.reverse_cashbox_entry(_transaction_id uuid, _reason text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  orig public.cashbox_transactions;
  new_id uuid;
  uid uuid;
  bid uuid;
begin
  if not public.app_has_perm('cashbox.update') and not public.is_super_admin() then
    raise exception 'not authorised to reverse cashbox entries';
  end if;
  if _reason is null or btrim(_reason)='' then
    raise exception 'a reversal reason is required';
  end if;

  select * into orig
  from public.cashbox_transactions
  where id=_transaction_id;

  if orig.id is null then raise exception 'transaction not found'; end if;
  if orig.is_reversed then raise exception 'transaction already reversed'; end if;
  if orig.reversal_of is not null then raise exception 'a reversal entry cannot itself be reversed'; end if;

  uid:=public.current_app_user_id();
  select branch_id into bid from public.users where id=uid;

  if not public.is_super_admin() and (bid is null or orig.branch_id is distinct from bid) then
    raise exception 'cross-branch cashbox access denied';
  end if;

  -- Use the existing, approved transaction type 'adjustment'.
  -- The reversal semantics are represented explicitly by source_type/reversal_of/reversal_reason.
  insert into public.cashbox_transactions(
    branch_id, transaction_type, amount, payment_method, category,
    description, source_type, transaction_date, created_by,
    reversal_of, reversal_reason
  )
  values(
    orig.branch_id, 'adjustment', -orig.amount, orig.payment_method, orig.category,
    coalesce(orig.description,'') || ' — reversal: ' || _reason,
    'reversal', now(), uid, orig.id, _reason
  )
  returning id into new_id;

  perform set_config('roshan.cashbox_write','on',true);
  update public.cashbox_transactions
  set is_reversed=true, reversal_reason=_reason
  where id=orig.id;
  perform set_config('roshan.cashbox_write','off',true);

  return new_id;
end;
$function$;
