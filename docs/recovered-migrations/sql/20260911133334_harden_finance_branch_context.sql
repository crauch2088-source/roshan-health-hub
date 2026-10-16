create or replace function public.post_cashbox_entry(_direction text,_amount numeric,_method text default 'cash',_category text default 'manual',_description text default null,_date timestamptz default now())
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare signed numeric; new_id uuid; uid uuid; bid uuid;
begin
  if not public.app_has_perm('cashbox.create') then raise exception 'not authorised to post cashbox entries'; end if;
  if _amount is null or _amount<=0 then raise exception 'amount must be greater than zero'; end if;
  if _direction not in ('deposit','withdrawal') then raise exception 'direction must be deposit or withdrawal'; end if;
  uid:=public.current_app_user_id(); select branch_id into bid from public.users where id=uid;
  if not public.is_super_admin() and bid is null then raise exception 'user branch is not configured'; end if;
  signed:=case when _direction='deposit' then _amount else -_amount end;
  insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,source_type,transaction_date,created_by)
  values(bid,_direction,signed,coalesce(_method,'cash'),coalesce(_category,'manual'),_description,'manual',coalesce(_date,now()),uid) returning id into new_id;
  return new_id;
end; $$;

create or replace function public.add_cashbox_entry(_direction text,_amount numeric,_type text default 'adjustment',_method text default 'cash',_category text default null,_description text default null,_date timestamptz default now())
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare uid uuid; bid uuid; txid uuid;
begin
  if not public.app_has_perm('accounting.create') then raise exception 'Permission denied'; end if;
  if _direction not in ('in','out') then raise exception 'Invalid cashbox direction'; end if;
  if _amount is null or _amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if _type not in ('deposit','withdrawal','adjustment') then raise exception 'Invalid manual transaction type'; end if;
  uid:=public.current_app_user_id(); select branch_id into bid from public.users where id=uid;
  if not public.is_super_admin() and bid is null then raise exception 'user branch is not configured'; end if;
  insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,transaction_date,created_by)
  values(bid,_type,case when _direction='in' then _amount else -_amount end,coalesce(_method,'cash'),_category,_description,coalesce(_date,now()),uid) returning id into txid;
  return txid;
end; $$;

create or replace function public.post_expense(_category text,_amount numeric,_description text default null,_expense_date date default current_date,_method text default 'cash',_paid_to text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare exp_id uuid; uid uuid; bid uuid;
begin
  if not public.app_has_perm('accounting.create') then raise exception 'not authorised to record expenses'; end if;
  if _amount is null or _amount<=0 then raise exception 'expense amount must be greater than zero'; end if;
  uid:=public.current_app_user_id(); select branch_id into bid from public.users where id=uid;
  if not public.is_super_admin() and bid is null then raise exception 'user branch is not configured'; end if;
  insert into public.expenses(branch_id,category,amount,description,expense_date,payment_method,paid_to,created_by)
  values(bid,coalesce(_category,'other'),_amount,_description,coalesce(_expense_date,current_date),coalesce(_method,'cash'),_paid_to,uid) returning id into exp_id;
  return exp_id;
end; $$;

create or replace function public.reverse_cashbox_entry(_transaction_id uuid,_reason text)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare orig public.cashbox_transactions; new_id uuid; uid uuid; bid uuid;
begin
  if not public.app_has_perm('cashbox.update') and not public.is_super_admin() then raise exception 'not authorised to reverse cashbox entries'; end if;
  if _reason is null or btrim(_reason)='' then raise exception 'a reversal reason is required'; end if;
  select * into orig from public.cashbox_transactions where id=_transaction_id;
  if orig.id is null then raise exception 'transaction not found'; end if;
  if orig.is_reversed then raise exception 'transaction already reversed'; end if;
  if orig.reversal_of is not null then raise exception 'a reversal entry cannot itself be reversed'; end if;
  uid:=public.current_app_user_id(); select branch_id into bid from public.users where id=uid;
  if not public.is_super_admin() and (bid is null or orig.branch_id is distinct from bid) then raise exception 'cross-branch cashbox access denied'; end if;
  insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,source_type,transaction_date,created_by,reversal_of,reversal_reason)
  values(orig.branch_id,'reversal',-orig.amount,orig.payment_method,orig.category,coalesce(orig.description,'')||' — reversal: '||_reason,'reversal',now(),uid,orig.id,_reason) returning id into new_id;
  perform set_config('roshan.cashbox_write','on',true);
  update public.cashbox_transactions set is_reversed=true,reversal_reason=_reason where id=orig.id;
  perform set_config('roshan.cashbox_write','off',true);
  return new_id;
end; $$;
