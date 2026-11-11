# Research: Prescription Correction Workflow

## Confirmed Current Schema (read-only QA catalog, 2026-11-10)

- `prescriptions` contains `id`, `patient_id`, `visit_id`, `prescribed_by`, `doctor_id`, `prescription_type`, `status`, `is_external`, `branch_id`, `deleted_at`, `dispensed_at`, and `dispensed_by`.
- `prescription_items` contains `id`, `prescription_id`, `medicine_id` (nullable), `medication_name`, `dose`, `dosage`, `frequency`, `duration`, `quantity` (nullable), `instructions`, `dosage_form`, `route`, `is_dispensed`, `dispensed_quantity`, `unit_price`, and soft-delete/audit fields.
- `visits` contains `patient_id`, `doctor_id`, `branch_id`, `status`, and soft-delete/audit fields.
- `patients` and `prescriptions` branch IDs are nullable in the current catalog; the visit branch is the canonical required branch for this workflow. Any non-NULL parent branch must agree with it.
- The current `doctor` role has `emr.create`, `emr.read`, `emr.update`, `visits.read`, and `visits.update`. The current `pharmacist` role has `pharmacy.read` and `pharmacy.update`. The current `admin` role has broad application permissions but is not a clinical prescriber role. `super_admin` is handled by the established explicit bypass.
- Current `create_prescription_atomic(uuid,boolean,jsonb)` sets both `prescribed_by` and `doctor_id` to the authenticated application actor, and creates the parent and item rows atomically. It does not create stock or invoice rows.
- Phase 57's deployed QA SQL guard is an immutable 10,954-byte statement. The current PR #209 candidate has restored the exact QA-applied SQL and separates subsequent free-text/external guards into Phase 57B. Production still has the older NULL-to-one fallback; do not change Production from this feature.

## Authorization Design Decision

Use dedicated permission codes rather than reusing broad `pharmacy.update`, `emr.update` or `admin.full`:
- `pharmacy.correction.request` → current `pharmacist` role.
- `prescriptions.correction.resolve` → current `doctor` role.
- `super_admin` retains the explicit existing permission bypass.
- `admin`, legacy pharmacist/GP/specialist roles, and unrelated same-branch doctors do not receive implicit rights.

A doctor is responsible only when their application user ID matches `prescriptions.prescribed_by`, `prescriptions.doctor_id`, or the parent visit's `doctor_id`. This matches the current prescription-creation contract and avoids exposing clinical details to every doctor in the branch.

## Open Implementation Questions

- Verify the exact prescription status values and current update/soft-delete triggers before implementing cancellation. Use only a status accepted by existing application conventions and tests; do not assume `cancelled` is already in a CHECK constraint.
- Verify `audit_logs` column contract and whether append-only event rows are sufficient as the canonical correction audit record.
- Inspect current RLS/GRANT behavior on `prescriptions` and `prescription_items`; the RPC must not rely on client-side row visibility.
- The current visit assignment may be changed after prescription creation. Resolution must revalidate all responsible-doctor links under lock.
- Determine whether a corrected replacement item should update the existing item in place or append a new item and soft-delete the original. Prefer append/soft-delete if it preserves the exact clinical history without breaking existing dispense RPCs; prove this in PG17 before choosing.
- Verify how existing prescription status transitions and cancellation are represented in the app before writing the resolver.

## Source Evidence

- Read-only Supabase catalog query for QA and Production, 2026-11-10.
- `db/roshan_phase7_atomic_prescription.sql`.
- `src/features/clinic/consultation/components/PrescriptionTab.tsx`.
- `db/roshan_phase57b_free_text_external_prescription_guard.sql` in the Phase 57 candidate branch.
- Issue #217 acceptance requirements.
