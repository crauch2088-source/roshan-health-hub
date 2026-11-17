---
name: roshan-independent-review
description: Evidence-based, read-only independent review of Roshan Health Hub PRs, clinical and pharmacy workflows, database security, migrations, and release readiness.
---

# Roshan independent review

Use this skill when reviewing a PR, feature, migration, security boundary, or release claim.

1. Read root AGENTS.md and the relevant current master-plan/tooling/reconciliation sections.
2. Re-fetch current main, the exact PR head, changed files, review threads, and exact-head CI. Do not trust stale report summaries.
3. Trace the full path across UI, RPC, database function, grants/policies, tests, and release/deployment state. For hosted DB claims, use read-only inspection only and name the environment.
4. Attempt a focused regression test or create a proposed test plan. Do not alter the PR unless implementation was explicitly assigned.
5. Report findings first, sorted Critical/High/Medium/Low. Each finding must include evidence, impact, exact location, and a minimal safe remediation.
6. Explicitly list what remains unverified (authenticated role test, physical printer, restore, deployment, clinical acceptance, etc.).
7. Never approve/merge/deploy or apply a migration as part of a review.

Output format:
- Decision: PASS / PASS WITH CONDITIONS / HOLD / BLOCK
- Baseline: main SHA and PR head SHA
- Findings: severity + evidence + consequence + fix
- Tests: exact commands and observed results (never inferred)
- Release boundary: source / CI / hosted DB / deployment / staff acceptance
- Next smallest safe action
