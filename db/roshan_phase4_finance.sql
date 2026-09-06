-- =====================================================================
-- ROSHAN MEDICAL CENTER — PHASE 4: FINANCE CORE
-- Cashbox ledger, customer receivables, suppliers, supplier bills and
-- supplier payments.
--
-- Safe to run multiple times (idempotent). Purely additive:
--   * no DROP TABLE, no DELETE, no data loss
--   * existing tables are only extended with missing columns
--   * finance triggers owned by this file are replaced, not duplicated
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. PRE-FLIGHT: required helpers from phase 1 must exist
-- ---------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.app_has_perm(text)') is null then
    raise exception 'run db/roshan_phase1_migration.sql first (app_has_perm missing)';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamptz,
  deleted_by uuid
);

alter table public.suppliers add column if not exists contact_person text;
alter table public.suppliers add column if not exists email text;
alter table public.suppliers add column if not exists notes text;
alter table public.suppliers add column if not exists active boolean not null default true;

create table if not exists public.supplier_bills (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id),
  branch_id uuid,
  invoice_number text,
  bill_date date not null default current_date,
  due_date date,
  subtotal numeric(14,2) not null default 0,
  discount_amount numeric(14,2) not null default 0,
  total_amount numeric(14,2) not null default 0,
  paid_amount numeric(14,2) not null default 0,
  status text not null default 'unpaid',
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

create table if not exists public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  supplier_bill_id uuid references public.supplier_bills(id),
  supplier_id uuid not null references public.suppliers(id),
  branch_id uuid,
  amount numeric(14,2) not null,
  payment_method text not null default 'cash',
  reference text,
  payment_date date not null default current_date,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

create table if not exists public.cashbox_transactions (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid,
  transaction_type text not null,
  amount numeric(14,2) not null,
  payment_method text not null default 'cash',
  category text,
  description text,
  source_type text,
  source_id uuid,
  transaction_date timestamptz not null default now(),
  created_by uuid,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

-- reversal / correction bookkeeping (no hard edits to posted rows)
alter table public.cashbox_transactions add column if not exists reversal_of uuid;
alter table public.cashbox_transactions add column if not exists is_reversed boolean not null default false;
alter table public.cashbox_transactions add column if not exists reversal_reason text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'cashbox_transactions_reversal_of_fkey'
  ) then
    alter table public.cashbox_transactions
      add constraint cashbox_transactions_reversal_of_fkey
      foreign key (reversal_of) references public.cashbox_transactions(id);
  end if;
end $$;

-- one ledger row per business document: makes double posting impossible
create unique index if not exists uq_cashbox_source
  on public.cashbox_transactions (source_type, source_id)
  where source_id is not null;

create index if not exists ix_cashbox_date on public.cashbox_transactions (transaction_date desc);
create index if not exists ix_cashbox_type on public.cashbox_transactions (transaction_type);
create index if not exists ix_supplier_bills_supplier on public.supplier_bills (supplier_id);
create index if not exists ix_supplier_bills_status on public.supplier_bills (status);
create index if not exists ix_supplier_payments_bill on public.supplier_payments (supplier_bill_id);
create index if not exists ix_supplier_payments_supplier on public.supplier_payments (supplier_id);
create unique index if not exists uq_payments_idempotency
  on public.payments (idempotency_key)
  where idempotency_key is not null;

-- ---------------------------------------------------------------------
-- 2. VIEWS (security_invoker => caller's RLS applies)
-- ---------------------------------------------------------------------

drop view if exists public.cashbox_balance;
create view public.cashbox_balance
  with (security_invoker = true) as
select
  coalesce(sum(amount), 0)::numeric(14,2) as balance,
  coalesce(sum(case when amount > 0 then amount else 0 end), 0)::numeric(14,2) as total_in,
  coalesce(sum(case when amount < 0 then -amount else 0 end), 0)::numeric(14,2) as total_out
from public.cashbox_transactions
where deleted_at is null;

drop view if exists public.v_supplier_outstanding;
create view public.v_supplier_outstanding
  with (security_invoker = true) as
select
  s.id as supplier_id,
  s.name,
  s.phone,
  count(b.id) filter (where b.id is not null) as bills_count,
  coalesce(sum(b.total_amount), 0)::numeric(14,2) as total_billed,
  coalesce(sum(b.paid_amount), 0)::numeric(14,2) as total_paid,
  coalesce(sum(greatest(b.total_amount - b.paid_amount, 0)), 0)::numeric(14,2) as outstanding
from public.suppliers s
left join public.supplier_bills b
  on b.supplier_id = s.id and b.deleted_at is null
where s.deleted_at is null
group by s.id, s.name, s.phone;

drop view if exists public.v_patient_receivables;
create view public.v_patient_receivables
  with (security_invoker = true) as
select
  i.id as invoice_id,
  i.invoice_number,
  i.invoice_date,
  i.patient_id,
  p.full_name as patient_name,
  p.mrn,
  p.phone,
  coalesce(i.net_amount, i.total_amount, 0)::numeric(14,2) as net_amount,
  coalesce(i.paid_amount, 0)::numeric(14,2) as paid_amount,
  greatest(coalesce(i.net_amount, i.total_amount, 0) - coalesce(i.paid_amount, 0), 0)::numeric(14,2) as outstanding,
  coalesce(i.status, i.payment_status, 'unpaid') as status
from public.invoices i
left join public.patients p on p.id = i.patient_id
where i.deleted_at is null
  and greatest(coalesce(i.net_amount, i.total_amount, 0) - coalesce(i.paid_amount, 0), 0) > 0;

-- ---------------------------------------------------------------------
-- 3. LEDGER IMMUTABILITY + AUDIT
-- ---------------------------------------------------------------------

create or replace function public.fn_cashbox_immutable()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('roshan.cashbox_write', true), '') = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception
    'posted cashbox transactions cannot be % — use reverse_cashbox_entry() instead', lower(tg_op);
end $$;

drop trigger if exists trg_cashbox_immutable on public.cashbox_transactions;
create trigger trg_cashbox_immutable
  before update or delete on public.cashbox_transactions
  for each row execute function public.fn_cashbox_immutable();

create or replace function public.fn_finance_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  begin
    uid := public.current_app_user_id();
  exception when others then uid := null;
  end;

  insert into public.audit_logs (table_name, record_id, action, user_id, old_data, new_data)
  values (
    tg_table_name,
    coalesce((case when tg_op = 'DELETE' then old.id else new.id end), gen_random_uuid()),
    tg_op,
    uid,
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end
  );
  return case when tg_op = 'DELETE' then old else new end;
end $$;

do $$
declare tbl text;
begin
  foreach tbl in array array['cashbox_transactions','supplier_bills','supplier_payments','payments','expenses']
  loop
    execute format('drop trigger if exists trg_finance_audit on public.%I', tbl);
    execute format(
      'create trigger trg_finance_audit after insert or update or delete on public.%I
         for each row execute function public.fn_finance_audit()', tbl);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 4. LEDGER SYNC TRIGGERS (idempotent, never double count)
--    Any pre-existing cashbox trigger on these tables is removed first
--    so a document can only ever produce one ledger row.
-- ---------------------------------------------------------------------

do $$
declare r record;
begin
  for r in
    select t.tgname, c.relname
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'public'
      and not t.tgisinternal
      and c.relname in ('payments','expenses','supplier_payments')
      and (p.proname ilike '%cash%' or p.proname ilike '%ledger%')
  loop
    execute format('drop trigger %I on public.%I', r.tgname, r.relname);
  end loop;
end $$;

create or replace function public.fn_ledger_post(
  _type text,
  _amount numeric,
  _method text,
  _category text,
  _description text,
  _source_type text,
  _source_id uuid,
  _date timestamptz,
  _branch uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid; uid uuid;
begin
  if _amount is null or _amount = 0 then
    return null;
  end if;

  begin
    uid := public.current_app_user_id();
  exception when others then uid := null;
  end;

  insert into public.cashbox_transactions (
    branch_id, transaction_type, amount, payment_method, category,
    description, source_type, source_id, transaction_date, created_by
  ) values (
    _branch, _type, _amount, coalesce(_method, 'cash'), _category,
    _description, _source_type, _source_id, coalesce(_date, now()), uid
  )
  on conflict (source_type, source_id) where source_id is not null
  do nothing
  returning id into new_id;

  return new_id;
end $$;

create or replace function public.fn_ledger_from_payment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.fn_ledger_post(
    'income', abs(new.amount), coalesce(new.payment_method, new.method, 'cash'),
    'patient_payment',
    'Invoice payment', 'payment', new.id,
    coalesce(new.payment_date::timestamptz, new.received_at, now()), new.branch_id);
  return new;
end $$;

drop trigger if exists trg_ledger_from_payment on public.payments;
create trigger trg_ledger_from_payment
  after insert on public.payments
  for each row execute function public.fn_ledger_from_payment();

create or replace function public.fn_ledger_from_expense()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.fn_ledger_post(
    'expense', -abs(new.amount), coalesce(new.payment_method, 'cash'),
    coalesce(new.category, 'other'),
    coalesce(new.description, 'Expense'), 'expense', new.id,
    coalesce(new.expense_date::timestamptz, now()), new.branch_id);
  return new;
end $$;

drop trigger if exists trg_ledger_from_expense on public.expenses;
create trigger trg_ledger_from_expense
  after insert on public.expenses
  for each row execute function public.fn_ledger_from_expense();

create or replace function public.fn_ledger_from_supplier_payment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.fn_ledger_post(
    'supplier_payment', -abs(new.amount), coalesce(new.payment_method, 'cash'),
    'supplier',
    coalesce(new.notes, 'Supplier payment'), 'supplier_payment', new.id,
    coalesce(new.payment_date::timestamptz, now()), new.branch_id);
  return new;
end $$;

drop trigger if exists trg_ledger_from_supplier_payment on public.supplier_payments;
create trigger trg_ledger_from_supplier_payment
  after insert on public.supplier_payments
  for each row execute function public.fn_ledger_from_supplier_payment();

-- ---------------------------------------------------------------------
-- 5. RECOMPUTE TRIGGERS (paid_amount + status are derived, never added)
-- ---------------------------------------------------------------------

create or replace function public.fn_recompute_invoice_paid()
returns trigger language plpgsql security definer set search_path = public as $$
declare inv uuid; total numeric; net numeric;
begin
  inv := coalesce(new.invoice_id, old.invoice_id);
  if inv is null then
    return coalesce(new, old);
  end if;

  select coalesce(sum(amount), 0) into total
  from public.payments
  where invoice_id = inv and deleted_at is null;

  select coalesce(i.net_amount, i.total_amount, 0) into net
  from public.invoices i where i.id = inv;

  update public.invoices
     set paid_amount = total,
         status = case when total <= 0 then 'unpaid'
                       when total >= net then 'paid'
                       else 'partial' end,
         payment_status = case when total <= 0 then 'unpaid'
                               when total >= net then 'paid'
                               else 'partial' end,
         updated_at = now()
   where id = inv;

  return coalesce(new, old);
end $$;

drop trigger if exists trg_recompute_invoice_paid on public.payments;
create trigger trg_recompute_invoice_paid
  after insert or update or delete on public.payments
  for each row execute function public.fn_recompute_invoice_paid();

create or replace function public.fn_recompute_supplier_bill()
returns trigger language plpgsql security definer set search_path = public as $$
declare bill uuid; total numeric; due numeric;
begin
  bill := coalesce(new.supplier_bill_id, old.supplier_bill_id);
  if bill is null then
    return coalesce(new, old);
  end if;

  select coalesce(sum(amount), 0) into total
  from public.supplier_payments
  where supplier_bill_id = bill and deleted_at is null;

  select coalesce(total_amount, 0) into due
  from public.supplier_bills where id = bill;

  update public.supplier_bills
     set paid_amount = total,
         status = case when total <= 0 then 'unpaid'
                       when total >= due then 'paid'
                       else 'partial' end,
         updated_at = now()
   where id = bill;

  return coalesce(new, old);
end $$;

drop trigger if exists trg_recompute_supplier_bill on public.supplier_payments;
create trigger trg_recompute_supplier_bill
  after insert or update or delete on public.supplier_payments
  for each row execute function public.fn_recompute_supplier_bill();

-- ---------------------------------------------------------------------
-- 6. RPCs — atomic finance operations
-- ---------------------------------------------------------------------

create or replace function public.post_invoice_payment(
  _invoice_id uuid,
  _amount numeric,
  _method text default 'cash',
  _reference text default null,
  _idempotency_key text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare net numeric; already numeric; outstanding numeric; pay_id uuid; uid uuid; br uuid;
begin
  if not public.app_has_perm('payments.create') and not public.app_has_perm('billing.create') then
    raise exception 'not authorised to record payments';
  end if;
  if _amount is null or _amount <= 0 then
    raise exception 'payment amount must be greater than zero';
  end if;

  if _idempotency_key is not null then
    select id into pay_id from public.payments where idempotency_key = _idempotency_key;
    if pay_id is not null then
      return pay_id;
    end if;
  end if;

  select coalesce(i.net_amount, i.total_amount, 0), coalesce(i.paid_amount, 0), i.branch_id
    into net, already, br
  from public.invoices i
  where i.id = _invoice_id and i.deleted_at is null
  for update;

  if net is null then
    raise exception 'invoice not found';
  end if;

  outstanding := greatest(net - already, 0);
  if _amount > outstanding then
    raise exception 'payment (%) exceeds outstanding balance (%)', _amount, outstanding;
  end if;

  uid := public.current_app_user_id();

  insert into public.payments (
    invoice_id, amount, payment_method, method, reference_no, reference,
    payment_date, received_at, received_by, created_by, branch_id, idempotency_key
  ) values (
    _invoice_id, _amount, coalesce(_method, 'cash'), coalesce(_method, 'cash'),
    nullif(btrim(coalesce(_reference, '')), ''), nullif(btrim(coalesce(_reference, '')), ''),
    current_date, now(), uid, uid, br, _idempotency_key
  ) returning id into pay_id;

  return pay_id;
end $$;

create or replace function public.post_expense(
  _category text,
  _amount numeric,
  _description text default null,
  _expense_date date default current_date,
  _method text default 'cash',
  _paid_to text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare exp_id uuid; uid uuid;
begin
  if not public.app_has_perm('accounting.create') then
    raise exception 'not authorised to record expenses';
  end if;
  if _amount is null or _amount <= 0 then
    raise exception 'expense amount must be greater than zero';
  end if;

  uid := public.current_app_user_id();

  insert into public.expenses (
    category, amount, description, expense_date, payment_method, paid_to, created_by
  ) values (
    coalesce(_category, 'other'), _amount, _description,
    coalesce(_expense_date, current_date), coalesce(_method, 'cash'), _paid_to, uid
  ) returning id into exp_id;

  return exp_id;
end $$;

create or replace function public.post_cashbox_entry(
  _direction text,
  _amount numeric,
  _method text default 'cash',
  _category text default 'manual',
  _description text default null,
  _date timestamptz default now()
) returns uuid
language plpgsql security definer set search_path = public as $$
declare signed numeric; new_id uuid; uid uuid;
begin
  if not public.app_has_perm('cashbox.create') then
    raise exception 'not authorised to post cashbox entries';
  end if;
  if _amount is null or _amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;
  if _direction not in ('deposit', 'withdrawal') then
    raise exception 'direction must be deposit or withdrawal';
  end if;

  signed := case when _direction = 'deposit' then _amount else -_amount end;
  uid := public.current_app_user_id();

  insert into public.cashbox_transactions (
    transaction_type, amount, payment_method, category, description,
    source_type, transaction_date, created_by
  ) values (
    _direction, signed, coalesce(_method, 'cash'), coalesce(_category, 'manual'),
    _description, 'manual', coalesce(_date, now()), uid
  ) returning id into new_id;

  return new_id;
end $$;

create or replace function public.reverse_cashbox_entry(
  _transaction_id uuid,
  _reason text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare orig public.cashbox_transactions; new_id uuid; uid uuid;
begin
  if not public.app_has_perm('cashbox.update') and not public.is_super_admin() then
    raise exception 'not authorised to reverse cashbox entries';
  end if;
  if _reason is null or btrim(_reason) = '' then
    raise exception 'a reversal reason is required';
  end if;

  select * into orig from public.cashbox_transactions where id = _transaction_id;
  if orig.id is null then
    raise exception 'transaction not found';
  end if;
  if orig.is_reversed then
    raise exception 'transaction already reversed';
  end if;
  if orig.reversal_of is not null then
    raise exception 'a reversal entry cannot itself be reversed';
  end if;

  uid := public.current_app_user_id();

  insert into public.cashbox_transactions (
    branch_id, transaction_type, amount, payment_method, category, description,
    source_type, transaction_date, created_by, reversal_of, reversal_reason
  ) values (
    orig.branch_id, 'reversal', -orig.amount, orig.payment_method, orig.category,
    coalesce(orig.description, '') || ' — reversal: ' || _reason,
    'reversal', now(), uid, orig.id, _reason
  ) returning id into new_id;

  perform set_config('roshan.cashbox_write', 'on', true);
  update public.cashbox_transactions
     set is_reversed = true, reversal_reason = _reason
   where id = orig.id;
  perform set_config('roshan.cashbox_write', 'off', true);

  return new_id;
end $$;

create or replace function public.post_supplier_bill(
  _supplier_id uuid,
  _invoice_number text,
  _bill_date date,
  _due_date date,
  _subtotal numeric,
  _discount numeric default 0,
  _notes text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare bill_id uuid; uid uuid; net numeric;
begin
  if not public.app_has_perm('debts.create') and not public.app_has_perm('pharmacy.create') then
    raise exception 'not authorised to record supplier bills';
  end if;
  if _subtotal is null or _subtotal <= 0 then
    raise exception 'bill total must be greater than zero';
  end if;

  net := greatest(_subtotal - coalesce(_discount, 0), 0);
  uid := public.current_app_user_id();

  insert into public.supplier_bills (
    supplier_id, invoice_number, bill_date, due_date, subtotal,
    discount_amount, total_amount, paid_amount, status, notes, created_by
  ) values (
    _supplier_id, nullif(btrim(coalesce(_invoice_number, '')), ''),
    coalesce(_bill_date, current_date), _due_date, _subtotal,
    coalesce(_discount, 0), net, 0, 'unpaid', _notes, uid
  ) returning id into bill_id;

  return bill_id;
end $$;

create or replace function public.post_supplier_payment(
  _bill_id uuid,
  _amount numeric,
  _method text default 'cash',
  _reference text default null,
  _payment_date date default current_date,
  _notes text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare bill public.supplier_bills; outstanding numeric; pay_id uuid; uid uuid;
begin
  if not public.app_has_perm('debts.create') and not public.app_has_perm('accounting.create') then
    raise exception 'not authorised to pay suppliers';
  end if;
  if _amount is null or _amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  select * into bill from public.supplier_bills
   where id = _bill_id and deleted_at is null for update;
  if bill.id is null then
    raise exception 'supplier bill not found';
  end if;

  outstanding := greatest(coalesce(bill.total_amount, 0) - coalesce(bill.paid_amount, 0), 0);
  if _amount > outstanding then
    raise exception 'payment (%) exceeds outstanding balance (%)', _amount, outstanding;
  end if;

  uid := public.current_app_user_id();

  insert into public.supplier_payments (
    supplier_bill_id, supplier_id, branch_id, amount, payment_method,
    reference, payment_date, notes, created_by
  ) values (
    bill.id, bill.supplier_id, bill.branch_id, _amount, coalesce(_method, 'cash'),
    nullif(btrim(coalesce(_reference, '')), ''), coalesce(_payment_date, current_date),
    _notes, uid
  ) returning id into pay_id;

  return pay_id;
end $$;

-- ---------------------------------------------------------------------
-- 7. BACKFILL: post already-recorded documents into the ledger once
-- ---------------------------------------------------------------------

insert into public.cashbox_transactions (
  branch_id, transaction_type, amount, payment_method, category,
  description, source_type, source_id, transaction_date, created_by
)
select p.branch_id, 'income', abs(p.amount),
       coalesce(p.payment_method, p.method, 'cash'), 'patient_payment',
       'Invoice payment', 'payment', p.id,
       coalesce(p.payment_date::timestamptz, p.received_at, p.created_at, now()), p.created_by
from public.payments p
where p.deleted_at is null
on conflict (source_type, source_id) where source_id is not null do nothing;

insert into public.cashbox_transactions (
  branch_id, transaction_type, amount, payment_method, category,
  description, source_type, source_id, transaction_date, created_by
)
select e.branch_id, 'expense', -abs(e.amount),
       coalesce(e.payment_method, 'cash'), coalesce(e.category, 'other'),
       coalesce(e.description, 'Expense'), 'expense', e.id,
       coalesce(e.expense_date::timestamptz, e.created_at, now()), e.created_by
from public.expenses e
where e.deleted_at is null
on conflict (source_type, source_id) where source_id is not null do nothing;

insert into public.cashbox_transactions (
  branch_id, transaction_type, amount, payment_method, category,
  description, source_type, source_id, transaction_date, created_by
)
select sp.branch_id, 'supplier_payment', -abs(sp.amount),
       coalesce(sp.payment_method, 'cash'), 'supplier',
       coalesce(sp.notes, 'Supplier payment'), 'supplier_payment', sp.id,
       coalesce(sp.payment_date::timestamptz, sp.created_at, now()), sp.created_by
from public.supplier_payments sp
where sp.deleted_at is null
on conflict (source_type, source_id) where source_id is not null do nothing;

-- ---------------------------------------------------------------------
-- 8. PERMISSIONS
-- ---------------------------------------------------------------------

insert into public.permissions (code, name, module, action)
values
  ('cashbox.read',      'View cashbox',        'cashbox',   'read'),
  ('cashbox.create',    'Post cashbox entry',  'cashbox',   'create'),
  ('cashbox.update',    'Reverse cashbox entry','cashbox',  'update'),
  ('debts.read',        'View debts',          'debts',     'read'),
  ('debts.create',      'Create debt records', 'debts',     'create'),
  ('debts.update',      'Update debt records', 'debts',     'update'),
  ('suppliers.read',    'View suppliers',      'suppliers', 'read'),
  ('suppliers.create',  'Create suppliers',    'suppliers', 'create'),
  ('suppliers.update',  'Update suppliers',    'suppliers', 'update')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code in ('super_admin', 'admin')
  and p.code in (
    'cashbox.read','cashbox.create','cashbox.update',
    'debts.read','debts.create','debts.update',
    'suppliers.read','suppliers.create','suppliers.update')
  and not exists (
    select 1 from public.role_permissions rp
    where rp.role_id = r.id and rp.permission_id = p.id
  );

-- accountant-style roles get read + posting rights where the role exists
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code in ('accountant', 'cashier')
  and p.code in ('cashbox.read','cashbox.create','debts.read','suppliers.read')
  and not exists (
    select 1 from public.role_permissions rp
    where rp.role_id = r.id and rp.permission_id = p.id
  );

-- ---------------------------------------------------------------------
-- 9. GRANTS + RLS
-- ---------------------------------------------------------------------

grant select, insert, update on public.suppliers to authenticated;
grant select, insert, update on public.supplier_bills to authenticated;
grant select, insert on public.supplier_payments to authenticated;
grant select, insert on public.cashbox_transactions to authenticated;
grant select on public.cashbox_balance to authenticated;
grant select on public.v_supplier_outstanding to authenticated;
grant select on public.v_patient_receivables to authenticated;

grant all on public.suppliers to service_role;
grant all on public.supplier_bills to service_role;
grant all on public.supplier_payments to service_role;
grant all on public.cashbox_transactions to service_role;

grant execute on function public.post_invoice_payment(uuid, numeric, text, text, text) to authenticated;
grant execute on function public.post_expense(text, numeric, text, date, text, text) to authenticated;
grant execute on function public.post_cashbox_entry(text, numeric, text, text, text, timestamptz) to authenticated;
grant execute on function public.reverse_cashbox_entry(uuid, text) to authenticated;
grant execute on function public.post_supplier_bill(uuid, text, date, date, numeric, numeric, text) to authenticated;
grant execute on function public.post_supplier_payment(uuid, numeric, text, text, date, text) to authenticated;

alter table public.suppliers enable row level security;
alter table public.supplier_bills enable row level security;
alter table public.supplier_payments enable row level security;
alter table public.cashbox_transactions enable row level security;

do $$
declare
  spec record;
begin
  for spec in
    select * from (values
      ('cashbox_transactions', 'cashbox.read',   'cashbox.create',   'cashbox.update'),
      ('suppliers',            'suppliers.read', 'suppliers.create', 'suppliers.update'),
      ('supplier_bills',       'debts.read',     'debts.create',     'debts.update'),
      ('supplier_payments',    'debts.read',     'debts.create',     'debts.update')
    ) as v(tbl, p_read, p_create, p_update)
  loop
    execute format('drop policy if exists %I on public.%I', spec.tbl || '_fin_sel', spec.tbl);
    execute format('drop policy if exists %I on public.%I', spec.tbl || '_fin_ins', spec.tbl);
    execute format('drop policy if exists %I on public.%I', spec.tbl || '_fin_upd', spec.tbl);
    execute format('drop policy if exists %I on public.%I', spec.tbl || '_fin_del', spec.tbl);

    execute format(
      'create policy %I on public.%I for select to authenticated using (public.app_has_perm(%L))',
      spec.tbl || '_fin_sel', spec.tbl, spec.p_read);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.app_has_perm(%L))',
      spec.tbl || '_fin_ins', spec.tbl, spec.p_create);

    -- posted ledger rows are never updatable/deletable through the API
    if spec.tbl <> 'cashbox_transactions' and spec.tbl <> 'supplier_payments' then
      execute format(
        'create policy %I on public.%I for update to authenticated using (public.app_has_perm(%L)) with check (public.app_has_perm(%L))',
        spec.tbl || '_fin_upd', spec.tbl, spec.p_update, spec.p_update);
    end if;
  end loop;
end $$;

commit;
