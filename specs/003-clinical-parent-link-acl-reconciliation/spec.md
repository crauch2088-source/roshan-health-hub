# Feature Specification: Clinical parent-link and private helper ACL reconciliation

**Feature Branch**: `003-clinical-parent-link-acl-reconciliation`  
**Created**: 2026-11-03  
**Status**: Candidate in PR #172; targeted PostgreSQL 17 workflow passed; full CI and QA application pending  
**Input**: `docs/MASTER_PLAN.md` — Phase 55, live clinical guard and helper ACL reconciliation.

## User Scenarios & Testing

### User Story 1 — Prevent lab item re-parenting (Priority: P1)

A lab operator updates a lab-order item, but cannot change its parent `order_id` after creation.

**Why this priority**: A child item must remain attached to its original order; re-parenting can detach it from the patient/visit context and undermine clinical traceability.

**Independent Test**: Use synthetic active and cancelled lab orders, attempt to change an existing item's `order_id`, and verify SQLSTATE 23514 with no stored change.

**Acceptance Scenarios**:

1. **Given** a saved lab-order item, **When** a user changes its `order_id`, **Then** the database trigger rejects the update and the original parent remains unchanged.
2. **Given** an update to a non-parent field on a valid active item, **When** an authenticated user performs the update, **Then** the trigger still runs and the update succeeds.
3. **Given** a child row linked to a cancelled visit, **When** an insert/update is attempted, **Then** the existing cancelled-visit guard rejects it.

### User Story 2 — Protect private helper functions (Priority: P1)

An authenticated or anonymous application role cannot directly invoke private claim-branch or role-sync helper functions.

**Why this priority**: Private SECURITY DEFINER helpers must be invoked only by their owning functions/triggers, not exposed as general RPC entry points.

**Independent Test**: Inspect effective function privileges for anon, authenticated, service_role and authenticator after the Phase55 migration.

**Acceptance Scenarios**:

1. **Given** the reconciled schema, **When** an application role checks EXECUTE on a private helper, **Then** it has no direct EXECUTE privilege.
2. **Given** an installed trigger invokes a private trigger function, **When** the trigger fires under authenticated role, **Then** the trigger continues to execute.

### Edge Cases

- Re-parenting an item to another active order.
- Re-parenting an item to an order linked to a cancelled visit.
- Direct function execution attempted by anon, authenticated, service_role or authenticator.
- Trigger invocation after direct EXECUTE revocation.
- Empty or malformed parent identifiers.

## Requirements

### Functional Requirements

- **FR-001**: `private.phase36_guard_clinical_visit_links()` MUST reject changes to `patient_id` and `visit_id`.
- **FR-002**: For `lab_order_items`, the same guard MUST reject changes to `order_id`.
- **FR-003**: Existing cancelled-visit insert/update protections MUST remain unchanged.
- **FR-004**: The clinical trigger function MUST remain SECURITY DEFINER with an empty `search_path`.
- **FR-005**: PUBLIC, anon, authenticated, service_role and authenticator MUST NOT directly execute the private trigger/helper functions.
- **FR-006**: Installed triggers MUST continue to execute correctly after direct function EXECUTE is revoked.
- **FR-007**: The migration MUST NOT alter tables, rows, triggers or patient data.

### Key Entities

- **Lab order**: Parent clinical order linked to patient, visit and branch.
- **Lab order item**: Child record whose `order_id`, `patient_id` and `visit_id` links are immutable.
- **Clinical visit**: Parent lifecycle state used by child insert/update guards.
- **Private helper function**: Internal SECURITY DEFINER function used by privileged functions/triggers.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% of attempted `lab_order_items.order_id` changes are rejected with SQLSTATE 23514.
- **SC-002**: Existing Phase36 patient/visit immutability and cancelled-visit regression tests remain green.
- **SC-003**: Authenticated-role updates to permitted child fields continue to invoke the trigger successfully.
- **SC-004**: anon, authenticated, service_role and authenticator have no direct EXECUTE privilege on the three reconciled private functions.
- **SC-005**: The trigger function remains SECURITY DEFINER with empty `search_path`.
- **SC-006**: PostgreSQL 17 integration workflow passes.

## Assumptions

- Existing triggers and tables are correct and must not be recreated or altered by Phase55.
- The tracked Phase36 migration is the canonical source for the clinical parent-link guard.
- Private helper functions are internal implementation details and do not require direct application-role EXECUTE grants.
- Production application requires encrypted backup and isolated restore evidence.
