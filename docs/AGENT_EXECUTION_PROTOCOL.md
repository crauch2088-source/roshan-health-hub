# Roshan Health Hub — Agent Execution and Handoff Protocol

**Purpose:** make work resumable across agents and sessions, reduce repeated discovery, and prevent self-reported progress from being mistaken for verified delivery.

## 1. Session bootstrap

1. Read `docs/AGENT_START_HERE.md`.
2. Refresh `docs/PROJECT_STATE.md` from live GitHub; refresh Supabase/Vercel when the task touches those systems.
3. Read the current roadmap in `docs/MASTER_PLAN.md` and the canonical GitHub Issue/PR.
4. Read `AGENTS.md`, this protocol, and only the relevant specialist skill/spec/test files.
5. Do not load `docs/archive/**` unless a specific historical decision or migration provenance question requires it.

Never treat a prior conversation, status snapshot, CI run on another SHA, or dated tool-map note as current state.

## 2. Classify before acting

Record domain, risk, affected users, environment, data classification, authorization, and dependencies. Choose the smallest useful process:

- New/material feature: Spec Kit Specify → Plan → Tasks → Implement → Converge.
- Existing behavior defect: reproduce and scope the defect, then use the repository's existing bug-fix/test workflow; do not force a full feature-spec ceremony onto a one-line fix.
- Read-only investigation: define the question, evidence sources, and stop condition; do not create speculative implementation tasks.
- Documentation-only change: identify the authoritative source and downstream references; avoid unnecessary app builds/deployments.

Use the already pinned, agent-neutral Spec Kit integration. Do not install a second planning framework, change CLI versions, add paid agents, or require owner-side local setup for routine work.

## 3. Define the task contract

Use `docs/AGENT_TASK_CONTRACT_TEMPLATE.md` for non-trivial work. Identify one observable objective, non-goals, allowed/forbidden paths, dependencies, target environment, data classification, authority, acceptance criteria, verification commands, evidence, stop conditions, and recovery.

Do not begin a risky write while target, authority, dependencies, or recovery are unknown.

## 4. Plan and assign work

- One orchestrator owns task sequencing, scope, evidence, and final reporting.
- One builder owns each mutable file/path set. Do not let parallel agents edit the same SQL migration, shared reference file, or workflow.
- Parallelize independent read-only reviews or disjoint implementation scopes only after interfaces and file ownership are fixed.
- High-risk SQL/security/production work requires an independent reviewer who did not implement the change. The reviewer reads the contract, complete diff, source callers, tests, and evidence.
- A handoff must include task ID, exact base/head SHA, owned paths, findings, commands actually run, evidence links, unresolved questions, and next action.

## 5. Implement in bounded steps

1. Inspect live source, callers, schema, migrations, tests, and existing behavior before changing anything.
2. For behavior changes, write a regression test that demonstrates the missing/incorrect behavior before implementing the minimal complete fix.
3. Preserve clinical safety, least privilege, RLS, branch isolation, atomic finance/stock operations, idempotency, auditability, and exact amount precision.
4. Keep each logical change in one atomic commit containing implementation, tests, migration, and documentation as applicable.
5. Do not force-push, amend published commits, rewrite synced history, or overwrite another agent's branch.

## 6. Verify by risk, not habit

Use `docs/VERIFICATION_MATRIX.md` to select the smallest relevant checks, then applicable integrated checks. Run one exact-head CI pass after the coherent change is ready. Re-run only after the candidate changes or a real correction is made.

| Label | Meaning |
|---|---|
| PASS | Check ran on the exact candidate and met its assertion |
| FAIL | Check ran and exposed a defect |
| SKIP | Runner intentionally skipped it; not evidence of success |
| BLOCKED | Could not run because a dependency, permission, environment, or human action is missing |
| NOT_RUN | Not attempted |
| STALE | Evidence belongs to another SHA, environment, or expired snapshot |

Never collapse these states into one green percentage. A successful deploy is not clinical acceptance; CI is not staff UAT; a source-contract test is not a live database read-back.

## 7. Database and production gates

- Use disposable PostgreSQL 17 for deterministic migration/integration tests and QA for controlled synthetic acceptance.
- Never create synthetic patient, clinical, pharmacy, laboratory, inventory, or financial transactions in Production.
- The owner-approved reset of existing synthetic/test rows is durable and documented in Constitution Section X; do not ask for it again. Preserve project identity, Auth recovery, secrets, environment bindings, and essential platform settings.
- Before Production writes, verify exact project/ref, current ledger, complete diff, dependency inventory, recovery path, exact-head tests, grants/RLS/SECURITY DEFINER behavior, branch isolation, and zero-cost impact.
- Never edit the migration ledger to manufacture parity. Stop if migration provenance, backup/recovery, data classification, or target is uncertain.
- Clinical protocols, diagnoses, medication choices/doses/frequencies, and decision-support policy require explicit clinician-approved specifications.

## 8. Durable checkpoints and recovery

At a meaningful checkpoint, update only the canonical record:

- Live branch/PR/CI/deployment/ledger evidence → `docs/PROJECT_STATE.md`.
- Strategic sequence and release blockers → `docs/MASTER_PLAN.md`.
- Work item status, dependencies, acceptance criteria → canonical GitHub Issue/PR.
- Reusable workflow rules → this protocol or `AGENTS.md`.
- Historical execution narrative → `docs/archive/**`.

Do not write a diary of every tool call. Record decisions, evidence, blockers, and the next executable action. On resume, verify the recorded SHA before continuing.

## 9. Definition of done

A task is done only when contract acceptance criteria are met with evidence; required focused/integrated checks pass on exact candidate SHA; full diff and scope are reviewed; independent review is recorded when required; canonical docs/GitHub records reflect the result; and residual risks plus skipped/blocked/untested checks are explicit.

Merge, deployment, and clinical/staff acceptance are separate gates. Do not declare release readiness by inference.