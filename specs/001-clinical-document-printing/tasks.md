# Tasks: Clinical Document Printing

**Input**: spec.md, plan.md, research.md, data-model.md, and contracts/print-document-contract.md.

**Status**: QA-only implementation remains in draft PRs #179 and #181. PR #178's invoice/certificate fix is merged and deployed. The encrypted Production backup, isolated PostgreSQL 17 restore rehearsal, and owner-device decryption/archive verification are now complete; this closes the backup/recovery sub-gate only. No Production migration, application data write, or release promotion has occurred. Checkboxes below track accepted work, not merely code present in an unmerged branch.

## Phase 0: Source and permission contracts

- [x] T001 Inspect QA and Production catalogs for columns, FKs, soft-delete fields, and relevant triggers for invoices, payments, ledger/reversal rows, prescriptions, prescription items, medical certificates, visits, users, and system settings. (Catalog-only; no patient or financial row contents read.)
- [ ] T002 Verify exact table grants under anon/authenticated/service roles and complete authenticated role/branch E2E. QA RLS policy predicates and branch boundaries have been inspected; the grant matrix and real user journeys remain.
- [ ] T003 Complete permission/role acceptance for invoice, receipt, prescription, and certificate read/print/reprint. Permission codes and selected role mappings have been inspected; actual center staff assignments and user journeys remain.
- [ ] T004 Verify prescription lifecycle semantics. **Confirmed:** no digital-signature/signed-at field exists; do not claim a digital signature. **Still open:** inspect all status transitions and confirm the center's meaning of a saved/pending order.
- [x] T005 Reconcile useSettings() with the settings page. Invoice print now uses the canonical center_name, center_name_ar, address, phone, and invoice_footer keys (PR #178); QA has no active settings rows, so branding values are not visually validated.
- [ ] T006 Record actual Android browser, desktop browser, printer model, driver, and supported paper sizes. Honor X7c is the known target device; the actual browser and printer are not yet confirmed.
- [ ] T007 Record G0–G2 evidence, role assignment test results, and Phase54C Production availability. Production receipt output remains blocked until the encrypted backup/restore gate permits Phase54C promotion.

**Gate:** Do not release the document-printing feature to Production until source contracts, grants, role/branch E2E, canonical identity values, and required Production RPCs are verified. QA-only implementation may proceed with synthetic fixtures.

## Phase 1: Shared print foundation

- [ ] T008 Add unit tests for immutable view models and required-field handling. Receipt and prescription model tests are present in draft PRs #181/#179; a common shared print-view-model contract is not yet accepted.
- [ ] T009 Add a real browser test proving one selected print root excludes unrelated route content. Current source-level guards are not a browser print-preview test.
- [ ] T010 Implement a shared typed print document shell in src/components/print/PrintDocument.tsx; current templates are separate route/component markup.
- [ ] T011 Enforce exact selected-root print isolation in src/styles.css and every print entry point. Target-specific isolation is implemented in draft PRs #179/#181 but is not yet merged or browser-verified.
- [ ] T012 Add shared bilingual identity header/footer components. Existing document templates use the canonical settings keys but are not yet consolidated into shared components.
- [ ] T013 Verify print cancellation, session expiry, and cleanup behavior on supported browsers without database writes.

## Phase 2: User Story 1 — Posted payment receipt (P1)

- [ ] T014 Add failing tests for posted receipt fidelity, partial payment, reversal, duplicate/retry, missing ledger, branch mismatch, and cashier privacy. Model/UI tests are in draft PR #181; synthetic PostgreSQL integration remains.
- [ ] T015 Implement the read-only receipt model in src/lib/print/receipt.ts. Implemented in draft PR #181; not yet merged/accepted.
- [ ] T016 Add a receipt surface that loads one persisted payment through Phase54C's authorized ledger-status RPC. Implemented in draft PR #181; Production remains blocked because Phase54C is QA-only.
- [ ] T017 Expose receipt printing only from persisted payment rows, never the unsaved payment form. Implemented in draft PR #181; not yet merged/accepted.
- [ ] T018 Verify displayed financial fields against authoritative payment/ledger records with synthetic PostgreSQL fixtures and authenticated role/branch tests.

## Phase 3: User Story 2 — Saved prescription order (P1)

- [ ] T019 Add failing tests for exact saved-field fidelity and incomplete instructions. Tests are in draft PR #179; not yet merged/accepted.
- [ ] T020 Implement the read-only prescription model in src/lib/print/prescription.ts. Implemented in draft PR #179; not yet merged/accepted.
- [ ] T021 Add an authorized print action only for a persisted prescription order, not unsaved composer state. Implemented in draft PR #179; not yet merged/accepted.
- [ ] T022 Block incomplete orders, preserve saved values, and never claim a digital signature. Implemented in draft PR #179; not yet merged/accepted.
- [ ] T023 Verify authorization, branch isolation, and status lifecycle using synthetic fixtures and authenticated role tests.

## Phase 4: User Story 3 — Invoice and medical certificate (P2)

- [x] T024 Add source-level regression tests for invoice print content and selected-certificate-only printing (PR #178).
- [x] T025 Isolate invoice content from payment forms/history and page chrome (PR #178, merged and deployed).
- [x] T026 Select exactly one persisted certificate and exclude other list rows/dialogs (PR #178, merged and deployed).
- [ ] T027 Complete deleted-record, branch-mismatch, and unauthorized role/branch E2E. Additional fail-closed guards are in draft PRs #179/#181.

## Phase 5: Bilingual print quality and polish

- [ ] T028 Add Arabic RTL and English LTR visual fixtures with mixed-language names, numerals, and long content.
- [ ] T029 Validate A4 page breaks, tables, and critical medication instructions in actual browser print preview.
- [ ] T030 Add 58 mm/80 mm profiles only after physical printer/browser validation is documented.
- [ ] T031 Verify keyboard accessibility, screen-reader labels, and Android/mobile interaction.
- [ ] T032 Complete clinical/finance staff acceptance, update user-facing instructions, and mark Phase 53 complete only after every release criterion passes.

## Dependencies and execution order

- Phase 0 blocks Production implementation/release.
- Phase 1 blocks all document-specific Production print surfaces.
- Prescription and invoice/certificate QA work can proceed with synthetic records while role E2E is prepared.
- Receipt UI can be developed against QA Phase54C but cannot be enabled in Production until encrypted backup/restore evidence exists and Phase54C is promoted.
- Physical thermal validation and staff acceptance are release gates, not assumptions.


## Evidence refresh — 2026-11-09

This section supersedes earlier backup-status notes in this task file. Historical task checkboxes remain unchanged unless the corresponding acceptance criterion is fully evidenced.

### Completed infrastructure evidence

- The private backup-runner PR #2 is merged. Workflow [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237) completed the PostgreSQL 17 dump, isolated restore rehearsal, critical row-count comparison, age encryption, and ciphertext-only artifact upload.
- The encrypted bundle was copied to private Google Drive. The owner verified the encrypted payload SHA-256 on Android/Termux, decrypted it using the locally held age identity, confirmed archive readability with `tar -tzf`, and removed the temporary plaintext archive. The private identity and decrypted SQL were not shared.
- Backup scope was database-only. At backup time there were zero Storage objects, zero Vault secrets, and three empty Storage buckets. No recurring backup schedule is configured.
- PR #201 (device-side recovery evidence) and PR #202 (engineering acceleration review) are merged. The Spec Kit CLI remains pinned at v1.2.6 with the agent-neutral `none` integration.

### Current implementation and release state

- PR #179 contains saved-prescription printing and authoring safeguards; PR #181 contains persisted-payment receipt printing. Both remain Draft and are not accepted for release. Their automated tests do not replace authenticated role/branch acceptance, browser print-preview checks, Android print-path checks, or physical printer/staff acceptance.
- PR #191 remains Draft. Its Phase 57 quantity guard and mixed catalogue/free-text prescription rejection are covered by the disposable PostgreSQL 17 integration workflow. Exact-head CI is recorded as 18 successful jobs, zero failures, and one intentionally skipped authenticated clinical-acceptance job. Persistent-QA pharmacist acceptance and independent review remain outstanding.
- PR #189 remains Draft. Its medicine identity implementation is present, but `pharmacy.update` is shared by admin and pharmacist roles; the catalogue is global (no `branch_id`); and the physical-pack acknowledgement is not a persisted audit attestation. These are unresolved product/access decisions, not checkbox-only documentation issues.
- Production migration head remains `20261102232941`; QA remains `20261104065852` with Phase 57 applied in QA only. Production and QA ledgers are not yet reconciled. Phase 54C receipt-integrity RPC is not yet available in Production.
- Issue [#199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) remains the canonical release-gate tracker.

### Remaining acceptance gates (not marked passed)

1. Obtain an authorized synthetic QA pharmacist sign-in path and complete Phase 57 rejection, valid FEFO dispensing, invoice atomicity, idempotency, and audit acceptance in persistent QA.
2. Complete independent review of PR #191; retain the Production gate until the owner explicitly approves the release plan.
3. Resolve PR #189's permission scope, shared-catalogue branch semantics, and durable physical-pack verification/audit requirements.
4. Complete browser print-preview and Android/mobile checks for Arabic RTL and English LTR, page breaks, print cancellation, and selected-document isolation; validate actual A4 hardware and only claim thermal support after testing the target printer/browser.
5. Complete role/branch E2E and staff UAT across reception → GP → lab → pharmacy → billing.
6. Reconcile Production and QA migration ledgers against canonical migration source and quarantine evidence before any Production rollout.

**Safety boundary:** the backup/recovery sub-gate is passed, but this does not authorize Production Phase 57, Phase 54C promotion, DDL/DML, permission changes, deployment promotion, or clinical launch. Do not create synthetic clinical or financial records in Production.
