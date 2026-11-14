# Agent Task Contract — Template

Use this contract for every non-trivial feature, bug fix, migration, security change, or multi-agent handoff. For trivial isolated documentation corrections, a short checklist is sufficient.

```yaml
task_id: "<github-issue-or-pr-id>"
objective: "<observable outcome>"
priority: "P0 | P1 | P2 | P3"
risk: "LOW | MEDIUM | HIGH | CRITICAL"
authority: "REPO_ONLY | QA_WRITE | PRODUCTION_DELEGATED | OWNER_DECISION_REQUIRED"
environment: "READ_ONLY | DISPOSABLE_PG17 | QA | PRODUCTION"
data_classification: "SYNTHETIC_ONLY | REAL_OR_UNKNOWN"
owner_decisions_required: []
source_of_truth: []
dependencies: []
allowed_paths: []
forbidden_paths:
  - ".env*"
  - "secrets/**"
  - "production exports/**"
non_goals: []
acceptance_criteria: []
verification_commands: []
evidence_required: []
stop_conditions: []
recovery_or_rollback: "<tested rollback or forward-recovery path>"
handoff_to: "<role or agent>"
```

## Required contract content

### Outcome and scope
- State the observable outcome, affected roles/workflows, in-scope behavior, and explicit non-goals.
- Identify expected files, SQL objects, RPCs, tables, callers, and integrations.
- Record dependencies and assumptions; label unknowns instead of guessing.

### Authority and environment
- Name required authority and exact target project/ref/branch.
- State data classification. Use synthetic data only outside Production.
- Production writes require Constitution Section X preflight, recovery, exact-head checks, security review, zero-cost compliance, and post-change read-back.
- Fresh owner decision remains required for clinical policy, real/uncertain irreversible data, unresolved critical/high security risk, or ambiguous scope/recovery.

### Acceptance criteria
Each criterion must be binary, observable, and traceable to at least one verification method. Include positive/negative cases, role/branch boundaries, failure/retry/concurrency behavior, and no-side-effect assertions where relevant.

### Verification and evidence
- Record exact command/workflow and target commit, expected result, actual result, and evidence link/output.
- Classify every check as `PASS`, `FAIL`, `SKIP`, `BLOCKED`, `NOT_RUN`, or `STALE`.
- A checked box without evidence is not complete. A skipped check is never a pass.

### Recovery and completion
- State rollback or forward-recovery before risky writes and name exact stop conditions.
- Preserve audit, finance, stock, branch, Auth, RLS, and project-identity invariants.
- Report exact commit/PR, changed paths, criteria/evidence, all check states, residual risks, untouched areas, and next dependency.
- High-risk SQL/security/production changes require independent review; the implementer must not self-certify that review.