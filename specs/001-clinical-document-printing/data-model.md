# Data Model — Clinical Document Printing

**Scope:** Presentation contracts over existing persisted records. This document does not propose schema changes.

## Read-only view models

### PrintDocumentIdentity
- `documentType`: receipt | invoice | prescription | medical_certificate
- `documentId`: opaque internal identifier, never embedded in a public URL/QR
- `documentNumber`: existing saved number if present; otherwise visibly omit
- `branchId`: source record's authoritative branch
- `createdAt`: persisted timestamp
- `language`: Arabic or English presentation choice

### ClinicIdentity
- `nameAr`, `nameEn`, `address`, `phone`, `footer`, `logoAsset`
- Map to the existing settings page keys: `center_name_ar`, `center_name`, `address`, `phone`, `invoice_footer`; verify logo mapping before using it.
- QA `system_settings` currently has no active rows; do not fabricate default address/contact values.
- No parallel `clinic_*` settings vocabulary may be introduced without a migration/design decision.

### ReceiptPrintModel
- Source: one persisted payment plus its linked invoice and authoritative ledger/reversal state.
- Fields: payment ID/number if present, invoice number, patient display name/MRN only when authorized, amount, currency, method, `received_at`, cashier from `received_by`, invoice balance, status/reversal reference.
- Amount and status must not come from an unsaved form or optimistic client state.
- Ledger integrity and reversal state must be checked through `get_invoice_payment_receipt_status(uuid[])`; this RPC currently exists in QA only. Production receipt UI must remain gated until Phase54C is deployed there.
- The RPC requires both `payments.read` and `billing.read` and checks branch/ledger linkage.

### InvoicePrintModel
- Source: one persisted invoice and its saved invoice items and payment aggregates.
- Fields: invoice number/date, patient display data, line descriptions, quantities, unit/line totals, subtotal/discount/net/paid/balance, status.
- Financial totals must match the authoritative saved invoice/payment model. The UI must not recompute posted ledger state from a client form.

### PrescriptionPrintModel
- Source: one persisted prescription and its saved prescription items.
- Fields: patient/visit context, persisted author (`prescribed_by` / `doctor_id`), creation date, workflow status, medication name, dose, route, frequency, duration, quantity, dosage form, instructions.
- The current schema has no explicit signature, signer, or approval timestamp. The output is a saved prescription/order copy, not a digitally signed document.
- Preserve original values exactly. A missing required field is represented as missing and blocks official print; no clinical inference or defaulting.

### MedicalCertificatePrintModel
- Source: one persisted medical certificate and authorized patient/visit/doctor relations.
- Fields: certificate number if persisted, issue date, start/end dates, type/purpose, saved diagnosis/notes, prescriber, branch.
- Do not derive or expand diagnosis text beyond the persisted record.

## Integrity invariants

1. Print view models are immutable and read-only.
2. One action prints exactly one document record.
3. Branch identity is derived from the authoritative source and cross-checked across linked rows.
4. Soft-deleted records are not printable as current official documents; reprint policy for historical/reversed items is explicit.
5. Financial values are copied from persisted authoritative rows/ledger.
6. Clinical instructions are copied verbatim from saved authorized records.
7. A prescription printout must not claim a digital signature or approval state absent from the schema.
8. No patient data is exposed through a public verification endpoint, QR code, or analytics event.
9. Print rendering never writes to Supabase.
