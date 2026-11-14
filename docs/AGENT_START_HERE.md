# Agent start here — Roshan Health Hub

Use this as the only entry point. Do not begin by reading the historical execution archive or the entire database/tooling history.

## Read in this order

1. `.specify/memory/constitution.md` — read the full file for release, security, clinical, data, or production work; otherwise consult applicable principles and authority sections.
2. `docs/PROJECT_STATE.md` — current snapshot of main, active PR, exact-head checks, open gates, and freshness limits. Refresh mutable facts from live systems.
3. `docs/MASTER_PLAN.md` — concise roadmap, current blockers, and release sequence.
4. `AGENTS.md` and `docs/AGENT_EXECUTION_PROTOCOL.md` — mandatory execution and handoff rules.
5. `docs/TASK_REGISTRY.md` — find canonical GitHub Issues/PRs; never duplicate their backlog.
6. `docs/VERIFICATION_MATRIX.md` — select focused and integrated evidence for the task.
7. The relevant GitHub Issue/PR, feature spec, source, schema/migration, callers, tests, and only the necessary specialist skill.
8. `docs/PLUGIN_TOOLING_MAP.md` only when an external integration is needed. Refresh connection state before use.

## First five minutes of every session

- Fetch live `main` SHA, active branch/PR head/state, branch comparison, changed files, reviews, review threads, exact-head CI, Vercel status when relevant, and open GitHub Issues/PRs.
- Compare live values with `docs/PROJECT_STATE.md`; correct stale facts rather than repeating them.
- Select one canonical task and identify acceptance evidence, dependencies, allowed paths, environment, and authority.
- Inspect relevant source, callers, database contracts, migrations, and tests before planning.
- Verify exact target project/ref and recovery path before any external write.
- If a task is blocked, continue independent safe work rather than repeatedly retrying the same dependency.

## Non-negotiable facts

- Existing rows in both QA and Production are synthetic/test data. The owner explicitly authorized resetting those existing rows and rebuilding affected schema objects under Constitution Section X. Do not ask for this authorization again.
- This authority does not permit creating new synthetic patient, clinical, pharmacy, laboratory, inventory, or financial transactions in Production.
- Preserve Supabase project identity, Auth access/recovery, credentials/secrets, environment bindings, deployment configuration, integrations, and essential platform settings.
- Production engineering authority is delegated only within Constitution Section X and its preflight, recovery, exact-head validation, security, zero-cost, and post-change safeguards.
- Clinical protocols, diagnoses, medication choices/doses/frequencies, and decision-support policy require clinician approval.
- Green CI, merge, deployment, and code review are not clinical/staff acceptance or launch approval.
- Report engineering release-candidate completion separately from real-world operational readiness.

## Historical references

`docs/archive/MASTER_PLAN_HISTORY.md`, `docs/archive/PLUGIN_TOOLING_HISTORY.md`, and dated release reports are historical records. Open them only when a specific past decision, migration provenance, or incident must be traced.