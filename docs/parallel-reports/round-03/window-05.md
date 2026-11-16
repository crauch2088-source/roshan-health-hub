# Roshan Parallel Engineering — Window 05
## Round 03: CI Workflow Routing Remediation

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Target:** [PR #256](https://github.com/crauch2088-source/roshan-health-hub/pull/256)
- **Updated PR head:** `067c2afd15126e633d28dd345e3d5e75c42d43d5`
- **Previous reviewed head:** `76f542c7a4a5ca1e3c2c67fa5d72e54e1ddc01a4`
- **Round 01 report:** `docs/parallel-reports/round-01/window-05.md`
- **Round 02 report:** `docs/parallel-reports/round-02/window-05.md`
- **Scope:** Implement the confirmed CI path-filter fixes and strengthen the routing regression contract.
- **Decision:** Remediation committed to PR #256. Await GitHub Actions completion; do not merge while checks are pending.

## 1. State checked before editing

At the start of this round:
- PR #256 was open, draft, and based on the same head reviewed in round 02.
- PR #265 and PR #273 (the two prior report-publication PRs) were still open and unmerged.
- No changes were made to the two earlier reports.
- The target PR branch was updated only after confirming its head SHA and using a fast-forward expected-SHA lease.

## 2. Test-driven remediation

### RED

A strengthened Node 22 routing contract was run against the pre-fix workflow definitions. It failed on the exact omissions found in rounds 01–02:
- Prescription atomicity did not trigger for changes to `src/lib/prescription-draft.ts`.
- Prescription atomicity did not trigger for changes to `src/features/clinic/consultation/components/PrescriptionTab.tsx`.
- Prescription atomicity did not trigger for changes to `package.json`.
- Privileged-role guard did not trigger for changes to `package.json`.

The first local RED run also exercised the event-semantics assertions. The local harness used the exact workflow trigger sections copied from the reviewed commit; it was a focused reproduction harness, not a full repository clone.

### GREEN

After applying the missing path entries, the local Node 22 test completed:
- **5 tests passed**
- **0 failed**
- Assertions covered all four workflow path contracts, each workflow's own-file trigger, absence of the old broad `db/**` and `tests/**` pull-request filters, exact branch-specific push filters, and expected `workflow_dispatch` behavior.
- A separate assertion verifies that the repository is configured with `"type": "module"` and that both Node/TypeScript PostgreSQL workflows include `package.json` in their pull-request paths.

## 3. Changes committed to PR #256

Commit: `067c2afd15126e633d28dd345e3d5e75c42d43d5`

### `.github/workflows/ci-prescription-atomicity.yml`
Added:
- `src/lib/prescription-draft.ts`
- `src/features/clinic/consultation/components/PrescriptionTab.tsx`
- `package.json`

The SQL fixture/migration/integration inputs, focused test, self-workflow path, PostgreSQL 17 job, Node 22 setup, and push branch remain unchanged.

### `.github/workflows/ci-privileged-role-guard.yml`
Added:
- `package.json`

This covers the root ESM module-mode configuration used when Node 22 runs the TypeScript test with `--experimental-strip-types`. SQL inputs, focused test, self-workflow path, PostgreSQL 17 job, and push branch remain unchanged.

### `tests/ci-broad-workflow-routing.test.mjs`
Expanded the routing contract to assert:
- Required input paths for all four workflows.
- Exact existing branch-specific push filters.
- The existing `workflow_dispatch` behavior (present only on insurance claim validation).
- Self-workflow triggering.
- Removal of broad `db/**` and `tests/**` PR filters.
- `package.json` module type and its routing into both TypeScript/PostgreSQL test workflows.

No change was made to `package.json` or `package-lock.json` in this remediation commit. The existing package script already included the routing test.

## 4. Deliberately excluded inputs

`package-lock.json` was not added to prescription atomicity or privileged-role guard. Neither workflow runs `npm ci` or consumes the dependency lockfile; adding it would create unnecessary CI triggers. Their Node test execution does depend on `package.json` module metadata, so that manifest is included.

## 5. GitHub Actions status at report time

Latest PR head: `067c2afd15126e633d28dd345e3d5e75c42d43d5`.

The following runs were observed after the update and were still pending/in progress at the latest status check:
- Prescription atomicity integration
- Privileged role guard integration
- Insurance claim integrity integration
- Insurance claim UI validation
- Main CI
- Clinical child RPC-only writes
- Finance-only RPC write isolation integration

No pass is claimed for these new runs yet. The local focused RED/GREEN test is not a substitute for the actual GitHub Actions execution. Recheck all latest-head runs before treating this PR as validated or mergeable.

## 6. Scope and safety

- No application runtime behavior changed.
- No SQL migration, database schema, Supabase, QA, production, or deployment changes.
- PostgreSQL integration commands and database fixtures were not modified.
- No changes to the broad main CI workflow.
- No package manifest or lockfile change in this remediation.
- No PR merge, approval, or review submission performed.
- GitHub Actions were triggered by the authorized PR branch update; no manual dispatch or extra reruns were requested.

## 7. Remaining action

1. Recheck every workflow run associated with the latest PR head.
2. Inspect any failed job logs and correct only failures attributable to this change.
3. Once all required checks pass, update the PR's final validation record and hand back for review/merge decision. Do not merge autonomously.

## 8. Publication

- **Window:** 05 — CI Workflow Routing Review
- **Round:** 03
- **Report path:** `docs/parallel-reports/round-03/window-05.md`
- **Report branch:** `docs/window-05-ci-routing-review-round-03-20261116`
- **Base SHA:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **Target implementation PR:** [#256](https://github.com/crauch2088-source/roshan-health-hub/pull/256)
- **Previous reports:** Round 01 and Round 02 remain separate and unchanged.
