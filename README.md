## Execution update — 2026-10-18: clinical regression trigger hardening

- Current main: `84c3d1fcef1c6213367e59103204d9c0403fc7d5`. Clinical PostgreSQL 17 regression passed on this SHA; overall check set was 17/18 successful at last read, with CodeQL JavaScript/TypeScript still running and no failures reported.
- Updated `.github/workflows/ci-clinical-child-rpc-writes.yml` so frontend changes to lab completion/certificate creation and related contract tests trigger the PostgreSQL 17 clinical RPC regression on main pushes, not only SQL-file changes.
- Production Supabase ledger remains 109 entries through `20261018065708_roshan_clinical_child_rpc_only_writes`. Phase 29 is confirmed live on four clinical child tables. Phase 30 remains unapplied.
- Canonical Vercel production alias remains on old deployment SHA `631abf83415b2c878569d34df1360936f5a9d158`; a pinned deployment attempt hit HTTP 402 `api-deployments-free-per-day` with retry-after 86,400 seconds. No bypass or database mutation was attempted.
- Security Advisor warnings and unused-index findings are being triaged, not bulk-applied: no broad SECURITY DEFINER revocations, extension relocation, or index drops without function-by-function behavior tests and rollback.

---

## Execution update — 2026-10-18: finance payment precision and idempotency regression

- PR [#77](https://github.com/crauch2088-source/roshan-health-hub/pull/77) merged as `8530995f8560e2cd050a5e12ea1e1b3cb59ce57f` after **30/30 exact-head checks succeeded**, including CodeQL, install/audit/typecheck/lint/build, source-parity validation, the PostgreSQL 17 finance RPC-only suite, the two-session invoice-payment idempotency race, and the combined security-candidate migration regression.
- The candidate finance migration now retains the live invoice-payment precision guard. The combined-schema workflow now applies the ordered migrations in a single `psql` command. Source-parity metadata was refreshed for the edited bundle while `live_sql_hash_verified=false` remains explicit; this does not claim persisted live SQL equality or a complete historical replay.
- Production read-only verification: the migration ledger remains **109 entries**, latest `20261018065708`. Authenticated direct INSERT/UPDATE/DELETE remains denied on `cashbox_transactions` and `payments`; INSERT remains denied on `expenses`, `supplier_bills`, and `supplier_payments`. The validated cashbox, invoice-payment, and supplier-bill RPCs remain executable by `authenticated`, not `anon`. The legacy `add_cashbox_entry` RPC exists but is executable by neither browser role. The live invoice-payment function retains its two-decimal precision guard.
- **No production SQL or business rows were changed by PR #77.** It adds source/test hardening and repairs CI; do not apply the candidate finance migration merely because it merged.
- Phase 30 remains deployment-gated: Vercel confirms the canonical production alias currently points to READY deployment commit `bfc34bba1a880b385bc356f3dca1db0fb5068fe1` (created 2026-10-18 06:32 UTC), which predates the current-main clinical RPC frontend commits `50c833cdcace` / `18299c5b4d91`. Do **not** revoke direct DML on `lab_order_items` or `medical_certificates` yet. After the recorded free-tier quota window ends at **2026-10-19 08:52 Africa/Khartoum**, verify a new production deployment includes current main, then smoke-test lab completion and medical-certificate creation through their RPCs before applying Phase 30.
- Read-only Phase 30 preflight confirms both target tables currently retain authenticated SELECT/INSERT/UPDATE/DELETE, with RLS and FORCE RLS enabled; `anon` has no INSERT. `complete_lab_order_item` and `create_medical_certificate` are executable by `authenticated` and not `anon`; authenticated still has USAGE/SELECT on the certificate ID sequence. This is the intentional staged rollout state, not a reason to bypass the deployment gate.

---

# Production monitoring update — 2026-10-18 07:24 UTC

- Better Stack monitor **Roshan Health Hub - Production** (`5086672`) now targets `https://roshan-health-hub.vercel.app/` and currently reports **UP**. Last check: `2026-10-18T07:23:50Z`; 180-second checks from EU/Asia, SSL verification, redirects, 15-second timeout, and email alerts remain configured.
- The previous 404 incident (`1033415913`) for `roshan-health-hub-hjfy.vercel.app` is **Resolved**, and there are no unresolved incidents for monitor `5086672`. No duplicate monitor or paid plan was created.
- Uptime monitoring is not an authenticated end-to-end or clinical-readiness test. See the [master plan](docs/MASTER_PLAN.md) and [tooling map](docs/PLUGIN_TOOLING_MAP.md).

---

# Latest verified status — 2026-10-17

- Current source includes merged PR #62 (`9404a9b71f8248398663c6ad7b7275208230db15`): desktop quick actions, permission-safe filtering, functional route listeners for patient/visit/invoice dialogs, and a visits-list hint for lab-order shortcuts. Test guard now includes `tests/quick-actions.test.ts`; tested head passed CI and associated PostgreSQL 17 workflows.
- Production security migrations are applied and read back. Supabase ledger has 97 rows; latest version `20261017133157`.
- All 44 policies across the 11 targeted child tables include their expected branch/parent helper. Direct write privileges are revoked for authenticated/anon on five finance and three insurance ledger tables; authenticated SELECT remains. The unused global `next_invoice_number()` RPC is no longer directly callable by browser roles.
- Insurance claim and coverage RPCs are updated, authenticated-only, and use an empty fixed `search_path`. Live definitions include invoice/visit patient/branch, amount split, service-type, and currency precision guards.
- Full evidence: [live migration delta](docs/LIVE_MIGRATION_DELTA_2026-10-17.md), [UX audit](docs/UX_AUDIT_2026-10-17.md), and [master plan](docs/MASTER_PLAN.md).
- Full historical migration replay remains unproven because the initial schema baseline is missing and one historical identity-link migration is intentionally redacted. No historical replay was attempted.
- Vercel production is behind current source; latest current-main build check is blocked by the free Hobby build-rate limit. No paid upgrade or forced deploy. Screenshot-based full UI audit and live browser smoke tests remain pending, so clinical readiness is not claimed.

---

# Live production status — 2026-10-17

> **Security release gate remains open.** The security bundle is present in source but has not been applied to production. Live Supabase inspection confirmed that 11 child-table RLS policies still lack expected parent/branch predicates, direct write grants remain on five finance tables, and the insurance-claim RPC is still on its older definition. These are configuration gaps, not evidence of an actual breach.

- Current main at audit start: `5b549663a4d8f26d372a31f19b63ee5d4cdba812`; the live audit documentation has since been committed to main.
- Supabase `jewzonxplxhogqrnhosl`: ACTIVE_HEALTHY, PostgreSQL 17.6; migration ledger has 93 entries. Source parity is 92/93 with one intentionally redacted identity-link migration; a clean historical bootstrap is not yet proven.
- Vercel production deployment is READY but behind current main. Current-main status reported a build-rate-limit failure. Do not pay to upgrade or bypass the limit.
- Full evidence and the exact release gate: [docs/LIVE_PRODUCTION_SECURITY_AUDIT_2026-10-17.md](docs/LIVE_PRODUCTION_SECURITY_AUDIT_2026-10-17.md) and [docs/MASTER_PLAN.md](docs/MASTER_PLAN.md).
- A new CI-only PR [#57](https://github.com/crauch2088-source/roshan-health-hub/pull/57) adds manual triggering for the PostgreSQL 17 security-bundle regression workflow; do not merge it until checks are green.
- No production SQL or data was changed during this audit. Do not treat the app as clinically ready until the security migration is safely applied and verified against live state.

---

# Roshan Health Hub

**Purpose:** a real, low-cost medical-center ERP/EMR for Roshan Medical Center in Hay Al-Sadaqa, Al-Hasahisa, Gezira, Sudan. This repository is the single application; do not create a parallel/replacement app.

> **Continuity rule:** start every work session by reading this README, then `docs/MASTER_PLAN.md`, `docs/DB_MIGRATION_RECONCILIATION.md`, and `docs/PLUGIN_TOOLING_MAP.md`. Re-check the live repository/PR/CI state before acting because this file is a maintained snapshot, not a substitute for current tool evidence. After each meaningful batch, update this README and the master plan with verified outcomes, commit/PR links, test evidence, blockers, and next actions.

- **Repository:** https://github.com/crauch2088-source/roshan-health-hub
- **Master plan (detailed execution source of truth):** [docs/MASTER_PLAN.md](docs/MASTER_PLAN.md)
- **Database migration reconciliation:** [docs/DB_MIGRATION_RECONCILIATION.md](docs/DB_MIGRATION_RECONCILIATION.md)
- **Per-migration source parity manifest:** [docs/recovered-migrations/source-parity-report.json](docs/recovered-migrations/source-parity-report.json)
- **Security PR review:** [docs/SECURITY_PR_REVIEW.md](docs/SECURITY_PR_REVIEW.md)
- **Security integration gate:** [docs/SECURITY_BRANCH_ISOLATION_INTEGRATION.md](docs/SECURITY_BRANCH_ISOLATION_INTEGRATION.md)
- **Tool/integration map:** [docs/PLUGIN_TOOLING_MAP.md](docs/PLUGIN_TOOLING_MAP.md)
- **Archived original product brief:** [docs/ORIGINAL_PRODUCT_BRIEF.md](docs/ORIGINAL_PRODUCT_BRIEF.md)
- **Production domain historically verified:** https://roshan-health-hub.vercel.app/

**Snapshot:** 2026-10-17 (UTC). Re-verify before relying on status below.

## 1. Current project snapshot

- **Application:** React + TypeScript + Tailwind CSS, TanStack Start, Supabase, Vercel; `package.json` specifies Node.js `22.x`. Mobile-first, Android-installable PWA, Arabic RTL and English LTR.
- **Clinic status:** one branch is active/planned for initial rollout; branch two is not open. Owner reports current stored patient/finance records are manually created synthetic test data, not real operational records. Still treat the connected Supabase project as production and verify target/environment before every mutation.
- **Latest verified `main` at last read:** [`838e696`](https://github.com/crauch2088-source/roshan-health-hub/commit/838e696d4d7a9d9ce4817e47c4fbcf95dc2b1e4c), updating the per-migration parity manifest to mark the redacted source as a non-executable placeholder. Recent commits in this batch were documentation-only; no application code or database was changed. Recheck main before relying on this snapshot.
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


- **Live authorization baseline (2026-10-17):** 56/56 public tables have RLS and none lacks policies; detailed advisor and grant findings are recorded in [security review](docs/SECURITY_PR_REVIEW.md). This is not a completed adversarial authorization matrix.


## No-cost security continuation — 2026-10-17

- No paid Supabase branch or project was created. Use GitHub Actions PostgreSQL 17 services for isolated tests.
- Regression suites were strengthened on PRs #50–#53: parent reassignments now exercise RLS `WITH CHECK`, with row postconditions and helper grants where applicable. Latest dedicated PostgreSQL 17 results passed for #50, #52, #53 and the parent-branch integration for #51; general CI for the final #51 test commit was still running at last check. PR #54's finance integration and CI are green.
- All PRs #50–#54 remain unmerged pending clean migration replay and any outstanding review gates. No production SQL or permissions changed.
- Full replay is still not proven: 92/93 normalized source matches, one intentionally redacted environment-specific identity-link migration, and no reviewed pre-migration baseline. Do not guess the baseline or replay against production.
- Details: [security PR review](docs/SECURITY_PR_REVIEW.md), [master plan](docs/MASTER_PLAN.md), [migration reconciliation](docs/DB_MIGRATION_RECONCILIATION.md), [source parity manifest](docs/recovered-migrations/source-parity-report.json).


## No-cost migration parity gate — 2026-10-17

- Added `scripts/verify-migration-source-parity.py` and wired it into the existing CI workflow. The new PostgreSQL-independent verifier passed against the complete source archive: 93 mappings, 92 normalized SQL hashes verified, one deliberately redacted non-executable placeholder. The dedicated GitHub Actions job passed on main commit `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`; all 13 checks on that commit were green, including both CodeQL language analyses.
- PR #54 was strengthened to check authenticated/anon EXECUTE privileges for all six finance write/reversal RPCs. Its focused finance integration passed on test commit `d0d818a9988216cdfc52723d7e9ffae7402a50d1`; general CI was still running at last poll.
- No paid resources, Supabase branches, production SQL, grants, policies, or production data were changed. PRs #50–#54 remain unmerged pending full replay and remaining review gates.
- Full replay remains unproven: the pre-migration schema baseline is missing and one identity-link migration is intentionally redacted. Never substitute a guessed baseline or replay against production.
- Details: [security PR review](docs/SECURITY_PR_REVIEW.md), [master plan](docs/MASTER_PLAN.md), [source parity manifest](docs/recovered-migrations/source-parity-report.json).


## Additional no-cost regression pass — 2026-10-17

- PR #51's latest parent-branch integration now also proves a NULL `patient_id` cannot be used to insert a procedure order pointing to a branch-B visit; all five checks passed on `4af41b893b12427b15577f2312b13e4d92785c20`.
- PR #52's latest queue/follow-up integration now tests the same NULL-patient cross-branch insert case for both tables and asserts no rejected rows remain; all five checks passed on `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`.
- PR #54's expanded finance RPC grant tests and full PR CI passed on `d0d818a9988216cdfc52723d7e9ffae7402a50d1`.
- Latest main documentation commit `696e422d959b308c5087339af74b541d941fa205` passed all 13 checks, including source-parity verification and both CodeQL analyses. Vercel's check points to the build-rate-limit page; the most recent READY deployment is on earlier docs-only commit `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`. No deployment was forced.
- Full-chain replay remains blocked by the missing trustworthy pre-migration baseline and one intentionally redacted identity-link migration. No paid resource or production database mutation was used.


## Final no-cost regression verification — 2026-10-17

- Latest focused PostgreSQL 17 integration and full CI checks are green on all five open security drafts: #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64`; #51 `4af41b893b12427b15577f2312b13e4d92785c20`; #52 `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`; #53 `8187d1d95e2b6d485163a8805947abee71ad086e`; #54 `670185193a0400634fe49f7e2e004b4223611ce3`.
- #51/#52 now explicitly reject NULL-patient rows whose visit belongs to another branch. #54 checks all six finance write/reversal RPC grants, anon denial, SECURITY DEFINER status, and pinned search_path.
- The prior main docs commit `1c996bcc906e0739b5c693f2fe3968acdc72b9c6` passed all 13 CI/CodeQL/source-parity checks. This documentation update will trigger a fresh verification run.
- Vercel's latest check still points to the build-rate-limit page. The last READY deployment inspected is on earlier docs-only SHA `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`; no deployment was forced.
- No paid service or production database mutation was used. All five PRs remain draft/unmerged because full historical replay still lacks a reviewed pre-migration baseline and safe replay treatment for the redacted identity-link migration.


## Replay-safe redacted migration policy validation — 2026-10-17

- Recovered a replay-only variant of `20260818191254_fix_patients_rls_and_admin_link` at [the replay-safe SQL file](docs/recovered-migrations/replay-safe/20260818191254_fix_patients_rls_and_admin_link.sql). It preserves the four patient RLS policy changes but intentionally omits the one-time environment-specific Auth-to-app-user identity UPDATE; no email or identity UUID is included.
- Added a synthetic PostgreSQL 17 fixture and behavioral integration test. The new `Replay redacted migration policy portion` job passed, and all 14 checks on main commit `ed1218e35121d9de08845fcc943fb8a3252717a6` were green, including CodeQL and the 93-entry source-parity check.
- This closes the isolated policy-portion test gap only. The full 93-migration chain still cannot be replayed from blank until a trustworthy pre-migration baseline is reconstructed and reviewed. No paid resource or production database change was used.


## Final verification after replay-safe migration checks — 2026-10-17

- Latest main SHA `ddf7d3b5b72d18bbfd13598472ce4db480c09bca` passed all **15/15** checks, including the 93-entry source-parity verifier, replay-safe patient-policy migration integration, application build/lint/typecheck, and both CodeQL language analyses.
- The parity verifier now additionally ensures the replay-safe migration variant contains no environment email/identity UUID or `UPDATE public.users SET auth_user_id`, while retaining all four patient policies.
- All PRs #50–#54 remain open/draft/unmerged; every workflow on their latest test heads is green. No paid resources or production database changes were used.
- Full-chain replay remains blocked by the missing trustworthy pre-migration baseline. Vercel's check on current main still reports the provider build-rate-limit page; the last READY deployment inspected is earlier documentation-only SHA `6f4409b48414fe3fe60ff45ab4b5898e9bc3887c`. No deployment was forced.


## Live continuation verification — 2026-10-17 10:30 UTC

This section supersedes older status snapshots above wherever they conflict. Sources were queried live during this continuation; no production database writes or manual deployments were performed.

- **GitHub main:** latest commit observed was `2143f63624993a7d8f9bfbf71c251d129fe0b691` (`docs: finalize replay-safe migration and CI evidence`). GitHub reported **14/14 check runs successful** on this SHA, including CodeQL analyses and the migration parity/replay-safe checks.
- **Vercel production:** latest READY production deployment returned for project `roshan-health-hub` was linked to `ddf7d3b5b72d18bbfd13598472ce4db480c09bca`, which is behind the observed `main` SHA. Therefore latest main is **not proven deployed**. Do not force a deployment while the provider build-rate-limit issue persists.
- **Supabase:** project `jewzonxplxhogqrnhosl` reports `ACTIVE_HEALTHY`, PostgreSQL 17.6, region `eu-west-1`. Live migration ledger still has **93 entries**, latest `20261016222009_roshan_phase25_current_app_profile_20261016`. No SQL was applied in this continuation.
- **Security Advisor (live, 2026-10-17 10:29 UTC):** 22 warnings for authenticated-callable public `SECURITY DEFINER` functions, one `pg_trgm` extension-in-public-schema warning, and the previously recorded leaked-password-protection warning. Performance Advisor reports 90 unused-index findings. These require per-item review; no blanket RPC revocation or index removal is justified.
- **Security PRs #50–#54:** all five are still **open and draft**; no merge was performed. Current heads: #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64`; #51 `4af41b893b12427b15577f2312b13e4d92785c20`; #52 `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`; #53 `8187d1d95e2b6d485163a8805947abee71ad086e`; #54 `670185193a0400634fe49f7e2e004b4223611ce3`. The PR API returned different base SHAs for the five requests (older than current main), so refresh/rebase and rerun checks before considering merge order.
- **Migration gate remains closed:** 92/93 normalized source matches, one intentionally redacted environment-specific identity-link migration, no reviewed trustworthy pre-migration baseline, and no proof of full clean replay. The replay-safe file is a test artifact, not an approved production migration.
- **Next actions:** (1) inspect PR diffs and dependency/ancestry against current main, refresh each PR base without merging, (2) expand free PostgreSQL 17 test coverage for role × operation × branch and RPC idempotency, (3) keep working on source/replay verification without paid resources, (4) update docs and verify the resulting SHA's CI. Do not create a Supabase branch: the previously quoted branch costs US$0.01344/hour and no cost was approved.


## Finance RPC regression and test-workflow update — 2026-10-17 10:37 UTC

- Found a concrete NULL-handling bug in draft PR #54: PL/pgSQL `IF _direction NOT IN (...)` does not reject NULL because the predicate evaluates to NULL, so the function could fall through to the withdrawal branch. This was a source-review finding, not a production incident.
- Added a regression assertion first, then corrected validation to `_direction IS NULL OR _direction NOT IN ('deposit','withdrawal')` on isolated PR branch `security/finance-only-rpc-writes`.
- Code commits: regression test [`ed1c14b`](https://github.com/crauch2088-source/roshan-health-hub/commit/ed1c14b218d2dab8c7dc7e862f273e3e990a9e42); fix [`53483d8`](https://github.com/crauch2088-source/roshan-health-hub/commit/53483d87bb30f3bbc6fe4e95f4e266d1f763b96f); manual-test workflow support [`c15d69a`](https://github.com/crauch2088-source/roshan-health-hub/commit/c15d69ab96b3ba7be8c45212bee3511130bd0bcd).
- Made the isolated finance workflow available on main in [`e4b1a6d`](https://github.com/crauch2088-source/roshan-health-hub/commit/e4b1a6d0cea31d3e6e3976451a331bd586811ff6) and enabled `workflow_dispatch` on the PR branch so its PostgreSQL 17 test can be run on demand. This is CI infrastructure only; no candidate SQL was added to main.
- **Verified:** [PostgreSQL 17 finance RPC-only writes integration](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025549230) passed on branch head `c15d69ab96b3ba7be8c45212bee3511130bd0bcd`, including the NULL-direction regression. Main's ordinary CI passed on `e4b1a6d`; CodeQL was still running at the latest check. The new docs commit will trigger fresh CI.
- **Release boundary:** PR #54 remains a draft/source-only proposal; no SQL was applied to Supabase. Full migration replay and review gates remain open. Do not merge the five security drafts automatically.


## Live status refresh — 2026-10-17 10:45 UTC

- Current main documentation commit checked: `147e1b2e978bb4a0ee65da92117a5448f1a03863`; GitHub reports 14 check runs and the associated main workflow run concluded successfully. See [main CI run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025657739) and [CodeQL run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025657774).
- All five security draft integration workflows have a successful result on their latest observed branch head:
  - PR #50 invoice-item branch isolation, SHA `ba5f742a05bb912ec169a056e9c29a0b08967f64`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39021158326).
  - PR #51 parent-branch isolation, SHA `4af41b893b12427b15577f2312b13e4d92785c20`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39022406414).
  - PR #52 queue/follow-up isolation, SHA `4b72a8761de5ec7dc936f4bc29b348e19fba5bea`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39022409722).
  - PR #53 prescription/lab child isolation, SHA `8187d1d95e2b6d485163a8805947abee71ad086e`: [run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39021361272).
  - PR #54 finance RPC-only writes, SHA `c15d69ab96b3ba7be8c45212bee3511130bd0bcd`: [manual PostgreSQL 17 run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39025549230).
- These are isolated SQL fixture/integration passes, not evidence of applying candidate migrations to Supabase or of full historical migration replay. Keep all five PRs as drafts until branch ancestry, complete migration-source parity, grants/policies, and the reviewed baseline are reconciled.
- The five PR API snapshots report different base SHAs; do not assume their diffs are based on the same current main or merge them in a batch. Refresh base/head comparisons immediately before any integration decision.
- Vercel's latest listed READY production deployment remains SHA `4b4b871b6637bb85703336d3c6f47e4e3f3f0c1f`, behind current main. Do not force deployment while the build-rate-limit failure remains unresolved.
- No Supabase writes, production migration, PR merge, or paid-resource creation was performed during this refresh.


## PR ancestry comparison against current main — 2026-10-17 10:47 UTC

GitHub compare API reports every security draft #50–#54 as **diverged** from current `main`; their merge bases are historical and their heads are respectively 49, 49, 49, 48, and 42 commits behind the current main tip (while 5, 18, 9, 10, and 9 branch commits are ahead). Current comparison results:
- #50: merge base `43afd071ace95f891591ba1ca5448713e1df38cb`, 5 ahead / 49 behind.
- #51: merge base `43afd071ace95f891591ba1ca5448713e1df38cb`, 18 ahead / 49 behind.
- #52: merge base `43afd071ace95f891591ba1ca5448713e1df38cb`, 9 ahead / 49 behind.
- #53: merge base `710f1232b8c972c0d1a5d9720c2cf8e03c8a96e7`, 10 ahead / 48 behind.
- #54: merge base `de28027ac8798e025f22f68a122b132ebf1b6029`, 9 ahead / 42 behind.

The focused SQL and fixture files appear as added files in each comparison, but that does not establish migration-order compatibility or prove clean replay. Treat current successful CI as fixture-level evidence only. Do not merge/rebase these drafts blindly; first reconstruct the dependency/order map and compare each candidate against current migration sources and grants.


## Parent/visit consistency regression expansion — 2026-10-17 10:48 UTC

- Reviewed PR #51's parent-branch integration test and found the certificate visit-reassignment assertion duplicated, leaving the patient-side reassignment path untested.
- Replaced the duplicate with a test that changes `patient_id` while retaining a visit belonging to another patient in the same branch. Added a second test that attempts to INSERT a certificate with same-branch but mismatched patient/visit parents.
- Commit: [`19e91bc38af9f16c2a6d46f8af6249742812ba84`](https://github.com/crauch2088-source/roshan-health-hub/commit/19e91bc38af9f16c2a6d46f8af6249742812ba84), on `security/parent-branch-isolation-50-batch`; no candidate SQL changed.
- Dedicated PostgreSQL 17 integration passed: [run #39026202054](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39026202054).
- The pull-request-wide CI run #39026202048 was still in progress at the last check. Main CI passed for `5ca587e`; CodeQL JavaScript/TypeScript analysis was still running at that point.


## Live verification refresh — 2026-10-17 10:56 UTC
- Verified current `main` at `5cf7eea2037314f7e90bf2f654e05a4d3840e667`: all 14 GitHub check runs concluded successfully, including both CodeQL analyses.
- Verified the newest Vercel production deployment is `READY` on the exact same SHA `5cf7eea`; aliases include `roshan-health-hub.vercel.app` and `roshan-health-hub-git-main-roshan45.vercel.app`. No manual deployment was triggered.
- PR #51 head `19e91bc38af9f16c2a6d46f8af6249742812ba84` now has both its dedicated PostgreSQL 17 parent-isolation integration ([run #39026202054](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39026202054)) and PR-wide CI ([run #39026202048](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39026202048)) successful. The CI included migration source-parity checks and the replay-safe policy fixture; neither substitutes for full historical replay.
- Read-only live catalog audit: 44 SECURITY DEFINER functions in `public` and 25 in `private`; 22 public functions are authenticated-callable and none are anon-callable. Five private functions show EXECUTE inherited for `anon`, but `anon` lacks USAGE on `private`; do not blindly revoke functions based on Advisor counts.
- No production SQL, migration, grant, merge, or paid resource was changed. The trusted pre-migration baseline/full 93-entry replay gate remains open.


## Execution batch — 2026-10-17 (verified follow-up)
- Corrected the migration reconciliation inventory to use the per-version source parity manifest instead of stale “source mapping pending” labels. The document now distinguishes 4 exact basename matches among 26 top-level `db/` files from 92 normalized content matches across 105 tracked candidates; the remaining one is the intentionally redacted environment-specific identity-link migration. Commit: [`b03b3c0`](https://github.com/crauch2088-source/roshan-health-hub/commit/b03b3c07f33266b55c60a27c7b7e5a3e154c708e).
- Found and fixed duplicated regression assertions in the parent-branch test suites. PR #51 now independently tests `procedure_orders.patient_id` reassignment and same-branch-but-mismatched patient/visit INSERT; current head [`b2cd795`](https://github.com/crauch2088-source/roshan-health-hub/commit/b2cd795af0ffa0d4de93ccdfe721bfa94257ee9f) passed 20/20 checks.
- PR #52 adds `patient_id` reassignment checks for both follow-ups and queue tickets; current head [`c806059`](https://github.com/crauch2088-source/roshan-health-hub/commit/c8060592284355ed1c934120be7cfe0ae7c650c1) passed 20/20 checks.
- PR #53 replaces a duplicate lab-order parent reassignment test with a distinct same-branch mismatched patient/visit parent test; current head [`91c6f33`](https://github.com/crauch2088-source/roshan-health-hub/commit/91c6f33d0873c533040a911de1599065aa995acf) passed 20/20 checks.
- PR #54 adds a compatibility regression for the documented super-admin-without-branch supplier-bill path. A read-only aggregate live audit found one active super-admin account without a branch; no user identity was copied into the repo. Current head [`9ad29bb`](https://github.com/crauch2088-source/roshan-health-hub/commit/9ad29bbc5f21d980279e916e8f4a9d5d140dffa4) passed 21/21 checks.
- Main migration-inventory documentation commit `b03b3c07f33266b55c60a27c7b7e5a3e154c708e` passed all 14 checks.
- Latest Vercel production deployment still verified READY on older SHA `5cf7eea2037314f7e90bf2f654e05a4d3840e667`; the current docs-only main SHA is not confirmed deployed. Do not trigger a manual deployment or bypass build-rate limits.
- PR #50 remains unchanged at the previously verified head `ba5f742a05bb912ec169a056e9c29a0b08967f64` with its focused checks green. All PRs #50–#54 remain draft/open; no SQL was applied to production and no PR was merged.
- Release blockers remain: safely reconcile PR ancestry/dependency order, preserve the intentionally redacted identity mapping, and prove the complete ordered migration chain against a reviewed pre-migration baseline in a zero-cost disposable PostgreSQL environment. Normalized text parity is not semantic proof or full replay evidence.



## Security release gate — live child-table policy audit (2026-10-17)

- Read-only live catalog review inspected 44 policies across 11 tables: `invoice_items`, `certificates`, `medical_certificates`, `patient_discounts`, `procedure_orders`, `procedure_results`, `followups`, `queue_tickets`, `prescriptions`, `prescription_items`, and `lab_order_items` (four policies per table). Their current row-policy expressions are permission-only; the queue delete policy is super-admin-only. They do not invoke branch-access helpers.
- Confirmed `public.app_has_perm(text)` delegates to `private.app_has_perm(text)`, which checks super-admin status or active user's role permissions; it does not check the row's patient/visit/parent branch. Therefore the current policies do not themselves enforce branch isolation. This is a release-blocking cross-branch access risk if real patient or financial data is introduced. Current project data is understood to be synthetic; no individual user data was copied into this audit note.
- PRs #50–#53 are directly relevant remediations for this gap. Current tested heads: #50 `ba5f742a05bb912ec169a056e9c29a0b08967f64` (previously verified 18/18); #51 `b2cd795af0ffa0d4de93ccdfe721bfa94257ee9f` (20/20); #52 `c8060592284355ed1c934120be7cfe0ae7c650c1` (20/20); #53 `91c6f33d0873c533040a911de1599065aa995acf` (20/20). PR #54's latest head `d77bb2fbb3fdc9db71f6251b39763775abb9b8ef` passed 21/21 checks, including PostgreSQL 17 finance RPC-only tests for NULL direction, NaN/Infinity rejection, and the documented unassigned super-admin supplier-bill compatibility path.
- Fresh comparison against `main`: #50 5 ahead / 54 behind (merge base `43afd071ace95f891591ba1ca5448713e1df38cb`); #51 21 ahead / 54 behind (same merge base); #52 10 ahead / 54 behind (same merge base); #53 11 ahead / 53 behind (merge base `710f1232b8c972c0d1a5d9720c2cf8e03c8a96e7`); #54 10 ahead / 47 behind (merge base `de28027ac8798e025f22f68a122b132ebf1b6029`). Do not merge or rebase blindly.
- PRs #51 and #52 both define `private.app_has_patient_visit_branch_access(uuid,uuid)`; the two definitions are semantically identical but formatted differently. Preserve a single agreed contract or retain identical definitions when reconciling their migration order.
- The main migration-inventory documentation commit `b03b3c07f33266b55c60a27c7b7e5a3e154c708e` passed 14/14 checks. The later main documentation commit `4ad258049f25c72fbc757a2782e8d3a908d31f4c` also passed 14/14 checks. Latest verified Vercel production deployment remains READY on older SHA `5cf7eea2037314f7e90bf2f654e05a4d3840e667`; the latest docs-only SHA is not confirmed deployed.
- No production SQL, RLS policy, grant, or row was changed; no PR merged; no paid resource created. Before real patient data: integrate the branch-isolation remediation after ancestry reconciliation and reviewed migration replay planning, then verify role × operation × branch behavior against the final integrated SQL. The 92/93 normalized source parity result is text-level matching, not semantic proof or full-chain replay.


## Security integration continuation — 2026-10-17

See [docs/SECURITY_BRANCH_ISOLATION_INTEGRATION.md](docs/SECURITY_BRANCH_ISOLATION_INTEGRATION.md) for exact-head CI evidence, shared helper overlap, proposed integration order, combined test matrix, and release gates. The five security PRs remain draft/open; no candidate SQL was applied to production. Full migration replay is still blocked by the missing reviewed pre-migration baseline and the intentionally redacted identity-link migration.


## Security integration progress — 2026-10-17

- Draft [PR #55](https://github.com/crauch2088-source/roshan-health-hub/pull/55) stages candidate fixes #50–#54 on one integration branch and adds a PostgreSQL 17 aggregate regression workflow.
- The isolated candidate matrix passed 5/5 jobs. More importantly, the shared-schema integration job passed at code head `e3bf1f47c3b5bdc96085ce08c907b26cba941dbb`: it applied all five candidate migrations in order, ran all five existing regression scripts against one database, and passed policy-catalog and finance-privilege assertions. The subsequent PR commits were documentation-only.
- The shared-schema fixture is synthetic and is **not** a replay of the entire historical production migration chain. Full baseline/source reconciliation, app RPC call-site audit, and release review remain required. PR #55 is draft/open and no candidate SQL was applied to production.
- See [docs/SECURITY_BRANCH_ISOLATION_INTEGRATION.md](docs/SECURITY_BRANCH_ISOLATION_INTEGRATION.md) on the integration branch / PR #55 for the complete evidence and remaining gates.


## Security bundle integration update — 2026-10-17

- PR #55 stages five child-table branch-isolation and finance direct-write hardening candidates. The combined PostgreSQL 17 test passed before the bundle was canonicalized; a fresh run against the canonical bundle is required before merge.
- Live read-only catalog evidence: 44 policies on 11 child tables still use permission-only predicates without parent-branch helpers; authenticated retains INSERT/UPDATE/DELETE privileges on all five finance tables targeted by the finance candidate.
- The application call-site scan found no direct client writes to `invoice_items`, `prescription_items`, `payments`, `cashbox_transactions`, `expenses`, `supplier_bills`, or `supplier_payments` in the inspected routes. Verified direct child-table writes remain in follow-ups, medical certificates, queue-ticket updates, and lab-order-item updates; these depend on RLS branch predicates. The finance screen's direct INSERT is to `suppliers`, not one of the five restricted ledger tables.
- Added `db/roshan_security_candidate_bundle_20261017.sql` as the ordered artifact; the combined-schema job applies this exact file, then runs the five integration suites and catalog assertions.
- Main is `627baa6568eebf1b69cd7afa73da7fa7e9fc3da9`; its Vercel status is a build-rate-limit failure, not a passing deployment for this source. Historical migration replay remains unproven: 92/93 normalized source matches, one intentionally redacted identity-link migration, zero unmapped ledger entries.
- No production SQL or grants have been changed. Merge/release remains blocked until fresh CI and a clean replay from a reviewed baseline.


## Supabase Auth password hardening — 2026-10-17

- Verified the Supabase Auth service is ACTIVE_HEALTHY.
- The live password_min_length was 6; it has been raised to **8** via the Management API, and the subsequent read-back verified 8. This applies to future password setting/change flows; it does not change existing passwords or require an immediate sign-out.
- Leaked-password protection (password_hibp_enabled) remains **disabled**. An attempted single-setting enable was rejected by Supabase because HaveIBeenPwned protection is available only on Pro plans and above. No upgrade or paid resource was purchased, and no other Auth setting was changed by that attempt.
- This Advisor finding remains open; do not mark it resolved or bypass the plan restriction. Revisit only if a no-cost supported alternative becomes available or the user explicitly approves a plan change.

## Live continuation — verified production and residual insurance policy gap (2026-10-18)

Read-only verification performed at approximately 2026-10-17 22:18 UTC:

- Canonical GitHub `main`: `868ea341b281f1218de490b603bf8d4632093a35` (`docs: record uptime monitor target correction`). GitHub Actions reports 14/14 check runs successful on this exact SHA.
- Canonical Vercel project `roshan-health-hub`: latest production deployment is `READY` on the same SHA, with alias assignment successful and no alias error. The verified production domain is `https://roshan-health-hub.vercel.app/`.
- Existing Better Stack monitor `5086672` (`Roshan Health Hub - Production`) is unpaused and now reports `UP`; its latest check at `2026-10-17T22:17:50Z` hit the corrected canonical URL. It retains 180-second checks from EU/Asia, TLS verification, redirects, 15-second timeout, and email alerts. No duplicate monitor or paid resource was created.
- Supabase project `jewzonxplxhogqrnhosl` currently has 97 migration-ledger entries through `20261017133157_roshan_revoke_legacy_invoice_number_20261017`. This confirms the security bundle and subsequent insurance/invoice hardening migrations are recorded; it does not prove a full clean replay from a reviewed baseline.
- A fresh catalog audit confirmed branch-helper expressions on all 40 policies across these 10 child tables: `followups`, `invoice_items`, `lab_order_items`, `medical_certificates`, `patient_discounts`, `prescription_items`, `prescriptions`, `procedure_orders`, `procedure_results`, and `queue_tickets`. The queue-ticket DELETE policy remains intentionally super-admin-only and also checks parent/branch access.
- **Residual gap found:** all 3 existing policies on `public.insurance_prior_authorizations` (`SELECT`, `INSERT`, `UPDATE`) still only check `app_has_perm(...)` and do not enforce the patient/branch context. The table links to `public.patient_insurance` through `patient_insurance_id`; that parent has `patient_id`, so a narrowly scoped parent-branch predicate can be designed. Do not claim branch isolation is complete until this table is covered by a tracked migration and synthetic cross-branch regression tests. No production SQL was run to change policies or grants during this audit.
- Supabase Security Advisor returned 21 WARN findings: 20 authenticated-callable `SECURITY DEFINER` functions and the `pg_trgm` extension in `public`. These need per-function call-site/privilege review; do not blanket-revoke RPCs or move/drop objects without compatibility tests. PostgreSQL configuration details were not returned by the connected read-only endpoint, so they remain unknown rather than assumed secure.
- Migration replay remains a release gate: 92/93 normalized source matches in the last documented parity run, with one intentionally redacted environment-specific identity-link migration and no reviewed initial schema baseline. No paid database branch/project was created.

### Next execution order
1. Add a source-only migration for branch-aware RLS on `insurance_prior_authorizations`, reusing the established patient-branch helper and preserving the existing permission checks.
2. Extend the disposable PostgreSQL 17 fixture and regression suite to prove same-branch allow, cross-branch SELECT/INSERT/UPDATE denial, mismatched/NULL parent fail-closed behavior, and unchanged permission semantics. Wire the test into free GitHub Actions.
3. Audit insurance prior-authorization application call sites and review the exact migration order against the 97-entry live ledger; do not apply another production migration until the test and rollback/recovery plan are reviewed.
4. Continue per-function review of the 20 Advisor warnings, using repository call-site evidence; leave paid-only leaked-password protection unresolved on the current free plan.
5. Continue the separate authenticated browser/mobile RTL clinical workflow audit. Uptime `UP` and CI green do not establish clinical readiness.

## Execution update — insurance prior-authorization branch isolation merged (2026-10-18)

- Merged PR [#64](https://github.com/crauch2088-source/roshan-health-hub/pull/64) into `main` as `580f4a4ef6b8745eaff9eb6e7f012a1e4afdd68e`. The source branch was deleted after merge.
- The merge includes `db/roshan_insurance_prior_authorization_branch_isolation.sql`, a fixed-search-path private branch helper, the SELECT/INSERT/UPDATE RLS policies that preserve `insurance.read/create/update`, a synthetic PostgreSQL 17 regression, and free GitHub Actions workflow wiring.
- All 27 checks on the exact PR head `654825a149cd158779ac4ca41a1cdfb81e0409ae` completed successfully, including the focused prior-authorization branch-isolation test, combined-schema regression, migration source-parity manifest, install/audit/typecheck/lint/build, and CodeQL (no new alerts). The first regression run caught a PostgreSQL catalog-query mistake; it was corrected and the exact final head passed.
- Source search found no current application-code call sites for `insurance_prior_authorizations`; the parent `patient_insurance` and insurance-claim flows are separate.
- **Production database was not modified.** The live Supabase migration ledger remains at 97 entries through `20261017133157_roshan_revoke_legacy_invoice_number_20261017`; therefore the live three-policy branch-isolation gap remains until a separately reviewed production migration is applied. Do not mistake the merged SQL source file for a live schema change.
- Post-merge GitHub Actions and Vercel production build for `580f4a4ef6b8745eaff9eb6e7f012a1e4afdd68e` were still running at the last check. Verify their final state before the next release action.

### Next steps
1. Verify post-merge CI and canonical production alias after the Vercel build completes.
2. Review migration replay/baseline parity and write a rollback/recovery plan before applying the source-only RLS migration to production.
3. Continue per-function Security Advisor review and the authenticated phone-first RTL clinical workflow audit.

## Migration parity clarification — 2026-10-18

The original machine-readable `docs/recovered-migrations/source-parity-report.json` describes the historical 93-row snapshot only: 92 normalized text matches and one deliberately redacted identity-link migration. The current live Supabase ledger has 97 entries; the reconciliation notes record 96/97 exact source matches after four subsequent entries were matched. Do not read the 93-row JSON report as a fresh 97-row report. Full-chain replay remains blocked by the missing reviewed pre-migration schema baseline; the redacted identity-link statement must never be restored to public source control.



## Latest execution status — 2026-10-18

- Live Supabase migration ledger: 107 entries through `20261018064139_roshan_phase20_clinical_child_branch_isolation`; the forward-source delta tracks 14 later source mappings on top of the frozen 93-entry historical snapshot. This is not proof of a clean historical replay or persisted live-SQL hash equality.
- Clinical child branch isolation is applied and read back. A separate PostgreSQL 17 regression workflow for the next RPC-only write rollout passed on `ef6858e7eb6d7386a3e962aae4b7f51e020d36dd`.
- The new clinical write RPC migrations remain source-only until the frontend call sites are migrated and deployed. Direct DML revocation is staged separately to avoid breaking certificate creation or lab completion during rollout.






## Latest execution update — 2026-10-18 (Phase 29 safe subset)

- Live Supabase ledger: **109 entries** through `20261018065708_roshan_clinical_child_rpc_only_writes`; the forward-source delta contains sixteen mappings above the frozen 93-entry historical snapshot.
- Phase 28 RPCs are live and verified. Phase 29 has revoked direct DML on `prescriptions`, `prescription_items`, `patient_discounts`, and `insurance_prior_authorizations`; SELECT and RLS remain intact.
- Global read-only audit: 56/56 public base tables have RLS; zero grant any privilege to `anon`; all 81 `SECURITY DEFINER` routines have fixed `search_path`; no public one is executable by `anon`. Two private helpers inherit PUBLIC EXECUTE but `anon` has no schema USAGE, and they remain unmodified.
- Phase 30 (revoking direct DML on `lab_order_items` and `medical_certificates`) is intentionally gated until the new RPC frontend is deployed to the canonical production alias. Vercel's free deployment API quota resets 2026-10-19 08:52 Africa/Khartoum; a one-time continuation task is scheduled for 09:00.
