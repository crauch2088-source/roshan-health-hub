# Research: Prescription Correction Workflow

**Evidence date**: 2026-11-10  
**Sources**: Read-only PostgreSQL catalog queries on Production and QA, repository source at current main, and Phase 57B candidate PR #209. No business rows were read.

## Live schema confirmed in Production and QA

### prescriptions
- `id`, `patient_id`, `visit_id`, `prescribed_by`, `doctor_id`, `status`, `is_external`, `branch_id`, `created_by`, `created_at`, `updated_by`, `updated_at`, `deleted_at`, `deleted_by`.
- `patient_id` is NOT NULL; `visit_id`, `prescribed_by`, `branch_id` are nullable.
- FK constraints: patient, visit, prescribed_by→users, branch→branches (RESTRICT).

### prescription_items
- `id`, `prescription_id`, `medicine_id`, `medication_name`, `dose`, `dosage`, `frequency`, `duration`, `quantity`, `instructions`, `created_by`, `updated_by`, `deleted_at`, `deleted_by`, `is_dispensed`, `dispensed_quantity`, `unit_price`, `dosage_form`, `route`, `created_at`, `updated_at`.
- `medicine_id`, `medication_name`, `quantity` are nullable; `unit_price` defaults to zero; `is_dispensed` defaults false; `dispensed_quantity` defaults zero.
- FK constraints: medicine→medicines; prescription→prescriptions ON DELETE CASCADE.

### Existing triggers
- `phase36_visit_link_guard` on prescriptions and prescription_items.
- `phase46_prescription_branch_attribution` on prescriptions.
- `trg_audit_prescriptions` and `trg_audit_prescription_items` via `audit_row_change()`.
- The existing audit trigger will capture replacement updates, but it does not replace the dedicated request/event trail required by this feature.

### Existing grants and helpers
- Production and QA grant authenticated SELECT only on prescriptions and prescription_items; direct browser INSERT/UPDATE/DELETE are absent.
- `current_app_user_id()`, `app_has_perm(text)`, `private.app_has_branch_access(uuid)`, and `private.app_has_prescription_branch_access(uuid)` exist with fixed empty `search_path`.
- `private.app_has_branch_access(uuid)` returns true for super-admin before checking the user's assigned branch. Therefore this feature must add a strict assigned-branch equality check for requests and prescriber resolution; relying on the helper alone would violate the wrong-branch acceptance criterion.
- `private.app_has_prescription_branch_access(uuid)` delegates to the existing prescription-parent access helper.

## Permission mapping confirmed in both environments

- `doctor`: `emr.create`, `emr.read`, `emr.update`.
- `pharmacist`: `pharmacy.create`, `pharmacy.read`, `pharmacy.update`.
- `admin`, `legacy_admin`, `super_admin`, `legacy_super_admin`: include both EMR and pharmacy permissions.

**Security consequence**: permission checks alone cannot establish clinical authorship. Resolve/reject must additionally require `prescriptions.prescribed_by = public.current_app_user_id()`; neither admin nor super-admin permission grants may bypass that equality. The assigned `users.branch_id` must also equal the prescription's server-derived branch, including for super-admin.

## Existing workflow dependency

- Phase 57 quantity guard is applied in QA only (migration `20261104065852`); Production does not have it.
- Phase 57B free-text/external-prescription dispensing guard is currently candidate code in PR #209 and is not part of current main or confirmed applied to either hosted environment.
- PR #209 exact head CI is green, but it remains Draft pending review and authenticated QA acceptance.
- Therefore this Phase 61 PR is specification-only. Implementation must either wait for Phase 57B to merge or explicitly include its reviewed code as a dependency; do not assume the candidate guard is deployed.

## Migration and release boundary

- Production ledger latest: `20261102232941`.
- QA ledger latest: `20261104065852`.
- No correction-request tables or migration exist in either environment.
- No patient, prescription, invoice, payment, stock, Auth, Storage, grant or deployment writes were performed during this research.
- Choose a new forward-only migration version after final source-to-ledger reconciliation; never rewrite Phase 57/57B history.
