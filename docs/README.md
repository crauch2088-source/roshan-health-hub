# Documentation index

Use this page to find the current authority. Do not treat every dated report as a live status source.

## Authority and precedence

1. **Roshan Constitution** — durable principles and delegated authority: `.specify/memory/constitution.md`.
2. **AGENTS.md** — repository execution rules and safety constraints.
3. **docs/MASTER_PLAN.md** — current strategic sequence, priorities and release gates.
4. **docs/PROJECT_STATE.md** — dated evidence snapshot; refresh live GitHub/Supabase/Vercel state before acting.
5. **specs/** — feature-specific requirements, contracts and acceptance criteria.
6. **GitHub Issues and PRs** — canonical work items, dependencies, review records and exact-head evidence.
7. **Dated reports and archive/** — historical evidence only; never override newer source, tests or live read-only verification.

If two records conflict, prefer the newest directly verified source or live evidence, preserve the discrepancy, and update the canonical record. Do not silently copy a stale claim.

## Current working documents

| Document | Purpose |
|---|---|
| [MASTER_PLAN.md](MASTER_PLAN.md) | One roadmap and release sequence |
| [PROJECT_STATE.md](PROJECT_STATE.md) | Latest checked repository, Supabase, Vercel and release state |
| [TASK_REGISTRY.md](TASK_REGISTRY.md) | GitHub work-item routing, priorities and PR cleanup disposition |
| [VERIFICATION_MATRIX.md](VERIFICATION_MATRIX.md) | Evidence required by domain and risk |
| [ARCHITECTURE_DECISIONS_2026-11-25.md](ARCHITECTURE_DECISIONS_2026-11-25.md) | Second review, architecture choices and external research |
| [CLINICAL_GUIDELINE_POLICY_AND_ICD10_RECOMMENDATION_2026-11-20.md](CLINICAL_GUIDELINE_POLICY_AND_ICD10_RECOMMENDATION_2026-11-20.md) | Proposed clinical-content governance; not activation approval |
| [ROSHAN_FULL_PROJECT_REVIEW_AND_EXECUTION_ROADMAP_2026-11-24.md](ROSHAN_FULL_PROJECT_REVIEW_AND_EXECUTION_ROADMAP_2026-11-24.md) | First full-project audit plus 2026-11-25 re-review addendum |
| [48H_ACCELERATED_EXECUTION_CHARTER.md](48H_ACCELERATED_EXECUTION_CHARTER.md) | Owner-approved time-boxed execution constraints; not a current status report |
| [ROSHAN_AGENT_SKILLS_SYSTEM.md](ROSHAN_AGENT_SKILLS_SYSTEM.md) | Agent-neutral specialist skill routing |

## Feature and technical specifications

- `specs/` contains feature specifications and design artifacts. Check the relevant spec before changing application behavior.
- `db/` and `db/tests/` contain SQL migrations, fixtures and database integration assertions.
- `tests/` contains application/source contract and focused regression tests.
- `.github/workflows/` defines exact-head CI and PostgreSQL integration routing.

## Historical material

`docs/archive/` preserves superseded plans, old execution snapshots and early phase reports without deleting their content. Root-level legacy report paths are retained as short compatibility pointers. Historical records are useful for provenance, not for declaring current readiness.

Do not create another master plan, execution ledger, parallel status spreadsheet or duplicate task list. Update the single canonical document or GitHub item that owns the information.