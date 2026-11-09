# Engineering acceleration review — 2026-11-09

## Purpose and decision

This review identifies the highest-leverage ways to shorten Roshan Health Hub's path to a safe first-clinic release. It is based on the current repository files, open PR/issue search, current Production and QA Supabase project metadata, current migration ledgers, and live Supabase security/performance advisors.

**Decision:** Do not add another coding agent, graph index, browser framework, issue tracker, or CI platform now. The repository already has Spec Kit 1.2.6 (agent-neutral `none` integration), Roshan engineering skills/orchestrator, Graphify, TDD guidance, GitHub Actions, PostgreSQL 17 integration tests, Playwright/axe-core public-route checks, Dependabot, CodeQL, and connected GitHub/Supabase/Vercel/browser capabilities. The highest-value acceleration is to unblock the existing acceptance gates, close/triage the current PR queue, and measure CI before changing its structure.

## Verified current state

- Repository policy in `AGENTS.md` requires one atomic commit per logical task, one CI run per completed stage, no redundant Vercel builds, read-only batched Supabase diagnostics, and no unapproved Production changes.
- Spec Kit is already installed in the repository at CLI v1.2.6 with the agent-neutral `none` integration. `docs/MASTER_PLAN.md` remains the roadmap and source of truth.
- Graphify is already integrated as a local, code-only navigation aid; it is not a runtime dependency and must not be used as proof of SQL, RLS, clinical, or release correctness.
- The root package scripts include `test:guard`, `test:e2e`, and `test:e2e:public`. The public browser workflow uses pinned Playwright and axe-core packages in an ephemeral CI job. Do not add Playwright MCP as a second browser test stack.
- The main CI workflow already uses concurrency cancellation and npm caching. A prior execution-plan inventory recorded 21 jobs and 15 PostgreSQL service declarations; this merits timing analysis, not speculative consolidation.
- The repository already has a Dependabot weekly configuration for npm and GitHub Actions. Do not add Renovate in parallel.
- The 2026-11-04 GitHub Actions audit already ran actionlint 1.7.12 successfully across 24 workflow files and zizmor 1.32.0 offline, reducing 116 findings to one documented low-severity ephemeral browser-package finding. Do not add duplicate scanners/workflows without a demonstrated new gap.
- Open PR search shows the recent device-recovery documentation PR #201 and still-open work including #191 (Phase 57 pharmacy quantity guard), #189 (medicine catalogue identity), #179 (prescription printing), #181 (payment receipt printing), and #185 (future prescribing decision-support specification), plus older documentation/dependency PRs. PR #201 records the successful phone-side backup verification but remains open at this review.
- Production Supabase is active on PostgreSQL 17.6; QA is active on PostgreSQL 17.11. The recorded live migration heads are Production `20261102232941` and QA `20261104065852`. Phase 57 is QA-only; do not promote it based on CI alone.
- The backup/restore evidence is now stronger than the earlier release snapshot: PostgreSQL 17 isolated restore rehearsal passed, the encrypted artifact was transferred, and the owner verified SHA-256, age decryption, archive readability, and deletion of the temporary plaintext archive on Android. This closes the device-decryptability sub-gate, not clinical acceptance or Production Phase 57 authorization.

## Fresh read-only Supabase advisor observations — 2026-11-09

The Supabase security/performance advisors were queried separately for Production and QA. Findings are leads for review, not automatic instructions to change privileges or drop indexes.

### Security

- Both environments report `pg_trgm` installed in `public`.
- Both report `public.setup_required()` executable by `anon` as SECURITY DEFINER. This appears to be the intentional public setup-status RPC introduced by Phase 51; verify its body returns only non-sensitive setup state and retain its intended access if confirmed.
- Production reports 26 and QA 28 authenticated-executable SECURITY DEFINER functions. These include intended authenticated RPC write boundaries. Do not blanket-revoke them; verify each function's fixed search_path, internal authorization, branch scoping, and exact EXECUTE ACL.
- Production reports two private pharmacy idempotency tables with RLS enabled and no policies; QA reports one. This may be intentional service-only/private-schema access. Confirm schema exposure and grants before changing it.
- No advisor result by itself establishes exploitability. Compare each finding with migration source, function definition, grants, and intended API contract.

### Performance

- The advisor reports 95 unused indexes in Production and 143 in QA. These are low-traffic/test-environment observations, not sufficient evidence to drop indexes. Re-evaluate after representative clinic workload and inspect query plans/usage windows.
- Production reports two unindexed foreign keys on the legacy pharmacy idempotency table. Review whether the legacy table is retained/quarantined and whether any supported query or delete path needs the indexes before deciding.
- No index drops or schema changes are authorized by this audit.

## Highest-leverage acceleration plan

### P0 — Close existing release gates before starting new tooling

1. Merge PR #201 only after its exact-head checks pass; update Issue #199 so device-side recovery is marked complete while QA pharmacist acceptance, staff UAT, physical printing, live-ledger reconciliation, and Phase 57 release planning remain open.
2. Resolve the missing authorized synthetic pharmacist identity / Auth Admin path for isolated QA. Do not write directly to `auth.users`, add an improvised credential endpoint, or use Production as a test environment.
3. Run the persistent-QA pharmacist acceptance scenario for Phase 57 once that identity path is approved. Keep PR #191 Draft until that evidence and independent review exist.
4. Resolve the catalogue permission/branch-scope decision in PR #189. The current `pharmacy.update` mapping is broader than pharmacist-only, and the medicine catalogue is shared across branches. Do not call the physical-pack acknowledgement a persisted verification attestation.
5. Run the supported staff UAT sequence (reception → GP → lab → pharmacy → billing) and A4/mobile/RTL/LTR printing checks using synthetic QA data. Record pass, fail, blocked, and not-tested separately.
6. Reconcile the live Production and QA migration ledgers against canonical source mappings. Preserve quarantine evidence; never rewrite migration history or replay fixed-ID cleanup SQL blindly.

### P1 — Reduce cycle time with measurements, not another CI system

1. Capture the last 10–20 representative GitHub Actions runs: queue time, per-job duration, p50/p90, PostgreSQL startup, install time, failures and reruns.
2. Identify redundant PostgreSQL service startup and duplicated tests. Consolidate only suites that can share a disposable PG17 service while using isolated databases/schemas and deterministic cleanup.
3. Keep existing npm caching and concurrency cancellation. Do not add duplicate caches or unsafe workflow-level path filters that leave required checks pending.
4. Keep docs/SQL/script-only changes off Vercel frontend builds using the existing ignored-build/conditional-build policy.
5. Add any new check to an existing workflow/job only when it catches a specific uncovered risk; avoid multiplying workflows and required checks.

### P2 — Narrow optional tooling

- **Already done / do not duplicate:** actionlint, zizmor, Playwright, axe-core, Dependabot, CodeQL, Graphify, Spec Kit, agent skills.
- **Possible report-only evaluation:** Knip for unused files/exports/dependencies. First configure real TanStack/Vite entry points and compare false positives; never run auto-fix or delete exports in bulk. Defer until the release blockers are closed.
- **Possible targeted database addition:** pgTAP only for SQL/RLS/grant contracts not already covered by the existing disposable PostgreSQL 17 integration suite. Do not create a second test framework for already-covered behavior.
- **Defer GitHub Agentic Workflows (gh-aw):** current GitHub documentation describes Markdown-authored agent workflows in GitHub Actions, but this is not required for Roshan's current delivery path. It introduces a new agent runtime and write-output boundary; if later piloted, start with read-only issue triage or report generation, restrict allowed files/outputs, and require human review for every code/SQL/permission/production change.
- **Do not add:** another graph engine (GitNexus/Serena overlap and license/setup review), another browser stack (Playwright already exists), another CI platform, paid agent runner, or a parallel app.

## Automation model

Use the connected GitHub, Supabase, Vercel, and browser tools directly for read-only audits, source edits on isolated branches, atomic commits, PR creation/review, and exact-head verification. Parallelize independent read-only work (e.g. PR inventory, workflow-run timing, Supabase advisor queries); keep dependent writes sequential. Use the repo's existing TDD and Roshan orchestrator policies for behavior changes. A connected browser may assist with authorized UI acceptance, but cannot replace a suitable synthetic QA identity or staff sign-off.

No autonomous background process, permanent agent, or continuous production operator is created by this document. Repository access does not grant permission for Production migrations, Auth/Storage mutations, grants/RLS changes, business-data writes, deployment promotion, paid services, or clinical acceptance.

## Suggested acceptance metrics

- Every open PR has a current owner, status, dependency, and next action; stale duplicates are closed only after their contents are reconciled.
- Each release blocker has a named evidence artifact and is explicitly Passed / Failed / Blocked / Not tested.
- Exact-head CI is green with no intentionally skipped required acceptance test misreported as passed.
- CI p50/p90 is measured before and after any consolidation; no coverage loss or increase in flaky failures.
- Production/QA schema and migration differences are classified with source provenance; no unexplained critical drift remains.
- Staff UAT and printing are signed off separately from code/CI checks.

## Sources

- Current repository: `AGENTS.md`, `docs/MASTER_PLAN.md`, `docs/PLUGIN_TOOLING_MAP.md`, `docs/ROSHAN_AGENT_SKILLS_SYSTEM.md`, `docs/GITHUB_ACTIONS_SECURITY_AUDIT_2026-11-04.md`, `docs/ENGINEERING_TOOLING_ROADMAP_2026-10-24.md`, `docs/ROSHAN_ENGINEERING_IMPROVEMENT_EXECUTION_PLAN_2026-11-03.md`, `docs/RELEASE_GATE_RECHECK_2026-11-09.md`, open PRs #189/#191/#201, Issue #199.
- Official Spec Kit: https://github.github.com/spec-kit/
- Official GitHub Agentic Workflows: https://docs.github.com/en/actions/tutorials/develop-agentic-workflows-in-github-actions
- Supabase branching: https://supabase.com/docs/guides/deployment/branching
- Supabase database testing / pgTAP: https://supabase.com/docs/guides/local-development/testing/overview
- actionlint: https://github.com/rhysd/actionlint
- zizmor: https://github.com/zizmorcore/zizmor
- Knip: https://knip.dev/
