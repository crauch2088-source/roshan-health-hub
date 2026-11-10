# Tasks: Pharmacist-to-Prescriber Correction Workflow

**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [correction-workflow-contract.md](contracts/correction-workflow-contract.md), Issue #217.

**Status**: Specification drafted; no application or database behavior changed.

## Phase 0 — Source verification
- [ ] T001 Confirm exact live/canonical types, constraints and FKs for prescriptions, prescription_items, users, visits and branches.
- [ ] T002 Verify permission helper, active-user helper, branch helper and role mappings.
- [ ] T003 Verify audit triggers and append-only enforcement patterns.
- [ ] T004 Reconcile migration ledger and choose a new forward-only version; do not rewrite Phase 57/57B.

## Phase 1 — RED: tests first
- [ ] T005 Add Node source-contract tests for RPC-only writes, pharmacist request UI, prescriber inbox, RTL/LTR and no fuzzy linking.
- [ ] T006 Add disposable PostgreSQL 17 fixture for request/event tables, roles and branch helpers.
- [ ] T007 Add failing tests for request creation, idempotent retry, duplicate-open conflict and immutable item snapshot.
- [ ] T008 Add denial tests for wrong branch, external/cancelled/dispensed/deleted parent, linked/deleted item, non-pharmacist requester, pharmacist resolver, other doctor, admin and super-admin without authorship.
- [ ] T009 Add failing replace/reject/stale snapshot/inactive medicine/append-only tests.
- [ ] T010 Add concurrency tests for duplicate request and dispense-vs-resolution.
- [ ] T011 Add cancel-and-reissue atomicity tests with valid and invalid complete payloads.
- [ ] T012 Assert zero inventory and financial side effects for all correction operations.

## Phase 2 — GREEN: database
- [ ] T013 Create request/event tables, constraints, indexes, RLS and append-only trigger.
- [ ] T014 Implement idempotent request RPC with server-derived snapshots, branch validation and locks.
- [ ] T015 Implement original-prescriber replace/reject/cancel-and-reissue RPCs.
- [ ] T016 Revoke direct DML and PUBLIC/anon EXECUTE; grant only required authenticated SELECT/EXECUTE.
- [ ] T017 Run focused PostgreSQL 17 integration.

## Phase 3 — Application
- [ ] T018 Add typed request API and status parsing.
- [ ] T019 Add pharmacist request action for eligible unlinked items; keep dispense disabled.
- [ ] T020 Add original-prescriber inbox in existing consultation/visit context.
- [ ] T021 Add exact catalogue selection, replacement confirmation, rejection reason and cancel/reissue.
- [ ] T022 Add Arabic/English strings and mobile/desktop RTL/LTR layouts.
- [ ] T023 Invalidate pharmacy/consultation queries after terminal actions; no optimistic dispense state.

## Phase 4 — Verify/release
- [ ] T024 Run test:guard, typecheck, lint and build.
- [ ] T025 Run PostgreSQL 17 workflow and existing pharmacy/clinical security integrations.
- [ ] T026 Run browser tests at 320–430px and desktop, RTL/LTR.
- [ ] T027 Complete authenticated synthetic QA pharmacist/original-prescriber acceptance.
- [ ] T028 Independent review of authorship, RLS, immutability and no-side-effect guarantees.
- [ ] T029 Keep hosted QA/Production migrations unapplied until separate release gates and approval.
