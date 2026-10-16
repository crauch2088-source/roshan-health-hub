create unique index if not exists uq_lab_results_order_parameter on public.lab_results(order_item_id, parameter_id) where deleted_at is null;
create index if not exists idx_lab_parameters_test_active on public.lab_parameters(test_id, active) where deleted_at is null;
create index if not exists idx_lab_orders_patient_visit on public.lab_orders(patient_id, visit_id) where deleted_at is null;
create index if not exists idx_invoices_visit_date on public.invoices(visit_id, invoice_date) where deleted_at is null;
create index if not exists idx_payments_invoice_date on public.payments(invoice_id, payment_date) where deleted_at is null;
