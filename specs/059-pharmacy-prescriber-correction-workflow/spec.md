# Feature Specification: Pharmacy-to-Prescriber Correction Workflow

**Feature Branch**: `059-pharmacy-prescriber-correction-workflow`

**Created**: 2026-11-10

**Status**: Draft — awaiting the Spec Kit review-spec gate; no implementation plan or tasks are authorized yet.

**Input**: GitHub Issue #217, plus read-only review of the current prescription schema, RPC authorization, table grants, RLS policies, and pharmacy/clinic routes.

## Context and Verified Baseline

- The pharmacy role currently has `pharmacy.create`, `pharmacy.read`, and `pharmacy.update`. The doctor role has `emr.create`, `emr.read`, and `emr.update`; administrator roles also have broad EMR permissions.
- `create_prescription_atomic(uuid,boolean,jsonb)` is a SECURITY DEFINER RPC with a fixed empty search path and EXECUTE granted to `authenticated`. Its current authorization accepts `pharmacy.create` OR `emr.create`, without restricting `pharmacy.create` to external prescriptions. A pharmacist can therefore call this RPC even though the clinic visit route is hidden from the pharmacist by its `visits.read` route gate. Server-side authorization must be corrected; route visibility is not a security boundary.
- Authenticated users currently have no direct INSERT, UPDATE, or DELETE table privileges on `prescriptions` or `prescription_items`. Preserve this RPC-only write boundary. Existing permissive-looking RLS predicates do not override the absence of table grants.
- `prescriptions` contains `patient_id`, nullable `visit_id`, nullable `prescribed_by`, nullable `doctor_id`, nullable `branch_id`, `status`, `is_external`, and soft-delete fields. `prescription_items` contains nullable `medicine_id`, `quantity`, clinical direction fields, and soft-delete fields. A correction request must fail closed when its parent/visit/patient/branch/prescriber context is absent or inconsistent.
- The pharmacy queue currently blocks unlinked items and invalid quantities, but it does not provide an auditable pharmacist-to-prescriber correction loop. Phase 57B is a separate candidate for database-level free-text/external-prescription guards and is not yet applied to QA or Production.
- The existing atomic dispensing RPC remains the only stock/invoice write boundary. This feature must not introduce browser-side stock, invoice, cashbox, or ledger writes.

## User Scenarios & Testing

### User Story 1 — Pharmacist requests correction for a blocked item (Priority: P1)

A pharmacist reviewing a saved, pending, internal prescription encounters a specific unlinked or ambiguous item. The pharmacist sends that item to its responsible prescriber for correction without changing the prescription or attempting to dispense it.

**Why this priority**: The current fail-closed behavior prevents unsafe dispensing but leaves the pharmacy workflow stranded. A traceable correction request closes that operational gap without transferring prescribing authority to the pharmacist.

**Independent Test**: In disposable PostgreSQL 17 with synthetic patient, visit, prescription, item, and users, a pharmacist in the correct branch submits a correction request. Verify that exactly one request and its creation event are persisted, all parent identifiers and the assigned prescriber are correct, and the prescription, item, invoice, stock, movements, and cashbox remain unchanged.

**Acceptance Scenarios**:

1. **Given** a saved, pending, internal prescription with a specific unlinked item and complete, consistent patient/visit/branch/prescriber context, **When** an authorized pharmacist requests correction with a reason, **Then** one pending request is created and linked to the exact prescription, item, visit, patient, branch, requester, and responsible prescriber.
2. **Given** an open correction request already exists for that item, **When** another pharmacist submits the same request or retries after a network timeout, **Then** the existing request is returned or a stable duplicate-open-request result is returned; no duplicate request or event is created.
3. **Given** an external, cancelled, dispensed, deleted, cross-branch, context-incomplete, or prescriber-unassigned prescription, **When** a pharmacist requests correction, **Then** the request is rejected without changing any clinical, stock, or financial record.
4. **Given** a pharmacist attempts to create an internal prescription through `create_prescription_atomic`, **When** the RPC is called directly despite the hidden clinic route, **Then** the request is denied by the authoritative permission check.

---

### User Story 2 — Responsible prescriber corrects, declines, or cancels and reissues (Priority: P1)

The responsible prescriber sees the pending request in the correct clinical context and explicitly chooses how to handle it. The prescriber may correct the item using a valid catalogue identity and explicit clinical directions, decline the request with a reason, or cancel the old prescription and issue a replacement.

**Why this priority**: Only an authorized clinician may make a prescribing decision. The pharmacist's request must never become an implicit medicine selection, dose, route, frequency, or duration decision.

**Independent Test**: In disposable PostgreSQL 17, create a request as a pharmacist and attempt resolution as the assigned prescriber, a different same-branch doctor, a wrong-branch doctor, a pharmacist, an administrator, and a super-administrator. Verify the exact allowed/denied outcomes and immutable event history.

**Acceptance Scenarios**:

1. **Given** a pending request assigned to the current active prescriber, with the required clinical permission and branch access, **When** the prescriber explicitly selects a valid catalogue item and supplies all fields required by the existing prescription contract, **Then** the item correction and request resolution are committed atomically and an immutable resolution event records the before/after evidence.
2. **Given** a pending request, **When** the assigned prescriber declines it with a reason, **Then** the request is marked declined and audited, but the prescription remains blocked from dispensing until the underlying clinical blocker is actually corrected or the prescription is cancelled and reissued.
3. **Given** a pending request, **When** the assigned prescriber chooses cancel-and-reissue, **Then** the old prescription is cancelled and a replacement internal prescription is created and linked in one transaction, with the same patient, visit, and branch; no stock or invoice mutation occurs.
4. **Given** a doctor who is not the assigned prescriber, a pharmacist, an administrator, a super-administrator, or a user from another branch, **When** they attempt to resolve the request, **Then** the authoritative RPC denies the action even if a broad route or general EMR permission would otherwise expose the record.
5. **Given** two concurrent resolution attempts, **When** both target the same pending request, **Then** at most one succeeds; the other receives a stable already-resolved/concurrent-change result and causes no second correction, cancellation, replacement, or audit transition.

---

### User Story 3 — Pharmacy resumes dispensing only after all blockers are cleared (Priority: P1)

The pharmacist can see the request status and the prescriber's disposition. Dispensing remains unavailable while any correction request is pending or any prescription item remains invalid. Once every blocker is resolved, the pharmacist can use the existing atomic dispense flow.

**Why this priority**: A correction request is not a workaround for the existing stock and invoice safeguards. The final dispensing boundary must independently revalidate the prescription.

**Independent Test**: In disposable PostgreSQL 17, attempt dispensing with a pending request, a declined request, an unresolved unlinked item, an external prescription, and a fully corrected prescription. Verify that only the fully valid internal prescription reaches the existing atomic dispense path.

**Acceptance Scenarios**:

1. **Given** any pending correction request for a prescription, **When** the pharmacy attempts dispensing, **Then** the database dispensing RPC rejects the entire prescription before invoice, stock, batch, movement, or status mutation.
2. **Given** a declined request whose underlying item is still unlinked or invalid, **When** dispensing is attempted, **Then** dispensing remains blocked; declining a request does not clear the clinical blocker.
3. **Given** every request is resolved and every item passes the existing quantity, catalogue, branch, and eligibility checks, **When** the pharmacist dispenses, **Then** the existing atomic dispense RPC performs the complete stock/invoice operation once.
4. **Given** an external prescription, **When** any internal stock dispense or internal billing path is attempted, **Then** it remains ineligible regardless of correction-request state.

## Edge Cases

- `prescribed_by`, `doctor_id`, `visit_id`, or branch context is NULL, inactive, soft-deleted, or inconsistent.
- The prescription's patient differs from the visit patient, or the prescription/item belongs to a different parent.
- The responsible prescriber no longer has access to the branch or is inactive.
- The item is already linked to an inactive/deleted catalogue entry, has been corrected by another clinician, or has been soft-deleted after the request was opened.
- Multiple unlinked items exist in one prescription; each item must have independently traceable correction state.
- A request is submitted twice, two pharmacists submit simultaneously, or a client retries after a timeout.
- A correction races with dispensing, cancellation, or another correction.
- A prescriber declines a request while the item remains invalid.
- A replacement prescription belongs to a different patient, visit, branch, or is marked external.
- A correction request is created for an external prescription, or a client attempts to convert an external prescription into an internal one.
- A pending request exists even though the item was independently edited; the resolve RPC must re-check the item snapshot/version and reject stale resolution.
- A correction is attempted with a missing/invalid catalogue identity, non-positive/non-finite quantity, or incomplete required directions.
- A direct REST/table write or an RPC call bypasses the visible UI.
- An administrator or super-administrator has broad `emr.update` but is not an authorized clinical prescriber.

## Requirements

### Functional Requirements

- **FR-001**: System MUST allow a pharmacist with the dedicated correction-request permission and branch access to request correction only for a saved, pending, internal prescription and a specific eligible item.
- **FR-002**: System MUST derive requester identity, branch, patient, visit, and responsible prescriber from trusted saved records; clients MUST NOT supply or override these authorization fields.
- **FR-003**: System MUST reject request creation when prescription, item, patient, visit, branch, or prescriber linkage is missing, deleted, inactive, or inconsistent.
- **FR-004**: System MUST store an immutable snapshot of the affected prescription item and the request reason at creation.
- **FR-005**: System MUST enforce at most one open request per prescription item and MUST handle retries/concurrent duplicate creation without duplicate requests or duplicate events.
- **FR-006**: System MUST keep request state separate from prescription state. Creating or declining a request MUST NOT silently edit, delete, omit, or change the clinical status of a prescription or item.
- **FR-007**: Only the responsible prescriber, or a separately authorized clinician under an explicitly approved delegation rule, MAY resolve a request. General `emr.update`, administrator status, super-administrator status, or branch access alone MUST NOT be sufficient.
- **FR-008**: The initial implementation MUST fail closed if `prescribed_by` is NULL or inconsistent. It MUST NOT silently fall back to the visit doctor, a branch administrator, or an arbitrary same-branch doctor.
- **FR-009**: A correction MUST require an explicit clinician-selected catalogue identity and explicit values for all fields required by the existing prescription contract. System MUST NOT fuzzy-match free text, infer a medicine, or auto-fill clinical directions.
- **FR-010**: A cancel-and-reissue resolution MUST atomically cancel the old prescription, create a replacement prescription in the same patient/visit/branch context, link the replacement, and append the audit event.
- **FR-011**: A declined request MUST remain visible and MUST NOT make an invalid prescription dispensable.
- **FR-012**: The authoritative dispensing RPC MUST reject a prescription while any correction request remains open or any existing dispensing blocker remains.
- **FR-013**: Request creation, decline, failed resolution, and successful correction/reissue MUST NOT create or modify invoices, payments, cashbox entries, stock balances, batches, or stock movements. Only the existing atomic dispense RPC may mutate stock and generate the associated invoice.
- **FR-014**: Request and resolution events MUST be append-only, attributable to actor and timestamp, branch-scoped, and protected against UPDATE, DELETE, and TRUNCATE.
- **FR-015**: Request reads MUST be RLS-enforced and limited to the requester, assigned prescriber, and explicitly authorized branch-level read-only oversight roles. Read access MUST NOT imply resolution authority.
- **FR-016**: All write operations MUST use dedicated SECURITY DEFINER RPCs with fixed empty `search_path`, explicit permission/role checks, parent-child and branch validation, row locking, and least-privilege EXECUTE grants. PUBLIC, anon, and unrelated service roles MUST NOT receive EXECUTE.
- **FR-017**: Authenticated direct DML privileges on prescriptions, prescription items, correction requests, and correction events MUST remain denied. RLS alone or a hidden button MUST NOT be treated as the write boundary.
- **FR-018**: `create_prescription_atomic` MUST NOT allow `pharmacy.create` alone to create an internal prescription. Prescription authoring MUST require a dedicated clinical authoring permission; any pharmacist external-intake capability requires a separately approved, explicitly external-only contract.
- **FR-019**: External prescriptions MUST remain ineligible for internal stock dispensing and internal pharmacy billing, independently of correction-request state.
- **FR-020**: All request, resolution, decline, cancellation, and reissue actions MUST be audited without storing secrets or exposing patient data outside the authorized application context.
- **FR-021**: The user experience MUST support Arabic RTL and English LTR, 320–430px mobile widths, accessible labels/focus/error states, and a clear explanation of why dispensing is blocked and who must act next.
- **FR-022**: Tests MUST cover pharmacist, assigned prescriber, other doctor, wrong-branch doctor, admin, super-admin, duplicate request, concurrent request, concurrent resolution, stale snapshot, external prescription, and negative assertions proving no stock/invoice/ledger mutation.

### Key Entities

- **Prescription correction request**: One request for one specific prescription item, linked to the prescription, patient, visit, branch, requester, assigned prescriber, reason, item snapshot, current state, and resolution reference.
- **Correction request event**: Append-only record of request creation, prescriber disposition, item correction, decline, cancellation, reissue, and any permitted reopening.
- **Prescription item snapshot**: Immutable evidence of the item's clinical/catalogue fields at the time the pharmacist requested correction.
- **Replacement prescription link**: Explicit reference from a cancelled prescription correction resolution to the replacement order created in the same transaction.

## Success Criteria

- **SC-001**: 100% of accepted correction requests have consistent prescription, item, patient, visit, branch, requester, and assigned-prescriber links.
- **SC-002**: 100% of unauthorized-role and cross-branch resolution attempts are denied at the database RPC boundary.
- **SC-003**: Zero invoice, payment, cashbox, stock, batch, or stock-movement changes occur when a request is created, declined, or rejected.
- **SC-004**: Zero duplicate open requests exist for the same prescription item, including concurrent submissions and retries.
- **SC-005**: At most one concurrent resolution can succeed for a request.
- **SC-006**: 100% of prescriptions with an open request or unresolved dispensing blocker are rejected by the dispensing RPC before any mutation.
- **SC-007**: Every request and resolution has immutable actor/time/reason/snapshot evidence.
- **SC-008**: Pharmacists cannot author or alter internal clinical prescription content through direct DML or an over-broad RPC permission.
- **SC-009**: The correction workflow is usable at 320–430px in Arabic RTL and English LTR without hiding the blocker, assignee, or next action.
- **SC-010**: No QA or Production release is accepted until exact-head CI, disposable PostgreSQL 17 integration, authenticated role/branch acceptance, and clinical staff review pass.

## Assumptions

- V1 stores one request per prescription item; a prescription with multiple blocked items can have multiple independently resolved requests.
- V1 permits resolution by the exact `prescriptions.prescribed_by` user only. No implicit delegation or fallback to `visits.doctor_id` is allowed.
- If the assigned prescriber is missing or unavailable, the request fails closed until an explicitly authorized reassignment/delegation workflow exists.
- A declined request is closed for audit but the clinical item remains blocked. Decline is not a dispensing approval.
- Cancel-and-reissue is one atomic clinical operation; it does not post stock or financial entries.
- Dedicated permission codes are preferred over reusing broad `pharmacy.update` or `emr.update` alone. Proposed permissions are `prescriptions.correction.request`, `prescriptions.correction.resolve`, and `prescriptions.create`; role assignment must explicitly exclude admin/super-admin from clinical resolution unless they are separately authorized clinical users.
- The existing Phase 57B candidate remains a separate dependency and must be reviewed/applied through its own release gates. This specification does not authorize any hosted migration.

## Open Decisions — Required Before Planning

1. **Delegated prescriber**: Should a different same-branch doctor be allowed to take over a correction request through an explicit, audited delegation, or must V1 remain restricted to the exact `prescribed_by` user? Recommended default: exact assigned prescriber only.
2. **External prescription intake**: Should pharmacy staff be allowed to register external prescriptions for documentation? Recommended default: not in this feature; any such intake must be explicitly external-only and separately specified.

## Scope Exclusions

- Automatic medicine matching, AI-generated substitutions, inferred doses/routes/frequencies/durations, or silent clinical normalization.
- Internal dispensing or billing of external prescriptions.
- Partial dispensing or silent omission of blocked items.
- Cross-branch reassignment without an explicit audited delegation policy.
- Any Production migration, privilege change, deployment promotion, or live clinical/financial data mutation.
