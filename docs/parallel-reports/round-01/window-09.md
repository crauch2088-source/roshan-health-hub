# Window 09 — Round 01 Report

## 1. Identity and scope

- Window: **09 — Pharmacist-to-prescriber correction workflow**
- Original task / Issue / PR: Issue [#217](https://github.com/crauch2088-source/roshan-health-hub/issues/217)
- Round: 01
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current task branch / PR: `feat/217-pharmacist-correction-backend-20261116` / Draft PR pending
- Scope: strengthen PostgreSQL 17 negative assertions for stock/financial side effects and prove Phase 57/57B dispensing blockers remain independent
- Explicit exclusions: no correction RPC redesign, no dispensing/billing behavior change, no shared workflow/package/manifest/MASTER_PLAN/AGENTS changes, no hosted migrations, no QA/Production writes, no edits to other windows' reports

## 2. Executive verdict

- Status: **PASS WITH FINDINGS**
- What is actually complete: Phase 61 correction backend already exists on the requested main baseline. This change strengthens its dedicated PostgreSQL 17 integration suite with full-row value snapshots and explicit Phase 57/57B guard tests.
- What remains incomplete: exact-head PostgreSQL 17 CI must run; this report does not claim a test pass before that run.
- Work type: verification and test-hardening of existing mainline behavior; no duplicate backend implementation.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main commit](https://github.com/crauch2088-source/roshan-health-hub/commit/79d81f08f6567f5145f7143e3bf5afdd6e93bf59) | verified |
| Phase 61 SQL | blob `a9bfec947bfb7f3355fbd60807d9e34131071261` | [source](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase61_prescription_item_correction_workflow.sql) | verified |
| Phase 61B SQL | blob `0d560f67aefc090630fa08da82a66d74bda114d6` | [source](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase61b_clinical_role_boundary.sql) | verified |
| Phase 57 SQL | blob `9db6768999352c32081f69b5e665c3cc95452616` | [source](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase57_pharmacy_quantity_required_guard.sql) | verified |
| Phase 57B SQL | blob `57516e08de8e314f687c21f2f292199d3adff178` | [source](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/db/roshan_phase57b_free_text_external_prescription_guard.sql) | verified |
| Issue #217 | Open | [Issue](https://github.com/crauch2088-source/roshan-health-hub/issues/217) | verified |
| PR #249 | Closed, merged; merge commit `a9040601702972bdf144fc96b9658eebd5a6d31a` is an ancestor of requested main SHA | [PR #249](https://github.com/crauch2088-source/roshan-health-hub/pull/249) | verified |
| Dedicated PG17 workflow | `ci-phase61-prescription-correction.yml` | [workflow](https://github.com/crauch2088-source/roshan-health-hub/blob/79d81f08f6567f5145f7143e3bf5afdd6e93bf59/.github/workflows/ci-phase61-prescription-correction.yml) | verified |
| Exact-head CI for this change | Pending | This PR | not run |

## 4. Work actually performed

- Re-read the Round 01 continuation protocol and report template from `docs/parallel-engineering-continuation-20261116`.
- Rechecked main SHA, Issue #217, merged PR #249, Phase 61/61B SQL, Phase 57/57B guards, fixture, integration tests and dedicated PostgreSQL 17 workflow.
- Confirmed the old integration test captured only row counts for stock/financial tables and omitted the medicine catalogue's persisted stock values.
- Confirmed the original dedicated Phase 61 PG17 workflow did not replay Phase 57 or Phase 57B. Therefore it could not behaviorally prove that the quantity, external-prescription and free-text dispensing blockers remained active in that integration environment.
- Added synthetic pre-existing sentinel rows for pharmacy inventory, stock movement, invoice, invoice item, payment and cashbox transaction.
- Replaced count-only assertions with full-row JSONB snapshots across `medicines`, `pharmacy_inventory`, `stock_movements`, `invoices`, `invoice_items`, `payments`, and `cashbox_transactions`.
- Added no-side-effect checkpoints after correction request/blocked dispense, accepted replacement, rejection and cancel-and-reissue.
- Updated only the dedicated Phase 61 PG17 workflow to replay Phase 57 and Phase 57B before Phase 61/61B, and to trigger when either guard SQL changes.
- Added behavioral assertions for Phase 57 NULL quantity, Phase 57B external prescription denial, and the remaining free-text item after partial correction.
- No application RPC or migration file was changed; no hosted environment was touched.

## 5. Findings

### F-09-01 — Count-only negative assertions could miss mutations to existing rows

- Severity: **Medium**
- Status: **Verified**
- Affected file/function/SQL object: `db/tests/phase61_prescription_correction_integration.sql`, prior `phase61_side_effect_baseline`
- Evidence: the previous baseline stored only `count(*)` for inventory, stock movements, invoices, invoice items, payments and cashbox transactions, and did not snapshot `medicines`.
- Reproduction or test: an UPDATE to a pre-existing row leaves its table count unchanged, so the old assertion could pass despite changed stock or ledger values.
- Impact: tests did not prove that existing stock and financial values remained unchanged.
- Recommended correction: full-row JSONB snapshots and pre-existing synthetic sentinels; implemented in this candidate.
- Required regression test: exact-head PostgreSQL 17 workflow.
- Dependency / owner: Window 09.

### F-09-02 — Dedicated Phase 61 PG17 workflow omitted Phase 57/57B replay

- Severity: **Medium**
- Status: **Verified**
- Affected file/function/SQL object: `.github/workflows/ci-phase61-prescription-correction.yml`
- Evidence: prior workflow replayed canonical baseline, Phase 36, Phase 46, Phase 61 and Phase 61B only. Baseline v112 does not contain the Phase 57 quantity or Phase 57B external/free-text guards.
- Reproduction or test: inspection of baseline and migration source confirmed the guards were absent from the previous test replay sequence.
- Impact: the Phase 61 PG17 suite did not prove that correction resolution could not bypass the existing fail-closed dispense guards.
- Recommended correction: replay Phase 57 and 57B before Phase 61/61B and assert NULL-quantity, external and free-text dispense denial; implemented in this candidate.
- Required regression test: exact-head PostgreSQL 17 workflow.
- Dependency / owner: Window 09; dedicated test workflow only.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result | Notes |
|---|---|---|---|
| Source/fixture/workflow inspection | GitHub read-only inspection at `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | PASS | Source contracts and prior workflow sequence verified |
| PostgreSQL 17 integration | `ci-phase61-prescription-correction.yml` on this PR head | NOT RUN | Must run after Draft PR creation |
| Hosted QA/Production | None | NOT RUN | Explicitly out of scope |

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `db/tests/phase61_prescription_correction_integration.sql` | Full-row snapshots, sentinel rows, phase57/57B negative assertions and disposition checkpoints | Pending |
| `.github/workflows/ci-phase61-prescription-correction.yml` | Replay Phase 57/57B before Phase 61/61B in disposable PG17; path-filter additions | Pending |
| `docs/parallel-reports/round-01/window-09.md` | Isolated Window 09 report | Pending |

- Branch: `feat/217-pharmacist-correction-backend-20261116`
- Commit(s): pending
- PR: pending Draft PR creation
- Report file path: `docs/parallel-reports/round-01/window-09.md`
- Report commit SHA: pending
- Report delivery: same task branch/PR

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No** — synthetic fixtures only
- Secret or credential changes: **No**
- PR merge / issue closure / release approval: **No**

## 9. Risks, dependencies, and owner decisions

- The new synthetic seed rows and full-row snapshots require exact PostgreSQL 17 CI to validate constraints, RLS bypass under the disposable test owner, and trigger interactions.
- The Phase 57/57B replay order is intentional: both dispense guards are installed before Phase 61B moves the invoice-linked dispense body behind its private role-checked wrapper.
- This is test-harness evidence, not authenticated browser/staff acceptance.
- Issue #217 remains open pending its separate UAT/release conditions.

## 10. Next action

Open the Draft PR and inspect the exact-head PostgreSQL 17 workflow result; correct only demonstrated fixture/assertion failures and rerun the focused workflow if necessary.

## 11. Session closeout

- Work completed in this session: continuation protocol adopted; source/history reconciled; test-hardening changes and isolated report prepared.
- Work not completed: exact-head PostgreSQL 17 execution and PR creation.
- Exact current state at close: feature branch exists from `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`; no commit has yet been pushed.
- Recommended continuation when the owner says **"أكمل"**: re-fetch the branch head and PR/CI state, then address only the first outstanding CI or review finding.
