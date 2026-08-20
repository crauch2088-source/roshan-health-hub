-- ROSHAN MEDICAL CENTER — PHASE 2 CLINICAL WORKFLOW FIXES
-- Additive / idempotent. Already applied to Supabase.

-- Ensure every configured laboratory test has at least one result parameter.
insert into public.lab_parameters
  (test_id, name, code, unit, data_type, display_order, active, created_at)
select
  t.id,
  'Result',
  coalesce(t.code, 'RESULT_' || substr(t.id::text, 1, 8)),
  '',
  'text',
  0,
  true,
  now()
from public.lab_tests t
where t.deleted_at is null
  and not exists (
    select 1
    from public.lab_parameters p
    where p.test_id = t.id
      and p.deleted_at is null
  );

create unique index if not exists uq_lab_results_order_parameter
  on public.lab_results(order_item_id, parameter_id)
  where deleted_at is null;

create index if not exists idx_lab_parameters_test_active
  on public.lab_parameters(test_id, active)
  where deleted_at is null;

create index if not exists idx_lab_orders_patient_visit
  on public.lab_orders(patient_id, visit_id)
  where deleted_at is null;

create index if not exists idx_invoices_visit_date
  on public.invoices(visit_id, invoice_date)
  where deleted_at is null;

create index if not exists idx_payments_invoice_date
  on public.payments(invoice_id, payment_date)
  where deleted_at is null;
