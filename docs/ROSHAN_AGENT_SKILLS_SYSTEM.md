# Roshan Agent Skills System

**Status:** Initial repository-local release candidate  
**Introduced:** 2026-11-04  
**Scope:** Engineering-agent guidance only. No application runtime, production service, model provider, or patient-data integration.

## Purpose
Provide repository-owned skills that teach agents to work safely and consistently in Roshan Health Hub. The orchestrator routes work to domain skills; specialists encode Roshan invariants that generic engineering skills cannot know.

## Inventory
| Skill | Responsibility |
|---|---|
| roshan-engineering-orchestrator | Entry point, task classification, routing, authority and completion protocol |
| roshan-architecture | Current architecture, domain boundaries, route/data-flow tracing |
| roshan-database | Supabase/PostgreSQL, migrations, RPC, grants, RLS and verification |
| roshan-clinical-safety | Clinical data fidelity, medication safety, clinician confirmation |
| roshan-security | Identity, role/permission, branch isolation, privacy and audit |
| roshan-pharmacy-laboratory | Medicine catalogue, inventory, dispensing, lab orders/results/verification |
| roshan-qa | Test selection, PostgreSQL 17, browser, mobile, RTL/LTR and acceptance |
| roshan-release | Branch/PR, exact-head CI, deployment and release gates |
| roshan-minimal-change | Evidence-led simplicity and dependency/abstraction discipline |

## Design inspirations
This is a Roshan-specific adaptation, not wholesale vendoring of third-party skill files.
- [Addy Osmani — Agent Skills](https://github.com/addyosmani/agent-skills): selected workflow concepts for planning, incremental implementation, source-driven work, testing, review, security and shipping. Upstream is MIT-licensed.
- [Ponytail](https://github.com/DietrichGebert/ponytail): simplicity/YAGNI discipline and skepticism toward unnecessary code, dependencies and abstractions. Only general engineering ideas are adapted; its skill text is not copied. Upstream is MIT-licensed.
- Existing AGENTS.md, Spec Kit Constitution, docs/MASTER_PLAN.md, tests and operating map remain authoritative. Installed general TDD/debugging/security/documentation skills complement rather than replace Roshan skills.

## Authority and precedence
1. Explicit owner-approved project/release gates and live source/database evidence.
2. .specify/memory/constitution.md for durable principles.
3. docs/MASTER_PLAN.md for roadmap and sequencing.
4. AGENTS.md for repository operating policy.
5. Feature specs and verified implementation contracts.
6. These skills as execution guidance.

If a skill conflicts with a higher-level source, follow the higher-level source and correct the skill in a reviewed change. Skills never authorize production operations.

## Usage
1. Start with roshan-engineering-orchestrator.
2. Read only relevant specialist skills.
3. Use installed TDD skill for behavior changes; write a failing regression test before implementation.
4. Use existing CI/test scripts; avoid duplicate workflows and unnecessary Vercel builds.
5. Keep one coherent task in one branch/atomic commit, including implementation, tests and docs.
6. Report exact evidence and unresolved gates; never claim skipped/unperformed checks passed.

## Graphify integration
Graphify is already integrated in `.agents/skills/graphify/SKILL.md` and `docs/GRAPHIFY_INTEGRATION.md`. Reuse that skill; do not create a duplicate.
- Route it selectively for cross-layer discovery, multi-hop dependency tracing, broad refactors, and pre-change impact analysis.
- Skip it for isolated edits and simple symbol lookups.
- Use current-branch, local `--code-only` graphs as navigation leads only; verify material findings against source, migrations, SQL definitions, and tests.
- Keep graph artifacts local/ignored. Never process real patient/financial data, secrets, credentials, or `.env` files; never connect Graphify to Production PostgreSQL.
- Do not make it a CI requirement or an application dependency.

## External tooling research
See [Agent Tooling Research — 2026-11-04](AGENT_TOOLING_RESEARCH_2026-11-04.md) for the comparative review of Graphify, GitNexus, Serena, Agent Skills, and the currently connected ChatGPT apps. That document records evaluated options and explicitly rejected additions to avoid overlapping tools and recurring cost.

## Safety boundaries
- No real patient, clinical, financial, staff identity, credential, private key, or production export data in prompts, fixtures, logs, screenshots, issues, or external model services.
- No production migration, grant/RLS change, Auth/Storage mutation, business-data write, deployment promotion, or clinical acceptance from skill instructions alone.
- No automatic medication route/dose/frequency/duration/indication inference. Catalogue identity is not a prescribing guideline.
- Preserve branch isolation, immutable finance/stock ledgers, atomic RPC boundaries, idempotency, auditability, and explicit missing-value handling.
- No frontend dependency, runtime, paid service, or external agent integration is introduced.

## Maintenance
Keep skills concise, task-triggered and operational. Add a skill only when it owns a distinct repeatable workflow or invariant. Prefer updating an existing skill over overlapping skills. Update contract tests whenever inventory or mandatory safety language changes. Review skills against current source and release policy at major architecture changes.
