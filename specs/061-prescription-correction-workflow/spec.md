# Feature Specification: Auditable Prescription Correction Workflow

**Feature Branch**: `061-prescription-correction-workflow`  
**Created**: 2026-11-10  
**Status**: Draft — implementation candidate only; no hosted migration authorized  
**Input**: Issue #217. Pharmacy must not dispense free-text/unlinked prescription items, but pharmacists need a durable route to ask the responsible prescriber to correct them.

## User Scenarios & Testing

### User Story 1 — Pharmacist requests a correction for one unlinked item (Priority: P1)

A pharmacist opens a saved, pending, internal prescription containing an active item with no catalogue medicine link. The pharmacist selects that exact item, records why it cannot be safely dispensed, and submits a correction request.

**Independent Test**: In disposable PostgreSQL 17, a pharmacist creates a request against a synthetic pending internal prescription and a specific `medicine_id IS NULL` item. Assert the request and immutable event exist while prescription status, item values, stock, stock movements, invoices, and invoice lines remain unchanged.

**Acceptance Scenarios**:
1. **Given** an active unlinked item in a pending internal prescription, **When** an authorized pharmacist requests correction, **Then** one pending request is created with the exact item snapshot, patient/visit/prescription/branch linkage, actor, server timestamp and reason.
2. **Given** a pending request already exists for the same item, **When** the pharmacist retries, **Then** the existing pending request is returned; no duplicate request or duplicate event is created.
3. **Given** an external, cancelled, dispensed, deleted, cross-branch or no-longer-unlinked item, **When** a request is attempted, **Then** the RPC rejects without changing any clinical or financial state.
4. **Given** a request is submitted, **When** the pharmacist returns to the queue, **Then** the original prescription remains pending and dispensing remains blocked.

### User Story 2 — Responsible prescriber resolves the request (Priority: P1)

The responsible prescriber, or an explicitly authorized doctor assigned to the same visit, reviews the saved item snapshot and either replaces it with an explicitly selected active catalogue medicine, rejects the request with a reason, or cancels the old prescription and issues a complete corrected order atomically.

**Independent Test**: In disposable PostgreSQL 17, test each disposition under a doctor identity and prove that only the responsible doctor can resolve. Request rejection changes only request/event state. Item replacement changes only the selected prescription item and request/event state. Cancel-and-reissue cancels the original prescription and creates a new linked order in the same transaction. None of these actions creates an invoice, payment, cashbox entry, stock movement or dispense flag.

**Acceptance Scenarios**:
1. **Given** a pending request and its responsible prescriber, **When** the doctor replaces the item with an explicitly selected active catalogue medicine and complete regimen, **Then** the saved item is updated from server-validated catalogue data and the request is resolved with actor/time/disposition evidence.
2. **Given** a pending request, **When** the responsible doctor rejects it with a reason, **Then** the request is marked rejected, its event is appended, and the original prescription/item remain unchanged and non-dispensable.
3. **Given** a prescription requiring broader correction, **When** the responsible doctor cancels and reissues it, **Then** the original becomes cancelled and a new complete internal prescription is created atomically; the old order and its item history remain intact.
4. **Given** a doctor from another branch or an unrelated doctor, **When** they read or resolve the request, **Then** access is denied or no row is disclosed.
5. **Given** two concurrent resolution attempts, **When** both target the same request, **Then** exactly one disposition commits; the other receives a deterministic already-resolved/stale response.

### User Story 3 — Pharmacy revalidates before dispensing (Priority: P1)

After a correction, the pharmacist reloads the queue and the existing authoritative dispensing RPC revalidates the complete prescription. No UI state or correction event itself authorizes dispensing.

**Independent Test**: Resolve one of two unlinked items and assert the queue remains blocked until every active item is linked and valid. After the entire prescription is corrected, the dispensing RPC independently validates quantity, catalogue status, branch, stock and billing atomicity.

## Edge Cases

- Duplicate request submissions and retries after network interruption.
- Two pharmacists requesting the same item concurrently.
- Two doctors resolving the same request concurrently.
- Item or prescription changes after the request snapshot was captured.
- Prescription becomes external, cancelled, dispensed or soft-deleted while a request is pending.
- Patient/visit/prescription branch linkage is NULL or inconsistent.
- Legacy prescription has no responsible prescriber or visit doctor.
- Catalogue medicine is soft-deleted, inactive, or has an invalid price.
- A prescription contains multiple unlinked items; resolving one must not silently omit or unblock the others.
- A replacement payload has missing dose, route, dosage form, frequency, duration or explicit positive whole quantity.
- Rejection leaves the original order pending and blocked; a new request may be submitted after rejection.
- A transaction fails during cancel-and-reissue; the original must remain pending and no replacement order may survive.

## Functional Requirements

- **FR-001**: Only an authorized pharmacist may request correction for a saved, pending, internal prescription item whose `medicine_id IS NULL`.
- **FR-002**: A request MUST bind to the exact prescription, item, patient, visit and branch; all relevant non-NULL branch IDs MUST agree, and the visit branch MUST be known.
- **FR-003**: The request MUST capture an immutable snapshot of the selected item, a non-empty reason, requesting actor and server-generated timestamp.
- **FR-004**: At most one pending correction request may exist per prescription item. Retries MUST be idempotent.
- **FR-005**: Only the responsible prescriber or an authorized doctor assigned to the same visit and branch may read/resolve the request. Super Admin follows the established explicit bypass; ordinary Admin does not receive an implicit clinical bypass.
- **FR-006**: A doctor may replace the item only with an explicitly selected, active, non-deleted catalogue medicine. No fuzzy matching, name-based auto-linking or inferred regimen is permitted.
- **FR-007**: A doctor may reject a request with a recorded reason. Rejection MUST NOT alter the prescription or item.
- **FR-008**: A doctor may cancel and reissue only through one atomic transaction that cancels the original prescription and creates a complete corrected internal order through the existing authorized prescription RPC contract.
- **FR-009**: Request creation, duplicate retry, and rejection MUST NOT change prescription status, prescription items, inventory, stock movements, invoices, invoice lines, payments or cashbox rows.
- **FR-010**: Correction resolution MUST NOT dispense, create an invoice, create a payment, or move stock. Dispensing remains a separate pharmacist action through the existing atomic RPC.
- **FR-011**: Every request and disposition MUST have append-only event evidence with actor, server timestamp, event type, and relevant before/after snapshots or references.
- **FR-012**: Request/event tables MUST use RLS for branch and responsible-doctor visibility. Browser roles receive SELECT only; writes occur through least-privilege SECURITY DEFINER RPCs with empty search_path and explicit checks.
- **FR-013**: Resolution MUST lock rows in a consistent order (prescription → item → request), revalidate the snapshot and pending status under lock, and reject stale/concurrent attempts.
- **FR-014**: External prescriptions remain ineligible for internal stock dispensing and billing, regardless of correction request state.
- **FR-015**: Arabic RTL and English LTR UI must explain the blocker and provide a clear request/review path without weakening the fail-closed queue behavior.

## Permission Model

- `pharmacy.correction.request`: granted to the current `pharmacist` role only.
- `prescriptions.correction.resolve`: granted to the current `doctor` role only.
- Super Admin retains only the existing explicit `app_has_perm()` bypass.
- Admin, legacy roles and unrelated doctors do not gain implicit access. Any future role expansion requires a separate reviewed permission-map change.

## Release Boundary

Candidate SQL/code and disposable PostgreSQL 17 tests only. Do not apply migrations to hosted QA or Production, create synthetic hosted clinical records, or promote a deployment until source/effective-catalog reconciliation, backup/restore, independent review and approved authenticated pharmacist/prescriber acceptance are complete.
