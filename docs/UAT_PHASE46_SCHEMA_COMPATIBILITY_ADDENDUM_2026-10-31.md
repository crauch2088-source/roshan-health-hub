# Phase 46 UAT schema review addendum — 2026-10-31

## Additional defect found during full live query-to-catalog comparison

The clinic consultation SELECT in `src/features/clinic/consultation/ConsultationPage.tsx` requests both `patients.allergies` and `patients.chronic_conditions`. Read-only inspection of production `public.patients` confirmed that **both columns are absent**. The initial Phase 46 candidate covered only `allergies`; that would have exposed a second missing-column failure immediately after the first was repaired.

Phase 46 has therefore been expanded to add:
- `patients.allergies text`
- `patients.chronic_conditions text`
- `prescriptions.branch_id uuid`

The existing disposable PostgreSQL 17 assertions now verify the type of `patients.chronic_conditions`, and the Phase 41 source guard requires all three schema additions to remain represented in the candidate migration.

The production catalog also confirms that the relevant clinic visit columns (`id`, `branch_id`, `visit_number`, `status`, `visit_date`, `patient_id`, `doctor_id`, `department_id`, `consultation_fee`) and the medicine fields currently selected by the inventory and prescription search screens (`id`, `name`, `generic_name`, `brand_name`, `strength`, `dosage_form`, `selling_price`, `stock_quantity`, `unit`, `reorder_level`, `cost_price`, `barcode`, `active`, `deleted_at`) exist. The pharmacy route still cannot succeed until `prescriptions.branch_id` is added.

This is a source/candidate correction only. It has not been applied to QA or production.
