# Roshan Health Hub — agent operating rules

Read `docs/AGENT_START_HERE.md` first. It routes to the current state, roadmap, execution protocol, and only the specialist references needed for the task.

## Authority and source-of-truth order

1. Owner-approved decisions and durable safety/authority rules in `.specify/memory/constitution.md`.
2. Live GitHub/Supabase/Vercel evidence, refreshed before relying on mutable state.
3. `docs/PROJECT_STATE.md` for the latest verified session snapshot (cache only; refresh it).
4. `docs/MASTER_PLAN.md` for strategic roadmap and release sequence.
5. This file and `docs/AGENT_EXECUTION_PROTOCOL.md` for execution mechanics.
6. GitHub Issues/PRs for canonical task status and acceptance criteria.
7. Feature specs, migration manifests, tests, and specialist skills for implementation detail.
8. Archived logs and dated integration notes are historical evidence only.

If sources conflict, prefer newer verified live evidence and the latest explicit owner decision. Record and reconcile the conflict; do not silently choose a stale note.

## Mandatory execution behavior

- Refresh main SHA, active branch/PR head, reviews, exact-head CI, and open Issues/PRs at session start. Recheck target identity before every external write.
- Use the Task Registry to find canonical GitHub work; do not create duplicate Markdown backlogs.
- Use `docs/AGENT_TASK_CONTRACT_TEMPLATE.md` for non-trivial tasks and `docs/VERIFICATION_MATRIX.md` to choose evidence.
- Inspect relevant implementation, schema, migrations, callers, tests, and dependencies before planning a change.
- For behavior changes, use test-first development: add a regression test, implement the smallest complete fix, then verify focused and integrated behavior.
- Batch each logical task into one atomic commit containing code, tests, migrations, and documentation as applicable.
- Run focused validation first, then one exact-head CI run after the complete change is ready. Rerun only checks needed after a real correction.
- Report `PASS`, `FAIL`, `SKIP`, `BLOCKED`, `NOT_RUN`, and `STALE` separately. Never call a skipped check a pass.
- Use disposable PostgreSQL 17 for migration replay and integration tests. Use QA for controlled synthetic acceptance. Never create synthetic patient/clinical/pharmacy/lab/inventory/financial test transactions in Production.
- Production engineering changes follow Constitution Section X, including preflight, recovery, exact-head, security, zero-cost, and post-change gates. Existing synthetic/test-row reset authority is durable; do not ask the owner to repeat it.
- Preserve migration history and provenance. Never edit the ledger to manufacture parity, weaken RLS/auth/audit/branch isolation, or expose secrets or real patient data.
- Protect free-tier limits: no paid services, quota bypasses, unnecessary builds/deployments, duplicate integrations, or forced retries.
- Do not force-push, amend published commits, or rewrite synced history. Use expected-SHA ref updates.
- Continue independent safe work when one task is blocked. Do not repeatedly retry a failing tool path; switch to a supported route or report the precise blocker.

## Clinical and operational boundaries

- Never invent or clinically approve diagnoses, medication choices, doses, frequencies, contraindications, or decision-support rules. Implement only clinician-approved specifications and authoritative, versioned evidence.
- A green CI run, merged PR, successful deployment, or code audit is not clinical/staff acceptance.
- Do not declare launch readiness until real staff workflow, clinical acceptance, security, backup/restore, and operational release gates are evidenced.
- Report engineering completion separately from operational readiness. Count only deduplicated, evidence-backed requirements; audits and documentation alone do not count as implementation completion.

## Specialist guidance

- For non-trivial work, read `.agents/skills/roshan-engineering-orchestrator/SKILL.md` and only relevant specialist skill(s).
- Use installed TDD/debugging/security/documentation skills when they add distinct value; avoid overlapping workflows.
- Graphify is optional analysis tooling only. It is not a runtime dependency and never replaces source/test/database verification.
- Spec Kit is agent-neutral and already integrated; use the pinned repository baseline. Do not add another planning framework or paid model/agent.