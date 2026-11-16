# Window 06 — Repomix & Snapshot Security Review (Round 04)

**Review date:** 2026-11-16  
**Target:** PR #254 — [chore(ci): add secure Repomix context snapshots](https://github.com/crauch2088-source/roshan-health-hub/pull/254)  
**Decision:** **CHANGES REQUIRED — NOT SECURITY-APPROVED**  
**Review type:** Independent, read-only revalidation. No source or workflow changes.

## 1. Current repository state

- Default branch: `main`
- Main tip at review: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- PR #254: open, Draft, not merged; head `fad354fd89b4126e76ffac852ee134ecd0df5d77`; base `fe8d770f1bd666d00b1bf1b3385f21e109e50872`; 7 commits and 5 changed files.
- PR head is unchanged from Round 03. No remediation commit was observed.
- PR #254 has seven PR-triggered workflow runs on its current head; all seven returned `completed/success`. These are not evidence that the separate `Repository context snapshot` workflow ran or that its artifact was generated and inspected.
- The Vercel check reported an ignored/canceled deployment, not a successful build or deployment.
- Prior documentation PRs #264, #271 and #277 remain open and unmerged.
- `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` both returned 404 on current `main`. This report therefore does not claim compliance with unavailable instructions/template.

## 2. Revalidated findings

### F-01 — Critical trust-boundary gap in `workflow_run` (still open)

The workflow listens for completion of `CI` on `main`. Its job condition checks:

- `github.ref == 'refs/heads/main'`
- for `workflow_run`, `github.event.workflow_run.head_branch == 'main'`

It then checks out `github.event.workflow_run.head_sha`.

The condition does not explicitly require `workflow_run.head_repository.full_name` to equal the trusted repository, nor establish that `head_sha` is reachable from the trusted repository's protected `main` history. A branch-name match is not repository identity or commit provenance. A same-named `main` branch from a fork is not explicitly rejected by the current guard.

**Required remediation:** Bind the event to the exact upstream repository identity and prove the selected SHA belongs to the trusted upstream main history before checkout or execution. Prefer building the snapshot from the trusted default-branch SHA rather than executing code selected from the triggering workflow payload. Add adversarial tests for fork-originated runs, a fork branch named `main`, repository mismatch, PR-originated runs, and non-ancestral/untrusted SHAs.

### F-02 — High risk: read token exposed to checked-out script (still open)

The workflow checks out the event-selected SHA, then passes `GH_TOKEN: ${{ github.token }}` into the step executing:

`node scripts/build-live-state-snapshot.mjs`

Because the script is read from the checked-out revision, a malicious or untrusted revision can change that script and read/exfiltrate the token. `persist-credentials: false` only prevents checkout from persisting credentials; it does not protect a token explicitly placed in the process environment.

The token is read-only under the workflow's declared permissions, but it still carries repository/API read access. Read-only does not mean safe to expose to untrusted code.

**Required remediation:** Do not execute code from an event-selected or otherwise untrusted SHA in a process that receives the GitHub token. Separate trusted snapshot logic from untrusted checkout content; minimize token scope and lifetime; add a test proving the untrusted script cannot observe credentials.

### F-03 — Medium: repository validation is format-only (still open)

`REPOSITORY_PATTERN` validates `owner/repository` syntax, not the exact expected repository. This is not a substitute for event-origin validation or an allowlist.

**Required remediation:** Enforce the exact repository identity expected by this workflow and test mismatches.

### F-04 — Medium: output text normalization is truncation-only (still open)

`safeText` slices strings but does not perform explicit control-character or presentation normalization. JSON serialization escapes JSON control characters, and this review did not establish a demonstrated structural JSON injection. The remaining concern is safe downstream rendering/consumption and explicit normalization policy, not a proven JSON parser breakout.

**Required remediation:** Define the output consumer contract, normalize or reject unexpected control characters where appropriate, and test hostile strings at the serialization and display boundaries.

### F-05 — Medium: Repomix exclusions are path-based (still open)

The ignore list excludes many credential-like paths and generated directories, but it is not a content-level secret scan of the final `repomix-output.xml`. Secrets accidentally committed in ordinary source/config files may still be packed.

**Required remediation:** Add a fail-closed secret scan of the generated artifact before upload, with safe handling of scanner output so secret values are never printed.

### F-06 — Medium: downstream artifact consumption must treat content as untrusted (still open)

The snapshot and packed repository are data, not trusted instructions. Any later model/agent consumer must preserve this boundary and must not follow instructions embedded in repository files, comments, metadata, or generated content.

**Required remediation:** Document and enforce the consumer-side untrusted-data contract before connecting this artifact to an agent workflow.

### F-07 — Medium: artifact access and integrity are unverified (still open)

No successful snapshot workflow run or generated artifact was inspected during this review. Retention is configured for 14 days, but this review has not verified who can download the artifact, its actual contents, provenance, or integrity.

**Required remediation:** After trust-boundary fixes, run only from a trusted main revision under an explicitly authorized execution; verify artifact access controls, contents, secret-scan results, and provenance. This review did not dispatch the workflow or upload/download an artifact.

## 3. Positive controls observed

- Workflow permissions are limited to `contents: read`, `pull-requests: read`, and `actions: read`.
- GitHub Actions are pinned to immutable commit SHAs.
- Checkout uses `persist-credentials: false`.
- The snapshot script performs GET requests only and excludes PR bodies, comments, user profiles, workflow logs, and artifact contents from the live-state JSON.
- The workflow does not configure database credentials or database access.
- Artifact retention is set to 14 days.

These controls reduce exposure but do not close F-01 or F-02.

## 4. Test coverage gaps

The current tests use `example/roshan` rather than the exact production repository and assert the existing branch-name condition. They do not demonstrate rejection of:

- a fork repository with a branch named `main`;
- `head_repository.full_name` mismatch;
- a pull-request-originated upstream workflow run;
- a SHA not proven to belong to trusted upstream `main`;
- an untrusted checked-out script attempting to read the token.

There is also no artifact-level secret scan test or end-to-end artifact inspection evidence.

## 5. Required remediation order

1. Close F-01: verify upstream repository identity and trusted SHA provenance; add adversarial event tests.
2. Close F-02: ensure no untrusted checked-out code can execute with `GH_TOKEN` in its environment; add token-isolation regression coverage.
3. Close F-03: exact repository allowlist.
4. Close F-05 and F-07: artifact secret scanning, access-control review, and provenance/integrity verification.
5. Close F-04 and F-06: explicit output normalization and downstream untrusted-data contract.

Do not treat green PR CI as approval of the snapshot workflow or its artifact.

## 6. Scope and safety statement

This round only inspected repository metadata, the current PR diff, and the three target files at the exact PR head. It did **not** modify PR #254, dispatch workflows, create or upload artifacts, change tokens/secrets/permissions, access QA or Production databases, merge PRs, or deploy anything.

## 7. Final outcome

**F-01 and F-02 remain unresolved. PR #254 is not security-approved.** No security finding was closed in this round. Re-review is required after a remediation commit changes the workflow trust boundary and token execution model.

**Round completion:** 100% of this revalidation/reporting task.  
**Project readiness:** This narrow review cannot update the overall Roshan readiness percentage or completion ETA. The latest mainline reconciliation still records Engineering Release Candidate 62% and Operational Acceptance 15%; these are distinct measures and neither means the clinic is ready for real-world clinical use.
