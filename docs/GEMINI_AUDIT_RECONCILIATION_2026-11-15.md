# Roshan Health Hub — Independent Audit Reconciliation
**Date:** 2026-11-15  
**Review basis:** Gemini independent audit report supplied by the owner, current GitHub main/PR state, current tracked source, and read-only PostgreSQL catalog/migration queries against Production and QA.  
**Repository baseline:** `main` at `f8c8b2d1767643561599764405b4cdbfd4db2c79`.  
**Safety boundary:** No Production/QA DDL, DML, ACL, RLS, Auth, Storage or migration writes were performed. No merge, deployment promotion, backup dispatch or test patient/financial transaction was performed during this reconciliation.

## 1. Executive decision

**Production remains NO-GO for real clinical and pharmacy operations.** This conclusion is supported by directly observed Production database state, not merely by the Gemini score.

The Gemini report is directionally correct about the release risk, but several individual statements need qualification or correction. In particular, the current inventory receive UI uses an atomic RPC (not a client-side stock increment), the latest receipt PR has changed its currency handling since the older review comments, and the current prescription UI/RPC explicitly excludes Admin from prescriber roles. Conversely, direct database stock-update privileges remain broader than the intended controlled workflow, and several serious Production-only gaps are confirmed.

The Gemini overall score of 23/100 is its own rubric. It is **not** the Roshan completion percentage and is not adopted as such.

## 2. Evidence hierarchy and scope

Evidence is classified as follows:

- **Live DB confirmed:** read-only PostgreSQL catalog, effective privilege, function-definition or migration-ledger query against the named hosted project.
- **Main source confirmed:** source fetched from the default branch at the recorded main SHA.
- **PR candidate:** code/SQL exists on an unmerged pull request branch; it is not a deployed or hosted fix.
- **Repository snapshot:** a prior release-gate report or workflow record in the repository; useful context, but not a substitute for a fresh runtime test.
- **Not verified:** requires a role-authenticated browser test, owner-controlled backup restore, physical printer test, or other evidence not obtained here.

This pass did not perform full authenticated Playwright/UAT, physical printer acceptance, owner-side backup decryption, or a professional independent human penetration test.

## 3. Directly confirmed Production/QA differences

### 3.1 Migration ledger divergence — confirmed

Read-only Supabase migration listings and catalog queries returned:

| Environment | PostgreSQL | Latest migration |
|---|---|---|
| Production `jewzonxplxhogqrnhosl` | 17.6.1.155 | `20261102232941` — `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` |
| QA `hopfohcnrtbiqjkgeukz` | 17.11.0.003 | `20261113232719` — `roshan_phase61b_clinical_role_boundary` |

QA has applied migrations not present in Production, including Phase 57, Phase 57B, Phase 58, Phase 59 and Phase 61B. Production has not. The histories must not be reconciled by editing migration-ledger rows or blindly replaying QA history into Production; the existing migration reconciliation document remains the controlling reference for semantic collisions and safe rollout sequencing.

### 3.2 Phase 55 private helper ACLs — critical, live DB confirmed

In Production, both `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` have a NULL explicit ACL and effective EXECUTE for `anon`, `authenticated`, `service_role` and `authenticator`. In QA, both have owner-only ACLs and no effective EXECUTE for those API roles.

This is a concrete Production privilege gap, not merely a generic advisor warning. Do not attempt a blanket revoke of private functions. Reconcile the exact intended callers, dependencies and regression tests, then apply a narrow ACL correction through a reviewed migration.

### 3.3 Pharmacy dispense role boundary — critical, live DB confirmed

Production exposes both of these SECURITY DEFINER RPCs to `authenticated`:

- `public.atomic_pharmacy_dispense(uuid, boolean, uuid)`
- `public.fn_dispense_prescription_with_invoice(uuid, boolean)`

The Production definitions currently authorize via broad permission checks (`pharmacy.update` and `billing.create`); they do not themselves require the canonical `pharmacist` role. The boolean `p_separate_invoice` is also supplied by the caller. This is a real role-boundary weakness, although the boolean alone is not evidence of an exploit.

QA's Phase 61B version has a stricter role boundary for the nested invoice-linked dispense RPC. Production has neither Phase 61B nor Phase 61C. PR [#250](https://github.com/crauch2088-source/roshan-health-hub/pull/250) contains the Phase 61C candidate: it moves the existing atomic implementation into a private unchecked function, revokes API-role execution on that implementation, and exposes a public wrapper requiring the canonical pharmacist role plus both permission bits. The candidate is still Draft and has no submitted PR reviews or inline review threads.

**Release implication:** the Production fix must be reviewed as a coherent Phase 61B/61C sequence, including the nested legacy RPC. Applying only the outer Phase 61C wrapper without the required inner boundary would leave an alternate authenticated entry point. No hosted migration was applied in this review.

### 3.4 Pharmacy quantity and prescription-integrity guards — critical, live DB confirmed

QA has Phase 57 and Phase 57B; Production does not. The Production invoice-linked dispense function still contains `COALESCE(pi.quantity, 1)` fallback behavior. QA's private implementation adds fail-closed checks for missing quantity, free-text medicine rows and external prescriptions.

The Production/QA difference is material: a green test of the QA function does not establish that Production is protected. These migrations require the documented reconciliation and a reviewed deployment sequence.

### 3.5 Direct stock-column mutation — high, live DB and source confirmed

Production has RLS enabled and forced on `public.medicines`, but the `authenticated` role still has UPDATE privilege on `medicines.stock_quantity`. The applicable row policy checks `app_has_perm('pharmacy.update')`; it does not narrow updates to catalogue identity fields.

The current main inventory screen does **not** implement the stock-receive action as a direct client-side increment:
- The medicine-create form inserts a catalogue row with `stock_quantity: 0`.
- The receive-batch workflow calls `fn_receive_pharmacy_batch_atomic`.
- The batch list is limited to 500 rows.
- The separate inventory statistics query reads medicine stock rows without explicit pagination, which is a potential scaling concern, not proof of a client-side stock write.

Therefore, Gemini's specific description of a direct `addStock` receive flow in the current inventory UI is not supported by the main source inspected. The underlying DB privilege risk is nevertheless confirmed. PR [#210](https://github.com/crauch2088-source/roshan-health-hub/pull/210) contains a Phase 60 candidate that revokes broad table UPDATE and grants only the intended medicine identity columns, while keeping stock changes in controlled RPCs. It is still Draft and is not applied to either hosted environment.

### 3.6 Currency provenance and receipts — split finding

Production has no `currency_code` columns on payments, invoices or cashbox transactions. QA has these columns from Phase 58/59. Production has not applied those migrations.

The older PR #181 review comments correctly identified a mutable-settings currency risk in an earlier version of the receipt implementation. However, the **current PR #181 patch has changed**: it uses fixed `ROSHAN_CURRENCY = "SDG"` behavior and the Phase 59 ledger-status RPC to establish currency provenance, and fails closed if provenance cannot be established. The old comments must not be repeated as if they describe the latest candidate unchanged.

PR [#181](https://github.com/crauch2088-source/roshan-health-hub/pull/181) remains Draft, has no SQL migration files in its current changed-file list, and is not merged. Its UI depends on the Phase 59 database contract; Production lacks the required currency columns/migration. Thus the candidate is not ready to promote to Production. A separate receipt table/sequence is not proven to be a defect solely because the PR does not add one: the current candidate derives a receipt from persisted payment and ledger records. Any requirement for a separate immutable receipt number should be explicitly specified and tested rather than assumed.

### 3.7 Prescription safety and prescriber authorization — confirmed with qualification

Current main source `src/features/clinic/consultation/components/PrescriptionTab.tsx` restricts the UI prescriber list to `doctor`, `legacy_gp`, `legacy_specialist` and `legacy_dentist`. The Production `create_prescription_atomic` function uses the same clinical-role allow-list. **The Gemini claim that Admin is accepted as a prescriber is contradicted for this prescription-creation path.**

The current UI retrieves visit-linked weight and displays a pediatric warning when weight is missing or cannot be verified. However, the save path validates prescription-field completeness and calls `create_prescription_atomic`; it does not make the presence of a current pediatric weight a hard save precondition. The warning is therefore advisory, not an enforced clinical stop. The UI also explicitly states that it does not calculate or auto-prescribe doses. This is safer than an unvalidated automatic dosing engine, but it does not replace clinician verification or an agreed pediatric workflow.

The current main file does not show Phase 63's alleged validator wired into the prescription save path. Do not claim Phase 63 clinical validation is integrated until a concrete validator call is demonstrated in both frontend and authoritative server-side RPC path, with regression tests. PR #179 remains Draft and non-mergeable; its pediatric warning is not equivalent to a hard stop.

### 3.8 Bootstrap helper — not a defect by itself

The public `setup_required()` wrapper is executable by `anon` and `authenticated` in both environments and returns a boolean by delegating to the private helper. The wrapper is an intentional bootstrap signal. Do not classify this public boolean-only wrapper as equivalent to the Phase 55 private-helper ACL exposure.

## 4. Pull request state at this review

Current GitHub metadata was fetched directly:

| PR | Current state | Draft | Mergeable | Reviews |
|---|---|---:|---:|---|
| [#250 Phase 61C role boundary](https://github.com/crauch2088-source/roshan-health-hub/pull/250) | Open | Yes | Yes | 0 submitted reviews; 0 inline threads |
| [#210 Phase 60 catalogue authority](https://github.com/crauch2088-source/roshan-health-hub/pull/210) | Open | Yes | Yes | 0 submitted reviews; 0 inline threads |
| [#181 payment receipts](https://github.com/crauch2088-source/roshan-health-hub/pull/181) | Open | Yes | Yes | Owner-authored historical comments only; no independent review |
| [#179 prescription printing](https://github.com/crauch2088-source/roshan-health-hub/pull/179) | Open | Yes | No | 0 submitted reviews; 0 inline threads |

The repository snapshot `docs/RELEASE_GATE_RECHECK_2026-11-15.md` on the PR #250 branch reports successful exact-head candidate workflows for PR #250 and #210, with intentional skips for canonical baseline/authenticated clinical acceptance. Those candidate test results do not mean the changes are merged or deployed. They also do not constitute an independent human security review.

## 5. Gemini findings reconciliation

| Gemini finding | Reconciliation |
|---|---|
| Production not ready for real clinical use | **Confirmed.** Multiple live Production ACL, role-boundary and migration gaps remain. |
| Phase 55 private helper EXECUTE exposure | **Confirmed.** Both helpers are effectively executable by API roles in Production; QA is owner-only. |
| Phase 57/57B quantity/free-text/external guards absent in Production | **Confirmed.** Production ledger and function definition support this. |
| Phase 61B/61C role boundary absent in Production | **Confirmed.** QA has 61B; Production has neither 61B nor 61C. |
| Admin can dispense through broad permissions | **Partially confirmed.** Production dispense SECURITY DEFINER functions rely on broad permission checks, not canonical pharmacist role checks. Actual exploitability for a specific Admin account depends on its live permission assignment and was not simulated. |
| Inventory receive UI still uses direct `addStock` | **Contradicted for the inspected current main route.** Receive uses an atomic RPC. However, direct authenticated stock-column UPDATE remains granted and RLS allows users with `pharmacy.update`; Phase 60 is still pending. |
| Prescription pediatric weight missing is only a warning | **Confirmed.** Current save path does not block on missing pediatric weight. |
| Admin is a permitted prescriber | **Contradicted for prescription creation.** Both main UI and Production RPC list clinical prescriber roles, not Admin. Other catalogue permissions are a separate concern. |
| Receipt currency still depends on mutable settings | **Stale for the current PR #181 patch.** Latest candidate uses fixed SDG and Phase 59 ledger provenance; Production lacks the required migrations, so the candidate remains unpromoted. |
| No persisted receipt table/sequence | **Not established as a defect.** Current candidate builds from persisted payment and ledger records; a separate receipt sequence must be a stated requirement before treating its absence as a blocker. |
| No idle session auto-lock, duplicate patient detection, default-gender issue | **Not independently verified in this pass.** Retain as audit follow-ups, not as confirmed findings. |
| Backup/restore not fully owner-verified | **Still an operational gate.** The repository's latest release-gate snapshot records an off-site encrypted PostgreSQL archive and prior isolated restore evidence, but owner-controlled decryption of the latest copy remains unverified; Storage bytes and Vault secrets are outside that backup scope. |
| Overall 23/100 score | **Not adopted.** It is a reviewer-specific score, not an independently reproduced measurement or project completion percentage. |

## 6. Ordered remediation gates

### P0 — must close before any real clinical or pharmacy data

1. Obtain an independent second-person SQL/security review of PR #250 and the Phase 61B dependency. Review SECURITY DEFINER ownership, fixed search_path, API-role ACLs, nested RPC reachability, canonical pharmacist role checks, branch isolation, idempotency, stock/invoice atomicity and audit effects.
2. Reconcile and prepare a safe Production migration sequence for Phase 57, Phase 57B, Phase 61B and Phase 61C. Do not apply until exact migration fingerprints, dependencies, rollback/forward-repair strategy and exact-head tests are reviewed.
3. Correct the Phase 55 Production private-helper ACLs narrowly, with dependency/call-site evidence and regression assertions. QA is the reference state for the intended owner-only ACL.
4. Remove broad authenticated UPDATE on medicine stock/catalogue and apply the reviewed Phase 60 column-level policy/RPC boundary. Confirm no required UI workflow depends on direct table UPDATE.
5. Reconcile Production/QA migration histories using `docs/DB_MIGRATION_RECONCILIATION.md`; never edit historical ledger rows to manufacture parity.

### P1 — clinical and financial integrity

6. Define and implement the pediatric prescription rule: missing/invalid current visit weight should block weight-based pediatric prescriptions, while any non-weight-based exception must be explicit and auditable. Enforce the authoritative rule server-side, not only with a frontend warning.
7. Verify all dispense entry points, including the legacy invoice-linked RPC, not just the newer atomic wrapper.
8. Promote Phase 58/59 currency provenance only after the matching receipt code and migration contract are reviewed and verified in QA; then gate Production rollout. Historical receipts must never be relabelled by mutable display settings.
9. Resolve PR #179's divergence/conflicts without rewriting published history; then perform mobile print-preview and physical printer acceptance.
10. Investigate the unpaginated inventory-statistics query and add bounded/aggregate server-side reporting if catalog size warrants it.

### P2 — operational acceptance

11. Run authenticated synthetic-role E2E on QA for receptionist, doctor, pharmacist, lab and finance workflows. Do not use Production for test transactions.
12. Complete owner-controlled decryption and isolated restore rehearsal of the latest encrypted backup; explicitly document that Storage object bytes and Vault secrets are not covered unless separately backed up.
13. Test idle session behavior, duplicate-patient detection and patient default-gender behavior against current code and authenticated runtime before classifying them as defects.
14. Complete on-site multi-role UAT and physical receipt/prescription printing before operational sign-off.

## 7. Guardrails for the next execution batch

- Keep all hosted diagnostics read-only until the owner explicitly approves a specific migration/release gate.
- Do not merge Draft PRs merely because CI is green. Require independent review for the security-sensitive database changes.
- Preserve the free Vercel build quota. Documentation-only changes must not trigger frontend builds or deployment promotion.
- Do not create real or synthetic clinical/financial business rows in Production.
- Maintain the distinction between Engineering Release Candidate completion and Operational Acceptance.
- Do not use a historical PR test result as proof that the current integrated main branch or deployed Production system has passed the same test.

## 8. Review outcome

This reconciliation materially narrows the Gemini report into confirmed database defects, corrected source-level claims, candidate fixes and unverified operational gates. It does **not** authorize Production changes and does not certify the application for clinical use.

**No Production/QA writes were made. No PR was merged. No deployment was promoted.**
