# Window 08 — Round 03 Delta Report

> Focused continuation after Round 02. This report records only material state changes and revalidated blockers; it does not approve merge, release, closure, hosted migration, backup dispatch, or branch-protection changes.

## 1. Identity and scope

- Window: **08 — Release & Branch Reconciliation**
- Round: **03**
- Main baseline rechecked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Previous report: [Round 02 PR #275](https://github.com/crauch2088-source/roshan-health-hub/pull/275)
- Scope: verify PR #275 CI completion; recheck PR #258 after its subsequent commits; inspect current Phase 63 source/manifest/review state; determine whether any release gate has changed.
- Exclusions: no changes to PR #258/#179/#257, Issues #199/#253, `MASTER_PLAN.md`, `AGENTS.md`, or other window reports; no merges/closures; no Production/QA writes, migrations, backup dispatch, secret changes, branch settings, or deployments.

## 2. Executive verdict

- Status: **PASS WITH FINDINGS**
- New progress: Round 02 report PR #275 completed its PR workflow successfully and remains open/unmerged.
- PR #258 advanced from the Round 02 recorded head `8312c922...` to `ae677eac59ad291821ba93547190fba5cd2a794d`. It is now nine commits ahead / zero behind main. Its latest exact-head check-run set includes successful CodeQL, Vercel Preview, install/audit/typecheck/lint/build, migration source parity, PostgreSQL 17 integration and the dedicated Phase 63 PostgreSQL 17 job.
- The canonical baseline replay/authenticated clinical acceptance job is still intentionally skipped; do not count it as clinical acceptance.
- No independent PR #258 approval has appeared. The only submitted review remains owner-authored COMMENTED; the Phase 63 inline comment remains in the API response.
- The two Round 02 source findings remain open:
  1. The Phase 63 soft-delete immutability comparison still omits `instructions`.
  2. The migration manifest still says Phase 63 is a source candidate in Draft PR #255, although current candidate is #258.
- Backup, human acceptance, migration provenance and branch protection have not been cleared.
- Release verdict: **Production NO-GO**.

## 3. Live state and evidence

| Item | Current verified state | Evidence |
|---|---|---|
| Main | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main](https://github.com/crauch2088-source/roshan-health-hub/tree/main) |
| Round 02 report PR #275 | Open, not merged, mergeable; head `ae8d78598283ebcb9b97906453abd8393640f32a`; one file | [PR #275](https://github.com/crauch2088-source/roshan-health-hub/pull/275) |
| PR #275 workflow | Run `43854765345` completed successfully | [Run #43854765345](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43854765345) |
| PR #258 | Open, Draft, mergeable; head `ae677eac59ad291821ba93547190fba5cd2a794d`; nine ahead / zero behind | [PR #258](https://github.com/crauch2088-source/roshan-health-hub/pull/258) |
| PR #258 CI | Exact-head run `43855626804`: application checks, migration source parity and Phase 63 PG17 succeeded; canonical baseline/authenticated acceptance intentionally skipped | [Run #43855626804](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43855626804) |
| PR #258 review | One owner-authored COMMENTED review; no independent approval; inline discussion #4584207030 still returned | [Inline discussion](https://github.com/crauch2088-source/roshan-health-hub/pull/258#discussion_r4584207030) |
| Phase 63 guard | Active→soft-delete rejects changes to medication name, dose/dosage, frequency, duration, quantity, dosage form and route; does not compare `instructions` | [SQL source](https://github.com/crauch2088-source/roshan-health-hub/blob/ae677eac59ad291821ba93547190fba5cd2a794d/db/roshan_phase63_prescription_item_completeness_guard.sql) |
| Phase 63 manifest | Still identifies Draft PR #255 as source candidate | [Manifest](https://github.com/crauch2088-source/roshan-health-hub/blob/ae677eac59ad291821ba93547190fba5cd2a794d/db/MIGRATIONS_MANIFEST.md) |
| Main protection | `protected=false`; enforcement off; no required contexts | [Branch API](https://api.github.com/repos/crauch2088-source/roshan-health-hub/branches/main) |
| Backup | Latest run #43764265014 failed credential preflight; latest full success remains #43183851731 on older runner SHA | [Failed run](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014) · [Prior success](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) |

## 4. Findings carried forward / delta

### F-01 — Soft-delete guard still omits `instructions`

- Severity: **Medium**
- Status: **Open; rechecked on latest head**
- The trigger's active-to-deleted row comparison includes eight fields but not `instructions`. The column exists on `public.prescription_items` and is present in the persisted prescription/print model.
- Risk: an UPDATE can archive an active row and change patient-facing instructions in the same statement while satisfying the trigger's current immutability comparison.
- Required decision: either include `instructions` in both OLD/NEW row comparisons and add a PG17 regression, or explicitly define why instructions are mutable at archive time and preserve the old value in an immutable audit record.
- No source change was made in this review-only window.

### F-02 — Phase 63 source manifest remains stale

- Severity: **Low**
- Status: **Open; rechecked on latest head**
- `db/MIGRATIONS_MANIFEST.md` continues to say source candidate Draft PR #255, and its text describes the older skip-soft-deleted behavior. That is inconsistent with the current #258 candidate and its active-to-deleted guard.
- Required correction: update the manifest to identify #258 and describe the actual current trigger semantics; retain #255 only as historical provenance if needed.

### F-03 — Automated checks are green; independent review is not

- Severity: **High**
- Status: **Open**
- Latest #258 exact-head check run reports successful CodeQL, Vercel Preview, install/audit/typecheck/lint/build, migration parity, PG17 integration and Phase 63 PG17 checks.
- Canonical baseline replay/authenticated clinical acceptance is intentionally skipped. This remains a gap, not a pass.
- Reviews API still shows only the owner's COMMENTED review; no independent approval. The inline review discussion #4584207030 remains.
- Required action: independent second-person clinical/security review of the full candidate and explicit disposition of both F-01 and F-02.

### F-04 — Round 02 documentation CI completed

- Severity: **Informational**
- Status: **Verified**
- PR #275's workflow run #43854765345 completed successfully. PR #275 remains open and unmerged, preserving the independent report branch and audit trail.

### F-05 — Other release blockers unchanged

- Backup: latest attempt still failed before dump because database credentials were unavailable; no new artifact. The prior successful artifact's owner-side decrypt/integrity verification is not established.
- Hosted migration history: Production/QA ledgers remain non-linear with three shared version IDs having different names; no forward-only reconciliation evidence was added.
- Clinical acceptance: no authenticated QA pharmacist acceptance, physical A4/thermal printing acceptance, or staff end-to-end UAT evidence.
- Governance: main remains unprotected with no required contexts or rulesets.
- PR #179 remains divergent and non-authoritative; PR #257 remains a historical snapshot. Neither is a merge candidate.

## 5. Tests and validation

| Validation | Result | Notes |
|---|---|---|
| PR #275 workflow #43854765345 | **PASS** | Report-only PR workflow completed successfully |
| PR #258 latest exact-head check set, run #43855626804 | **PASS with intentional SKIP** | Dedicated Phase 63 PG17 job passed; canonical baseline/authenticated acceptance skipped |
| PR #258 review state | **BLOCKED** | No independent approval |
| Phase 63 instructions immutability | **NOT TESTED / FINDING OPEN** | Trigger comparison omits instructions |
| Backup latest run #43764265014 | **FAIL / BLOCKED** | Credential preflight; no dump/artifact |
| QA pharmacist, physical print, staff UAT | **NOT RUN** | Requires owner-authorized human acceptance |
| Production/QA writes | **NOT RUN** | Read-only scope |

## 6. Actions not performed

- No PR or issue merged/closed.
- No edits to PR #258 implementation or its review thread.
- No changes to `MASTER_PLAN.md`, `AGENTS.md`, continuation protocol or another window report.
- No Production/QA writes, migrations, ACL/RLS changes or deployments.
- No backup workflow dispatch, secret handling or branch-protection/ruleset changes.
- No use of real patient data.

## 7. Next action

The next meaningful action is for the PR #258 owner to resolve F-01 and F-02 in the feature branch, then request an independent reviewer. This Window 08 review-only task must not modify that feature branch. Re-run only the affected exact-head checks after code changes; preserve the current successful run as evidence for the current head, not a future changed head.

## 8. Closeout

- Round 03 is a focused delta report, not a new release approval.
- Main remains `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`.
- PR #258 is now at `ae677eac59ad291821ba93547190fba5cd2a794d`, nine ahead / zero behind, Draft/open; checks are green except the intentionally skipped clinical-acceptance job; independent review is still absent.
- PR #275's workflow succeeded; PR #275 remains open/unmerged.
- Production remains **NO-GO**.
