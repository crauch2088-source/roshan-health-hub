-- Roshan production hardening: additive only.
-- No tables, columns, or existing data are removed or renamed.

create index if not exists idx_patients_branch_id on public.patients (branch_id);
create index if not exists idx_users_branch_id on public.users (branch_id);
create index if not exists idx_users_role_id on public.users (role_id);
create index if not exists idx_users_department_id on public.users (department_id);
create index if not exists idx_appointments_patient_id on public.appointments (patient_id);
create index if not exists idx_appointments_doctor_id on public.appointments (doctor_id);
create index if not exists idx_appointments_department_id on public.appointments (department_id);
create index if not exists idx_appointments_branch_id on public.appointments (branch_id);
create index if not exists idx_appointments_visit_id on public.appointments (visit_id);
create index if not exists idx_visits_patient_id on public.visits (patient_id);
create index if not exists idx_visits_doctor_id on public.visits (doctor_id);
create index if not exists idx_visits_branch_id on public.visits (branch_id);
create index if not exists idx_visits_department_id on public.visits (department_id);
create index if not exists idx_visits_appointment_id on public.visits (appointment_id);
create index if not exists idx_vitals_patient_id on public.vitals (patient_id);
create index if not exists idx_diagnoses_visit_id on public.diagnoses (visit_id);
create index if not exists idx_diagnoses_doctor_id on public.diagnoses (doctor_id);
create index if not exists idx_clinical_notes_visit_id on public.clinical_notes (visit_id);
create index if not exists idx_lab_parameters_test_id on public.lab_parameters (test_id);
create index if not exists idx_lab_reference_ranges_parameter_id on public.lab_reference_ranges (parameter_id);
create index if not exists idx_lab_orders_patient_id on public.lab_orders (patient_id);
create index if not exists idx_lab_orders_visit_id on public.lab_orders (visit_id);
create index if not exists idx_lab_orders_ordered_by on public.lab_orders (ordered_by);
create index if not exists idx_lab_orders_branch_id on public.lab_orders (branch_id);
create index if not exists idx_lab_order_items_order_id on public.lab_order_items (order_id);
create index if not exists idx_lab_order_items_test_id on public.lab_order_items (test_id);
create index if not exists idx_lab_results_order_item_id on public.lab_results (order_item_id);
create index if not exists idx_lab_results_parameter_id on public.lab_results (parameter_id);
create index if not exists idx_lab_results_entered_by on public.lab_results (entered_by);
create index if not exists idx_lab_results_verified_by on public.lab_results (verified_by);
create index if not exists idx_pharmacy_inventory_medicine_id on public.pharmacy_inventory (medicine_id);
create index if not exists idx_pharmacy_inventory_branch_id on public.pharmacy_inventory (branch_id);
create index if not exists idx_pharmacy_inventory_supplier_id on public.pharmacy_inventory (supplier_id);
create index if not exists idx_prescriptions_patient_id on public.prescriptions (patient_id);
create index if not exists idx_prescriptions_visit_id on public.prescriptions (visit_id);
create index if not exists idx_prescriptions_prescribed_by on public.prescriptions (prescribed_by);
create index if not exists idx_prescription_items_prescription_id on public.prescription_items (prescription_id);
create index if not exists idx_prescription_items_medicine_id on public.prescription_items (medicine_id);
create index if not exists idx_procedures_catalog_department_id on public.procedures_catalog (department_id);
create index if not exists idx_procedure_orders_patient_id on public.procedure_orders (patient_id);
create index if not exists idx_procedure_orders_visit_id on public.procedure_orders (visit_id);
create index if not exists idx_procedure_orders_procedure_id on public.procedure_orders (procedure_id);
create index if not exists idx_procedure_orders_ordered_by on public.procedure_orders (ordered_by);
create index if not exists idx_procedure_results_procedure_order_id on public.procedure_results (procedure_order_id);
create index if not exists idx_invoices_patient_id on public.invoices (patient_id);
create index if not exists idx_invoices_visit_id on public.invoices (visit_id);
create index if not exists idx_invoices_branch_id on public.invoices (branch_id);
create index if not exists idx_invoices_corporate_account_id on public.invoices (corporate_account_id);
create index if not exists idx_invoice_items_invoice_id on public.invoice_items (invoice_id);
create index if not exists idx_payments_invoice_id on public.payments (invoice_id);
create index if not exists idx_payments_received_by on public.payments (received_by);
create index if not exists idx_payments_branch_id on public.payments (branch_id);
create index if not exists idx_patient_discounts_patient_id on public.patient_discounts (patient_id);
create index if not exists idx_patient_discounts_partner_id on public.patient_discounts (partner_id);
create index if not exists idx_attachments_patient_id on public.attachments (patient_id);
create index if not exists idx_attachments_visit_id on public.attachments (visit_id);
create index if not exists idx_followups_patient_id on public.followups (patient_id);
create index if not exists idx_followups_visit_id on public.followups (visit_id);
create index if not exists idx_certificates_patient_id on public.certificates (patient_id);
create index if not exists idx_certificates_visit_id on public.certificates (visit_id);
create index if not exists idx_certificates_issued_by on public.certificates (issued_by);
create index if not exists idx_queue_tickets_visit_id on public.queue_tickets (visit_id);
create index if not exists idx_queue_tickets_patient_id on public.queue_tickets (patient_id);
create index if not exists idx_queue_tickets_department_id on public.queue_tickets (department_id);
create index if not exists idx_audit_logs_user_id on public.audit_logs (user_id);
create index if not exists idx_expenses_created_by on public.expenses (created_by);
create index if not exists idx_expenses_branch_id on public.expenses (branch_id);
create index if not exists idx_invoices_payment_status on public.invoices (payment_status);
create index if not exists idx_visits_queue_date_number on public.visits (queue_date, queue_number);
create index if not exists idx_visits_active on public.visits (visit_date) where deleted_at is null;
create index if not exists idx_patients_active on public.patients (branch_id, full_name) where deleted_at is null;
create index if not exists idx_lab_orders_active on public.lab_orders (patient_id, created_at desc) where deleted_at is null;
create index if not exists idx_prescriptions_active on public.prescriptions (patient_id, created_at desc) where deleted_at is null;

-- Compatibility view for older application code that used follow_ups.
-- The canonical table remains public.followups.
drop view if exists public.follow_ups;
create view public.follow_ups
with (security_invoker = true)
as
select
  f.id,
  f.patient_id,
  f.visit_id,
  f.followup_date,
  f.followup_date as follow_up_date,
  p.mrn as patient_number,
  f.notes,
  f.status,
  f.reason,
  f.completed_at,
  f.created_at,
  f.created_by,
  f.updated_by,
  f.deleted_at,
  f.deleted_by
from public.followups f
left join public.patients p on p.id = f.patient_id
where f.deleted_at is null;

revoke all on public.follow_ups from anon;
revoke all on public.follow_ups from authenticated;
grant select on public.follow_ups to authenticated;
