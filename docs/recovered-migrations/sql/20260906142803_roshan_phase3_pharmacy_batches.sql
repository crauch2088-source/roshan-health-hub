begin;

alter table public.pharmacy_inventory
  add column if not exists quantity_received numeric not null default 0,
  add column if not exists quantity_remaining numeric not null default 0,
  add column if not exists manufacture_date date,
  add column if not exists invoice_reference text;

alter table public.pharmacy_inventory
  drop constraint if exists pharmacy_inventory_quantity_received_check,
  drop constraint if exists pharmacy_inventory_quantity_remaining_check,
  drop constraint if exists pharmacy_inventory_quantity_remaining_bound_check,
  drop constraint if exists pharmacy_inventory_dates_check;

alter table public.pharmacy_inventory
  add constraint pharmacy_inventory_quantity_received_check check (quantity_received >= 0),
  add constraint pharmacy_inventory_quantity_remaining_check check (quantity_remaining >= 0),
  add constraint pharmacy_inventory_quantity_remaining_bound_check check (quantity_remaining <= quantity_received),
  add constraint pharmacy_inventory_dates_check
    check (manufacture_date is null or expiry_date is null or manufacture_date <= expiry_date);

update public.pharmacy_inventory
set quantity_received = coalesce(nullif(quantity_received, 0), quantity, 0),
    quantity_remaining = coalesce(nullif(quantity_remaining, 0), quantity, 0)
where quantity_received = 0 and quantity_remaining = 0;

create or replace function public.sync_pharmacy_inventory_legacy_columns()
returns trigger
language plpgsql
as $$
begin
  if new.quantity_remaining is not null then
    new.quantity := new.quantity_remaining;
  elsif new.quantity is not null then
    new.quantity_remaining := new.quantity;
  end if;

  if new.batch_number is not null and new.batch_number <> '' then
    new.batch_no := new.batch_number;
  elsif new.batch_no is not null and new.batch_no <> '' then
    new.batch_number := new.batch_no;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_sync_pharmacy_inventory_legacy on public.pharmacy_inventory;
create trigger trg_sync_pharmacy_inventory_legacy
  before insert or update on public.pharmacy_inventory
  for each row execute function public.sync_pharmacy_inventory_legacy_columns();

create index if not exists idx_pharmacy_inventory_fefo
  on public.pharmacy_inventory (medicine_id, expiry_date)
  where deleted_at is null;

create index if not exists idx_pharmacy_inventory_supplier
  on public.pharmacy_inventory (supplier_id)
  where deleted_at is null;

comment on column public.pharmacy_inventory.quantity_received is
  'Units received into this batch at intake time. Immutable after receiving.';
comment on column public.pharmacy_inventory.quantity_remaining is
  'Units left in this batch. Decremented by FEFO dispensing via fn_dispense_prescription(). Canonical field going forward; `quantity` is a synced legacy mirror.';
comment on column public.pharmacy_inventory.manufacture_date is 'Optional. Must be on/before expiry_date when both are set.';
comment on column public.pharmacy_inventory.invoice_reference is 'Supplier invoice / delivery note number for this batch, free text.';

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  medicine_id uuid not null references public.medicines(id),
  batch_id uuid references public.pharmacy_inventory(id),
  movement_type text not null check (movement_type in ('purchase', 'dispense', 'adjustment', 'return', 'writeoff')),
  quantity numeric not null,
  reference_id uuid,
  reference_table text,
  notes text,
  branch_id uuid references public.branches(id),
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_stock_movements_medicine on public.stock_movements (medicine_id, created_at desc);
create index if not exists idx_stock_movements_batch on public.stock_movements (batch_id);
create index if not exists idx_stock_movements_reference on public.stock_movements (reference_id);

alter table public.stock_movements enable row level security;

drop policy if exists stock_movements_select on public.stock_movements;
create policy stock_movements_select on public.stock_movements
  for select using (app_has_perm('pharmacy.read'));

drop policy if exists stock_movements_insert on public.stock_movements;
create policy stock_movements_insert on public.stock_movements
  for insert with check (app_has_perm('pharmacy.create') or app_has_perm('pharmacy.update'));

drop trigger if exists trg_audit_stock_movements on public.stock_movements;
create trigger trg_audit_stock_movements
  after insert or update or delete on public.stock_movements
  for each row execute function audit_row_change();

comment on table public.stock_movements is
  'Append-only ledger of every pharmacy stock change: purchase (receive), dispense (FEFO or legacy), adjustment, return, writeoff. quantity is signed: negative = stock leaving, positive = stock arriving.';

create or replace function public.fn_dispense_prescription(p_prescription_id uuid)
returns table (
  item_id uuid,
  medicine_id uuid,
  medicine_name text,
  batch_id uuid,
  batch_number text,
  expiry_date date,
  quantity_dispensed numeric,
  batch_quantity_remaining numeric,
  source text
)
language plpgsql
as $$
declare
  v_item record;
  v_batch record;
  v_needed numeric;
  v_take numeric;
  v_from_batches numeric;
  v_shortfall numeric;
  v_stock numeric;
  v_uid uuid := current_app_user_id();
begin
  if not app_has_perm('pharmacy.update') then
    raise exception 'insufficient_permission' using errcode = '42501';
  end if;

  perform 1 from public.prescriptions
    where id = p_prescription_id and deleted_at is null and status = 'pending'
    for update;
  if not found then
    raise exception 'prescription_not_pending';
  end if;

  for v_item in
    select pi.id, pi.medicine_id, coalesce(pi.quantity, 1) as qty, m.name, m.stock_quantity
    from public.prescription_items pi
    join public.medicines m on m.id = pi.medicine_id
    where pi.prescription_id = p_prescription_id
      and pi.deleted_at is null
      and pi.medicine_id is not null
  loop
    v_needed := v_item.qty;
    v_from_batches := 0;

    for v_batch in
      select id, batch_number, expiry_date, quantity_remaining
      from public.pharmacy_inventory
      where medicine_id = v_item.medicine_id
        and quantity_remaining > 0
        and deleted_at is null
      order by expiry_date asc nulls last, created_at asc
      for update
    loop
      exit when v_needed <= 0;

      v_take := least(v_needed, v_batch.quantity_remaining);

      update public.pharmacy_inventory
      set quantity_remaining = quantity_remaining - v_take
      where id = v_batch.id;

      insert into public.stock_movements (medicine_id, batch_id, movement_type, quantity, reference_id, reference_table, created_by)
      values (v_item.medicine_id, v_batch.id, 'dispense', -v_take, p_prescription_id, 'prescriptions', v_uid);

      item_id := v_item.id;
      medicine_id := v_item.medicine_id;
      medicine_name := v_item.name;
      batch_id := v_batch.id;
      batch_number := v_batch.batch_number;
      expiry_date := v_batch.expiry_date;
      quantity_dispensed := v_take;
      batch_quantity_remaining := v_batch.quantity_remaining - v_take;
      source := 'batch';
      return next;

      v_needed := v_needed - v_take;
      v_from_batches := v_from_batches + v_take;
    end loop;

    v_shortfall := v_needed;
    if v_shortfall > 0 then
      select stock_quantity into v_stock from public.medicines where id = v_item.medicine_id for update;
      if v_stock < v_shortfall then
        raise exception 'insufficient_stock: %', v_item.name;
      end if;

      insert into public.stock_movements (medicine_id, batch_id, movement_type, quantity, reference_id, reference_table, created_by)
      values (v_item.medicine_id, null, 'dispense', -v_shortfall, p_prescription_id, 'prescriptions', v_uid);

      item_id := v_item.id;
      medicine_id := v_item.medicine_id;
      medicine_name := v_item.name;
      batch_id := null;
      batch_number := null;
      expiry_date := null;
      quantity_dispensed := v_shortfall;
      batch_quantity_remaining := null;
      source := 'legacy';
      return next;
    end if;

    update public.medicines
    set stock_quantity = stock_quantity - v_item.qty
    where id = v_item.medicine_id;

    update public.prescription_items
    set is_dispensed = true, dispensed_quantity = v_item.qty
    where id = v_item.id;
  end loop;

  update public.prescriptions
  set status = 'dispensed', dispensed_by = v_uid, dispensed_at = now()
  where id = p_prescription_id;

  return;
end;
$$;

comment on function public.fn_dispense_prescription(uuid) is
  'Dispenses every item on a pending prescription using First-Expire-First-Out batch consumption, falling back to medicines.stock_quantity for medicines with no batch stock yet. Runs in one transaction with row locks so concurrent dispensing cannot double-spend the same batch. Returns one row per batch (or legacy) consumption for UI display.';

commit;
