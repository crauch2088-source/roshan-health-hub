# Phase 53 Research — Clinical Document Printing

**Date:** 2026-11-03  
**Base:** `main` at `a1ee3ae937f351311ab1838a135ce6e95d825db0`; QA catalog inspected read-only on `hopfohcnrtbiqjkgeukz`.  
**Status:** Source and QA catalog inspection complete; implementation remains gated by lifecycle, branding, and device decisions.

## Verified QA schema contracts

The following columns were confirmed in both QA and Production catalogs. This was catalog-only inspection; no clinical or financial row contents were read.

- `invoices`: `id, invoice_number, patient_id, visit_id, total_amount, discount_amount, paid_amount, payment_status, created_at, created_by, updated_by, deleted_at, deleted_by, status, subtotal, net_amount, discount_type, corporate_account_id, branch_id, updated_at, invoice_date, partner_id, is_primary`.
- `invoice_items`: `id, invoice_id, item_type, item_name, quantity, unit_price, total_price, created_by, updated_by, deleted_at, deleted_by, item_id, discount, created_at`.
- `payments`: `id, invoice_id, payment_method, amount, reference_no, received_at, payment_date, created_by, updated_by, deleted_at, deleted_by, created_at, reference, received_by, branch_id, notes, idempotency_key, method`.
- `cashbox_transactions`: includes `source_type`, `source_id`, `transaction_type`, `amount`, `transaction_date`, `created_by`, `is_reversed`, `reversal_of`, and `reversal_reason`.
- `prescriptions`: `id, patient_id, visit_id, prescribed_by, prescription_type, created_at, created_by, updated_by, deleted_at, deleted_by, doctor_id, status, is_external, notes, dispensed_at, dispensed_by, updated_at, branch_id`.
- `prescription_items`: includes `medication_name`, `dose`, `dosage`, `frequency`, `duration`, `quantity`, `instructions`, `dosage_form`, `route`, and soft-delete/dispense fields.
- `medical_certificates`: `id, patient_id, doctor_id, diagnosis, start_date, end_date, created_at, deleted_at, deleted_by, visit_id, certificate_number`.
- `system_settings`: `setting_key, setting_value, is_public` plus audit/soft-delete columns.

The prescription catalog exposes a generic `status` column but no explicit signature/approval timestamp or signer field was found. The exact status values and their lifecycle semantics still need inspection before describing a prescription as signed or approved.

## Verified row-level security

QA `pg_policies` inspection confirmed:

| Source | SELECT permission | Branch/parent boundary |
|---|---|---|
| `invoices` | `billing.read` or `billing.view` | `private.app_has_branch_access(invoices.branch_id)` |
| `invoice_items` | `billing.read` or `billing.view` | parent invoice branch |
| `payments` | `payments.read` | `private.app_has_branch_access(payments.branch_id)` |
| `cashbox_transactions` | `accounting.read` or `cashbox.read` | `private.app_has_branch_access(cashbox_transactions.branch_id)` |
| `prescriptions` | `pharmacy.read` or `emr.read` | `private.app_has_prescription_parent_access(patient_id, visit_id)` |
| `prescription_items` | `pharmacy.read` or `emr.read` | `private.app_has_prescription_branch_access(prescription_id)` |
| `medical_certificates` | `certificates.read` | `private.app_has_patient_branch(patient_id)` |
| `system_settings` | `is_public = true` or `settings.read` | authenticated role; update separately requires `settings.update` |

These are database policies, not merely frontend gates. Do not broaden them to make printing work. Any composite query must continue to be filtered by these policies.

## Verified frontend behavior and defects

### Print isolation
- `src/components/kit.tsx` exports `PrintButton`, which invokes global `window.print()`.
- `src/styles.css` hides `.no-print` and styles `.print-area`, but it does not isolate a single target element from all other visible page content.
- Invoice detail uses `PrintButton` and marks its invoice card `.print-area`; payment history and payment-entry UI remain adjacent content and are not proven excluded by the existing rules.
- Certificates invoke `window.print()` directly from each list row without selecting one certificate as the only print target. This is a concrete wrong-scope printing defect.
- No dedicated posted-payment receipt print surface was found.
- No print action was found in the inspected prescription composer.

### Settings mismatch and QA configuration state
- `src/routes/_authenticated/settings.tsx` manages `center_name`, `center_name_ar`, `phone`, `address`, `currency`, `tax_percent`, and `invoice_footer`.
- `useSettings()` in `src/lib/db.ts` simply maps every saved `setting_key` to a string. It does not alias keys.
- The invoice detail route reads `clinic_name`, `clinic_address`, and `clinic_phone`. Those keys are not among the settings page's managed keys. This mismatch is confirmed.
- The QA `system_settings` table currently has no active rows. No setting values were read. Therefore there is no configured QA branding to validate.
- A logo asset exists in the public application, but its authoritative configurable mapping was not established.

## Existing atomic write paths

- Prescription creation uses `create_prescription_atomic(p_visit_id, p_is_external, p_items)`. The composer validates medication name, dose, frequency, duration, and positive integer quantity; route and dosage form are stored too. Pediatric dose safety remains clinician-entered, not inferred.
- Pharmacy reads saved `prescriptions` and nested `prescription_items`, but the queue query is not automatically the correct printable read model.
- Invoice detail reads saved `invoices`, `invoice_items`, and `payments`. Payment posting uses `post_invoice_payment`; unsaved form state is not a receipt source.
- Payment rows have both `created_by` and `received_by`, plus `received_at` and `payment_date`. The business meaning of cashier attribution and timestamp precedence must be confirmed before choosing one.
- Invoice reversal is source-aware through `reverse_invoice_payment`; print must reflect current persisted reversal state. Cashbox rows expose reversal linkage, but exact invoice-payment-to-ledger join semantics must be verified before receipt totals are derived.

## Safe v1 decisions

1. **No new database migration/table** for presentation-only printing.
2. **No patient-facing public verification URL and no patient identifier in QR content.** QR/serial verification is excluded from v1 until a separately reviewed opaque-token contract and owner-approved destination exist.
3. **Browser-native print first.** No PDF-generation dependency or server renderer is justified by the inspected repository. Browser print / Save as PDF is the baseline.
4. **One-document print isolation is mandatory.** A print action must target one persisted record and exclude navigation, forms, unrelated list rows, and other page chrome.
5. **Reuse the exact existing RLS permission gates** listed above. Reprint permissions must not be invented as a separate permission until the current product policy is established.
6. **Normalize clinic identity to the existing settings page contract** (`center_name`, `center_name_ar`, `phone`, `address`, `invoice_footer`) after verifying logo requirements. Do not introduce parallel `clinic_*` keys.
7. **Receipt values are persisted-record-derived.** Only print a persisted payment linked to its invoice; never use the unsaved payment form.
8. **Prescription printing preserves saved values exactly.** Missing required fields block official printing or show an unmistakable incomplete state; never infer dose, route, frequency, duration, or quantity.
9. **A4 is the initial baseline.** 58 mm and 80 mm output remain unclaimed until tested with the actual browser/printer combination at the center.

## Remaining verification items

- Inspect exact prescription `status` values, transitions, and whether `pending` is a valid clinician-authorized order or only a draft.
- Confirm cashier attribution and timestamp semantics for receipts (`received_by` vs `created_by`; `received_at` vs `payment_date`).
- Verify exact cashbox ledger source linkage for invoice payments and reversals.
- Confirm logo asset source and whether clinic name/address/phone should be branch-specific (the current settings page is global).
- Confirm target browser/printer model and whether thermal output is required at opening.
- Run authorized-role and cross-branch E2E with synthetic QA fixtures; catalog policy inspection alone does not prove the full user journey.

## Why implementation is still gated

The source inspection established enough to write a concrete plan and identify current print defects. It did not establish prescription finalization semantics, receipt ledger joins, or the physical printer matrix. Coding around those unknowns could mislabel an unsigned prescription, print an incorrect receipt, or leak another row. These are explicit G0/G2 tasks, not reasons to invent new schema or permissions.
