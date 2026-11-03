# Phase 53 Research — Clinical Document Printing

**Date:** 2026-11-03  
**Base:** `main` at `a1ee3ae937f351311ab1838a135ce6e95d825db0`  
**Status:** Source inspection complete; implementation contracts remain gated by targeted schema and permission verification.

## Findings from tracked source

### Existing print infrastructure
- `src/components/kit.tsx` exports `PrintButton`, which invokes the browser's global `window.print()`.
- `src/styles.css` has global print rules: hide `.no-print`, remove decoration from `.print-area`, set white/black print colors, avoid breaks inside table rows/cards, and repeat table headers.
- The existing styles do **not** isolate a single document from other visible page content. They are generic print styling, not a document-specific print boundary.
- The invoice detail route uses `PrintButton` and marks its main invoice card `.print-area`, but the page also contains a payment-entry panel and payment history. The current CSS does not by itself prove that these adjacent elements are excluded from printing.
- The certificates route invokes `window.print()` directly from each row. It does not select one certificate as the only print target; the current page can therefore print more than the clicked row.
- No evidence was found in the inspected source that a posted payment has a dedicated receipt print surface.
- No print action was found in the inspected prescription composer. The pharmacy queue is a dispensing workflow, not proof of a printable prescription read model.

### Existing source-of-truth settings
- `src/routes/_authenticated/settings.tsx` reads/writes the `system_settings` keys `center_name`, `center_name_ar`, `phone`, `address`, `currency`, `tax_percent`, and `invoice_footer`.
- The invoice detail route reads `clinic_name`, `clinic_address`, and `clinic_phone` through `useSettings()`. This key mismatch is a concrete integration defect to resolve before claiming that print identity is authoritative. Do not silently create a second settings vocabulary.
- The logo asset exists in the public application, but no verified persisted print-branding contract was established in this source pass.

### Existing clinical and financial write paths
- Prescription creation is atomic through `create_prescription_atomic` in `src/features/clinic/consultation/components/PrescriptionTab.tsx`. The draft requires medication name, dose, frequency, duration, and positive integer quantity; route and dosage form are also stored in the payload. Pediatric dose safety remains clinician-entered, not inferred.
- Pharmacy reads `prescriptions` with nested `prescription_items`, but this is a dispensing queue query and is not yet established as the authorized print read model.
- Invoice detail reads saved `invoices`, `invoice_items`, and `payments`. Payment creation is performed through `post_invoice_payment`; client-entered unsaved amounts are not a valid receipt source.
- Medical certificates are created through `create_medical_certificate` and the certificates route reads persisted `medical_certificates` with patient, visit, and doctor relations. The current row print action is not scoped to one certificate.

## Decisions and safe defaults for the first implementation

1. **No new database migration or table** for presentation-only printing.
2. **No patient-facing public verification URL and no patient identifier in QR content.** QR/serial verification is excluded from the first implementation until a separately reviewed opaque-token contract and owner-approved destination exist. Do not invent a destination.
3. **Browser-native print first.** No PDF-generation dependency or server renderer is justified by the inspected repository. Browser print / Save as PDF is the baseline; exact PDF guarantees require browser validation.
4. **One-document print isolation is mandatory.** A print action must target one persisted record and exclude navigation, forms, unrelated list rows, payment-entry controls, and other page chrome.
5. **Permissions must reuse existing server-enforced document permissions and branch scoping.** Do not add broad grants or infer a role matrix from UI visibility alone. Verify the actual permission catalog/RLS policies before implementation.
6. **Canonical clinic identity must be resolved from existing settings.** The observed `center_*` versus `clinic_*` key mismatch is a blocker; normalize through the existing settings model rather than writing parallel keys.
7. **Receipt status is ledger-derived.** A receipt can only be rendered from a persisted payment linked to its invoice and current reversal state. Never construct one from the payment form state.
8. **Prescription printing must preserve exact saved values.** Missing required fields block official printing or show an unmistakable incomplete state; never infer dose, route, frequency, duration, or quantity.
9. **A4 is the baseline page.** 58 mm and 80 mm are responsive print profiles, but must not be declared supported until tested with the actual browser/printer combination at the center.

## Open verification items

- Confirm the exact columns, foreign keys, soft-delete/reversal semantics, and RLS policies for `payments`, `invoices`, `prescriptions`, `prescription_items`, and `medical_certificates` in the current QA schema.
- Confirm whether prescriptions have an explicit signed/approved state. The inspected composer persists a prescription but does not establish a separate signature workflow.
- Confirm role/permission codes for reading prescriptions and certificates, and reprint rights for receipts.
- Confirm `useSettings()` key mapping and all existing identity setting names before changing any consumer.
- Confirm actual printer models, driver paper-size options, browser, and whether 58/80 mm output is required for first opening.
- Confirm whether the center wants QR at all in v1. Current safe default is to omit it.

## Why implementation has not started

The code inspection exposed page-isolation and settings-key mismatches, while the authorization and persisted-document contracts still need verification against the live QA catalog. Implementing print templates before those contracts are known risks printing the wrong record, exposing patient data, or displaying incorrect clinic identity. This research intentionally avoids such assumptions.
