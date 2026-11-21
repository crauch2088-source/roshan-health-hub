# Window 08 — Round 04 Report

## 1. Identity and scope

- Window: 08 — Release & Branch Reconciliation Audit
- Original task / Issue / PR: PRs #179, #257, #258; Issues #199 and #253; release/backup/migration/branch-protection gates
- Round: 04
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current task branch / PR: `docs/parallel-release-reconciliation-window-08-round-04` / report PR to be opened
- Scope: Read-only revalidation and a new isolated report of material findings on current PR #258 and release gates.
- Explicit exclusions: No clinical implementation edits, no changes to another window's report, no MASTER_PLAN.md or AGENTS.md edits, no PR merges/closures, no branch settings, no hosted database writes/migrations, no backup dispatch, no deployment.

## 2. Executive verdict

- Status: **HOLD**
- What is actually complete: Rechecked PR #276 exact state and its workflow; rechecked PR #258 head, exact-head CI, reviews and changed SQL/test/print sources. Confirmed the report PR workflow passed.
- What remains incomplete: PR #258 still lacks independent review and authenticated clinical/device acceptance. The Phase 63 soft-delete immutability check omits the persisted patient-facing `instructions` field. The migration manifest still points to #255. Branch protection remains disabled and the latest backup attempt remains failed.
- Is this implementation, review-only work, or verification of existing mainline work? Review-only verification. No implementation change was appropriate within this window's assigned scope.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main branch](https://github.com/crauch2088-source/roshan-health-hub/tree/main) | verified |
| PR #276 | Open, not merged; head `51f51773d5867ae9059b3dc6c72fc321f4c65c4d`; draft=false; mergeable=true | [PR #276](https://github.com/crauch2088-source/roshan-health-hub/pull/276) | verified |
| PR #276 exact-head CI | Run `43857405000`, completed success; both CodeQL language analyses passed | [workflow run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43857405000) | verified |
| PR #258 | Open, Draft, not merged; head `ae677eac59ad291821ba93547190fba5cd2a794d`; 9 commits ahead / 0 behind per latest recorded comparison; mergeable=true | [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) | verified |
| PR #258 exact-head CI | Run `43855626804`, completed success; dedicated Phase 63 PG17 and required checks passed; canonical authenticated clinical acceptance was intentionally skipped | [workflow run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43855626804) | verified |
| PR #258 reviews | Only one COMMENTED review by repository owner; no independent approval | [reviews](https://github.com/crauch2088-source/roshan-health-hub/pulls/258) | verified |
| Phase 63 source | `db/roshan_phase63_prescription_item_completeness_guard.sql` at #258 head | [source](https://github.com/crauch2088-source/roshan-health-hub/blob/ae677eac59ad291821ba93547190fba5cd2a794d/db/roshan_phase63_prescription_item_completeness_guard.sql) | verified |
| Phase 63 manifest | Still identifies Draft PR #255 as candidate and says soft-deleted rows are skipped | [manifest](https://github.com/crauch2088-source/roshan-health-hub/blob/ae677eac59ad291821ba93547190fba5cd2a794d/db/MIGRATIONS_MANIFEST.md) | verified |
| Issue #199 | Open; no new owner acceptance evidence surfaced in the current recheck | [Issue #199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) | verified |
| Issue #253 / branch protection | Open; main branch API still reports `protected=false`, protection disabled, required contexts empty | [Issue #253](https://github.com/crauch2088-source/roshan-health-hub/issues/253) | verified |
| Backup runner | Latest attempt `43764265014` completed failure during credential preflight; no new backup artifact | [failed run](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014) | verified |

## 4. Work actually performed

- Re-read the continuation protocol and report template from the dedicated continuation branch.
- Rechecked main SHA, PR #276, report workflow #43857405000, PR #258, exact-head workflow #43855626804, PR #258 review records and inline comments, Issues #199/#253, and the latest backup-runner attempt.
- Read the exact Phase 63 trigger source, migration manifest, PostgreSQL 17 integration regression, print model and print-model tests at PR #258 head.
- Confirmed that the soft-delete regression tests cover changes to dose/dosage and other protected fields but do not include `instructions`.
- Confirmed that `src/lib/print/prescription.ts` persists `instructions` into the printable item model.
- Created this isolated Round 04 report branch/file. No application or database source was modified.

## 5. Findings

### F-01 — Soft-delete guard omits persisted prescription instructions

- Severity: **Medium**
- Status: **Verified**
- Affected file/function/SQL object: `db/roshan_phase63_prescription_item_completeness_guard.sql`, `private.validate_prescription_item_completeness()`
- Evidence and exact source/commit: PR #258 head `ae677eac59ad291821ba93547190fba5cd2a794d`. The active-to-soft-deleted comparison covers medication_name, dose, dosage, frequency, duration, quantity, dosage_form and route, but not `instructions`. The trigger's UPDATE OF list includes `deleted_at`, so an UPDATE that changes `instructions` and sets `deleted_at` invokes the trigger but passes its comparison.
- Reproduction or test: The PG17 fixture defines `instructions`; integration tests exercise a legacy already-deleted row's instructions update and active-row soft-delete mutations to dose/dosage. There is no regression asserting that an active row's `instructions` cannot be altered in the same UPDATE that sets `deleted_at`. The print model maps the persisted `instructions` field at `src/lib/print/prescription.ts` (line 80 in the inspected file).
- Impact: A soft-delete transition can rewrite patient-facing directions on the archived prescription record while the guard claims to preserve the clinical payload. This weakens historical prescription integrity; it is not evidence that the current active printable copy is altered after deletion, because deleted items are filtered from current print output.
- Recommended correction: Decide whether `instructions` is part of the immutable prescription payload. Given it is persisted and printed, include it in both OLD/NEW row comparisons and the trigger UPDATE OF list (or explicitly document a separate mutable/audited policy).
- Required regression test: On an active synthetic prescription row, attempt one UPDATE setting `deleted_at` and changing `instructions`; assert SQLSTATE 23514 and unchanged stored instructions. Retain tests proving ordinary soft delete succeeds and pre-existing soft-deleted rows preserve the intended legacy-update behavior.
- Dependency / owner: Window 01 / PR #258 implementer; independent SQL/clinical reviewer to verify the final policy.

### F-02 — Phase 63 manifest still points to superseded PR #255

- Severity: **Medium**
- Status: **Verified**
- Affected file/function/SQL object: `db/MIGRATIONS_MANIFEST.md`, Candidate Phase 63 section.
- Evidence and exact source/commit: At PR #258 head `ae677eac59ad291821ba93547190fba5cd2a794d`, the manifest says the source candidate is Draft PR #255, cites the #255 exact-head job, and describes soft-deleted rows as skipped. Current candidate is PR #258 and its active-to-soft-delete behavior has been changed and tested.
- Reproduction or test: Read the manifest's Candidate Phase 63 block (lines 323–329 in the inspected file) and compare with PR #258 description/current source.
- Impact: Reviewers and release operators can follow a stale candidate and obsolete behavior description when evaluating migration provenance and release readiness.
- Recommended correction: Update the manifest in the owning feature PR to identify #258, its exact source/test paths and exact-head PG17 evidence; describe current soft-delete semantics accurately. Keep hosted status explicitly candidate-only/not applied.
- Required regression test: Add a documentation/source parity assertion if the repository has an appropriate manifest contract test; otherwise require exact-head manifest review in PR checklist.
- Dependency / owner: Window 01 / PR #258 implementer.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result: PASS / FAIL / SKIP / NOT RUN / BLOCKED | Notes |
|---|---|---|---|
| Round 03 report PR workflow | `43857405000` | PASS | Both CodeQL analyses succeeded on PR #276 head. |
| PR #258 exact-head CI | `43855626804` | PASS | Workflow completed success on exact head. |
| Phase 63 PostgreSQL 17 integration | Job `133259022872` within run `43855626804` | PASS | Existing test suite passes; it does not test active-row instructions mutation during soft delete. |
| Canonical baseline/authenticated clinical acceptance | Job `133259024492` within run `43855626804` | SKIP | Intentionally skipped; not clinical acceptance. |
| PR #258 independent review | GitHub reviews API | NOT RUN / absent | Only owner COMMENTED review exists. |
| QA pharmacist, physical printer, staff UAT | Issue #199 | BLOCKED | No new authenticated or human acceptance evidence. |
| Backup credential preflight | Run `43764265014` | FAIL | No new artifact produced. |
| Live main branch protection | GET `/branches/main` | FAIL / disabled | `protected=false`; no required contexts. |

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `docs/parallel-reports/round-04/window-08.md` | New isolated audit delta report | To be supplied after commit |

- Branch: `docs/parallel-release-reconciliation-window-08-round-04`
- Commit(s): To be supplied after commit
- PR: To be supplied after opening
- Report file path: `docs/parallel-reports/round-04/window-08.md`
- Report commit SHA: To be supplied after commit
- Was the report committed with the implementation or through a separate docs-only PR? Separate docs-only PR, because this window is review-only.
- No implementation patch was appropriate: the defect belongs to PR #258's feature owner/window; this window's mandate is reconciliation/review, and editing another window's candidate would violate strict window ownership.

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No**
- Secret or credential changes: **No**
- PR merge / issue closure / release approval: **No**
- Branch protection/ruleset changes: **No**
- Backup workflow dispatch: **No**

## 9. Risks, dependencies, and owner decisions

1. PR #258 must remain Draft until F-01/F-02 are corrected, exact-head CI is rerun, and independent review is obtained.
2. Clinical acceptance remains distinct from CI: authenticated QA pharmacist acceptance, Android/A4/thermal printer checks, and reception-to-billing staff UAT remain unproven.
3. Backup recovery evidence for the earlier artifact does not cure the latest failed preflight; owner-controlled credential setup and an explicitly approved fresh run are still required.
4. Live migration ledger reconciliation remains a release blocker; do not replay or repair migration history blindly.
5. Main branch protection remains disabled; do not enable a partial required-check configuration before an always-running aggregate gate is proven.
6. PR #179 and #257 remain historical/superseded candidates; do not close them until the replacement candidate is accepted and the owner authorizes closure.

## 10. Next action

Window 01 / PR #258 owner: add the missing `instructions` immutability assertion and regression, update the Phase 63 manifest from #255 to #258, then rerun exact-head PostgreSQL 17 and repository CI and request independent clinical/security review. Window 08 will recheck release/branch reconciliation only after a material state change.

## 11. Session closeout

- Work completed in this session: Revalidated PR #276 report CI and PR #258 exact-head state; confirmed F-01 and F-02 directly from current source, tests, print model and manifest; refreshed branch-protection and backup failure evidence.
- Work not completed: No feature implementation, independent review, authenticated QA acceptance, physical printer test, staff UAT, fresh backup, migration reconciliation or branch protection configuration.
- Exact current state at close: main `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`; PR #258 head `ae677eac59ad291821ba93547190fba5cd2a794d`, Open/Draft; PR #276 Open/not merged with successful report CI; production release remains **NO-GO**.
- Recommended continuation when the owner says **"أكمل"**: Recheck the current PR #258 head and confirm whether F-01/F-02 were fixed and independently reviewed. Do not create another report unless material evidence changes.
