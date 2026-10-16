CREATE OR REPLACE FUNCTION public.fn_dispense_prescription(p_prescription_id uuid)
RETURNS TABLE(item_id uuid, medicine_id uuid, medicine_name text, batch_id uuid, batch_number text, expiry_date date, quantity_dispensed numeric, batch_quantity_remaining numeric, source text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  v_item record; v_batch record; v_needed numeric; v_take numeric; v_shortfall numeric; v_stock numeric;
  v_uid uuid := public.current_app_user_id(); v_branch uuid; v_prescription_branch uuid;
begin
  if not public.app_has_perm('pharmacy.update') then raise exception 'insufficient_permission' using errcode='42501'; end if;
  select u.branch_id into v_branch from public.users u where u.id=v_uid and u.deleted_at is null;
  if v_branch is null and not public.is_super_admin() then raise exception 'user branch is not configured'; end if;

  perform 1 from public.prescriptions p
  where p.id=p_prescription_id and p.deleted_at is null and p.status='pending'
  for update;
  if not found then raise exception 'prescription_not_pending'; end if;

  select v.branch_id into v_prescription_branch
  from public.prescriptions p join public.visits v on v.id=p.visit_id
  where p.id=p_prescription_id;
  if not public.is_super_admin() and v_prescription_branch is distinct from v_branch then raise exception 'cross_branch_access_denied'; end if;

  for v_item in
    select pi.id, pi.medicine_id, coalesce(pi.quantity,1) as qty, m.name
    from public.prescription_items pi join public.medicines m on m.id=pi.medicine_id
    where pi.prescription_id=p_prescription_id and pi.deleted_at is null and pi.medicine_id is not null
    order by pi.id
  loop
    v_needed := v_item.qty;
    for v_batch in
      select inv.id, inv.batch_number, inv.expiry_date, inv.quantity_remaining
      from public.pharmacy_inventory inv
      where inv.medicine_id=v_item.medicine_id and inv.quantity_remaining>0 and inv.deleted_at is null
        and (inv.expiry_date is null or inv.expiry_date>=current_date)
        and (public.is_super_admin() or inv.branch_id=v_branch)
      order by inv.expiry_date asc nulls last, inv.created_at asc
      for update
    loop
      exit when v_needed<=0;
      v_take := least(v_needed, v_batch.quantity_remaining);
      update public.pharmacy_inventory inv
      set quantity_remaining=inv.quantity_remaining-v_take, quantity=inv.quantity_remaining-v_take,
          updated_at=now(), updated_by=v_uid where inv.id=v_batch.id;
      insert into public.stock_movements (medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by)
      values (v_item.medicine_id,v_batch.id,'dispense',-v_take,p_prescription_id,'prescriptions',coalesce(v_prescription_branch,v_branch),v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=v_batch.id;
      batch_number:=v_batch.batch_number; expiry_date:=v_batch.expiry_date; quantity_dispensed:=v_take;
      batch_quantity_remaining:=v_batch.quantity_remaining-v_take; source:='batch'; return next;
      v_needed := v_needed-v_take;
    end loop;

    v_shortfall := greatest(v_needed,0);
    if v_shortfall>0 then
      select m.stock_quantity into v_stock from public.medicines m where m.id=v_item.medicine_id and m.deleted_at is null for update;
      if coalesce(v_stock,0)<v_shortfall then raise exception 'insufficient_stock: %',v_item.name; end if;
      insert into public.stock_movements (medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by)
      values (v_item.medicine_id,null,'dispense',-v_shortfall,p_prescription_id,'prescriptions',coalesce(v_prescription_branch,v_branch),v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=null;
      batch_number:=null; expiry_date:=null; quantity_dispensed:=v_shortfall; batch_quantity_remaining:=null; source:='legacy'; return next;
    end if;

    update public.medicines m set stock_quantity=m.stock_quantity-v_item.qty::integer, updated_at=now(), updated_by=v_uid
    where m.id=v_item.medicine_id;
    update public.prescription_items pi set is_dispensed=true, dispensed_quantity=v_item.qty, updated_at=now(), updated_by=v_uid
    where pi.id=v_item.id;
  end loop;
  update public.prescriptions p set status='dispensed', dispensed_by=v_uid, dispensed_at=now(), updated_at=now(), updated_by=v_uid
  where p.id=p_prescription_id;
  return;
end;
$function$;
