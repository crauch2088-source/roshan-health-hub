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

- Status: **HOLD — focused code correction verified; full clinical/operational acceptance remains open**
- What is actually complete: The initial soft-delete bypass was reproduced with a PostgreSQL 17 regression test. A candidate SQL correction now rejects clinical-field mutation in the same UPDATE that soft-deletes an active prescription item, while allowing an unchanged active item to be archived and preserving already-soft-deleted historical rows.
- What remains incomplete: independent clinical/security approval, authenticated QA role/branch acceptance, Arabic RTL/English LTR browser checks, Android/A4/thermal printer acceptance, and staff UAT remain open.
- Work type: implementation and regression verification on a Draft PR branch; not merged or deployed.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main](https://github.com/crauch2088-source/roshan-health-hub/commits/main) | verified |
| Implementation head SHA | `8312c92273d50d6eb9d8e700a2eebf89192bcf68` | [code commit](https://github.com/crauch2088-source/roshan-health-hub/commit/8312c92273d50d6eb9d8e700a2eebf89192bcf68) | verified |
| PR state | #258 open, Draft; base is current main | [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) | verified |
| RED regression run | CI run #43853551408, Phase 63 job #133251967715 failed before SQL fix | [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853551408) | verified |
| Post-fix exact-head CI | Commit `8312c922`; CI run #43853928921 and Phase63 PG17 job #133253285611 passed; other required jobs in that run passed | [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853928921) | verified |
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

- Severity: **High (original defect); resolved in candidate branch**
- Status: **Corrected and verified by exact-head PostgreSQL 17 CI**
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
| Phase 63 PostgreSQL 17 after fix | Commit `8312c922`; run #43853928921, job #133253285611 | **PASS** | Exact implementation head; regression and guard passed. |
| Full exact-head CI | Commit `8312c922`; run #43853928921 | **PASS for returned required jobs** | Includes typecheck/lint/build, security and PG integration workflows. Canonical baseline/authenticated clinical acceptance job #133253287590 was intentionally skipped; it is not a pass. |
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

Window 01 / coordinator: obtain independent clinical/security review and complete authenticated QA, branch-isolation, mobile, bilingual and physical printer acceptance. Keep PR #258 Draft until these gates are satisfied.

## 11. Session closeout

- Work completed in this session: reproduced the soft-delete bypass; implemented a narrowly scoped trigger correction; added preserved-payload and valid-archive assertions; prepared the isolated report.
- Work not completed: exact-head post-fix CI confirmation, independent review, hosted migration, physical print and staff acceptance.
- Exact current state at close: PR #258 remains Draft and unmerged; code is source-only.
- Recommended continuation when the owner says **"أكمل"**: check the live PR head and exact Phase 63 job first; do not repeat the RED reproduction if the fix has already passed.


---

## Independent review continuation — 2026-11-16 (Window 01)

### Recheck against current PR head

- Rechecked PR #258 after the earlier review. It remains **OPEN / DRAFT**, based on main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`, with current head `8312c92273d50d6eb9d8e700a2eebf89192bcf68`.
- The previously reported active-to-soft-deleted clinical mutation gap is **corrected in the current candidate source**. The trigger compares the protected clinical payload between OLD and NEW on the active-to-deleted transition and raises SQLSTATE `23514` if any protected field changes.
- The PostgreSQL 17 integration test now checks rejection of a combined `deleted_at` + blank `dose`/`dosage` update, verifies the original active payload remains unchanged, allows a normal soft delete without clinical mutation, and preserves an already-soft-deleted incomplete historical row.
- Review comment `4584207030` / review submission `5918007011` remains present as an **unresolved, non-outdated review thread** at the time of recheck. The code correction is present, but the thread has not been formally resolved.

### Exact-head CI evidence

- Commit: `8312c92273d50d6eb9d8e700a2eebf89192bcf68`.
- Workflow runs returned for the exact commit: CI run [#43853928921](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853928921), prescription atomicity [#43853929194](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853929194), finance RPC-only writes [#43853929314](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853929314), Phase 48 Storage [#43853929036](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853929036), privileged role guard [#43853929124](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853929124), clinical child RPC writes [#43853929250](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853929250), insurance claim integrity [#43853929248](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853929248), and insurance UI validation [#43853928979](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43853928979). All returned runs completed successfully.
- Within CI run #43853928921, the dedicated **Phase 63 prescription item completeness guard (PostgreSQL 17)** job `133253285611` passed. The same run's typecheck, lint, dependency audits, build, and listed PostgreSQL integration jobs passed.
- The **Canonical PG17 baseline replay and authenticated clinical acceptance** job `133253287590` was intentionally **SKIPPED**. It is not a pass and does not establish authenticated clinical acceptance.
- These results supersede the earlier report statement that post-fix exact-head CI was pending.

### Updated review verdict

- **The prior High-severity soft-delete finding is corrected in the current PR head and its dedicated PostgreSQL 17 regression is green.**
- No new P0/P1 defect was established by this focused re-review.
- **Medium / owner decision:** the print model carries the patient's MRN but does not require it for a complete official print copy; patient full name is required. Whether MRN or another stable secondary identifier is mandatory must be decided by the clinic's document/identity policy, not inferred by this reviewer. This is not treated as a merge blocker absent that policy.
- The PR remains Draft. CI does not replace independent clinical/security approval, authenticated role/branch QA, Arabic RTL and mobile browser acceptance, or physical A4/thermal printer verification.
- **Recommendation: HOLD / keep Draft pending formal review-thread disposition, independent clinical/security approval, and operational acceptance.** The specific soft-delete correction itself is verified at source and in the exact-head PostgreSQL 17 job.

### Actions in this re-review

- Read-only GitHub/source/CI inspection only.
- No application source, SQL, migration, QA/Production database, deployment, merge, issue closure, or credential changes were made by this re-review.
- This addendum updates the existing Window 01 Round 01 report; it does not replace another window's report or a prior round.


### Evidence correction — 2026-11-16

- Latest code-bearing head: `8312c92273d50d6eb9d8e700a2eebf89192bcf68`.
- Report-only branch commit observed after the code head: `2e4a8d30d9fc67c596300ac6aa27c6a83a35263b`.
- CI run #43853928921 completed successfully. The dedicated Phase 63 PostgreSQL 17 job `133253285611` passed. The canonical baseline/authenticated clinical acceptance job `133253287590` was intentionally skipped and is not counted as acceptance.
- The prior inline review thread for F-01 (`4584207030`) was resolved after verifying the exact-head correction and regression.
- PR #258 remains open and Draft; no merge, deployment, QA/Production migration, or physical print acceptance occurred.
