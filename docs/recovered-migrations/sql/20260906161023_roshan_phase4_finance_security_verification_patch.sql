-- ROSHAN Phase 4 — finance security / verification patch
-- Idempotent: safe to run once; does not delete or rewrite financial data.

alter table public.cashbox_transactions enable row level security;
alter table public.supplier_bills enable row level security;
alter table public.supplier_payments enable row level security;

-- Cashbox: read/create for accounting users; only Super Admin may mutate/delete ledger rows.
drop policy if exists cashbox_sel on public.cashbox_transactions;
create policy cashbox_sel on public.cashbox_transactions
  for select to authenticated using (public.app_has_perm('accounting.read'));
drop policy if exists cashbox_ins on public.cashbox_transactions;
create policy cashbox_ins on public.cashbox_transactions
  for insert to authenticated with check (public.app_has_perm('accounting.create'));
drop policy if exists cashbox_upd on public.cashbox_transactions;
create policy cashbox_upd on public.cashbox_transactions
  for update to authenticated using (public.is_super_admin()) with check (public.is_super_admin());
drop policy if exists cashbox_del on public.cashbox_transactions;
create policy cashbox_del on public.cashbox_transactions
  for delete to authenticated using (public.is_super_admin());

-- Supplier bills/payments follow the accounting permission matrix.
drop policy if exists supplier_bills_sel on public.supplier_bills;
create policy supplier_bills_sel on public.supplier_bills
  for select to authenticated using (public.app_has_perm('accounting.read'));
drop policy if exists supplier_bills_ins on public.supplier_bills;
create policy supplier_bills_ins on public.supplier_bills
  for insert to authenticated with check (public.app_has_perm('accounting.create'));
drop policy if exists supplier_bills_upd on public.supplier_bills;
create policy supplier_bills_upd on public.supplier_bills
  for update to authenticated using (public.app_has_perm('accounting.update')) with check (public.app_has_perm('accounting.update'));
drop policy if exists supplier_bills_del on public.supplier_bills;
create policy supplier_bills_del on public.supplier_bills
  for delete to authenticated using (public.is_super_admin());

drop policy if exists supplier_payments_sel on public.supplier_payments;
create policy supplier_payments_sel on public.supplier_payments
  for select to authenticated using (public.app_has_perm('accounting.read'));
drop policy if exists supplier_payments_ins on public.supplier_payments;
create policy supplier_payments_ins on public.supplier_payments
  for insert to authenticated with check (public.app_has_perm('accounting.create'));
drop policy if exists supplier_payments_upd on public.supplier_payments;
create policy supplier_payments_upd on public.supplier_payments
  for update to authenticated using (public.app_has_perm('accounting.update')) with check (public.app_has_perm('accounting.update'));
drop policy if exists supplier_payments_del on public.supplier_payments;
create policy supplier_payments_del on public.supplier_payments
  for delete to authenticated using (public.is_super_admin());

-- Idempotency guard for automatically posted cash movements.
create unique index if not exists uq_cashbox_source
  on public.cashbox_transactions(source_type, source_id)
  where source_type is not null and source_id is not null;

create index if not exists idx_cashbox_date
  on public.cashbox_transactions(transaction_date desc)
  where deleted_at is null;
create index if not exists idx_cashbox_branch_date
  on public.cashbox_transactions(branch_id, transaction_date desc)
  where deleted_at is null;
