---
name: roshan-engineering-orchestrator
description: Entry point for engineering work in Roshan Health Hub. Classify tasks, load only necessary Roshan skills, preserve authority boundaries, and require evidence before completion.
---

# Roshan Engineering Orchestrator

## Mandatory orientation
1. Read AGENTS.md and the relevant current section of docs/MASTER_PLAN.md.
2. Read .specify/memory/constitution.md for requirements, clinical, security, architecture, or release work.
3. Inspect current GitHub main SHA, relevant open PRs/issues, exact source and tests.
4. Check docs/PLUGIN_TOOLING_MAP.md before invoking integrations. Prefer existing connected capabilities.
5. Keep concurrent branches independent; never rewrite published history or overwrite another PR.

## Skill routing
Load only the smallest useful set:
- Any non-trivial task: roshan-architecture.
- Database, SQL, migration, RPC, grants, RLS: roshan-database + roshan-security; add clinical-safety or pharmacy-laboratory where relevant.
- Clinical records, diagnoses, observations, prescriptions, certificates: roshan-clinical-safety + roshan-qa.
- Pharmacy, medicine catalogue, dispensing, laboratory: roshan-pharmacy-laboratory + roshan-clinical-safety + roshan-qa.
- Authentication, permissions, branch scope, privacy: roshan-security + roshan-database + roshan-qa.
- UI, navigation, mobile, RTL/LTR: roshan-architecture + roshan-qa.
- PR, CI, deployment, release: roshan-release + roshan-security + roshan-qa.
- Refactoring, dependencies, abstraction, performance: roshan-minimal-change plus the affected domain skill.

Use installed general TDD, debugging, security-review, and documentation skills when they add distinct method. Do not duplicate generic instructions.

## Graphify routing
Graphify is already integrated in `.agents/skills/graphify/SKILL.md`; reuse that skill rather than creating a second Graphify skill or duplicating its setup instructions.

Consult Graphify when all of the following are true:
- The question spans multiple modules or layers, or asks for broad architecture/onboarding context.
- Dependency tracing, call paths, data flow, or change blast-radius analysis could materially reduce missed relationships.
- A local graph generated from the relevant current branch is available, or the documented local CLI can be run safely.

Typical triggers:
- Cross-layer flows (UI → service/RPC → SQL/schema → tests).
- Broad refactors, shared contract changes, dependency upgrades, or architecture changes.
- Debugging that crosses several modules or follows a multi-hop call/data path.
- Pre-change impact analysis for a non-trivial PR.

Do not invoke Graphify for a small isolated edit, a straightforward symbol lookup, or a task whose relevant source and tests are already clear. If no current graph or CLI is available, continue with targeted source search; Graphify is an aid, never a blocker.

Graphify operating constraints:
1. Use the existing Roshan Graphify skill and `docs/GRAPHIFY_INTEGRATION.md`; default to local `--code-only` processing.
2. Confirm the graph corresponds to the current branch and meaningful source changes before relying on it. Do not assume an ignored local `graphify-out/` artifact exists or is fresh.
3. Use graph queries to discover candidate files, callers, paths, and affected modules; then verify each material conclusion in source code, SQL definitions, migrations, tests, and current CI.
4. Treat inferred or low-confidence edges as hypotheses. Record gaps and parser warnings when they affect the conclusion.
5. Never use Graphify as proof of RLS/grants, SQL correctness, transaction atomicity, clinical safety, or release readiness. Inspect authoritative database definitions and tests directly.
6. Do not send production data, patient/financial records, credentials, tokens, or `.env` content to Graphify or any model. Do not connect it to Production PostgreSQL.
7. Do not add a Graphify dependency to the application, a paid/hosted graph service, or graph generation to every CI run. Refresh locally only when the expected benefit justifies it.

## Execution protocol
1. Classify domain, risk, affected users, data boundaries, and behavior impact.
2. Inspect implementation, neighboring tests, database contracts, flags, and live release gates.
3. For non-trivial user-visible work, use existing Spec Kit artifacts and mark unknowns.
4. Plan the smallest complete change, tests, risks, and non-goals.
5. For behavior changes, write a failing regression test before implementation. For docs/policy-only changes, add contract checks where they prevent drift.
6. Implement narrowly while preserving established contracts.
7. Run focused tests, then applicable full guard/type/lint/build/integration checks.
8. Review full diff for safety, privacy, scope creep, and workflow impact.
9. Follow one-atomic-commit policy; report exact SHA, CI evidence, and remaining gates.

## Authority boundaries
- MASTER_PLAN.md is roadmap; AGENTS.md is operating policy; Constitution is durable principles; specs are feature requirements. Skills are guidance only.
- Repository-work authorization does not automatically authorize production migrations, data writes, grants/RLS changes, Auth/Storage mutation, deployment promotion, paid services, or clinical acceptance.
- Never put real patient, clinical, financial, staff identity, credential, private-key, or production-export data in prompts, fixtures, logs, issues, screenshots, or external services. Synthetic fixtures only.
- Never claim clinical safety or acceptance solely from code, tests, CI, or deployment. Staff acceptance and clinical release gates are separate.
- Preserve immutable finance/stock ledgers, atomic RPC boundaries, idempotency, exact monetary precision, branch attribution, RLS, audit history, and explicit missing-value handling.
- Do not add runtime, package, CI workflow, external service, or model provider merely to make agent orchestration elaborate.

## Completion report
Report scope; branch/PR/exact commit; files changed; tests actually run and results; security/clinical/database/deployment impact; deliberately untouched areas; remaining blockers. Never report skipped or unperformed checks as passed.
