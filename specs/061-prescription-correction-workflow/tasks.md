# Tasks: Prescription Correction Workflow

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contract](contracts/prescription-correction-contract.md)  
**Status**: Draft specification; implementation not started.

## Phase 0 — Confirm source contracts

- [ ] T001 Inspect prescription status constraints, update triggers, RLS and grants in the current canonical PostgreSQL 17 baseline.
- [ ] T002 Confirm `audit_logs` contract and current soft-delete/history conventions.
- [ ] T003 Confirm the exact behavior of `create_prescription_atomic` and the active-prescription queue after cancellation.
- [ ] T004 Decide append-new-item/soft-delete versus in-place replacement based on dispense RPC and audit compatibility.

## Phase 1 — RED: regression tests first

- [ ] T005 Add failing PostgreSQL 17 tests for pharmacist request authorization and exact item/parent/branch binding.
- [ ] T006 Add failing tests for duplicate pending requests and retry idempotency.
- [ ] T007 Add failing tests for unrelated doctor, wrong branch, Admin, legacy roles, Super Admin, external/cancelled/dispensed/deleted prescriptions.
- [ ] T008 Add failing tests for stale item snapshots and concurrent resolution.
- [ ] T009 Add failing no-side-effect assertions for request, duplicate retry and rejection (stock, movements, invoices, payments, cashbox, prescription and item state).
- [ ] T010 Add failing tests for item replacement and atomic cancel-and-reissue, including rollback on invalid payload.

## Phase 2 — GREEN: database contract

- [ ] T011 Add a forward-only candidate migration for dedicated permissions, request/event tables, indexes, RLS, append-only guards and least-privilege grants.
- [ ] T012 Implement pharmacist request RPC with lock order prescription → item → request and idempotent duplicate handling.
- [ ] T013 Implement responsible-doctor resolution RPC with locked status/snapshot revalidation and explicit dispositions.
- [ ] T014 Implement atomic cancel-and-reissue using the existing prescription creation contract; prohibit all stock/financial side effects.
- [ ] T015 Run focused PostgreSQL 17 integration and source-contract tests until green.

## Phase 3 — UI and acceptance

- [ ] T016 Add bilingual pharmacist request UI to the blocked free-text line in the pharmacy queue.
- [ ] T017 Add a branch/visit-scoped correction inbox for responsible doctors.
- [ ] T018 Add explicit catalogue selection and clinician-entered regimen fields; no fuzzy link or dose inference.
- [ ] T019 Refresh the full prescription and revalidate every active item after resolution.
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
