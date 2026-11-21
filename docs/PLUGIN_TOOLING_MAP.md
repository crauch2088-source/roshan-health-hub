# Roshan Health Hub — Integration Routing Map

**This file describes when to use integrations, not whether a connection is currently active.** Verify live connection, account, scope, and permissions before every external write.

## Current project state

Do not duplicate branch, PR, migration, deployment, or backup status here. Use `docs/PROJECT_STATE.md` and refresh the underlying service before relying on it.

## Routing

| Capability | Use it for | Required safeguards |
|---|---|---|
| GitHub native connector | Repository files, commits, branches, Issues/PRs, reviews, Actions | Fetch live refs; bind CI to exact SHA; use atomic commits and expected-SHA ref updates; no force-push |
| Composio | Cross-app orchestration or a GitHub action missing from the native connector | Search tools first, follow returned plan, inspect full schemas, confirm active connection/account; sequence dependent actions |
| Supabase | Schema, migration ledger, grants, RLS, RPCs, Auth/Storage, advisors | Verify exact project ref; read before write; test in disposable PG17/QA; Production follows Constitution Section X; never expose secrets |
| Vercel | Canonical project, alias, deployment, environment and logs | Verify project/branch/environment/SHA and quota; no forced deployment, quota bypass, duplicate project, or paid upgrade |
| Browser automation | Defined route, permission, and workflow acceptance | Use synthetic QA identities/data; state whether actions are read-only or mutating; inspect postconditions; no Production synthetic transactions |
| Firecrawl / web research | Broad documentation, repository, and evidence research | Prefer official/primary sources; record URL/date/version; distinguish source claims from repo-verified facts |
| Context7 | Version-sensitive React, TanStack, Supabase, Vite, and library APIs | Match installed package version; examples are not proof; add tests |
| Graphify | Cross-module call paths, data flow, blast radius | Optional local code-only analysis; verify findings against source/tests; never use as proof of SQL/RLS or clinical safety |
| Figma / Product Design | Specific UX audit, design handoff, or flow redesign | Optional; source of truth remains this repository; do not block urgent engineering work |
| Drive / Gmail / Slack | A specific authorized backup transfer or communication | No plaintext dumps, credentials, patient data, or unsolicited messages; verify recipient and scope |

## Efficient execution rules

1. Use one source of truth: GitHub Issues/PRs for tasks, `MASTER_PLAN.md` for roadmap, `PROJECT_STATE.md` for live snapshot, Constitution for authority.
2. Do not add a service, integration, dependency, agent, or workflow unless it removes a demonstrated blocker or materially improves assurance.
3. Prefer already-connected and free capabilities. No paid resources, quota bypasses, or new recurring services without explicit cost authorization.
4. For code, inspect source and tests first; use repository TDD and QA skills; run focused checks before the applicable integrated suite.
5. For clinical research, preserve authoritative source, guideline/version/date, population, contraindications, and clinician review owner. Research does not authorize a clinical policy change.
6. Never transmit real patient, clinical, financial, staff identity, credential, or production-export data to external research or agent services.

## Specialist routing

- SQL, migrations, RPC, grants, RLS: `roshan-database` + `roshan-security` + relevant domain skill.
- Clinical records, medication, diagnosis, decision support: `roshan-clinical-safety` + `roshan-qa`; clinician-approved specification required.
- Pharmacy/laboratory: `roshan-pharmacy-laboratory` + `roshan-clinical-safety` + `roshan-qa`.
- UI, navigation, mobile, RTL/LTR: `roshan-architecture` + `roshan-qa`.
- Release, CI, deployment, backup: `roshan-release` + `roshan-security` + `roshan-qa`.

Historical connection snapshots and dated execution notes are preserved in `docs/archive/PLUGIN_TOOLING_HISTORY.md`. They must not be used as evidence of current connection or service state.