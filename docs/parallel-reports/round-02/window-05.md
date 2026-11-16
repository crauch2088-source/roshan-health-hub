# Roshan Parallel Engineering — Window 05
## Round 02: CI Routing Follow-up and Baseline Reconciliation

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Review target:** [PR #256](https://github.com/crauch2088-source/roshan-health-hub/pull/256)
- **Target head reviewed:** `76f542c7a4a5ca1e3c2c67fa5d72e54e1ddc01a4`
- **Current main baseline verified:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **Window 05 round 01 report:** `docs/parallel-reports/round-01/window-05.md`
- **Review type:** Read-only follow-up; runtime dependency and CI status verification
- **Outcome:** Round 01 findings remain valid. Do not approve PR #256 until the routing gaps are addressed.
- **Changes to PR #256:** None
- **New CI runs initiated:** None

## 1. Current repository and PR state

### PR #256 — workflow path tightening

- State: open
- Draft: yes
- Mergeable: yes (GitHub metadata at time of this follow-up)
- Head: `76f542c7a4a5ca1e3c2c67fa5d72e54e1ddc01a4`
- Base ref: `main`
- No review submissions or inline review threads were present at the time of inspection.
- The PR patch is unchanged from the round 01 review.

### PR #265 — round 01 report publication

- State: open
- Draft: no
- Mergeable: yes (GitHub metadata at time of this follow-up)
- Head: `6dc1e219f5a08d9260e0f90cf82b01574f4107e2`
- Contains only `docs/parallel-reports/round-01/window-05.md`.
- It remains unmerged. This round does not merge or retarget it.

## 2. Revalidated workflow dependency findings

The prescription atomicity focused test imports `../src/lib/prescription-draft.ts` and reads `../src/features/clinic/consultation/components/PrescriptionTab.tsx`. Its dedicated workflow currently lists the SQL fixture/migration/integration files, the focused test, and its own workflow file, but omits both source files.

The prescription test therefore has a genuine dedicated-workflow false-negative route: a change isolated to either imported/read source file does not match the workflow's pull-request path filter. The broad main CI runs `test:guard`, which includes the focused test, but that does not preserve the dedicated PostgreSQL 17 integration job for those source-only changes.

The privileged-role test is a Node/TypeScript ESM test using built-in Node imports. The repository's root `package.json` sets `"type": "module"` and Node 22 is configured in the workflow. The package manifest is therefore part of the module-runtime contract. Its omission from the privileged-role workflow path filter can skip that dedicated validation if the module configuration changes.

The same package manifest dependency applies to the prescription TypeScript test. `package-lock.json` is not a direct input for either workflow because neither executes `npm ci`; adding the lockfile would not be justified by the present execution steps.

**Required path additions remain:**
- Prescription atomicity: `src/lib/prescription-draft.ts`
- Prescription atomicity: `src/features/clinic/consultation/components/PrescriptionTab.tsx`
- Prescription atomicity: `package.json`
- Privileged-role guard: `package.json`

No new missing SQL input was identified in this follow-up.

## 3. Routing regression test limitation

The new `tests/ci-broad-workflow-routing.test.mjs` verifies manually declared required paths, own-workflow inclusion, the presence of pull-request and push blocks, and removal of broad `db/**` / `tests/**` patterns.

It does not discover or derive the workflow's real inputs from:
- SQL files passed to `psql`;
- TypeScript imports;
- `readFileSync(new URL(...))` source reads;
- package-level Node module configuration.

The test's manually maintained contracts also do not assert the exact branch values for push triggers or the preservation of `workflow_dispatch`. As a result, it passes while the prescription and package-manifest omissions remain.

Recommendation: retain a declarative routing contract, but make its dependency list complete and add explicit assertions for the event semantics that the PR claims to preserve. Do not claim that the current test dynamically proves dependency completeness.

## 4. Existing CI evidence on PR #256

Read-only inspection of the workflow runs associated with the reviewed PR head found the following relevant completed results:

| Workflow | Result |
|---|---|
| Prescription atomicity integration | success |
| Privileged role guard integration | success |
| Insurance claim integrity integration | success |
| Insurance claim validation regression | success |
| Main CI | success |

The main CI job set included the install/audit/typecheck/lint/build verification and the relevant SQL integration jobs; all completed jobs shown by the API reported success. The deferred authenticated clinical E2E job was skipped by its configured readiness gate and is not counted as a passing execution.

These results are evidence that the changed workflow files and their current inputs executed successfully on this PR head. They do **not** disprove the path-filter false negatives: all four dedicated workflow files are themselves changed in PR #256 and included in their own path filters, which is sufficient to trigger their current runs.

No additional test, workflow, or CI execution was initiated for this report.

## 5. Baseline reconciliation

The PR #256 metadata reports base SHA `fe8d770f1bd666d00b1bf1b3385f21e109e50872`, while the declared baseline and current main base reported by the open documentation PR #265 is `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`.

A commit comparison establishes:
- `79d81f0` is exactly one commit ahead of `fe8d770`.
- That intervening commit changes only `docs/INDEPENDENT_RELEASE_AUDIT_RECONCILIATION_2026-11-15.md`.
- There are no commits behind in that comparison.

Therefore the baseline discrepancy is now explained: PR #256 is based on main one documentation-only commit earlier than the declared/current baseline. This is not evidence of a code divergence. GitHub currently reports the PR mergeable. The PR author may update the branch for a clean base, but the evidence does not support describing this as a substantive source-code conflict.

## 6. Continuation instruction and template availability

The requested `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` were checked again at the reviewed PR head and remained unavailable (GitHub returned 404). This report does not claim to have read or reproduced an inaccessible template. It continues the previously assigned isolated Window 05 reporting convention and preserves round 01 as a separate immutable report.

## 7. Decision and next action

**Decision:** Retain the overall narrow-filter approach, but request changes to PR #256 before approval.

The next implementation/review step is to add the four missing paths listed in section 2 and strengthen the routing contract test to detect the dependency omissions and assert exact event behavior. Re-run the relevant validation only after the PR author has made those corrections and the user authorizes CI execution. Do not change production, QA, database state, application behavior, or unrelated workflows as part of this review.

## 8. Scope and safety

- Read-only follow-up on PR #256 and its existing CI evidence.
- No source, workflow, test, manifest, migration, QA, or production changes.
- No review submission, approval, or merge.
- No new GitHub Actions runs initiated.
- Documentation publication is the only write performed in this round.

## 9. Report publication

- **Window:** 05 — CI Workflow Routing Review
- **Round:** 02
- **Report path:** `docs/parallel-reports/round-02/window-05.md`
- **Report branch:** `docs/window-05-ci-routing-review-round-02-20261116`
- **Base:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **Previous report:** `docs/parallel-reports/round-01/window-05.md`
- **Related report PR:** [#265](https://github.com/crauch2088-source/roshan-health-hub/pull/265)
