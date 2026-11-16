# Roshan Parallel Engineering — Window 06
## Round 03: Security Revalidation and CI Evidence

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Main SHA verified:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **Target:** [PR #254](https://github.com/crauch2088-source/roshan-health-hub/pull/254)
- **PR #254 head:** `fad354fd89b4126e76ffac852ee134ecd0df5d77`
- **Prior report:** `docs/parallel-reports/round-02/window-06.md`
- **Review type:** Read-only security revalidation
- **Disposition:** **CHANGES REQUIRED — NOT SECURITY-APPROVED**

## 1. Executive summary

No remediation commit has appeared on PR #254 since Round 02. The security-relevant workflow and snapshot script are unchanged. The two release-blocking findings remain:

- **F-01 (Critical):** `workflow_run` can select an upstream run by branch name without proving that the upstream repository is the trusted repository. The job then checks out the upstream `head_sha`.
- **F-02 (High):** The same job exposes `GH_TOKEN` to a script loaded from that checked-out revision. `persist-credentials: false` does not prevent the explicitly injected environment token from being read by that script.

The PR's seven observed PR-triggered GitHub Actions runs completed successfully. Those results do **not** prove the `workflow_run` trust boundary, token isolation, Repomix execution, or artifact publication. No run for the new snapshot workflow was found for this head SHA.

## 2. Current repository and PR state

| Item | Verified state |
|---|---|
| Main | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` |
| PR #254 | Open, Draft, not merged |
| PR #254 head | `fad354fd89b4126e76ffac852ee134ecd0df5d77` |
| PR #254 base SHA | `fe8d770f1bd666d00b1bf1b3385f21e109e50872` |
| Relationship | Main is one commit ahead of the PR base; compare reports ahead_by=1, behind_by=0 |
| PR #254 changed files | 5 |
| PR #254 commits | 7 |
| PR #271 (Round 02 report) | Open, not merged, mergeable |
| Continuation instructions | Still 404 on main |
| Required report template | Still 404 on main |

The apparent base mismatch is explained: main contains one additional commit, `79d81f0`, with message `docs(roshan): append late-session execution evidence`. This is not evidence of divergent histories. PR #254 should be rebased/updated against current main before merge, but the one-commit lag does not resolve any security finding.

## 3. CI evidence and its limits

For PR head `fad354f`, the Actions API returned seven completed PR-triggered workflow runs with `conclusion=success`, including CI and six dedicated integration/validation workflows. The Vercel status was marked successful with description `Canceled by Ignored Build Step`; this is not a deployment or build verification.

No run of the `Repository context snapshot` workflow was found for this head SHA. Therefore:
- no end-to-end Repomix run is evidenced;
- no artifact upload is evidenced;
- no artifact contents or artifact access policy were inspected;
- the workflow's `workflow_run` trigger has not been demonstrated safe by these checks.

## 4. Findings — current disposition

| Finding | Severity | Round 03 disposition |
|---|---|---|
| F-01 — `workflow_run` source repository and SHA trust not established | Critical | **Open — unchanged** |
| F-02 — Explicit GitHub token passed to repository-controlled script | High | **Open — unchanged** |
| F-03 — Snapshot script validates repository syntax, not exact expected identity | Medium / defence-in-depth | Open — unchanged |
| F-04 — `safeText` only truncates; no explicit normalization policy | Medium / hardening | Open — unchanged; JSON serialization escapes control characters, so no structural injection was demonstrated |
| F-05 — Ignore patterns are not a content-level secret scan | Medium | Open — unchanged |
| F-06 — Snapshot content requires an explicit untrusted-data contract for downstream AI use | Medium / consumer control | Open — unchanged; no downstream consumer execution was tested |
| F-07 — Artifact access and package integrity/provenance are not verified | Medium | Open — unchanged; no artifact was produced in this review |

### Evidence for F-01

The workflow still contains:
- `workflow_run` for the CI workflow with `types: [completed]` and `branches: [main]`;
- a job condition that checks `github.event.workflow_run.head_branch == 'main'`;
- checkout of `github.event.workflow_run.head_sha`.

It does not validate `workflow_run.head_repository.full_name` against `crauch2088-source/roshan-health-hub`, nor does it prove that the selected SHA belongs to the trusted repository's main history. A branch name is not a repository identity.

### Evidence for F-02

The checkout uses the event-selected SHA and disables persisted checkout credentials. However, the subsequent step sets `GH_TOKEN: ${{ github.token }}` and runs `node scripts/build-live-state-snapshot.mjs`. Because the script is read from the checked-out tree, code in that tree executes in a process that can read the token. Disabling persisted checkout credentials does not remove this explicit environment variable.

### Test-quality observation

The workflow test asserts that the current branch-name condition exists; it does not test hostile upstream repository identities or prove SHA ancestry. Snapshot unit tests use `example/roshan` and verify malformed syntax, not the production repository allowlist. No tests cover fork branch named `main`, mismatched `head_repository`, PR-originated upstream runs, or token isolation.

## 5. Required remediation before approval

### P0 — blocking

1. Prefer removing `workflow_run` if the trusted-main push, manual, and scheduled triggers meet the use case.
2. If retained, require exact `head_repository.full_name == 'crauch2088-source/roshan-health-hub'`, an allowed upstream event type, and independent verification that the selected SHA is in the trusted main history. Fail closed on missing/null repository metadata.
3. Never execute repository-controlled code in a step with `GH_TOKEN`. Separate trusted API retrieval from packaging, and ensure the Repomix/script execution environment has no token.
4. Add adversarial workflow tests for fork branch named `main`, mismatched repository, PR-originated upstream run, missing metadata, and non-main/untrusted SHA.
5. Add a token-isolation test proving the checked-out script cannot read any GitHub token.

### P1/P2 — artifact safety

6. Add a content-level secret scan against the exact generated artifact and fail closed before upload.
7. Define exact repository identity validation in the standalone snapshot script.
8. Document the artifact as untrusted input for downstream model consumers; truncation is not a prompt-injection defence.
9. Verify artifact visibility/access controls and document the package integrity/provenance strategy for Repomix.

## 6. Scope and safety

- Read-only inspection of GitHub metadata, patch, workflow, script, and tests.
- No workflow dispatch/rerun, no artifact generation/download/upload.
- No source code, workflow, token, secret, permission, database, or deployment changes.
- No production writes or exploit attempt.

## 7. Continuation

The requested `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` remain unavailable on current main (404). This report records that limitation and does not claim use of the missing template.

Next round: recheck PR #254 head and current main; review only newly changed security-relevant lines. Close F-01/F-02 only after implementation and adversarial regression evidence. Do not run the snapshot workflow or publish artifacts without explicit authorization.

---
**Window:** 06  
**Round:** 03  
**Result:** Revalidation complete; no security remediation detected; seven PR CI runs passed but do not validate snapshot trust or artifact publication.
