-- ROSHAN Phase 3 pharmacy runtime hardening
create index if not exists medicines_barcode_idx on public.medicines (barcode) where deleted_at is null and barcode is not null;
create index if not exists medicines_generic_name_idx on public.medicines (generic_name) where deleted_at is null and generic_name is not null;
create index if not exists pharmacy_inventory_fefo_idx on public.pharmacy_inventory (medicine_id, expiry_date asc, created_at asc) where deleted_at is null and quantity_remaining > 0;
create index if not exists stock_movements_medicine_created_idx on public.stock_movements (medicine_id, created_at desc);

create or replace function public.fn_receive_pharmacy_batch(p_medicine_id uuid,p_quantity numeric,p_batch_number text default null,p_expiry_date date default null,p_manufacture_date date default null,p_purchase_price numeric default 0,p_selling_price numeric default null,p_supplier_id uuid default null,p_invoice_reference text default null) returns uuid language plpgsql security definer set search_path = public as $$
declare v_uid uuid := public.current_app_user_id(); v_branch uuid; v_batch_id uuid; v_sell numeric;
begin
  if not public.app_has_perm('pharmacy.update') then raise exception 'insufficient_permission' using errcode='42501'; end if;
  if p_quantity is null or p_quantity <> trunc(p_quantity) or p_quantity <= 0 then raise exception 'invalid_quantity'; end if;
  if p_purchase_price is null or p_purchase_price < 0 then raise exception 'invalid_purchase_price'; end if;
  if p_expiry_date is not null and p_manufacture_date is not null and p_manufacture_date > p_expiry_date then raise exception 'manufacture_after_expiry'; end if;
  select branch_id into v_branch from public.users where id=v_uid;
  select coalesce(p_selling_price, selling_price, 0) into v_sell from public.medicines where id=p_medicine_id and deleted_at is null for update;
  if not found then raise exception 'medicine_not_found'; end if;
  insert into public.pharmacy_inventory(medicine_id,batch_number,batch_no,expiry_date,manufacture_date,quantity,quantity_received,quantity_remaining,purchase_price,selling_price,supplier_id,invoice_reference,branch_id,created_by,updated_by)
  values(p_medicine_id,nullif(trim(p_batch_number),''),nullif(trim(p_batch_number),''),p_expiry_date,p_manufacture_date,p_quantity,p_quantity,p_quantity,p_purchase_price,v_sell,p_supplier_id,nullif(trim(p_invoice_reference),''),v_branch,v_uid,v_uid)
  returning id into v_batch_id;
  update public.medicines set stock_quantity=coalesce(stock_quantity,0)+p_quantity::integer,cost_price=p_purchase_price,selling_price=v_sell,updated_at=now(),updated_by=v_uid where id=p_medicine_id;
  insert into public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by) values(p_medicine_id,v_batch_id,'purchase',p_quantity,v_batch_id,'pharmacy_inventory',v_branch,v_uid);
  return v_batch_id;
end; $$;
revoke all on function public.fn_receive_pharmacy_batch(uuid,numeric,text,date,date,numeric,numeric,uuid,text) from public;
grant execute on function public.fn_receive_pharmacy_batch(uuid,numeric,text,date,date,numeric,numeric,uuid,text) to authenticated;

create or replace function public.fn_dispense_prescription(p_prescription_id uuid) returns table(item_id uuid,medicine_id uuid,medicine_name text,batch_id uuid,batch_number text,expiry_date date,quantity_dispensed numeric,batch_quantity_remaining numeric,source text) language plpgsql security definer set search_path=public as $$
declare v_item record; v_batch record; v_needed numeric; v_take numeric; v_shortfall numeric; v_stock numeric; v_uid uuid:=public.current_app_user_id(); v_branch uuid;
begin
  if not public.app_has_perm('pharmacy.update') then raise exception 'insufficient_permission' using errcode='42501'; end if;
  select branch_id into v_branch from public.users where id=v_uid;
  perform 1 from public.prescriptions where id=p_prescription_id and deleted_at is null and status='pending' for update;
  if not found then raise exception 'prescription_not_pending'; end if;
  for v_item in select pi.id,pi.medicine_id,coalesce(pi.quantity,1) qty,m.name from public.prescription_items pi join public.medicines m on m.id=pi.medicine_id where pi.prescription_id=p_prescription_id and pi.deleted_at is null and pi.medicine_id is not null order by pi.id loop
    v_needed:=v_item.qty;
    for v_batch in select id,batch_number,expiry_date,quantity_remaining from public.pharmacy_inventory where medicine_id=v_item.medicine_id and quantity_remaining>0 and deleted_at is null and (expiry_date is null or expiry_date>=current_date) order by expiry_date asc nulls last,created_at asc for update loop
      exit when v_needed<=0;
      v_take:=least(v_needed,v_batch.quantity_remaining);
      update public.pharmacy_inventory set quantity_remaining=quantity_remaining-v_take,quantity=quantity_remaining-v_take,updated_at=now(),updated_by=v_uid where id=v_batch.id;
      insert into public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by) values(v_item.medicine_id,v_batch.id,'dispense',-v_take,p_prescription_id,'prescriptions',v_branch,v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=v_batch.id; batch_number:=v_batch.batch_number; expiry_date:=v_batch.expiry_date; quantity_dispensed:=v_take; batch_quantity_remaining:=v_batch.quantity_remaining-v_take; source:='batch'; return next;
      v_needed:=v_needed-v_take;
    end loop;
    v_shortfall:=greatest(v_needed,0);
    if v_shortfall>0 then
      select stock_quantity into v_stock from public.medicines where id=v_item.medicine_id and deleted_at is null for update;
      if coalesce(v_stock,0)<v_shortfall then raise exception 'insufficient_stock: %',v_item.name; end if;
      insert into public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by) values(v_item.medicine_id,null,'dispense',-v_shortfall,p_prescription_id,'prescriptions',v_branch,v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=null; batch_number:=null; expiry_date:=null; quantity_dispensed:=v_shortfall; batch_quantity_remaining:=null; source:='legacy'; return next;
    end if;
    update public.medicines set stock_quantity=stock_quantity-v_item.qty::integer,updated_at=now(),updated_by=v_uid where id=v_item.medicine_id;
    update public.prescription_items set is_dispensed=true,dispensed_quantity=v_item.qty,updated_at=now(),updated_by=v_uid where id=v_item.id;
  end loop;
  update public.prescriptions set status='dispensed',dispensed_by=v_uid,dispensed_at=now(),updated_at=now(),updated_by=v_uid where id=p_prescription_id;
  return;
end; $$;
revoke all on function public.fn_dispense_prescription(uuid) from public;
grant execute on function public.fn_dispense_prescription(uuid) to authenticated;
