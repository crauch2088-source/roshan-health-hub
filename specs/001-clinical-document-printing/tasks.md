# Tasks: Clinical Document Printing

**Input**: [spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md), [data-model.md](./data-model.md), and [contracts/print-document-contract.md](./contracts/print-document-contract.md).

**Status**: Planning baseline. Implementation tasks remain blocked by G0–G2 until their evidence is recorded.

## Phase 0: Source and permission contracts

- [ ] T001 Inspect QA PostgreSQL catalogs for exact columns, FKs, soft-delete fields, indexes, and triggers for `invoices`, `invoice_items`, `payments`, ledger/reversal tables, `prescriptions`, `prescription_items`, `medical_certificates`, `visits`, `users`, and `system_settings`.
- [ ] T002 [P] Verify RLS policies and grants for each source table under anon, authenticated, and service roles; record branch-scoping predicates.
- [ ] T003 [P] Verify the permission catalog and actual UI/RPC authorization paths for invoice, receipt, prescription, and certificate read/print/reprint actions.
- [ ] T004 Verify whether prescription records have an explicit signed/approved/finalized state; document the exact existing lifecycle semantics.
- [ ] T005 Verify `useSettings()` key mapping against `src/routes/_authenticated/settings.tsx`; resolve the observed `center_*` versus `clinic_*` mismatch without adding parallel settings keys.
- [ ] T006 Record browser, Android device/browser, printer model, driver, and actual supported paper sizes; keep thermal support unclaimed until physical tests pass.
- [ ] T007 Record the G0–G2 evidence and update this plan/spec before enabling implementation tasks.

**Gate:** Do not begin document UI implementation until T001–T005 are complete and reviewed.

## Phase 1: Shared print foundation

- [ ] T008 [P] Add failing unit tests for immutable view models and required-field handling in `tests/print/print-view-model.test.ts`.
- [ ] T009 [P] Add a browser test proving one selected print root excludes all unrelated route content in `tests/print/print-isolation.spec.ts`.
- [ ] T010 Implement a shared print document shell in `src/components/print/PrintDocument.tsx` with one explicit print root and no mutation capability.
- [ ] T011 Update `src/styles.css` to print only the selected root and preserve accessible, page-break-safe content.
- [ ] T012 Add bilingual identity header/footer components backed by the verified canonical settings mapping.
- [ ] T013 Verify browser print cancellation and session-expiry behavior without database writes.

## Phase 2: User Story 1 — Posted payment receipt (P1)

- [ ] T014 [P] Add failing tests for receipt source fidelity, partial payment, reversed payment, and duplicate/retry cases in `tests/print/receipt-print-model.test.ts`.
- [ ] T015 Add a persisted-payment receipt view-model helper in `src/lib/print/receipt.ts`; reject unsaved form state and missing invoice/payment linkage.
- [ ] T016 Add a receipt print surface that receives one persisted payment ID and loads it through the verified authorized read path.
- [ ] T017 Add the receipt action only to persisted payment rows; never to the unsaved payment entry form.
- [ ] T018 Verify every displayed financial field against the authoritative payment and ledger records under synthetic PostgreSQL fixtures.

## Phase 3: User Story 2 — Authorized prescription (P1)

- [ ] T019 [P] Add failing tests for exact field fidelity and incomplete instructions in `tests/print/prescription-print-model.test.ts`.
- [ ] T020 Implement the read-only prescription view model in `src/lib/print/prescription.ts` from the verified saved prescription/child-item contract.
- [ ] T021 Add an authorized print action to the persisted prescription workflow, not to unsaved composer state.
- [ ] T022 Block official printing when required saved medication instructions are missing; preserve all saved strings and quantities verbatim.
- [ ] T023 Verify authorization, branch isolation, and prescription lifecycle state using synthetic records.

## Phase 4: User Story 3 — Invoice and medical certificate (P2)

- [ ] T024 [P] Add tests for invoice totals and selected-certificate-only print behavior in `tests/print/invoice-certificate-print.test.ts`.
- [ ] T025 Refactor invoice route to print only the selected invoice document and exclude payment forms/history and navigation.
- [ ] T026 Refactor certificate route so the print action selects exactly one persisted certificate and excludes other rows and dialogs.
- [ ] T027 Verify deleted, branch-mismatched, and unauthorized invoice/certificate records cannot be rendered as official documents.

## Phase 5: Bilingual print quality and polish

- [ ] T028 [P] Add Arabic RTL and English LTR rendering fixtures with mixed-language names, numerals, and long content.
- [ ] T029 Validate A4 page breaks, tables, and critical medication instructions in browser print preview.
- [ ] T030 Add 58 mm and 80 mm profiles only after physical printer/browser validation is documented.
- [ ] T031 Verify keyboard-accessible print actions, screen-reader labels, and mobile interaction.
- [ ] T032 Update user-facing documentation and mark Phase 53 complete only after all acceptance criteria and staff validation pass.

## Dependencies and execution order

- Phase 0 blocks every implementation phase.
- Phase 1 blocks all document-specific print surfaces.
- Receipt and prescription stories can proceed independently after Phase 0/1, using separate files.
- Invoice/certificate correction can proceed after Phase 0/1.
- Physical thermal validation and staff acceptance are release gates, not assumptions.
