# Implementation Plan: Auditable Prescription Correction Workflow

**Branch**: `061-prescription-correction-workflow` | **Date**: 2026-11-10 | **Issue**: #217

## Summary

Add an auditable, branch-bound correction request workflow between the pharmacy queue and the responsible prescriber. Preserve Phase 57/57B fail-closed dispensing. A correction request is not a dispensing action and must not touch inventory, invoices, payments or cashbox state.

## Technical Context

- **Application**: React, TypeScript, TanStack Router, Supabase JS, PostgreSQL 17.
- **Existing write boundary**: `create_prescription_atomic(uuid, boolean, jsonb)` creates a saved prescription and binds `prescribed_by` and `doctor_id` to the authenticated application actor.
- **Existing pharmacy boundary**: `fn_dispense_prescription_with_invoice(uuid, boolean)` is the authoritative FEFO/atomic invoice and stock mutation path; it remains unchanged by this feature.
- **Roles**: current live role codes include `pharmacist`, `doctor`, `admin`, `super_admin`. Do not assume legacy role codes are equivalent to current roles.
- **Tests**: node:test source guards and disposable PostgreSQL 17 integration fixtures/workflows. Add multi-session concurrency coverage where the workflow requires it.
- **Platform**: Android-installable PWA, mobile-first, Arabic RTL and English LTR.
- **Constraints**: no paid services, no hosted QA/Production DDL/DML, no direct browser writes to clinical/financial tables.

## Constitution Check

- Clinical safety and no inference: PASS — no fuzzy medicine matching, no inferred dose/route/quantity.
- Least privilege: PASS — dedicated pharmacist-request and doctor-resolve permissions; Super Admin only through existing explicit bypass.
- Branch isolation: REQUIRED — prescription, item, patient, visit, actor and request must be revalidated at the database boundary.
- Auditability: REQUIRED — append-only request event history with actor and server timestamp.
- Atomicity: REQUIRED — cancellation/reissue is all-or-nothing; stock/billing remains separate.
- Test-first engineering: REQUIRED — prove the malformed/stale/concurrent cases fail before implementation.
- Migration safety: PASS — candidate migration only; no hosted application.
- Cost efficiency: PASS — existing Supabase/PostgreSQL and app infrastructure only.

## Proposed Database Design

1. `prescription_item_correction_requests`: one row per correction lifecycle, bound to prescription/item/patient/visit/branch; stores immutable original item snapshot, reason, requester/time, current status and final disposition metadata.
2. `prescription_item_correction_events`: append-only events (`requested`, `item_replaced`, `rejected`, `cancelled_and_reissued`) with actor, server timestamp and JSON payload containing before/after snapshots or replacement references.
3. Partial unique index on `prescription_item_id WHERE status = 'pending'` to prevent duplicate pending requests.
4. RLS-enabled, forced-RLS read models; authenticated receives SELECT only. Direct INSERT/UPDATE/DELETE/TRUNCATE are revoked. Mutations happen through RPCs only.
5. `request_prescription_item_correction(uuid,text)`: pharmacist-only, validates exact active unlinked item and pending internal parent, locks prescription then item, returns existing pending request on retry, and appends the request event.
6. `resolve_prescription_item_correction(uuid,text,jsonb,text)`: responsible-doctor-only. Supported actions:
   - `replace_item`: replace the selected unlinked item with an explicitly chosen active catalogue medicine and complete clinician-entered regimen; server derives catalogue display name and price.
   - `reject`: append a rejection disposition; do not alter prescription or item.
   - `cancel_and_reissue`: cancel the old pending order and call the existing atomic prescription-creation RPC with a complete replacement order in the same transaction.
7. Consistent row-lock order: prescription → selected item → request. Revalidate request status and captured item snapshot after locks; concurrent second resolver must fail without side effects.
8. The correction functions never call dispense, invoice, payment, stock movement, or cashbox RPCs.

## Clinical/Authorization Rules

- Request creation requires the pharmacist's current application identity, `pharmacy.correction.request`, active user, same branch, active patient/visit/prescription/item, internal pending order, and `medicine_id IS NULL`.
- Resolve requires `prescriptions.correction.resolve`, current doctor identity, same branch, and assignment through `prescribed_by`, `doctor_id`, or `visits.doctor_id`. An unrelated doctor in the same branch is insufficient.
- If all responsible-prescriber references are absent, resolution fails closed and the request is flagged for manual data-governance remediation; do not silently assign any doctor.
- All non-NULL branch IDs must agree; visit branch is mandatory. Super Admin retains the established explicit bypass.
- A replacement must specify quantity as a finite positive whole number and provide complete dose, frequency, duration, dosage form and route. No route or dose default is inferred.

## Project Structure

```text
specs/061-prescription-correction-workflow/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── contracts/
    └── prescription-correction-contract.md

db/
db/tests/
src/routes/_authenticated/pharmacy.tsx
src/features/clinic/consultation/components/PrescriptionTab.tsx
tests/
```

## Verification Sequence

1. Add failing source-contract tests for permissions, lock order, status transitions, no direct DML and no stock/billing side effects.
2. Add a disposable PostgreSQL 17 fixture and tests for requester roles, assigned/unassigned doctors, branch mismatch, invalid prescription states, duplicate requests, stale snapshots and rejection.
3. Add two-session resolution race test; assert one commit and one deterministic conflict.
4. Implement migration and RPCs; run the focused PG17 workflow.
5. Add pure TypeScript model tests for bilingual status, allowed actions and stale state.
6. Add pharmacist and doctor UI using only RPCs; refresh queue after completion and keep dispensing disabled until every active line is valid.
7. Run exact-head full CI, CodeQL, source parity and Spec Kit validation.
8. Keep Draft pending independent SQL review and authenticated QA pharmacist/prescriber/browser acceptance.

## Risks

- Legacy prescriptions may lack a responsible prescriber. Do not broaden access to all doctors as a workaround.
- Existing prescription/item RLS and role maps differ across legacy and current roles. Use exact current permission codes and test under real role fixtures.
- Reissue must preserve the original order and avoid any stock/financial mutation.
- A partial correction must not accidentally make a mixed prescription dispensable.
- A direct UI-only correction would be bypassable; PostgreSQL RPC validation is authoritative.
