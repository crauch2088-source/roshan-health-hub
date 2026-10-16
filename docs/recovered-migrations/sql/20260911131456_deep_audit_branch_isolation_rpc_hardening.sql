create or replace function public.post_invoice_payment(_invoice_id uuid, _amount numeric, _method text default 'cash'::text, _reference text default null::text, _idempotency_key text default null::text)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare net numeric; already numeric; outstanding numeric; pay_id uuid; uid uuid; br uuid; user_br uuid;
begin
  if not public.app_has_perm('payments.create') and not public.app_has_perm('billing.create') then raise exception 'not authorised to record payments'; end if;
  if _amount is null or _amount <= 0 then raise exception 'payment amount must be greater than zero'; end if;
  uid := public.current_app_user_id();
  select branch_id into user_br from public.users where id=uid and deleted_at is null;
  if not public.is_super_admin() and user_br is null then raise exception 'user branch is not configured'; end if;
  if _idempotency_key is not null then
    select id into pay_id from public.payments where idempotency_key = _idempotency_key;
    if pay_id is not null then return pay_id; end if;
  end if;
  select coalesce(i.net_amount, i.total_amount, 0), coalesce(i.paid_amount, 0), i.branch_id into net, already, br
  from public.invoices i where i.id=_invoice_id and i.deleted_at is null for update;
  if net is null then raise exception 'invoice not found'; end if;
  if not public.is_super_admin() and br is distinct from user_br then raise exception 'cross_branch_access_denied'; end if;
  outstanding := greatest(net-already,0);
  if _amount > outstanding then raise exception 'payment (%) exceeds outstanding balance (%)',_amount,outstanding; end if;
  insert into public.payments(invoice_id,amount,payment_method,method,reference_no,reference,payment_date,received_at,received_by,created_by,branch_id,idempotency_key)
  values(_invoice_id,_amount,coalesce(_method,'cash'),coalesce(_method,'cash'),nullif(btrim(coalesce(_reference,'')),''),nullif(btrim(coalesce(_reference,'')),''),current_date,now(),uid,uid,br,_idempotency_key)
  returning id into pay_id;
  return pay_id;
end;$function$;

create or replace function public.post_supplier_payment(_bill_id uuid,_amount numeric,_method text default 'cash'::text,_reference text default null::text,_payment_date date default current_date,_notes text default null::text)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare bill public.supplier_bills; outstanding numeric; pay_id uuid; uid uuid; user_br uuid;
begin
  if not public.app_has_perm('debts.create') and not public.app_has_perm('accounting.create') then raise exception 'not authorised to pay suppliers'; end if;
  if _amount is null or _amount <= 0 then raise exception 'amount must be greater than zero'; end if;
  uid:=public.current_app_user_id();
  select branch_id into user_br from public.users where id=uid and deleted_at is null;
  if not public.is_super_admin() and user_br is null then raise exception 'user branch is not configured'; end if;
  select * into bill from public.supplier_bills where id=_bill_id and deleted_at is null for update;
  if bill.id is null then raise exception 'supplier bill not found'; end if;
  if not public.is_super_admin() and bill.branch_id is distinct from user_br then raise exception 'cross_branch_access_denied'; end if;
  outstanding:=greatest(coalesce(bill.total_amount,0)-coalesce(bill.paid_amount,0),0);
  if _amount>outstanding then raise exception 'payment (%) exceeds outstanding balance (%)',_amount,outstanding; end if;
  insert into public.supplier_payments(supplier_bill_id,supplier_id,branch_id,amount,payment_method,reference,payment_date,notes,created_by)
  values(bill.id,bill.supplier_id,bill.branch_id,_amount,coalesce(_method,'cash'),nullif(btrim(coalesce(_reference,'')),''),coalesce(_payment_date,current_date),_notes,uid)
  returning id into pay_id;
  return pay_id;
end;$function$;

create or replace function public.fn_dispense_prescription(p_prescription_id uuid)
returns table(item_id uuid,medicine_id uuid,medicine_name text,batch_id uuid,batch_number text,expiry_date date,quantity_dispensed numeric,batch_quantity_remaining numeric,source text)
language plpgsql security definer set search_path to 'public' as $function$
declare v_item record; v_batch record; v_needed numeric; v_take numeric; v_shortfall numeric; v_stock numeric; v_uid uuid:=public.current_app_user_id(); v_branch uuid; v_prescription_branch uuid;
begin
  if not public.app_has_perm('pharmacy.update') then raise exception 'insufficient_permission' using errcode='42501'; end if;
  select branch_id into v_branch from public.users where id=v_uid and deleted_at is null;
  if v_branch is null and not public.is_super_admin() then raise exception 'user branch is not configured'; end if;
  select v.branch_id into v_prescription_branch from public.prescriptions p left join public.visits v on v.id=p.visit_id where p.id=p_prescription_id and p.deleted_at is null and p.status='pending' for update;
  if not found then raise exception 'prescription_not_pending'; end if;
  if not public.is_super_admin() and v_prescription_branch is distinct from v_branch then raise exception 'cross_branch_access_denied'; end if;
  for v_item in select pi.id,pi.medicine_id,coalesce(pi.quantity,1) qty,m.name from public.prescription_items pi join public.medicines m on m.id=pi.medicine_id where pi.prescription_id=p_prescription_id and pi.deleted_at is null and pi.medicine_id is not null order by pi.id loop
    v_needed:=v_item.qty;
    for v_batch in select id,batch_number,expiry_date,quantity_remaining from public.pharmacy_inventory where medicine_id=v_item.medicine_id and quantity_remaining>0 and deleted_at is null and (expiry_date is null or expiry_date>=current_date) and (public.is_super_admin() or branch_id=v_branch) order by expiry_date asc nulls last,created_at asc for update loop
      exit when v_needed<=0;
      v_take:=least(v_needed,v_batch.quantity_remaining);
      update public.pharmacy_inventory set quantity_remaining=quantity_remaining-v_take,quantity=quantity_remaining-v_take,updated_at=now(),updated_by=v_uid where id=v_batch.id;
      insert into public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by) values(v_item.medicine_id,v_batch.id,'dispense',-v_take,p_prescription_id,'prescriptions',coalesce(v_prescription_branch,v_branch),v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=v_batch.id; batch_number:=v_batch.batch_number; expiry_date:=v_batch.expiry_date; quantity_dispensed:=v_take; batch_quantity_remaining:=v_batch.quantity_remaining-v_take; source:='batch'; return next;
      v_needed:=v_needed-v_take;
    end loop;
    v_shortfall:=greatest(v_needed,0);
    if v_shortfall>0 then
      select stock_quantity into v_stock from public.medicines where id=v_item.medicine_id and deleted_at is null for update;
      if coalesce(v_stock,0)<v_shortfall then raise exception 'insufficient_stock: %',v_item.name; end if;
      insert into public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by) values(v_item.medicine_id,null,'dispense',-v_shortfall,p_prescription_id,'prescriptions',coalesce(v_prescription_branch,v_branch),v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=null; batch_number:=null; expiry_date:=null; quantity_dispensed:=v_shortfall; batch_quantity_remaining:=null; source:='legacy'; return next;
    end if;
    update public.medicines set stock_quantity=stock_quantity-v_item.qty::integer,updated_at=now(),updated_by=v_uid where id=v_item.medicine_id;
    update public.prescription_items set is_dispensed=true,dispensed_quantity=v_item.qty,updated_at=now(),updated_by=v_uid where id=v_item.id;
  end loop;
  update public.prescriptions set status='dispensed',dispensed_by=v_uid,dispensed_at=now(),updated_at=now(),updated_by=v_uid where id=p_prescription_id;
  return;
end;$function$;
