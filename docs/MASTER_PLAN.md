# Roshan Health Hub — Master Plan

**Purpose:** authoritative strategic roadmap and release sequence. Live mutable facts are cached in `docs/PROJECT_STATE.md` and must be refreshed from GitHub, Supabase, and Vercel before action.
**Last roadmap review:** 2026-11-14. **Repository:** `crauch2088-source/roshan-health-hub`.

## Current execution snapshot

- Main baseline: `a9040601702972bdf144fc96b9658eebd5a6d31a`.
- Active PR: [#250](https://github.com/crauch2088-source/roshan-health-hub/pull/250), Draft, branch `fix/phase61c-atomic-dispense-role-boundary-20261114`, last verified head `2ced297b6942408354445fc24792304f4c4a68f5`.
- Live comparison at that checkpoint: 27 commits ahead, 0 behind `main` (the former 24-ahead figure was stale).
- Exact-head workflows and Vercel status were successful on that checkpoint; 0 independent reviews and 0 inline review threads. Authenticated clinical acceptance remains skipped/deferred.
- Production and QA migration counts in the prior snapshot are historical checkpoints only. Re-read live ledgers and target refs before any migration.
- Existing QA/Production rows are synthetic/test data. Owner-approved reset/rebuild authority is in Constitution Section X; never create new synthetic clinical/business transactions in Production.
- Backup evidence is incomplete as a current release proof: latest archive metadata check did not include decryption in that session, and latest restore evidence predates the current runner head.
- Last separately stated estimates (2026-11-12) were 62% engineering RC and 15% operational readiness; these are historical, not current percentages.

## Execution order

1. **PR #250 independent review:** review complete SQL diff and role/permission semantics; verify canonical and legacy pharmacist behavior, RLS/grants, branch scope, idempotency, audit, inventory, and billing invariants. Do not merge or apply Phase 61C to hosted QA/Production until review and QA gate pass.
2. **Migration provenance and security reconciliation:** reconcile source, manifest, Production/QA ledgers, baseline/replay evidence, and ACL differences. Never edit ledger history to manufacture parity.
3. **Release blockers:** refresh encrypted backup/decryption/restore evidence; complete role × operation × branch tests; resolve outstanding high-risk security/data-integrity Issues, including #218.
4. **Core workflows:** complete the 22 authenticated application screens and end-to-end module workflows using source-backed acceptance criteria. Prioritize reception, GP, lab, pharmacy, and finance.
5. **Operational acceptance:** authenticated QA acceptance, real staff UAT, clinician/pharmacist/finance validation, 320–430 px mobile layouts, Arabic RTL/English LTR, physical printing, and controlled release decision.

## Completion and release semantics

- A task is complete only when observable acceptance criteria are met with evidence on the exact candidate commit.
- Audits, plans, PR creation, CI from another SHA, skipped tests, and successful deployment alone do not count as implementation or clinical acceptance.
- Engineering release-candidate completion and operational readiness are separate metrics. Count deduplicated, evidence-backed requirements only; exclude post-launch experiments.
- A skipped or unavailable mandatory check is not a pass. Record residual risk and the precise blocker.
- Do not declare launch readiness until real staff workflow, clinical acceptance, security, backup/restore, and operational release gates are evidenced.

## Reference map

| Need | Canonical reference |
|---|---|
| Live branch/PR/CI/deployment/ledger checkpoint | `docs/PROJECT_STATE.md` (refresh before use) |
| Canonical backlog and priorities | GitHub Issues/PRs; see `docs/TASK_REGISTRY.md` |
| Task scope, acceptance, authority, recovery | `docs/AGENT_TASK_CONTRACT_TEMPLATE.md` |
| Session execution and agent handoffs | `docs/AGENT_EXECUTION_PROTOCOL.md` |
| Test and acceptance routing | `docs/VERIFICATION_MATRIX.md` |
| Durable safety/owner authority | `.specify/memory/constitution.md` |
| Agent startup | `docs/AGENT_START_HERE.md` and `AGENTS.md` |
| Historical execution narrative | `docs/archive/MASTER_PLAN_HISTORY.md` |

Historical phase checklists and old status snapshots have been moved to `docs/archive/MASTER_PLAN_HISTORY.md`. They are evidence, not current status.