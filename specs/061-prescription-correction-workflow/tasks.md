# Tasks: Prescription Correction Workflow

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contract](contracts/prescription-correction-contract.md)  
**Status**: Phase 61 database backend implemented in PR #226; pharmacist request, prescriber replacement/rejection, and full multi-item cancel-and-reissue UI implemented as candidates in PR #229. Mobile browser acceptance and release gates remain outstanding.

## Phase 0 — Confirm source contracts

- [x] T001 Inspect prescription status constraints, update triggers, RLS and grants in the current canonical PostgreSQL 17 baseline.
- [x] T002 Confirm `audit_logs` contract and current soft-delete/history conventions.
- [x] T003 Confirm the exact behavior of `create_prescription_atomic` and the active-prescription queue after cancellation.
- [x] T004 Decide append-new-item/soft-delete versus in-place replacement based on dispense RPC and audit compatibility.

## Phase 1 — RED: regression tests first

- [x] T005 Add failing PostgreSQL 17 tests for pharmacist request authorization and exact item/parent/branch binding.
- [x] T006 Add failing tests for duplicate pending requests and retry idempotency.
- [x] T007 Add failing tests for unrelated doctor, wrong branch, Admin, legacy roles, Super Admin, external/cancelled/dispensed/deleted prescriptions.
- [x] T008 Add failing tests for stale item snapshots and concurrent resolution.
- [x] T009 Add failing no-side-effect assertions for request, duplicate retry and rejection (stock, movements, invoices, payments, cashbox, prescription and item state).
- [x] T010 Add failing tests for item replacement and atomic cancel-and-reissue, including rollback on invalid payload.

## Phase 2 — GREEN: database contract

- [x] T011 Add a forward-only candidate migration for dedicated permissions, request/event tables, indexes, RLS, append-only guards and least-privilege grants.
- [x] T012 Implement pharmacist request RPC with lock order prescription → item → request and idempotent duplicate handling.
- [x] T013 Implement responsible-doctor resolution RPC with locked status/snapshot revalidation and explicit dispositions.
- [x] T014 Implement atomic cancel-and-reissue using the existing prescription creation contract; prohibit all stock/financial side effects.
- [x] T015 Run focused PostgreSQL 17 integration and source-contract tests until green.

## Phase 3 — UI and acceptance

- [x] T016 Add bilingual pharmacist request UI to the blocked free-text line in the pharmacy queue.
- [x] T017 Add a branch/visit-scoped correction inbox for responsible doctors.
- [x] T018 Add explicit catalogue selection and clinician-entered regimen fields; no fuzzy link or dose inference.
- [x] T019 Refresh the full prescription and revalidate every active item after resolution.
- [ ] T020 Add mobile 320–430 px and Arabic RTL/English LTR source/browser tests.

## Phase 4 — Release gates

- [ ] T021 Exact-head full CI, CodeQL, Spec Kit and migration source parity.
- [ ] T022 Independent SQL/RLS/ACL/clinical review.
- [ ] T023 Authenticated QA acceptance with synthetic pharmacist and responsible prescriber.
- [ ] T024 Staff acceptance and current backup/restore evidence.
- [ ] T025 Keep Production blocked until the complete migration provenance and explicit release approval are satisfied.

## Dependencies

- T001–T004 block migration implementation.
- T005–T010 must be RED before T011–T014.
- T021–T025 block hosted release.


## 2026-11-10 implementation checkpoint

- PR #226 contains the candidate database/RPC layer and its PostgreSQL 17 authorization, audit, no-side-effect, idempotency and two-session concurrency coverage.
- PR #229 adds bilingual pharmacist request and responsible-prescriber replacement/rejection surfaces. All writes use the dedicated correction RPCs; direct writes to request/event tables are not granted or used.
- The pharmacy queue continues to block unlinked, invalid-quantity and external prescriptions from internal dispense; correction requests do not dispense or bill.
- PR #229 now includes a permission-gated `cancel_and_reissue` action with a complete multi-item editor. Every replacement item requires an active catalogue selection and clinician-entered dose, frequency, duration, quantity, dosage form and route; no original regimen is copied or inferred.
- The editor submits the full array to the existing atomic resolver RPC. The backend cancels the original prescription and creates the replacement in one transaction; no stock or financial side effects are introduced.
- Dedicated PostgreSQL 17 + source-contract workflow passed on commit `4cc6756b88ec834f7654f4a76a493975d8842c1a`. Repository-wide CI was dispatched separately and remains the next exact-head gate.
- Both pharmacist and prescriber dialogs now use RTL/LTR direction and bounded mobile-height scrolling; source checks cover these contracts, while real-device/browser acceptance remains open.
- The existing `PrescriptionTab` composer is now gated by the dedicated `prescriptions.create` permission, matching the Phase 61 RPC authorization. It no longer treats broader `emr.create` or `pharmacy.create` as permission to prescribe; users without the dedicated permission receive a bilingual notice.
- The current live role catalogue has an active `doctor` prescriber role; before activating future `dentist` or `specialist` role codes, explicitly grant and test the dedicated prescribing permissions. Legacy roles remain excluded.
- PR #229 remains Draft. No hosted migration or clinical staff acceptance has been performed.
