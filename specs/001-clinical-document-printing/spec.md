# Feature Specification: Clinical Document Printing

**Feature Branch**: 001-clinical-document-printing

**Created**: 2026-11-03

**Status**: Draft

**Input**: docs/MASTER_PLAN.md — Phase 53, Clinical document printing (receipt, invoice, prescription, certificates).

## User Scenarios & Testing

### User Story 1 — Print a payment receipt (Priority: P1)
A receptionist or authorized finance user opens a saved payment and produces a receipt that accurately represents the immutable payment ledger.

**Why this priority**: A receipt is a financial record. It must never be generated from an unposted client-side amount or imply a payment that was not committed.

**Independent Test**: Using synthetic invoice/payment fixtures, print a receipt for a posted payment and compare every financial field with the authoritative ledger.

**Acceptance Scenarios**:
1. **Given** a saved posted payment, **When** an authorized user prints its receipt, **Then** the receipt shows amount paid, method, timestamp, cashier, invoice balance, and reversal state from saved records.
2. **Given** an unposted amount or failed payment request, **When** a user attempts to print a receipt, **Then** no receipt representing that amount is produced.
3. **Given** a reversed or voided payment, **When** a user reprints its receipt, **Then** the document clearly reflects the reversal/void state.

### User Story 2 — Print an authorized prescription (Priority: P1)
A clinician or explicitly authorized role produces a readable copy of a saved, signed/authorized prescription without changing its clinical meaning.

**Why this priority**: Missing or altered medication instructions can create direct patient-safety risk.

**Independent Test**: Use synthetic complete and incomplete prescriptions; verify exact field fidelity and safe handling of incomplete instructions.

**Acceptance Scenarios**:
1. **Given** a saved, signed/authorized prescription, **When** an authorized user prints it, **Then** the output includes saved generic/brand name, dose, route, frequency, duration, quantity, prescriber, and date.
2. **Given** a prescription missing a required instruction, **When** a user attempts to print it, **Then** the system does not invent or infer the missing value.
3. **Given** a prescription the current user is not authorized to access, **When** the user attempts to preview or print it, **Then** access is denied without leaking details.

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
3. A4, 58 mm, and 80 mm layouts do not clip required content or split critical totals/medication instructions.

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
- **FR-003**: Receipts reconcile to the immutable payment ledger and display amount paid, method, timestamp, cashier, invoice balance, and reversal state.
- **FR-004**: Prescriptions render only saved signed/authorized data and include generic/brand name, dose, route, frequency, duration, quantity, prescriber, and date.
- **FR-005**: Never infer missing medication instructions or silently fabricate clinical/financial values.
- **FR-006**: Support Arabic RTL and English LTR.
- **FR-007**: Support A4 PDF/browser printing and 58 mm/80 mm thermal layouts.
- **FR-008**: Clinic identity/footer content comes from an approved configurable source; exact source is unresolved.
- **FR-009**: Support QR/serial verification without embedding patient data or exposing public patient/document URLs; contract unresolved.
- **FR-010**: Preview/print layout supports controlled page breaks and accessible interaction.
- **FR-011**: Preview/print access enforces existing document-specific role and branch authorization; exact role matrix must be verified.
- **FR-012**: No new database table unless print-job audit/versioning is explicitly required and justified.
- **FR-013**: Void/reversal and reprint states are represented unambiguously.
- **FR-014**: Synthetic-data tests cover RTL/LTR, thermal widths, PDF/browser snapshots, receipt/payment linkage, void/reprint labels, prescription completeness, and role authorization.

### Needs Clarification Before Planning
- **[NEEDS CLARIFICATION]** What is the authoritative QR/serial verification contract and destination? No public document URL or patient identifier may be assumed.
- **[NEEDS CLARIFICATION]** Which roles may preview, print, and reprint each document type? Derive from current permissions and owner decisions.
- **[NEEDS CLARIFICATION]** Where are clinic identity, logo, address, contact details, and footer settings stored?
- **[NEEDS CLARIFICATION]** Which existing invoice, payment, prescription, and certificate read models are supported print contracts?
- **[NEEDS CLARIFICATION]** Is PDF generation browser-native, server-generated, or an existing capability? Inspect source/dependencies before choosing.
- **[NEEDS CLARIFICATION]** Which printers/browsers and paper sizes are actually available at the center?

### Key Entities
- **Payment**: Authoritative posted payment and immutable ledger attributes.
- **Invoice**: Saved financial document and current balance/payment state.
- **Prescription**: Saved, signed/authorized medication order and exact instructions.
- **Medical certificate**: Saved authorized clinical document with persisted content/dates.
- **Print presentation**: Rendered representation of an existing document; it must not mutate the underlying record.

## Success Criteria
- **SC-001**: All four document types render from saved authoritative source records.
- **SC-002**: Every receipt field required by FR-003 matches its source ledger record; unposted client-side amounts never produce an official receipt.
- **SC-003**: 100% of required prescription fields are rendered exactly as saved, or printing is blocked/marked incomplete; no missing instruction is inferred.
- **SC-004**: Arabic RTL and English LTR render in A4, 58 mm, and 80 mm tests without clipping required content.
- **SC-005**: Unauthorized preview/print attempts are denied for every tested document/role combination.
- **SC-006**: QR/serial content contains no patient-identifying data and exposes no public document URL.
- **SC-007**: No new database table unless a separately approved audit/versioning requirement justifies it.

## Assumptions
- Existing saved invoice, payment, prescription, and medical-certificate records remain authoritative.
- This is primarily a frontend/presentation capability and may proceed only after saved-data and authorization contracts are verified.
- The clinic needs bilingual documents and A4/thermal output as specified in Phase 53.
- No live production data or new production migration is needed to write or validate the initial specification.
