# Roshan Health Hub — Master Plan

**Purpose:** authoritative strategic roadmap and release sequence. Live mutable facts are cached in `docs/PROJECT_STATE.md` and must be refreshed from GitHub, Supabase, and Vercel before action.
**Last roadmap review:** 2026-11-14. **Repository:** `crauch2088-source/roshan-health-hub`.

## Current execution snapshot

- Main baseline: `a9040601702972bdf144fc96b9658eebd5a6d31a`.
- Active PR: [#250](https://github.com/crauch2088-source/roshan-health-hub/pull/250), Draft, branch `fix/phase61c-atomic-dispense-role-boundary-20261114`, latest docs-only head `d912ae9a8da17dc34c301545fe57d6dafb6a8311`; tested SQL/application code head `83ed9a9d82b3a1ee78ccadcc70db86139b182983`.
- Live comparison at that checkpoint: 40 commits ahead, 0 behind `main`.
- Exact-head CI on `83ed9a9d82b3a1ee78ccadcc70db86139b182983` completed with 31 successful checks, 1 intentional authenticated clinical-acceptance skip, and 0 failures ([run 43577740702](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43577740702)). The Vercel status is marked success because the build was canceled by the Ignored Build Step; no preview deployment was produced. There are 0 independent reviews and 0 inline review threads. Authenticated clinical acceptance remains skipped/deferred.
- PR #249 merged the Phase 61 correction workflow and deterministic medication-engine foundation to main (`a9040601702972bdf144fc96b9658eebd5a6d31a`). PRs #233 and #185 were closed as superseded; the Feature 056 specification package is preserved in [PR #252](https://github.com/crauch2088-source/roshan-health-hub/pull/252), based on current main, with all Spec Kit and CodeQL checks passing.
- Fresh read-only Phase 55 check: QA has migration `20261103155227` and denies direct application-role EXECUTE on the two private helpers; Production lacks Phase 55 and still exposes `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` through default PUBLIC EXECUTE. See Issue #218. No hosted changes were made.
- Production and QA migration counts in the prior snapshot are historical checkpoints only. Re-read live ledgers and target refs before any migration.
- Existing QA/Production rows are classified by the owner as synthetic/test data. This classification is not destructive-reset authorization; see Constitution Section X. Never create new synthetic clinical/business transactions in Production.
- Backup runner main is `f171732b61fe0460c61a36aa63b861065f9ea9d1`; CI run `43190851147` passes. The latest full encrypted Production backup/PG17 restore is run `43183851731` on older runner SHA `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`. Owner-side Android/Termux decryption remains unverified; no new backup was dispatched because the required DB password secret had been deleted. See Issue #199.
- Last separately stated estimates (2026-11-12) were 62% engineering RC and 15% operational readiness; these are historical, not current percentages.

## Execution order

1. **PR #250 independent review:** review complete SQL diff and role/permission semantics; verify canonical and legacy pharmacist behavior, RLS/grants, branch scope, idempotency, audit, inventory, and billing invariants. Do not merge or apply Phase 61C to hosted QA/Production until review and QA gate pass.
2. **Phase 55/61 release sequence:** complete Issue #218 source/ledger/catalogue reconciliation and independent review; apply only forward-only ACL remediation in QA first, then separately authorize Production. Phase 61C remains a candidate only. Never edit ledger history to manufacture parity.
3. **Backup and recovery:** owner completes local encrypted artifact verification via Android/Termux; owner re-establishes required backup credentials; generate a current encrypted backup and PostgreSQL 17 restore rehearsal; document Storage/Vault exclusions.
4. **Catalogue and finance:** reconcile PR #210 (74 ahead / 18 behind main) and PR #181 (37 ahead / 18 behind main) using normal two-parent merges; do not merge either stale branch before exact-head tests and hosted migration prerequisites.
5. **Operational acceptance:** authenticated QA acceptance, real staff UAT, clinician/pharmacist/finance validation, 320–430 px mobile layouts, Arabic RTL/English LTR, physical printing, and controlled release decision. The medication engine remains a non-clinical foundation until verified local source corpus, product identity, structured patient context and independent GP/pharmacist approval exist.

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
| Medication engine specification and evidence governance | [PR #252](https://github.com/crauch2088-source/roshan-health-hub/pull/252), pending review |

Historical phase checklists and old status snapshots have been moved to `docs/archive/MASTER_PLAN_HISTORY.md`. They are evidence, not current status.