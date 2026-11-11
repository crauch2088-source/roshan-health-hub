# Execution policy — quota-safe, atomic delivery

These rules govern every Roshan Health Hub task and override older conflicting workflow notes.

1. **One atomic commit per logical task.** Prepare the complete implementation, tests, and documentation together; create one Git tree, one commit, then advance the branch ref with an expected-SHA lease. Never split a single task into repeated test/fix/docs commits.
2. **One CI run per completed stage.** Finish the coherent change bundle before pushing and triggering CI. If CI fails, fix the actual failure and rerun only the necessary validation; do not create redundant commits merely to iterate on formatting or documentation.
3. **Protect free Vercel quota.** Documentation-, SQL-, migration-, and script-only commits must skip frontend builds. Always squash-merge PRs. Never bypass quota limits, deploy unnecessarily, or upgrade paid services.
4. **Batch read-only Supabase diagnostics.** Combine catalog, migration-ledger, policy, and role checks into one read-only CTE/JSON query wherever practical. Do not run repeated equivalent diagnostics; never use production as a synthetic test database.
5. **Closed phases stay closed.** Do not re-verify or reopen Phases 29–33 unless relevant code or migration content changes, or new evidence identifies a concrete regression.
6. **Consolidate database changes.** Prefer one comprehensive migration per logical phase. Use an Expand/Contract pair only when compatibility or deployment sequencing demonstrably requires it. Keep baseline fixtures and CI assertions aligned; never apply candidate migrations to production without an explicit release gate.
7. **Resolve conflicts without rewriting published history.** Preserve newer main safety fixes, merge main into the existing feature branch with a normal fast-forwardable merge commit, then squash-merge. Never force-push or amend published commits.

---

<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->


## Phase 34 release gate

- Keep all Phase 34 SQL, TypeScript, tests, and docs in one atomic tree commit on `feat/phase34-consolidated-realtime-storage-lab-verify`.
- Do not apply the candidate to production unless the exact PR head passes all GitHub Actions checks. Keep behavior tests isolated on disposable PostgreSQL 17; no production test data.
- Never use direct table writes to mark lab orders verified. Use `verify_lab_order(uuid)` only. Preserve the append-only audit contract.


## Phase 34 manual database gate

- Supabase MCP migration application returned `must be owner of table objects`; a batched post-failure read-only query confirmed no partial Phase 34 schema or migration-ledger changes.
- Do not enable `VITE_ROSHAN_PHASE34_ENABLED` until the full consolidated SQL file has been executed successfully by the table-owning role in Supabase SQL Editor and a read-only post-apply diagnostic confirms the buckets, publication membership, verification columns/RPC and audit protections.

## Graphify knowledge-graph workflow

- Graphify is an **optional local developer/agent aid**, not a runtime dependency of the Roshan application. Do not add it to the frontend package dependencies or production deployment.
- For repository-wide architecture questions, consult the generated Graphify graph first when `graphify-out/graph.json` exists; then verify important conclusions against source files, migrations, and tests. Treat graph edges marked inferred as hypotheses, not facts.
- Build or refresh the graph locally using `docs/GRAPHIFY_INTEGRATION.md`. Never commit generated graph output by default, and never upload real patient data, credentials, `.env` files, private keys, or production exports to Graphify or any model.
- Keep the graph scoped to source, migrations, schemas, documentation, and safe configuration examples. Exclude secrets, local environment files, build output, dependency directories, backups, and any real clinical/financial records.
- Graphify does not replace TypeScript checks, tests, migration-parity checks, RLS/security review, or read-only verification against Supabase. Do not run its generation in every CI job or trigger a Vercel deployment solely to refresh the graph.

## Spec Kit — agent-neutral specification policy

- This repository uses GitHub Spec Kit CLI v1.2.6 with the official none integration. Do not add an agent-specific integration, IDE plugin, coding-agent CLI, model credential, or agent runtime as a project requirement.
- The committed .specify/ directory is the shared Spec Kit baseline: official scripts, templates, workflow metadata, and the Roshan Constitution. specify integration status must report OK, with none as the only installed and default integration.
- docs/MASTER_PLAN.md remains the execution roadmap and project-level source of truth. AGENTS.md contains operational instructions; .specify/memory/constitution.md contains durable principles; specs/ contains feature-specific requirements and design artifacts. Do not duplicate the roadmap.
- For non-trivial features, clarify user-visible behavior and acceptance criteria in spec.md before technical planning. Produce plan.md and tasks.md only after requirements and existing implementation contracts are understood.
- ChatGPT operates directly on the connected GitHub repository to inspect, author, commit, and review project artifacts. The none integration intentionally installs no agent commands; no local agent setup or owner-operated terminal workflow is required.
- Every accepted requirement must map to observable verification: focused regression tests, security/authorization checks, disposable PostgreSQL 17 tests where relevant, and exact-head CI evidence. Never mark a task complete merely because its document exists.
- Never transmit real patient, clinical, financial, identity, credential, or production-export data to any model or external service. Use synthetic fixtures only.
- A Spec Kit task never authorizes production SQL/migration, Auth/Storage mutation, deployment, or live clinical/financial data changes. Preserve separately documented owner authorization and release gates.
- Keep work quota-aware: avoid redundant CI runs, do not add production dependencies for development tooling, and keep each logical change in one atomic commit.


## Roshan Agent Skills — routing policy

- For non-trivial engineering work, begin with .agents/skills/roshan-engineering-orchestrator/SKILL.md, then load only the relevant specialist skill(s).
- Skill files are repository-local execution guidance, not a new source of truth and not an authorization mechanism. Precedence remains owner-approved release gates, the Spec Kit Constitution, docs/MASTER_PLAN.md, this file, feature specs, then skills.
- Use docs/ROSHAN_AGENT_SKILLS_SYSTEM.md for inventory, routing, upstream inspiration, and maintenance policy.
- Use installed general TDD/debugging/security/documentation skills when they add distinct value; avoid duplication and overlapping Roshan skills.
- Simplicity/YAGNI must never weaken clinical safety, data fidelity, clinician confirmation, authentication, permissions, RLS, branch isolation, auditability, atomic finance/stock operations, or test coverage.
- Skills do not authorize Production migrations, grants/RLS changes, Auth/Storage mutations, live business-data writes, deployment promotion, paid services, or clinical/staff acceptance.


## Work-closure protocol — owner-approved 2026-11-11

These rules govern every Roshan task. They override conversational momentum and informal progress claims.

1. **Close work, do not accumulate phases.** Select one primary workstream with explicit acceptance criteria. Parallelize only genuinely independent tasks with non-overlapping files and contracts.
2. **Definition of done.** A task is complete only when observable acceptance criteria are met, behavior changes have regression tests, required checks pass on the exact current commit, the diff is reviewed, and the documentation records evidence and remaining external gates.
3. **Exact-head evidence.** CI on an ancestor commit never certifies a newer head. Record the exact SHA, workflow/run, passed/failed/skipped jobs, and intentional skip reasons. A Vercel status is not a substitute for CI or clinical acceptance.
4. **Failure closure.** Retrieve failing job logs, identify the concrete cause, fix only that cause, and rerun affected checks plus required dependent gates. Never relabel a failed check as passed.
5. **No false completion.** Code written, a PR opened, a migration authored, a passing test subset, or a preview does not itself complete a phase. Distinguish engineering readiness, database rollout, clinical review, staff/device acceptance, and production release.
6. **No unsupported percentages or dates.** Recalculate progress from documented weighted acceptance gates. Keep Engineering RC and Operational Acceptance separate. If a defensible re-weight is unavailable, say so rather than recycling a historical percentage or inventing an ETA.
7. **Protect production and quotas.** No production DDL/DML, migration, Auth/Storage/ACL/RLS mutation, deployment promotion, paid upgrade, or quota bypass without separate authorization. When the Vercel free daily limit is exhausted, stop preview retries and continue verifiable work that does not require deployment.
8. **Atomic delivery.** Bundle source, tests and relevant documentation into one logical commit. Preserve published history, use expected-SHA ref updates, and squash-merge only after exact-head checks and review.
9. **User reporting.** Report concrete artifacts, commit/PR links, actual test results, untouched areas and blockers. Do not substitute status narration for work.

### Session baseline discovered 2026-11-11

- PR #233 is open and Draft; inspected head: `c288390cfe4a697bb42e5d6d0ead863dfd4ac597`.
- Exact-head CI run `43090861346` failed at lint due to five Prettier errors in `src/lib/medication-engine/protocol-matcher.ts`. Typecheck, security audits, role-guard tests and the other listed integration jobs passed; build was skipped after lint failure.
- Insurance claim UI validation run `43090861400` passed its focused insurance tests but failed its combined typecheck/lint/build step because the same shared lint errors remained. This is not evidence of an insurance-behavior defect.
- Vercel reported the free daily deployment cap (`api-deployments-free-per-day`). No retry or quota bypass is authorized.
- No clinical protocol was activated and no hosted Supabase DDL/DML, production data, Auth, Storage, role or ACL mutation was performed during this inspection.
- This baseline is superseded only by a new exact-head result after the formatting repair; the failed run remains historical evidence and must not be described as green.


### Follow-up exact-head validation — 2026-11-11

- Commit `528bc3caddef708111de1ffd92796750a992797c` corrected four of the five Prettier findings. Its exact-head CI run `43092737006` still failed on one remaining status-union formatting line in `protocol-matcher.ts`; typecheck and all completed security/PG17/integration jobs passed, while build was skipped after lint failure.
- Insurance validation run `43092736912` passed its focused tests but failed the combined lint/build gate on the same single Prettier issue.
- The remaining formatting correction is included in the next commit. Do not count this as fixed until exact-head lint/build and all required workflows finish successfully.


### Second formatter correction — 2026-11-11

- Exact-head run `43093172320` completed with 27 successful checks, one intentional authenticated clinical-acceptance skip, and one lint failure: Prettier requires the protocol status union's first line to begin on the line after the assignment. The separate insurance aggregate run failed on the same one-line formatting issue; its focused tests passed.
- All other completed checks, including CodeQL and applicable PostgreSQL 17 integration workflows, passed. The remaining issue is formatting-only; no clinical or insurance behavior regression was reported.
- The exact formatter layout is now corrected in the following commit. Final acceptance still requires a fresh exact-head CI and the insurance validation workflow.
