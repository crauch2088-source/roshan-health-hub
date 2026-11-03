# Feature Specification: Clinical parent-link and private helper ACL reconciliation

**Status:** Candidate in PR #172; targeted PostgreSQL 17 workflow passed; full CI and QA application pending  
**Related phase:** 55  
**Source of truth:** `docs/MASTER_PLAN.md`

## Problem statement

Live catalog comparison found production's Phase36 clinical child guard missing the `lab_order_items.order_id` immutability check present in the tracked source and QA. QA also retained PUBLIC EXECUTE on two private helper/trigger functions whose production ACLs are already revoked.

## User stories

- As a clinician or lab operator, a lab-order item cannot be re-parented by changing its `order_id` after creation.
- As a security administrator, private branch/role helper functions are not directly callable by application roles.
- As an application user, existing clinical triggers continue to enforce parent-link and cancelled-visit rules after direct function EXECUTE is revoked.

## Functional requirements

- **FR-001:** `private.phase36_guard_clinical_visit_links()` must reject changes to `patient_id`, `visit_id` and, for `lab_order_items`, `order_id`.
- **FR-002:** Existing cancelled-visit insert/update protections remain unchanged.
- **FR-003:** The trigger function remains SECURITY DEFINER with an empty `search_path`.
- **FR-004:** PUBLIC, anon, authenticated, service_role and authenticator cannot directly execute the private trigger/helper functions.
- **FR-005:** Installed triggers continue to execute correctly after direct EXECUTE revocation.
- **FR-006:** No table DDL, patient data changes, trigger recreation or data backfill is part of this reconciliation.

## Acceptance criteria

- An attempted `lab_order_items.order_id` update raises SQLSTATE 23514 and leaves the stored parent link unchanged.
- Existing Phase36 patient_id/visit_id immutability and cancelled-visit tests continue to pass.
- Authenticated-role updates still invoke the trigger successfully.
- The three private functions have no EXECUTE privilege for anon, authenticated, service_role or authenticator.
- The Phase36 trigger function remains SECURITY DEFINER with empty `search_path`.

## Out of scope

Changing the clinical child schema, altering existing trigger definitions, or applying the production migration before backup/restore evidence.
