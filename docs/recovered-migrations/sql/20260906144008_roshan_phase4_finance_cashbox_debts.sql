begin;

-- Phase 4: finance ledger, cashbox and supplier/customer debt controls.
create table if not exists public.cashbox_transactions (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id) on delete set null,
  transaction_type text not null check (transaction_type in ('customer_payment','expense','supplier_payment','deposit','withdrawal','adjustment')),
  amount numeric not null check (amount <> 0),
  payment_method text,
  category text,
  description text,
  source_type text,
  source_id uuid,
  transaction_date timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.users(id) on delete set null
);
create unique index if not exists uq_cashbox_source on public.cashbox_transactions(source_type, source_id) where source_type is not null and source_id is not null;
create index if not exists idx_cashbox_date on public.cashbox_transactions(transaction_date desc) where deleted_at is null;
create index if not exists idx_cashbox_branch_date on public.cashbox_transactions(branch_id, transaction_date desc) where deleted_at is null;

create table if not exists public.supplier_bills (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  branch_id uuid references public.branches(id) on delete set null,
  invoice_number text,
  bill_date date not null default current_date,
  due_date date,
  subtotal numeric not null default 0 check (subtotal >= 0),
  discount_amount numeric not null default 0 check (discount_amount >= 0),
  total_amount numeric not null default 0 check (total_amount >= 0),
  paid_amount numeric not null default 0 check (paid_amount >= 0),
  status text not null default 'unpaid' check (status in ('unpaid','partial','paid','cancelled')),
  notes text,
  created_by uuid references public.users(id) on delete set null,
  updated_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.users(id) on delete set null,
  check (paid_amount <= total_amount)
);
create index if not exists idx_supplier_bills_supplier_date on public.supplier_bills(supplier_id, bill_date desc) where deleted_at is null;
create index if not exists idx_supplier_bills_status on public.supplier_bills(status) where deleted_at is null;

create table if not exists public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  supplier_bill_id uuid not null references public.supplier_bills(id) on delete restrict,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  branch_id uuid references public.branches(id) on delete set null,
  amount numeric not null check (amount > 0),
  payment_method text not null default 'cash',
  reference text,
  payment_date timestamptz not null default now(),
  notes text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.users(id) on delete set null
);
create index if not exists idx_supplier_payments_bill_date on public.supplier_payments(supplier_bill_id, payment_date desc) where deleted_at is null;

-- Grants and RLS: accounting permission is the gate for finance operations.
grant select, insert, update, delete on public.cashbox_transactions to authenticated;
grant select, insert, update, delete on public.supplier_bills to authenticated;
grant select, insert, update, delete on public.supplier_payments to authenticated;
grant all on public.cashbox_transactions, public.supplier_bills, public.supplier_payments to service_role;

drop policy if exists cashbox_sel on public.cashbox_transactions;
drop policy if exists cashbox_ins on public.cashbox_transactions;
drop policy if exists cashbox_upd on public.cashbox_transactions;
drop policy if exists cashbox_del on public.cashbox_transactions;
create policy cashbox_sel on public.cashbox_transactions for select to authenticated using (public.app_has_perm('accounting.read'));
create policy cashbox_ins on public.cashbox_transactions for insert to authenticated with check (public.app_has_perm('accounting.create'));
create policy cashbox_upd on public.cashbox_transactions for update to authenticated using (public.is_super_admin()) with check (public.is_super_admin());
create policy cashbox_del on public.cashbox_transactions for delete to authenticated using (public.is_super_admin());

drop policy if exists supplier_bills_sel on public.supplier_bills;
drop policy if exists supplier_bills_ins on public.supplier_bills;
drop policy if exists supplier_bills_upd on public.supplier_bills;
drop policy if exists supplier_bills_del on public.supplier_bills;
create policy supplier_bills_sel on public.supplier_bills for select to authenticated using (public.app_has_perm('accounting.read'));
create policy supplier_bills_ins on public.supplier_bills for insert to authenticated with check (public.app_has_perm('accounting.create'));
create policy supplier_bills_upd on public.supplier_bills for update to authenticated using (public.app_has_perm('accounting.update')) with check (public.app_has_perm('accounting.update'));
create policy supplier_bills_del on public.supplier_bills for delete to authenticated using (public.is_super_admin());

drop policy if exists supplier_payments_sel on public.supplier_payments;
drop policy if exists supplier_payments_ins on public.supplier_payments;
drop policy if exists supplier_payments_upd on public.supplier_payments;
drop policy if exists supplier_payments_del on public.supplier_payments;
create policy supplier_payments_sel on public.supplier_payments for select to authenticated using (public.app_has_perm('accounting.read'));
create policy supplier_payments_ins on public.supplier_payments for insert to authenticated with check (public.app_has_perm('accounting.create'));
create policy supplier_payments_upd on public.supplier_payments for update to authenticated using (public.app_has_perm('accounting.update')) with check (public.app_has_perm('accounting.update'));
create policy supplier_payments_del on public.supplier_payments for delete to authenticated using (public.is_super_admin());

-- Finance permissions (idempotent). Admin receives them; super_admin is implicit.
insert into public.permissions(code,name,module,action) values
 ('cashbox.read','Cashbox read','cashbox','read'),
 ('cashbox.create','Cashbox create','cashbox','create'),
 ('cashbox.update','Cashbox update','cashbox','update'),
 ('debts.read','Debts read','debts','read'),
 ('debts.create','Debts create','debts','create'),
 ('debts.update','Debts update','debts','update')
on conflict (code) do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code='admin' and p.code in ('cashbox.read','cashbox.create','cashbox.update','debts.read','debts.create','debts.update')
on conflict (role_id,permission_id) do nothing;

-- Canonical cashbox insertion for existing and future customer payments.
create or replace function public.record_cashbox_payment()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(new.deleted_at is null, true) and coalesce(new.amount,0) > 0 then
    insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,description,source_type,source_id,transaction_date,created_by)
    values(new.branch_id,'customer_payment',new.amount,coalesce(new.payment_method,new.method,'cash'),'Customer invoice payment', 'payment', new.id, coalesce(new.payment_date,new.received_at,now()), coalesce(new.received_by,public.current_app_user_id()))
    on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;
  end if;
  return new;
end; $$;

drop trigger if exists trg_cashbox_payment on public.payments;
create trigger trg_cashbox_payment after insert on public.payments for each row execute function public.record_cashbox_payment();

create or replace function public.record_cashbox_expense()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(new.deleted_at is null, true) and coalesce(new.amount,0) > 0 then
    insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,source_type,source_id,transaction_date,created_by)
    values(new.branch_id,'expense',-new.amount,coalesce(new.payment_method,'cash'),new.category,new.description,'expense',new.id,(new.expense_date::timestamp at time zone 'UTC'),coalesce(new.created_by,public.current_app_user_id()))
    on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;
  end if;
  return new;
end; $$;

drop trigger if exists trg_cashbox_expense on public.expenses;
create trigger trg_cashbox_expense after insert on public.expenses for each row execute function public.record_cashbox_expense();

create or replace function public.record_cashbox_supplier_payment()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(new.deleted_at is null, true) and coalesce(new.amount,0) > 0 then
    insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,description,source_type,source_id,transaction_date,created_by)
    values(new.branch_id,'supplier_payment',-new.amount,new.payment_method,'Supplier bill payment','supplier_payment',new.id,new.payment_date,coalesce(new.created_by,public.current_app_user_id()))
    on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;
  end if;
  return new;
end; $$;

drop trigger if exists trg_cashbox_supplier_payment on public.supplier_payments;
create trigger trg_cashbox_supplier_payment after insert on public.supplier_payments for each row execute function public.record_cashbox_supplier_payment();

create or replace function public.sync_supplier_bill_payment()
returns trigger language plpgsql security definer set search_path=public as $$
declare new_paid numeric;
begin
  if new.deleted_at is not null then return new; end if;
  select coalesce(sum(amount),0) into new_paid from public.supplier_payments where supplier_bill_id=new.supplier_bill_id and deleted_at is null;
  update public.supplier_bills
    set paid_amount=least(new_paid,total_amount),
        status=case when new_paid >= total_amount then 'paid' when new_paid > 0 then 'partial' else 'unpaid' end,
        updated_at=now(), updated_by=coalesce(new.created_by,public.current_app_user_id())
    where id=new.supplier_bill_id;
  return new;
end; $$;

drop trigger if exists trg_sync_supplier_bill_payment on public.supplier_payments;
create trigger trg_sync_supplier_bill_payment after insert or update on public.supplier_payments for each row execute function public.sync_supplier_bill_payment();

-- Manual cashbox movements are performed through a controlled function so branch/user attribution is server-side.
create or replace function public.add_cashbox_entry(_direction text,_amount numeric,_type text default 'adjustment',_method text default 'cash',_category text default null,_description text default null,_date timestamptz default now())
returns uuid language plpgsql security definer set search_path=public as $$
declare uid uuid; bid uuid; txid uuid;
begin
  if not public.app_has_perm('accounting.create') then raise exception 'Permission denied'; end if;
  if _direction not in ('in','out') then raise exception 'Invalid cashbox direction'; end if;
  if _amount is null or _amount <= 0 then raise exception 'Amount must be greater than zero'; end if;
  if _type not in ('deposit','withdrawal','adjustment') then raise exception 'Invalid manual transaction type'; end if;
  uid:=public.current_app_user_id();
  select branch_id into bid from public.users where id=uid;
  insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,transaction_date,created_by)
  values(bid,_type,case when _direction='in' then _amount else -_amount end,_method,_category,_description,coalesce(_date,now()),uid)
  returning id into txid;
  return txid;
end; $$;
grant execute on function public.add_cashbox_entry(text,numeric,text,text,text,text,timestamptz) to authenticated;

create or replace view public.cashbox_balance as
select coalesce(sum(amount) filter (where deleted_at is null),0)::numeric as balance from public.cashbox_transactions;

-- Historical backfill, idempotent by source key.
insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,description,source_type,source_id,transaction_date,created_by)
select p.branch_id,'customer_payment',p.amount,coalesce(p.payment_method,p.method,'cash'),'Historical customer invoice payment','payment',p.id,coalesce(p.payment_date,p.received_at,now()),p.received_by
from public.payments p where p.deleted_at is null and p.amount > 0
on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;
insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,source_type,source_id,transaction_date,created_by)
select e.branch_id,'expense',-e.amount,coalesce(e.payment_method,'cash'),e.category,e.description,'expense',e.id,(e.expense_date::timestamp at time zone 'UTC'),e.created_by
from public.expenses e where e.deleted_at is null and e.amount > 0
on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;

-- Audit the new finance records with the existing append-only audit function.
drop trigger if exists trg_audit_cashbox_transactions on public.cashbox_transactions;
create trigger trg_audit_cashbox_transactions after insert or update or delete on public.cashbox_transactions for each row execute function public.audit_row_change();
drop trigger if exists trg_audit_supplier_bills on public.supplier_bills;
create trigger trg_audit_supplier_bills after insert or update or delete on public.supplier_bills for each row execute function public.audit_row_change();
drop trigger if exists trg_audit_supplier_payments on public.supplier_payments;
create trigger trg_audit_supplier_payments after insert or update or delete on public.supplier_payments for each row execute function public.audit_row_change();

commit;
