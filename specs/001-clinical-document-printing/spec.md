# Feature Specification: Clinical Document Printing

**Feature Branch**: 001-clinical-document-printing

**Created**: 2026-11-03

**Status**: Draft

**Input**: Phase 53 in `docs/MASTER_PLAN.md` — clinical document printing (receipt, invoice, prescription, certificates).

## User Scenarios & Testing

### User Story 1 — Print a payment receipt (Priority: P1)

A receptionist or authorized finance user opens a saved payment and produces a receipt that accurately represents the immutable payment ledger.

**Why this priority**: A receipt is a financial record. It must never be generated from an unposted client-side amount or imply a payment that was not committed.

**Independent Test**: Using synthetic invoice/payment fixtures, print a receipt for a posted payment and compare every financial field with the authoritative ledger.

**Acceptance Scenarios**:
1. **Given** a saved posted payment, **When** an authorized user prints its receipt, **Then** the receipt shows amount paid, method, received timestamp, cashier, invoice balance, and reversal state from saved records and the ledger-integrity RPC.
2. **Given** an unposted amount or failed payment request, **When** a user attempts to print a receipt, **Then** no receipt representing that amount is produced.
3. **Given** a reversed or voided payment, **When** a user reprints its receipt, **Then** the document clearly reflects the persisted reversal/void state.

### User Story 2 — Print a saved prescription order (Priority: P1)

An authorized user produces a readable copy of a persisted prescription order without changing its clinical meaning or claiming a digital signature that the current system does not provide.

**Why this priority**: Missing or altered medication instructions can create direct patient-safety risk. A saved prescription order must remain faithful to the clinician-entered record.

**Independent Test**: Use synthetic complete and incomplete prescriptions; verify exact field fidelity and safe handling of incomplete instructions.

**Acceptance Scenarios**:
1. **Given** a persisted prescription order created through the authorized application workflow, **When** a user with existing `emr.read` or `pharmacy.read` access prints it, **Then** the output includes saved medication name, dose, route, frequency, duration, quantity, author, and creation date, without adding a digital signature claim.
2. **Given** a prescription missing a required instruction, **When** a user attempts to print it, **Then** the system does not invent or infer the missing value and clearly marks the order incomplete or blocks official printing.
3. **Given** a prescription outside the current user's branch or read permission, **When** the user attempts to preview or print it, **Then** database authorization denies access without leaking details.

### User Story 3 — Print invoices and medical certificates (Priority: P2)

An authorized user prints a saved invoice or saved medical certificate using its authoritative stored content.

**Independent Test**: Use synthetic saved invoices and certificates; verify printed content matches persisted source and unauthorized users cannot retrieve it.

**Acceptance Scenarios**:
1. **Given** a saved invoice, **When** an authorized user prints it, **Then** displayed totals and payment state agree with authoritative invoice/payment records.
2. **Given** a saved medical certificate, **When** an authorized user prints it, **Then** printed text and dates match the saved authorized certificate.
3. **Given** an unsaved or unauthorized document, **When** a user attempts to print it, **Then** the system refuses to present it as official.

### User Story 4 — Produce readable bilingual and device-appropriate layouts (Priority: P1)

A user previews and prints supported documents in Arabic or English on supported page and thermal-paper formats.

**Independent Test**: Render synthetic documents in Arabic RTL and English LTR at A4, 58 mm, and 80 mm widths; inspect direction, clipping, totals, and page breaks.

**Acceptance Scenarios**:
1. Arabic content remains readable in RTL, including mixed-language values and numerals.
2. English content remains readable in LTR.
3. A4, 58 mm, and 80 mm layouts do not clip required content or split critical totals/medication instructions. Thermal support is not claimed until tested on the actual printer/browser combination.

## Edge Cases

- Partial payments, zero/outstanding balance, reversed/voided payments, and reprints.
- Missing, incomplete, or unauthorized prescription/certificate data.
- Long Arabic text, mixed Arabic/English drug names, numerals, and punctuation.
- Multi-page A4 output, thermal widths, and printer/browser cancellation.
- Session expiry or authorization changes between preview and print.
- QR/serial verification data absent, invalid, or unavailable.

## Requirements

### Functional Requirements

- **FR-001**: Support shared print templates for receipts, invoices, prescriptions, and medical certificates.
- **FR-002**: Render from authoritative saved records; never create official receipts from unposted client-side amounts.
- **FR-003**: Receipts reconcile to the immutable payment ledger and display amount paid, method, received timestamp, cashier, invoice balance, and reversal state.
- **FR-004**: Prescription copies render only saved application-authorized order data and include medication name, dose, route, frequency, duration, quantity, author, and creation date; they must not claim a digital signature absent from the current schema.
- **FR-005**: Never infer missing medication instructions or silently fabricate clinical/financial values.
- **FR-006**: Support Arabic RTL and English LTR.
- **FR-007**: Support A4 browser printing/Save as PDF and 58 mm/80 mm thermal layouts only after physical validation.
- **FR-008**: Clinic identity/footer content comes from the existing canonical settings source; QA currently has no active settings rows, and the existing key mismatch must be reconciled.
- **FR-009**: QR/serial verification is excluded from v1; do not embed patient data or expose public patient/document URLs.
- **FR-010**: Preview/print layout supports controlled page breaks and accessible interaction.
- **FR-011**: Preview/print access enforces existing document-specific role and branch authorization; no broad grants or new permissions are introduced.
- **FR-012**: No new database table unless print-job audit/versioning is separately justified and approved.
- **FR-013**: Void/reversal and reprint states are represented unambiguously using persisted status.
- **FR-014**: Synthetic-data tests cover RTL/LTR, print isolation, thermal widths after hardware validation, receipt/payment linkage, void/reprint labels, prescription completeness, and role authorization.

### Needs Clarification Before Release

- **[NEEDS CLARIFICATION]** Which printer models and browsers are available at the center, and is 58/80 mm printing required for opening?
- **[NEEDS CLARIFICATION]** Does the center require a configurable logo, and should identity settings remain global or become branch-specific?
- **[NEEDS CLARIFICATION]** Which real clinic roles will perform receipt reprints and prescription printing? Validate against existing permission assignments; do not create new permission codes by assumption.

### Key Entities

- **Payment**: Authoritative posted payment and immutable ledger attributes.
- **Invoice**: Saved financial document and current balance/payment state.
- **Prescription order**: Persisted application-authorized medication order with saved instructions and author attribution; no digital signature claim.
- **Medical certificate**: Saved authorized clinical document with persisted content/dates.
- **Print presentation**: Rendered representation of an existing document; it must not mutate the underlying record.

## Success Criteria

- **SC-001**: All four document types render from saved authoritative source records.
- **SC-002**: Every receipt field required by FR-003 matches its source ledger record; unposted client-side amounts never produce an official receipt.
- **SC-003**: 100% of required prescription fields are rendered exactly as saved, or printing is blocked/marked incomplete; no missing instruction is inferred.
- **SC-004**: Arabic RTL and English LTR render in A4, 58 mm, and 80 mm tests without clipping required content; thermal formats are not released without physical tests.
- **SC-005**: Unauthorized preview/print attempts are denied for every tested document/role combination.
- **SC-006**: No QR or public verification route is exposed in v1.
- **SC-007**: No new database table unless a separately approved audit/versioning requirement justifies it.

## Assumptions

- Existing saved invoice, payment, prescription, and medical-certificate records remain authoritative.
- This is primarily a frontend/presentation capability and may proceed only after saved-data and authorization contracts are verified.
- The application does not currently persist a digital prescription signature/approval field; print output must not claim one.
- No live production data or new production migration is needed to write or validate the initial specification.
