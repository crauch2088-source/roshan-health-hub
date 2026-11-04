---
name: roshan-release
description: Use for Roshan pull requests, exact-head CI review, branch promotion, Vercel checks, release gates, rollback planning, and handoff documentation.
---

# Roshan Release
- Re-read current main, target branch, open PRs, and changed-file overlap before branch or PR operations.
- Use a dedicated branch for a coherent task; never append unrelated work to another PR.
- Preserve published history: no force push, rebase, amend, or history rewrite.
- Batch implementation, tests, and docs into one atomic tree/commit.
- Check required GitHub Actions against exact PR head SHA; inspect skipped jobs and their reason.
- Review required approvals, draft/ready status, mergeability, and conflicts.
- Squash merge only when all project release gates are satisfied and policy permits.
- Docs/SQL/migration/script-only changes must avoid unnecessary frontend builds where configured.
- Never bypass Vercel quota, deployment protection, account controls, or create duplicate projects/paid upgrades.
- Preview READY is not production release or clinical acceptance.
- Do not promote deployment, apply Production migrations, change grants/RLS, mutate Auth/Storage, or write live clinical/financial data without documented explicit authorization and gates.
- Handoff records main SHA, branch/PR/head SHA, exact checks, Vercel status, database environment if relevant, blockers, next safe action, and operations not performed.
