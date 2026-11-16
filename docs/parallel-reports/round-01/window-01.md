# Window 01 — Round 01 Report

## 1. Identity and scope

- Window: 01 — prescription completeness, safety and printing
- Original task / Issue / PR: Phase 63 prescription item completeness guard and prescription print workflow; Draft PR #258 (successor to stale #179).
- Round: 01
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current task branch / PR: `feat/phase53-prescription-print-rebased-20261116` / [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258)
- Scope: server-side completeness validation, soft-delete behavior, regression tests, print-path review.
- Explicit exclusions: no clinical dose selection or automated dosing; no hosted migration, QA/Production deployment, physical printer acceptance, or staff UAT.

## 2. Executive verdict

- Status: **CHANGES REQUIRED**
- What is actually complete: The initial soft-delete bypass was reproduced with a PostgreSQL 17 regression test. A candidate SQL correction now rejects clinical-field mutation in the same UPDATE that soft-deletes an active prescription item, while allowing an unchanged active item to be archived and preserving already-soft-deleted historical rows.
- What remains incomplete: Exact-head CI after the correction is pending at report time; independent clinical/security review, authenticated QA acceptance, and physical printing remain open.
- Work type: implementation and regression verification on a Draft PR branch; not merged or deployed.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main](https://github.com/crauch2088-source/roshan-health-hub/commits/main) | verified |
| Task branch/head SHA | `3da44e6e7d1759467eaf5f59ad1fd920fcd8ba58` | [branch commit](https://github.com/crauch2088-source/roshan-health-hub/commit/3da44e6e7d1759467eaf5f59ad1fd920fcd8ba58) | verified |
| PR state | #258 open, Draft; base is current main | [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) | verified |
| RED regression run | CI run #43853551408, Phase 63 job #133251967715 failed before SQL fix | [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853551408) | verified |
| Post-fix exact-head CI | Commit `3da44e6`; run was not yet visible at report capture | [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) | not rechecked |
| Hosted migration state | No QA/Production migration performed in this session | N/A | verified |

## 4. Work actually performed

1. Rechecked current main and open PR state; confirmed #258 still targets the current main SHA.
2. Re-read `db/roshan_phase63_prescription_item_completeness_guard.sql` and its PostgreSQL 17 fixture/integration test.
3. Added a RED test to `db/tests/phase63_prescription_item_completeness_integration.sql`:
   - attempts to set `deleted_at` while blanking `dose` and `dosage`;
   - requires SQLSTATE class check violation;
   - verifies the active row's complete clinical payload and `deleted_at IS NULL` remain unchanged;
   - separately verifies soft deletion with no clinical mutation remains allowed.
4. Confirmed the RED test failed in the dedicated Phase 63 PostgreSQL 17 job on commit `654126d09a53712504a28fb751374dc95ff60ceb`.
5. Updated the trigger in `db/roshan_phase63_prescription_item_completeness_guard.sql` to compare the clinical fields on an active-to-deleted UPDATE and reject any simultaneous clinical-field change. Historical deleted rows and inserts already marked deleted retain the existing preservation behavior.
6. Updated the trigger comment and committed the change as `3da44e6e7d1759467eaf5f59ad1fd920fcd8ba58`.
7. Added this isolated report to the same PR branch.

## 5. Findings

### F-01 — Active prescription clinical fields could be mutated during soft deletion

- Severity: **High**
- Status: **Verified on candidate branch; correction awaiting exact-head CI**
- Affected file/function/SQL object: `db/roshan_phase63_prescription_item_completeness_guard.sql`, `private.validate_prescription_item_completeness()`
- Evidence and exact source/commit: Original guard returned early for every `NEW.deleted_at IS NOT NULL`; regression test commit `654126d09a53712504a28fb751374dc95ff60ceb`.
- Reproduction or test: PostgreSQL 17 Phase 63 job #133251967715 failed on the regression before the fix, proving the guard accepted an active-row UPDATE that set `deleted_at` and blanked both dose fields.
- Impact: The archived prescription record could lose or alter the originally prescribed clinical details in the same write that removes it from active views.
- Recommended correction: Reject clinical-field changes in the same UPDATE that transitions an active row to soft-deleted; allow archival without clinical mutation; retain historical deleted-row compatibility.
- Required regression test: The new integration case asserts rejection and exact persisted payload preservation, then checks allowed unchanged soft deletion.
- Dependency / owner: Window 01 / PR #258; independent reviewer to verify exact-head CI and migration semantics.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result | Notes |
|---|---|---|---|
| Phase 63 PostgreSQL 17 RED reproduction | CI run #43853551408, job #133251967715 | **FAIL — expected RED** | Fails before trigger correction; confirms regression test catches the bypass. |
| Phase 63 PostgreSQL 17 after fix | Expected from commit `3da44e6e7d1759467eaf5f59ad1fd920fcd8ba58` | **NOT RUN / not yet visible** | Must verify the exact post-fix head; do not infer success. |
| Full exact-head CI | PR #258 head `3da44e6e7d1759467eaf5f59ad1fd920fcd8ba58` | **NOT RUN / pending** | Other workflows are not a substitute for the dedicated Phase 63 job. |
| Physical Android/A4/thermal print acceptance | Not performed | **NOT RUN** | Operational gate. |

Never count the intentional canonical-baseline/authenticated clinical acceptance skip as a pass.

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `db/tests/phase63_prescription_item_completeness_integration.sql` | RED regression for soft-delete plus clinical mutation; preserved-payload and allowed-archive assertions | `654126d09a53712504a28fb751374dc95ff60ceb` |
| `db/roshan_phase63_prescription_item_completeness_guard.sql` | Reject clinical field changes during active-to-deleted transition | `3da44e6e7d1759467eaf5f59ad1fd920fcd8ba58` |
| `docs/parallel-reports/round-01/window-01.md` | This isolated report | Pending commit below |

- Branch: `feat/phase53-prescription-print-rebased-20261116`
- Commits: `654126d09a53712504a28fb751374dc95ff60ceb`, `3da44e6e7d1759467eaf5f59ad1fd920fcd8ba58`
- PR: [#258](https://github.com/crauch2088-source/roshan-health-hub/pull/258)
- Report file path: `docs/parallel-reports/round-01/window-01.md`
- Report commit SHA: to be verified after report creation.
- Report is committed with the implementation PR.

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No; synthetic disposable PostgreSQL fixtures only**
- Secret or credential changes: **No**
- PR merge / issue closure / release approval: **No**

## 9. Risks, dependencies, and owner decisions

- Exact-head CI must pass on the final code commit; the RED run is not a passing result.
- Phase 63 remains a source candidate only. Do not apply it to QA/Production until independent review and migration-chain reconciliation.
- Clinical completeness validation is not clinical appropriateness validation and does not determine a dose.
- Authenticated mobile browser, Arabic RTL/English LTR, A4 and thermal printer checks remain operational acceptance gates.
- The broader PR #258 print workflow still needs independent review beyond this focused trigger correction.

## 10. Next action

Window 01 / coordinator: verify the dedicated Phase 63 PostgreSQL 17 job and all required exact-head CI checks on the latest PR #258 commit; if any fail, diagnose and fix before requesting independent review.

## 11. Session closeout

- Work completed in this session: reproduced the soft-delete bypass; implemented a narrowly scoped trigger correction; added preserved-payload and valid-archive assertions; prepared the isolated report.
- Work not completed: exact-head post-fix CI confirmation, independent review, hosted migration, physical print and staff acceptance.
- Exact current state at close: PR #258 remains Draft and unmerged; code is source-only.
- Recommended continuation when the owner says **"أكمل"**: check the live PR head and exact Phase 63 job first; do not repeat the RED reproduction if the fix has already passed.
