# Roshan Health Hub

**Purpose:** a real, low-cost medical-center ERP/EMR for Roshan Medical Center in Hay Al-Sadaqa, Al-Hasahisa, Gezira, Sudan. This repository is the single application; do not create a parallel/replacement app.

> **Continuity rule:** start every work session by reading this README, then `docs/MASTER_PLAN.md`, `docs/DB_MIGRATION_RECONCILIATION.md`, and `docs/PLUGIN_TOOLING_MAP.md`. Re-check the live repository/PR/CI state before acting because this file is a maintained snapshot, not a substitute for current tool evidence. After each meaningful batch, update this README and the master plan with verified outcomes, commit/PR links, test evidence, blockers, and next actions.

- **Repository:** https://github.com/crauch2088-source/roshan-health-hub
- **Master plan (detailed execution source of truth):** [docs/MASTER_PLAN.md](docs/MASTER_PLAN.md)
- **Database migration reconciliation:** [docs/DB_MIGRATION_RECONCILIATION.md](docs/DB_MIGRATION_RECONCILIATION.md)
- **Per-migration source parity manifest:** [docs/recovered-migrations/source-parity-report.json](docs/recovered-migrations/source-parity-report.json)
- **Security PR review:** [docs/SECURITY_PR_REVIEW.md](docs/SECURITY_PR_REVIEW.md)
- **Tool/integration map:** [docs/PLUGIN_TOOLING_MAP.md](docs/PLUGIN_TOOLING_MAP.md)
- **Archived original product brief:** [docs/ORIGINAL_PRODUCT_BRIEF.md](docs/ORIGINAL_PRODUCT_BRIEF.md)
- **Production domain historically verified:** https://roshan-health-hub.vercel.app/

**Snapshot:** 2026-10-17 (UTC). Re-verify before relying on status below.

## 1. Current project snapshot

- **Application:** React + TypeScript + Tailwind CSS, TanStack Start, Supabase, Vercel; `package.json` specifies Node.js `22.x`. Mobile-first, Android-installable PWA, Arabic RTL and English LTR.
- **Clinic status:** one branch is active/planned for initial rollout; branch two is not open. Owner reports current stored patient/finance records are manually created synthetic test data, not real operational records. Still treat the connected Supabase project as production and verify target/environment before every mutation.
- **Latest known `main` documentation commit:** [`09dc07e`](https://github.com/crauch2088-source/roshan-health-hub/commit/09dc07ec4efe72657e3e30ae318170cb77f02099), which records the full 93-entry SQL source comparison. Preceding commits `90c30ea`, `77a5bf2`, and `ae45a40` also updated documentation only. No application code or database was changed by these commits; recheck main before relying on this snapshot.
- **Current check evidence:** on `4d141ca`, all 11 reported check runs completed successfully, including CodeQL [run #39018693474](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39018693474). Documentation commits after that triggered new checks; the latest status lookup on `09dc07e` reported a Vercel status failure linking to the team build-rate-limit page, while fresh GitHub check runs were still in progress at last poll. Do not claim the latest docs SHA fully green until the runs complete. CI and deployment status are separate.
- **Repository safeguards:** GitHub reported `main` as unprotected with no required status checks at the last branch query. Review and enable appropriate branch protection / required checks after confirming the repository policy.
- **Production release:** live Vercel listing now succeeds for team `team_GxMH4eyATlCfJMG8SJXzDcAg` / slug `roshan45` and confirms one linked project `roshan-health-hub` (`prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`). Latest listed production deployment is **READY** on SHA `710f1232b8c972c0d1a5d9720c2cf8e03c8a96e7` (commit message references PR #50 security regressions), not on latest docs-only `main` SHA `90c30ea`. The prior 403 is not reproduced by current list calls, but deployment details/domain alias still need final verification; do not assume current main is production-live.
- **Database:** connected Supabase project is documented in the master plan. Read-only audits reported RLS enabled on all 56 public tables, and no sampled `anon` execution of public SECURITY DEFINER functions. Security Advisor still reports `pg_trgm` in `public`, authenticated-callable SECURITY DEFINER functions, and leaked-password protection disabled. Do not treat these findings as automatically exploitable or blindly revoke active application RPCs.

## 2. What has been delivered

### Application and workflow work already merged

- Core medical-center ERP/EMR workflows and role-aware navigation exist in the same app; Node 22 runtime, SSR log redaction, cashbox reversal concurrency protections, and prior shell/navigation changes are recorded in the master plan.
- PR #49 delivered a 40-item clinical UX batch and was merged into main. The code in main is **not automatically production-live**; use the deployment gate above.
- Earlier batches added regression coverage for atomic billing/pharmacy/patient registration flows, role and permission handling, clinic-local queue dates, and safer visit form options. The main CI run above exercises the current regression suite.

### Security-focused SQL proposals (source-only; not live changes)

These PRs remain open/draft candidates. Their dedicated PostgreSQL 17 integration checks and normal application CI passed, but migration replay/source-parity gates remain open:

- [PR #50 — invoice-item branch isolation](https://github.com/crauch2088-source/roshan-health-hub/pull/50): invoice child-row access derived from parent invoice branch.
- [PR #51 — certificates, discounts and procedure parent authorization](https://github.com/crauch2088-source/roshan-health-hub/pull/51): branch-aware parent/child checks and 54 regression checks.
- [PR #52 — followups and queue parent authorization](https://github.com/crauch2088-source/roshan-health-hub/pull/52): parent branch access, patient/visit linkage checks, and super-admin-only queue delete invariant.
- [PR #53 — prescription and lab child-row isolation](https://github.com/crauch2088-source/roshan-health-hub/pull/53): separates clinical child-row security from insurance-coupled work; dedicated PostgreSQL 17, prescription atomicity, and full CI passed.
- [PR #54 — finance RPC-only writes](https://github.com/crauch2088-source/roshan-health-hub/pull/54): isolates five finance tables from insurance changes, removes direct client DML in favor of validated RPC paths, and tests finance RPC behavior; dedicated PostgreSQL 17 and full CI passed.

**Critical distinction:** PRs #50–#54 are proposals in source control, not production database changes. No SQL from these candidates was applied to live Supabase in the latest verified snapshot. Do not merge/apply them just because CI is green; first close the migration-history and clean-replay gates.

### Documentation and migration audit

- The live Supabase ledger was re-queried on 2026-10-17: **93 applied migration entries**, latest `20261016222009_roshan_phase25_current_app_profile_20261016`. Exact migration SQL was retrieved read-only for all 93 versions and compared against 105 tracked source candidates: 92/93 normalized source matches, zero unmapped versions. The sole mismatch is the deliberately redacted environment-specific identity-link migration `20260818191254`; clean replay remains unproven and blocked on a replay-safe variant plus a reviewed pre-migration baseline schema. See [migration reconciliation](docs/DB_MIGRATION_RECONCILIATION.md).
- `docs/DB_MIGRATION_RECONCILIATION.md` contains the detailed inventory and comparison notes. Its top-level snapshot/header must be reconciled with the newer 93-entry state before relying on the document as a complete ledger summary.

## 3. Highest-priority remaining work

1. **Restore Vercel access** for team `team_roshan45` through the connected Vercel integration; do not guess project/team IDs or bypass the 403. Then verify current project, production alias, deployment SHA, and environment.
2. **Finish migration reconciliation:** map every live ledger entry to exact historical source/effects; resolve the mismatch between the reconciliation document header and latest master-plan count; produce an ordered, reproducible migration chain. Never invent missing SQL.
3. **Prove clean replay in a disposable PostgreSQL/Supabase environment** using synthetic fixtures; capture results and rollback notes. Never use production as the replay target.
4. **Complete authorization matrix** across role × table/RPC × operation × branch, including direct table access and authenticated SECURITY DEFINER RPCs. Retain fail-closed behavior for missing/mismatched patient, visit, invoice, procedure, lab, and prescription parents.
5. **Review and simplify overlapping SQL proposals.** Keep insurance-specific authorization out of clinical and finance PRs until insurer/patient and invoice-line linkage rules are explicitly defined. Review PRs #50–#54 after parity and replay gates close; merge only when all relevant checks and review gates pass.
6. **Clinical/product QA:** clinician review of medication templates and pediatric dosing cues; synthetic end-to-end reception → visit → prescription/lab/procedure → invoice/payment workflows; real-phone Android/RTL/LTR/light/dark/print checks; accessibility/keyboard review; authenticated live smoke after deployment access is restored.
7. **Release only after gates:** review database changes and rollback, apply canonical migrations in controlled order, re-run tests, deploy through the single canonical Vercel project, verify production SHA and smoke tests, then update this README and master plan.

## 4. Non-negotiable operating rules for future sessions

- Work directly on the existing repository and make tangible progress across independent workstreams; the owner prefers long, consolidated batches and concise Arabic status reports.
- Use connected tools, primarily Composio for GitHub writes when native GitHub access fails; use Supabase for read-only schema/audits and controlled migrations, Context7 for version-specific docs, PostHog only after privacy-safe event design, and Vercel only after access is restored.
- The owner primarily works from an Android phone. Prefer actions carried out through connected tools and complete files/patches over desktop-only instructions or isolated code snippets.
- Do not ask for repeat approval for routine, in-scope work. Still require evidence-based gates for irreversible/destructive changes, production SQL, merges with unresolved dependencies, and production deployment. Owner says test records are disposable, but never delete data unless a specific, verified task requires it.
- Do not expose, commit, or echo credentials, tokens, secrets, or identifiable patient data. Do not request passwords in chat.
- Never equate “CI green”, “PR merged”, “SQL committed”, “preview passed”, or “deployment created” with a verified production release. Report each state separately.
- Do not repeatedly retry a blocked integration. Record the exact blocker, continue useful independent work, and ask only for the specific access action needed.
- Update `docs/MASTER_PLAN.md` as the detailed execution plan and update this README as the compact context/continuity index after each meaningful work batch. Include date, commit/PR/run links, verified tests, what changed, what did not change, unresolved gates, and the next action. Keep both consistent.

## 5. Suggested first actions in a new chat

1. Read this README, `docs/MASTER_PLAN.md`, `docs/DB_MIGRATION_RECONCILIATION.md`, and `docs/PLUGIN_TOOLING_MAP.md`.
2. Re-query main SHA, open PRs #50–#54, latest checks, Supabase migration ledger/audit, and Vercel access/deployment state. Do not trust a stale status without rechecking.
3. Fix the stale migration reconciliation header and continue historical source mapping/replay preparation while separately requesting Vercel team re-authorization.
4. Keep PRs #50–#54 source-only until migration parity and disposable replay are proven. Do not apply their SQL to production before that.
5. Make real progress, run targeted tests and full CI where applicable, and update this README plus the master plan before handing off.

---

*This file is a maintained project-context entrypoint, not a substitute for live verification. Detailed history, phase checklists, SQL evidence, and test logs belong in `docs/MASTER_PLAN.md` and linked PRs/workflow runs.*


## Migration reconciliation evidence — 2026-10-17

- The connected Supabase migration-history API returned all **93/93** applied versions and their exact stored SQL bodies. Compared those bodies with **105** tracked migration-source files (79 timestamped historical recovery files and 26 top-level `db/` SQL files): **92 normalized text matches, 1 intentionally redacted exception, 0 unmapped ledger entries**. The comparison ignores comments and whitespace and is not a SQL-parser semantic proof.
- Exception: `20260818191254_fix_patients_rls_and_admin_link` includes a one-time environment-specific Auth-to-app-user identity link. The public source is deliberately redacted to avoid publishing its email/user UUID; it cannot be replayed as-is. Do not restore those literals to public docs or repository history.
- The 93 migrations are not yet a proven clean bootstrap: earliest migrations assume pre-existing objects. A reviewed baseline schema and replay-only variant that omits the environment-specific identity UPDATE are still required.
- Supabase quoted development-branch cost is **US$0.01344/hour**. No branch was created because nonzero recurring cost requires explicit user agreement. Continue static/source work while waiting; do not use production as replay target.
- Vercel team/project listing now succeeds, so the old 403 was not reproduced. Project `roshan-health-hub` and canonical domain aliases are visible; latest production deployment reports READY. The newest source commit's Vercel check still points to the build-rate-limit page; do not bypass or force deployment.


## Security review continuation — 2026-10-17

- Added [per-migration source parity manifest](docs/recovered-migrations/source-parity-report.json) with 93 version/name entries and SHA-256 hashes of normalized SQL (no SQL text or identity literals included). Result: 92 normalized matches, one intentionally redacted identity-link migration, zero unmapped entries.
- Added [security PR review](docs/SECURITY_PR_REVIEW.md) documenting concrete regression-test gaps for PRs #50–#53 and remaining replay/authorization matrix gates for #54. All five PRs remain open/draft and source-only.
- Read-only live schema checks confirmed `patient_id`/`visit_id` nullable on `followups`, `queue_tickets`, `patient_discounts`, and `procedure_orders`; prescription and lab-order patient IDs are NOT NULL. Helper semantics in #51/#52 should reject or explicitly constrain null-patient + valid-visit linkage.
- A disposable Supabase development branch quote is US$0.01344/hour. It has not been created pending explicit approval of this nonzero recurring cost.
