# Roshan Parallel Engineering — Window 06
## Round 01: Repomix & Snapshot Security Review

- **Repository:** `crauch2088-source/roshan-health-hub`
- **Main baseline reviewed:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- **Target:** PR #254 — [chore(ci): add secure Repomix context snapshots](https://github.com/crauch2088-source/roshan-health-hub/pull/254)
- **Target PR head observed:** `fad354fd89b4126e76ffac852ee134ecd0df5d77`
- **Review type:** Independent, read-only security review
- **Report path:** `docs/parallel-reports/round-01/window-06.md`
- **Disposition:** **CHANGES REQUIRED — not security-approved**

## 1. Executive summary

PR #254 introduces a useful repository-context artifact consisting of a Repomix XML snapshot and a sanitized GitHub live-state JSON file. The design has meaningful baseline protections: read-only GitHub permissions, immutable action pins, checkout credentials disabled, limited metadata collection, no hosted database access, and 14-day artifact retention.

The security boundary is nevertheless incomplete. In particular, the `workflow_run` path accepts a branch-name test as a proxy for source trust and checks out `workflow_run.head_sha`. The downstream job has a write-disabled but still authenticated GitHub token in the environment of a script checked out from that SHA. A malicious upstream run could therefore turn an insufficiently validated source into code executing in a more privileged workflow context.

**Do not approve PR #254 on security grounds until F-01 and F-02 are remediated and covered by adversarial tests.** This review found design weaknesses; it did not establish that exploitation has occurred.

## 2. Scope and evidence

Reviewed:
- `.github/workflows/repomix-snapshot.yml` in PR #254.
- `scripts/build-live-state-snapshot.mjs` as included in the PR diff.
- `tests/live-state-snapshot.test.mjs` as included in the PR diff.
- Main CI workflow `.github/workflows/ci.yml`.
- PR metadata and changed-file/diff evidence for PR #254.

Not performed:
- No workflow was dispatched or rerun.
- No artifact was generated or uploaded.
- No repository file was modified during the security review.
- No token, secret, permission, database, deployment, or production setting was changed.
- No exploit or exfiltration test was executed.

The PR is open and Draft. The repository default branch was observed at the stated baseline SHA during this continuation.

## 3. Threat model

| Element | Description |
|---|---|
| Assets | GitHub token, source tree, repository metadata, generated artifact, project operational context |
| Entry points | `push`, `workflow_dispatch`, `schedule`, and especially `workflow_run` |
| Untrusted inputs | PR-controlled source files, branch names, commit SHAs, PR titles, workflow metadata, repository text |
| Trust boundaries | Upstream CI → downstream workflow → checkout → Node script → Repomix → uploaded artifact → downstream AI/agent consumer |
| Adversaries | Fork PR author, compromised dependency/tooling, malicious repository contributor, prompt-injection content author |
| Main impacts | Privileged code execution, token disclosure, accidental secret disclosure, misleading AI instructions, artifact exposure |

## 4. Findings (prioritized)

### F-01 — Critical: `workflow_run` source trust is not established

**Evidence:** The workflow job condition checks `github.ref == 'refs/heads/main'` and, for `workflow_run`, `github.event.workflow_run.head_branch == 'main'`. Checkout then uses `github.event.workflow_run.head_sha || github.sha`.

**Issue:** A branch name is not proof of repository identity. A fork can use a branch named `main`; a completed CI run associated with that branch can satisfy the branch-name test unless the source repository and original event are separately constrained. The downstream workflow's own `github.ref` is not a substitute for validating the upstream run's source repository. The current condition does not validate `workflow_run.head_repository.full_name` or the repository identity associated with the upstream run.

**Impact:** Potential checkout and execution of attacker-controlled code in a downstream workflow that has its own token and artifact permissions.

**Required remediation:**
1. Prefer removing the `workflow_run` trigger if the snapshot can be produced safely by trusted-main `push`, schedule, or manual dispatch.
2. If retained, validate the upstream repository identity against the exact expected repository, validate the upstream event type, and validate that the selected SHA belongs to the trusted repository's protected main history.
3. Do not treat `head_branch == 'main'` as an adequate trust check.
4. Add fork-PR adversarial tests, including a fork branch named `main`.

### F-02 — High: checked-out script executes with `GH_TOKEN` in its environment

**Evidence:** The workflow checks out a SHA selected from the event and later runs `node scripts/build-live-state-snapshot.mjs` with `GH_TOKEN: ${{ github.token }}` in the step environment.

**Issue:** `persist-credentials: false` prevents checkout from persisting Git credentials; it does not protect a token explicitly passed to a process. If the checked-out script is attacker-controlled, it can read the token and attempt network exfiltration.

**Impact:** Token disclosure and use of the permissions granted to the workflow. The current permissions are read-only, which limits impact but does not eliminate exposure.

**Required remediation:**
- Do not execute repository-controlled script code in the same trust context as the token.
- Use a trusted, pinned implementation for the API-fetching step, or split the workflow so the token-bearing metadata fetch runs only trusted code and the untrusted-content packaging step has no token.
- Keep the token scoped to the smallest possible step and continue to avoid adding permissions or secrets.

### F-03 — Medium: repository identity validation checks syntax, not identity

**Evidence:** The script validates `GITHUB_REPOSITORY` with a generic `owner/repository` regular expression.

**Issue:** The expression verifies only the shape of the value. It does not enforce the intended repository identity.

**Required remediation:** Compare against the explicit expected repository identifier and fail closed on mismatch. Keep this check independent of event-derived branch/ref values.

### F-04 — Medium: metadata sanitization is truncation, not content sanitization

**Evidence:** `safeText()` truncates strings by length but does not reject control characters or normalize untrusted metadata.

**Issue:** JSON serialization protects JSON structure, but truncation alone does not neutralize control characters, deceptive display text, or AI-directed prompt-injection content in titles and branch names.

**Required remediation:** Apply per-field allowlists, length limits, and safe character handling where practical. Preserve the semantic boundary: metadata remains untrusted data, never executable instructions.

### F-05 — Medium: filename exclusions do not prove secret-free content

**Evidence:** Repomix receives an explicit ignore list for common credential and generated-file paths.

**Issue:** A secret can be embedded in an ordinary source, SQL, Markdown, or JSON file whose path is not excluded. Path filters are useful defense-in-depth, not a content-level secret guarantee.

**Required remediation:** Run secret scanning against the exact generated snapshot before upload and fail closed on findings. Avoid printing secret-bearing content in logs. Do not add secrets or tokens to accomplish this.

### F-06 — Medium: prompt-injection risk is transferred to artifact consumers

**Evidence:** Repomix serializes repository files and documentation into a model-readable artifact; live-state metadata includes PR titles and branch names.

**Issue:** Trusted provenance of the branch does not make every string in the repository safe as instructions. A contributor can place model-targeted instructions in a source file or metadata field.

**Required remediation:** Label snapshot contents as untrusted data in consumer instructions. Maintain instruction hierarchy outside the artifact, and do not permit artifact text to authorize tool calls, secret access, or code execution.

### F-07 — Medium: artifact and package supply-chain assurances are incomplete

**Evidence:** The upload action is pinned by commit SHA and retention is set to 14 days; Repomix is invoked through `npx --package=repomix@1.19.0`.

**Issue:** Retention is bounded, but this review did not establish artifact access restrictions or a pre-upload content scan. A pinned version string does not by itself document a verified package integrity/provenance policy for this ephemeral invocation.

**Required remediation:** Verify repository artifact access policy, scan the final files before upload, and document package provenance/integrity controls. Preserve the 14-day retention unless a shorter justified period is feasible.

## 5. Control assessment

| Control | Assessment | Evidence / limitation |
|---|---|---|
| GitHub Actions permissions | Good baseline | `contents: read`, `pull-requests: read`, `actions: read` |
| Checkout credentials | Good baseline | `persist-credentials: false` |
| Action pinning | Good baseline | Checkout, setup-node, upload-artifact pinned to immutable SHAs |
| `workflow_run` trust boundary | Insufficient | Branch-name check; no explicit source repository identity check |
| Token isolation | Insufficient | Explicit `GH_TOKEN` supplied to checked-out script |
| Repository identity | Partial | Syntax validation only |
| SHA/ref validation | Partial | SHA shape and main ref checks do not prove trusted ancestry/source |
| PR bodies/comments/logs | Good | Not fetched by the reviewed snapshot script |
| Secret exclusion | Partial | Path-based ignore patterns only; no demonstrated content scan |
| Metadata sanitization | Partial | Truncation and JSON serialization, not robust input normalization |
| Artifact retention | Good baseline | 14 days |
| Artifact access control | Unverified | Repository artifact visibility/access settings were not independently verified |
| Prompt injection | Unmitigated at consumer boundary | Requires explicit untrusted-data handling by consuming agents |

## 6. Test coverage gaps

Existing tests cover:
- Main-ref rejection in the snapshot script.
- Minimal PR/workflow metadata selection.
- Exclusion of PR bodies and log URLs from the serialized object.
- Malformed repository and SHA formats.
- API failure handling without logging response bodies.
- Presence of selected Repomix ignore patterns.

Missing adversarial coverage:
1. Fork repository with a branch named `main`.
2. Upstream `workflow_run.event` equal to `pull_request`.
3. `workflow_run.head_repository.full_name` different from the expected repository.
4. Valid-looking SHA that is not a commit on trusted main.
5. Explicit proof that untrusted checked-out code cannot access the token.
6. Prompt-injection strings and control characters in titles/branch names.
7. Secret canaries embedded in ordinary source/document files and detected before upload.
8. Verification of actual Repomix output contents, not merely presence of ignore patterns in YAML.

The current workflow regex test proves only that a specific conditional string exists; it does not prove that the event trust boundary is safe.

## 7. Remediation order

| Priority | Action |
|---|---|
| P0 | Remove or strictly constrain the `workflow_run` path; prove source repository identity and trusted SHA provenance |
| P0 | Separate token-bearing GitHub API access from execution of repository-controlled scripts |
| P1 | Enforce explicit repository identity and trusted ref/SHA relationship |
| P1 | Add adversarial event tests and a token-isolation regression test |
| P1 | Scan generated artifact contents for secrets before upload |
| P2 | Normalize untrusted metadata and document the prompt-injection boundary |
| P2 | Verify artifact access settings and document Repomix package provenance |

No remediation should expand workflow permissions or introduce additional secrets.

## 8. Final decision

**CHANGES REQUIRED — PR #254 is not security-approved in its reviewed form.**

The overall snapshot concept is worth retaining. The minimum approval gate is to close F-01 and F-02, add regression coverage for fork-originated `workflow_run` events and token isolation, and demonstrate secret scanning of the exact artifact payload.

This is a design review, not evidence of an actual compromise. No workflow was run and no artifact was uploaded as part of this review.

## 9. Review procedure / continuation note

The user requested that Window 06 use `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md`, with one immutable report per round under `docs/parallel-reports/round-01/`.

At the time of this report, both requested instruction/template files returned 404 on the current `main` baseline and on PR #254's head. The `docs/parallel-reports/` directory was also absent on `main`. Therefore this report uses a conventional structured security-review format and records the missing governing files as a process limitation. It does not claim exact compliance with an unavailable template. No other window's report was created, edited, or replaced.

For subsequent rounds, first re-check the current `main` tip, recover the governing continuation instructions and template when they exist, and create a new round-specific report without overwriting this one.

---
**Window:** 06  
**Round:** 01  
**Result:** Read-only security review completed; documentation-only PR submitted separately.
