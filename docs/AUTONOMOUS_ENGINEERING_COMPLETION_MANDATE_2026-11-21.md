# Roshan Health Hub — Autonomous Engineering Completion Mandate
**Created:** 2026-11-21  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Status:** EXECUTE TO COMPLETION — this is an execution mandate, not a planning request.

## 0. Binding instruction and authority

You are the **sole primary engineering executor** for this campaign. The user has given standing authorization to proceed autonomously with ordinary engineering work. **Do not ask the user for routine approvals, confirmation after each task, permission to inspect files, permission to edit code, permission to run tests, permission to create commits/branches/PRs, or permission to continue.** Do not return after every small task. Continue until all work that can be completed autonomously has been completed, verified, documented, and reported.

The user has explicitly asked that you work through the **connected Composio MCP integrations**. Use Composio MCP as the primary execution interface for GitHub, Supabase, Vercel, and any other connected service required by this repository. At the start:
1. Discover the exact required tools with Composio tool search.
2. Verify the relevant GitHub, Supabase and Vercel connections are ACTIVE; select the correct connected account/project explicitly where multiple accounts exist.
3. Retrieve the schemas for the exact tool slugs before invoking them.
4. Prefer structured Composio actions over browser-only/manual workarounds. Use browser automation only when the required operation cannot be completed through the available MCP action.
5. If a Composio action fails, diagnose and retry appropriately; do not silently switch to an unrelated account or an unapproved route. If the connection/tool is genuinely unavailable, document the exact limitation and continue all independent work.

**Standing authorization covers normal repository engineering and QA work**: inspection, coding, tests, documentation, commits, branches, PR creation/update, CI reruns where available, synthetic-only QA data and authenticated QA testing. Do not repeatedly ask for permission.

### Non-waivable safety boundaries
- **Production Supabase is strictly READ-ONLY throughout this mandate.** No Production INSERT/UPDATE/DELETE, RPC writes, SQL DDL/DML, migrations, grants/revokes, role/account changes, secrets/config changes, storage mutations, or destructive actions. Do not use elevated/service-role write tools against Production. You may inspect Production catalogs, grants, RLS, migration history, project configuration and read-only data necessary for diagnosis.
- No Production deployment, promotion, rollback, alias change, environment-variable change, or Vercel project setting change. Inspect only.
- QA may be mutated only with clearly synthetic/test accounts and data, after confirming the exact QA project reference. Never copy real patient data into QA. Do not expose credentials, tokens, backup passphrases, encryption keys or PHI in commits, reports, logs, or chat.
- Do not activate clinical protocols, make clinical approval decisions, or represent clinical review as complete without a documented qualified clinician sign-off. Build and test the software pathway, but leave activation gated.
- Do not bypass branch protection, suppress failing tests, weaken fixtures, delete historical evidence, rewrite migration ledgers, or force-push over others' work.
- Merges are allowed only when every required check is green, review/security gates for that change are satisfied, branch ancestry is current, and you have verified that the merge cannot trigger an unauthorized Production deployment. If merge would deploy to Production or deployment behavior is uncertain, leave the PR ready for review and report why. Never treat CI green as permission to deploy.
- Owner-dependent tasks (credentials, offline decryption, physical printer checks, staff UAT, clinical sign-off, owner-only branch protection settings) must be recorded precisely, but they must **not** stop unrelated autonomous work. Do not ask the user for these repeatedly; list them once in the final owner-action section.

## 1. Source of truth and mandatory initial reconciliation

Before editing:
1. Read and follow:
   - `docs/MASTER_PLAN.md` (primary project source of truth)
   - `AGENTS.md`
   - `docs/PARALLEL_ENGINEERING_CONTINUATION.md`
   - `docs/parallel-reports/TEMPLATE.md`
   - `docs/AUTONOMOUS_COMPLETION_PLAN_2026-11-20.md`
   - `docs/ROSHAN_CHECKPOINT_AND_EXACT_PATCHES_2026-11-21.md`
   - all relevant recent reports under `docs/parallel-reports/`
   - the clinical guideline policy and checkpoint files supplied in the 2026-11-20/21 work.
2. Inspect the actual current GitHub default branch, all active branches, all open PRs/issues, current CI, commit ancestry, deployments and both Supabase projects. Do not assume a pasted report is current.
3. Reconcile the previously observed baseline discrepancy: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` versus `f046e41f7c67ccb3d7f3ad63fcd00729bb756e74`. Prior comparison showed `f046e41` seven commits ahead of `79d81f0`, with documentation-only changes in the comparison, but verify the live default branch and each PR base/head now. Do not rebase blindly.
4. Current reported campaign state to revalidate, not blindly trust:
   - PR #293 head `3eb2253`: Pharmacy Cancellation & Return; CI and Insurance UI validation were failing on Prettier only at that head; TypeScript had 0 errors and reported unit guard tests 332/332.
   - PR #294 head `707a985`: Inventory Ledger Controls; CI failed because Phase 39 schema consistency test could not find `medicine_batches` in canonical baseline/tracked migrations. The failing assertion is a real schema-source-of-truth issue until proven otherwise, not permission to weaken the test.
   - PR #295 head `ced42ae`: autonomous completion plan/checkpoint documentation.
   - Reported 45 open PRs and issues #253, #218, #217, #199; re-fetch exact live counts and current set.
   - Reported Production P0: `public.atomic_pharmacy_dispense` callable by `authenticated` without canonical pharmacist-role enforcement.
   - Reported Production P1: `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` with `proacl IS NULL` / inherited PUBLIC EXECUTE.
   - Reported Production backup runner failure #199 on 2026-11-15 due to exactly-one DB credential preflight; last Drive archive reported 2026-11-12.
   - Reported Production/QA migration-ledger divergence (129 vs 27 entries), QA role coverage 5/9, zero authenticated E2E journeys, and no completed mobile/RTL/WCAG live QA sweep.
5. Record actual timestamps, branch names, commit SHAs, project refs and CI run IDs in your checkpoint/report. Separate verified facts from historical claims and assumptions.

## 2. Execution model: one continuous campaign, not serial micro-sessions

Work through all workstreams below in dependency order. Parallelize only genuinely independent tasks. Do not return a plan instead of implementation. Do not stop after one PR. Do not ask the user to say “continue”. If a task is blocked by an owner-only gate, record the blocker and immediately continue with all remaining independent tasks.

For each change: inspect the existing implementation and tests, write/adjust regression tests first where practical, implement the smallest safe change, run targeted tests, run relevant full suites, inspect the final diff, commit with a descriptive message, update the PR, and record exact evidence. Never report a test as passed unless you have observed its successful result on the exact commit SHA being reported.

## 3. RHH-00 — Governance, source of truth, branch safety, reporting

- Reconcile #295 and the autonomous completion plan with actual state.
- Update `docs/MASTER_PLAN.md` so every item has a truthful status: planned, implemented, technically tested, evidence verified, clinically reviewed, approved for activation, operationally accepted, or blocked.
- Consolidate duplicate/overlapping parallel work reports and PRs (reported #257–#286, plus current active work) without discarding unique fixes or evidence. Identify duplicate PRs, dependencies, conflicts and the canonical implementation for each work item.
- Inspect #253 branch protection/rulesets and document exact current settings. If owner-level permission is needed to change protection, leave a precise owner action; do not bypass it.
- Keep `AGENTS.md`, continuation instructions, templates and checkpoint aligned with actual collaboration model and safety boundaries.
- Preserve one authoritative checkpoint with current branch/PR/commit state, completed items, outstanding items, exact next action, CI IDs and blockers.
- Ensure commits contain code + tests + docs together where appropriate; avoid fragmented one-line commits and unnecessary CI/build churn.

## 4. RHH-01 — Pharmacy cancellation, return and financial integrity (PR #293; Phase 62)

Finish PR #293 completely:
1. Resolve all current formatting/lint failures using the repository's pinned formatter version/configuration; run Prettier on the exact affected files, including `src/routes/_authenticated/pharmacy.tsx`, `tests/phase39-permissions-and-schema-consistency.test.ts`, and `tests/phase62-pharmacy-lifecycle-ui.test.ts` as applicable. Do not hand-wave a “prettier-only” failure.
2. Re-run typecheck, lint, build, unit/guard tests, all relevant PG17 integration workflows and Insurance UI validation on the final exact head.
3. Audit idempotency semantics:
   - same idempotency key + same canonical payload + same actor + same branch returns the original outcome without duplicate effects;
   - same key with changed payload, actor or branch fails explicitly and safely;
   - concurrent duplicate requests produce exactly one financial/inventory effect;
   - payload canonicalization is stable and tested.
4. Preserve immutable dispensing history. Cancellation/return must not erase the historical quantity dispensed, actor, timestamp, batch, invoice, visit, branch, handover state or prior event. Avoid resetting historical facts such as `is_dispensed`/ `dispensed_quantity` without a durable append-only event/history model and a proven audit trail.
5. Verify invoice association is unambiguous and scoped to patient + visit + branch, including NULL visit semantics. Ambiguous matches fail closed. Verify `financial_compensations` against the real schema; the reported canonical column is `source_invoice_id`, not `invoice_id`, but inspect current DDL before editing tests.
6. Test multi-visit patients to prove the correct invoice and compensation are selected.
7. Enforce role and permission boundaries in production code and tests. Tests must explicitly set caller role/context; a fixture that permits solely by permission when `test.role` is unset is not acceptable proof of a role boundary. Do not weaken production contract to make tests pass.
8. Enforce cumulative return quantity <= actually dispensed quantity under concurrent transactions. Returned stock must enter quarantine/non-saleable state until authorized disposition/release; expired/contaminated/unknown-condition goods must never return directly to saleable inventory.
9. Verify cancellation before handover, post-handover return, partial returns, repeated requests, stale requests, invoice compensation, stock reconciliation, audit events, branch isolation, RLS and failure rollback.
10. Verify Phase 60 -> Phase 62 -> Phase 63 integration once dependencies are available. Use real PostgreSQL 17 two-session concurrency tests, not sequential simulations.
11. Do not merge until all required CI and review gates are green.

## 5. RHH-03 — Inventory ledger controls (PR #294; Phase 63)

Complete PR #294 and resolve the `medicine_batches` schema failure correctly:
1. Trace the canonical origin of `medicine_batches` through baseline SQL, historical migrations, forward migrations, schema snapshots and live catalog evidence. Determine whether the table is missing from the baseline, missing from a tracked migration, or incorrectly named/located. Do not simply add a test exception, hardcode a phantom table, or rewrite migration history.
2. Keep canonical schema tests meaningful and fail-closed.
3. Review `db/roshan_phase63_inventory_ledger_controls.sql` around reported lines 176, 263 and 369, especially `GREATEST(0, stock_quantity + ...::integer)`. Prevent silent negative-stock clamping, truncation, overflow, stale writes or ledger drift. Validate quantities, units, bounds and exact arithmetic. Reject invalid state transitions rather than silently normalizing them.
4. Review typed wrapper `src/lib/inventory-ledger.ts` and the five RPCs:
   - `adjust_inventory_batch_atomic`
   - `quarantine_expired_batch_atomic`
   - `record_inventory_writeoff_atomic`
   - `update_medicine_selling_price_atomic`
   - `reconcile_medicine_stock_ledger`
5. Audit authorization, canonical pharmacist/authorized-role checks, branch binding, idempotency keys, audit records, race conditions, batch expiry, write-off reasons, price history and reconciliation invariants.
6. Audit the Ledger Controls UI in `src/routes/_authenticated/inventory.tsx`: Arabic RTL/English LTR, role guard, accessible labels/errors, no hidden direct table writes, safe UUID idempotency, loading/duplicate-submit/error states, mobile usability and confirmation for consequential actions.
7. Keep the Phase 63 UI test grounded in the canonical `medicine_batches` schema.
8. Add the combined Phase 60 -> Phase 62 return -> Phase 63 reconciliation regression, including returned/quarantined/write-off stock and multi-visit/invoice isolation.
9. Add real PostgreSQL 17 two-session concurrency coverage for conflicting adjustments, returns, write-offs and reconciliation.
10. Run all required CI on the final exact head and document any remaining dependency on #293.

## 6. RHH-02 — Pediatric prescribing safety (PR #292)

- Review `src/lib/medication-engine/pediatric-safety.ts` and PR #292 from source, not only its summary.
- Wire the safety engine into actual consultation/visit/prescribing UI and pharmacy workflow; a helper with zero real UI callers is not complete.
- Use patient age, current measured weight (with units and measurement date), indication/diagnosis, route, formulation/concentration, renal/hepatic factors when relevant, allergies, contraindications, maximum single/daily doses, interval, duration and relevant interactions.
- Make missing/implausible weight, age or required clinical inputs fail safely; never silently substitute adult dose or fabricate a value.
- Distinguish dose recommendation from prescription authorization. Clinician must review/approve consequential prescribing; do not activate protocols without qualified clinical sign-off.
- Provide transparent calculation basis, source/version, warnings and editable clinician decision with audit history.
- Validate all dose calculations and bounds against current trusted references; no invented dose thresholds.
- Test neonates, infants, children, adolescents, weight extremes, missing weight, unit conversion, max dose, duplicate ingredients, allergy, renal adjustment where supported, and high-risk diagnoses.
- Ensure the UI makes it impossible to confuse mg/kg/dose with mg/kg/day.
- Document clinical-review and activation gates separately from engineering tests.

## 7. RHH-04 — WHO ICD-10 2019 persistence and coding (PR #291)

- Complete persistent WHO ICD-10 2019 coding/search/versioning, not just a UI list.
- Preserve the WHO ICD-10 2019 code set and provenance; do not substitute ICD-10-CM.
- Preserve historical diagnosis text/code/version when catalogs change; do not silently remap prior clinical records.
- Support safe search, exact code validation, Arabic/English display where source data permits, branch-safe access and audit trail.
- Verify coding specificity, exclusions/inclusions, code validity, unknown/retired code behavior and clinical workflow integration.
- Document source URL, publication/version date, population/setting limitations and any localization decisions.
- Leave clinical adoption/activation as pending until clinician review is documented.

## 8. RHH-05 — Authenticated QA, complete workflows and accessibility

- Build and execute authenticated E2E journeys against QA only, using synthetic data.
- Verify all nine required roles: Super Admin, Admin, Reception, GP/Doctor, Dentist, Specialist, Lab Doctor, Lab Assistant/Lab Tech, Pharmacist. Reconcile naming differences with the actual role model and permissions; do not invent role equivalences.
- Reported QA currently has five active role accounts (admin, doctor, lab_tech, pharmacist, receptionist) and missing super_admin, dentist, specialist, lab_doctor/lab_assistant; recheck actual state. Create only synthetic QA users if permitted by the connected QA environment and existing auth workflow. Never modify Production Auth users.
- Test end-to-end journeys: registration/search, reception/queue, GP consultation, diagnosis/ICD-10, prescribing, pediatric safety, pharmacy dispense/handover/cancellation/return, lab order/sample/result/review, dental workflow, specialist referral, billing/compensation, inventory receipt/adjustment/quarantine/write-off, reports, certificates, follow-ups, appointments, partners/insurance where currently in scope, audit and logout/session expiry.
- Cover all authenticated routes/screens in `MASTER_PLAN.md` (reported 27; verify current count). Test allowed and denied actions per role, branch isolation, session expiry, direct URL access and API/RPC enforcement.
- Run viewport sweeps at 320, 360, 375, 390 and 430 px; Arabic RTL and English LTR; keyboard and screen-reader basics; WCAG 2.2 AA contrast, focus, labels, target size, error announcement and navigation.
- Do not claim authenticated E2E, mobile, RTL/LTR or WCAG complete unless executed against the actual QA deployment and recorded with evidence.
- If Vercel preview is SSO-protected, use authorized connected browser/auth flows if available; do not bypass SSO or invent credentials.

## 9. RHH-06 — Security, PHI, RLS, RPC and telemetry (PR #290 and related #250/#260/#218)

### SEC-01 — Pharmacy dispense boundary (P0; PR #250 / Phase 61C)
- Independently review the actual SQL, grants, wrapper and tests for `public.atomic_pharmacy_dispense`.
- Verify the reported Production finding: authenticated execution plus `pharmacy.update` and `billing.create` permissions without canonical pharmacist role enforcement. Confirm live grants and function body using read-only Production queries.
- Review the proposed fix for least privilege, canonical role resolution, branch binding, caller identity, transaction atomicity and all relevant role-denial cases.
- Explicitly test Admin, Super Admin, Reception, GP, Dentist, Specialist, Lab Doctor, Lab Assistant, Pharmacist and unauthenticated callers. Decide from documented product policy whether Super Admin may dispense; do not assume privilege inheritance.
- Test direct RPC calls, not only UI hiding. UI restrictions do not substitute for database authorization.
- Do not apply the fix to Production under this mandate. Prepare and test a safe forward-only migration and report the exact Production remediation required.

### SEC-02 — Private helper EXECUTE ACL (P1; PR #260 / Issue #218)
- Inspect `private.app_has_claim_branch(uuid)`, `private.sync_user_role_text()` and all related Phase 55 helper functions/grants in Production and QA, read-only.
- Reported Production `proacl IS NULL` may inherit PUBLIC EXECUTE; verify effective privileges, owner, schema usage and function signatures rather than relying on raw ACL text alone.
- Replace the intentionally failing reproduction in #260 with a forward-only, idempotent ACL remediation migration. Preserve function owners and required internal callers. Explicitly revoke PUBLIC/anon/authenticated where appropriate and grant only required execution to trusted roles.
- Test least privilege and all legitimate callers in isolated QA/PG17. Do not rewrite applied migration ledgers or backdate migration versions.
- Never execute the migration on Production.

### Broader security and PHI
- Complete RHH-06 / #290: RLS and storage policy audit, branch isolation, least privilege, PHI-safe logs/telemetry, audit events, error redaction, secrets handling, rate limits and direct RPC enforcement.
- Review #210 medicine identity work and resolve all seven reported technical blockers. Preserve product/medicine identity, pack/formulation/strength/unit consistency, barcode/brand/generic identity and safe dispense mapping. Do not merge on green CI alone.
- Inspect #218 catalog ACL/snapshots and #217. Reconcile Production and QA catalog/migration divergence using provenance evidence; never replay all QA migrations into Production or edit migration ledger history.
- Review all security-sensitive functions, triggers, views, policies and grants introduced by campaign PRs.
- Verify `setup_required()` remains safe and returns only the intended boolean status; preserve private billing idempotency/archive data and do not blindly enable RLS or drop Production archives.

## 10. RHH-07 — Medicine identity, pharmacy physical workflow and finance

- Resolve PR #210's seven blockers through source-level review and tests.
- Review finance/printing/receipt and related work in #280, #181, #258, #179 and any linked PRs/issues.
- Validate accounting invariants: invoice, payment, compensation, cancellation, return, stock valuation, branch attribution and idempotency.
- Ensure finance-only RPC writes are not reachable from clinical roles and clinical workflows cannot mutate accounting state except through explicitly authorized atomic RPCs.
- Verify thermal/A4 print layouts, Arabic/English, paper sizes, totals, tax/discount fields if used, patient privacy and print failure/retry behavior in a real device test where available. If no physical printer/device is available, complete code/automated checks and mark physical verification as owner-dependent.
- Do not invent Sudan-specific regulatory/tax requirements; document unknowns for owner review.

## 11. Backup, restore and Production/QA provenance — Issues #199, #218

- Diagnose backup runner #199 using connected GitHub Actions, repository workflow and logs. Reported failure run #43764265014 (2026-11-15): preflight requires exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`. Verify current workflow and latest run; do not assume the old run is still latest.
- Do not request secrets in chat, print secrets, commit secrets or alter repository secrets. If a secret is missing and only an owner can configure it, provide the exact secret name(s), repository, workflow and safe configuration instruction once in the final owner actions.
- Inspect latest backup artifact metadata, coverage, encryption, retention, storage objects and run history without exposing secret material.
- Reported last encrypted Drive archive: `roshan-production-backup-43183851731.zip`, 2026-11-12, 305,284 bytes. Revalidate exact file/date/size and whether it includes database, Storage, Auth/Vault/config as expected.
- Do not claim restore verified until an isolated restore rehearsal is performed and integrity checks pass.
- Offline `age` decryption requires owner-held key/device; do not ask for the key or upload it. Record as owner-dependent if unavailable.
- Compare Production and QA migration ledgers, versions, schema objects, grants, RLS, functions and triggers with provenance. Reported 129 vs 27 migration rows and differing PostgreSQL minor versions must be independently checked. Produce a migration reconciliation matrix: applied in Production only, QA only, common same checksum, common different checksum, missing source, and safe forward remediation. Never bulk replay QA migrations to Production or mutate history.
- Backup/restore rehearsal must be isolated and must not affect Production.

## 12. Vercel and deployment controls

- Use Composio Vercel tools to inspect the canonical `roshan-health-hub` project, production branch, recent production and preview deployments, source SHAs, build status, logs/events and aliases.
- Confirm whether merge to main automatically creates/promotes a Production deployment. Treat unknown deployment behavior as a hard stop for merge.
- QA preview SSO restrictions must be handled through authorized account/browser workflows only.
- Do not change Vercel project settings, environment variables, domains, aliases, deployment targets or Production deployments.
- A successful preview deployment is not proof of production readiness; a successful Vercel status is not proof that all GitHub Actions checks passed.

## 13. Clinical evidence and guideline policy (mandatory)

Sudan-specific guidance may be unavailable, incomplete or outdated. **Do not block evidence-based implementation solely because a Sudanese guideline cannot be found.** Use the following hierarchy, selecting the latest applicable version:
1. WHO guidance, prioritizing primary care, emergency, maternal/newborn, pediatric and resource-limited settings.
2. Current specialty guidelines from reputable organizations (e.g. NICE, CDC, IDSA, AAP, ACOG, RCOG, ESC and relevant specialty bodies).
3. High-quality national guidelines from reputable health systems.
4. Systematic reviews/meta-analyses and high-quality primary evidence when no suitable guideline exists.

For every clinical protocol/decision-support rule, record source URL, title, publication/update date, version, population, care setting, recommendation strength/limitations and date accessed. Contextualize recommendations to available medicines, diagnostics, equipment, monitoring, referral and follow-up in the actual service setting. Distinguish ideal standard-of-care recommendation from evidence-supported feasible alternatives. Do not fabricate doses, thresholds, contraindications or evidence.

Medication rules must specify indication, population, dose, units, route, frequency, duration, maximum single/daily dose, weight/age basis, renal/hepatic adjustment when relevant, contraindications, interactions, formulation/concentration and reference/version. Require clinician approval before consequential prescribing. Keep these states distinct: implemented in code; technically tested; evidence verified; clinically reviewed; approved for activation.

## 14. Cross-cutting quality requirements

- PostgreSQL 17: test actual migrations and transaction behavior. Concurrency claims require two genuinely concurrent sessions/transactions.
- Test-driven development for behavior changes: regression test first where feasible; test happy path, denial, invalid inputs, idempotency, concurrency, rollback and branch isolation.
- Preserve backward compatibility and historical data; migrations must be forward-only, idempotent where appropriate, reversible only where safely possible, and never rewrite production history.
- Verify RLS and grants at the database layer; UI visibility is not authorization.
- Ensure branch scoping across all data and RPCs.
- Test Arabic RTL and English LTR, 320–430px mobile widths and WCAG 2.2 AA.
- No test may use real patient data, production credentials or real patient identifiers.
- No test may pass by skipping the substantive assertion or weakening the fixture.
- Inspect full diff and run secret/PHI scanning before PR updates.
- Record exact commands/tool actions, environment, versions, commit SHA, workflow run IDs and results.
- Do not overstate completion. Use separate labels for implementation, technical verification, evidence verification, clinical review, activation approval and operational acceptance.

## 15. Final completion criteria

Do not call the campaign complete merely because the PRs are green. The autonomous campaign is complete only when:
- All autonomous engineering tasks above are implemented or have a specific, evidence-backed reason they cannot be completed.
- Every PR has current base/head, a reviewed diff, passing required CI or a clearly documented blocker, and no hidden failing/skipped gate.
- #293 pharmacy lifecycle, #294 inventory ledger, #292 pediatric safety UI integration, #291 WHO ICD-10 persistence, #250 dispense authorization review, #260/#218 ACL/provenance, #210 medicine identity, #290 PHI/security and finance/printing work have been addressed to the extent technically possible.
- The Phase 60 -> 62 -> 63 combined regression and real PG17 concurrency tests are completed where dependencies allow.
- Authenticated QA E2E, all nine roles, all authenticated screens, mobile, RTL/LTR and WCAG are run or precisely blocked by missing owner-only access/device/account.
- Production and QA migration/catalog divergence is reconciled into an evidence-backed matrix, without any Production mutation.
- Backup-runner failure is either resolved through owner-authorized secret configuration or documented with exact owner steps; backup freshness and restore status are explicit.
- `MASTER_PLAN.md`, autonomous completion plan, checkpoint and PR descriptions accurately reflect reality.
- Production remains untouched.

## 16. Required final report — repository deliverable, not chat-only

When all autonomous work is exhausted, create/update this repository file:
`docs/parallel-reports/FINAL_AUTONOMOUS_CAMPAIGN_REPORT_2026-11-21.md`

Follow `docs/parallel-reports/TEMPLATE.md`. If the template requires a per-window report, create it in the correct numbered folder and link it from the consolidated report. Also update:
- `docs/MASTER_PLAN.md`
- `docs/AUTONOMOUS_COMPLETION_PLAN_2026-11-20.md`
- `docs/ROSHAN_CHECKPOINT_AND_EXACT_PATCHES_2026-11-21.md`
- relevant PR descriptions/issues with concise evidence and dependencies.

The final report must include:
1. Actual verified baseline/default branch SHA and date/time.
2. All commits, PRs, issues and exact final heads; merged/unmerged status.
3. Work completed by workstream, files changed and rationale.
4. Tests run on exact SHAs, commands, CI run IDs, pass/fail/skipped counts and links.
5. Live QA/Production read-only catalog/security/migration findings and project refs (never credentials).
6. Security risk register with severity, evidence, mitigation status and whether Production remains exposed.
7. Clinical evidence sources and explicit clinical review/activation state.
8. QA role coverage, authenticated E2E journeys, route coverage, mobile/RTL/LTR/WCAG evidence.
9. Backup latest run/artifact, encryption/decryption and restore status.
10. Vercel deployment state and proof Production was not changed.
11. Engineering completion percentage and operational readiness percentage, each with rubric/denominator and evidence. Do not reuse stale 64.5% / 27.0% estimates without recalculation.
12. Remaining owner-only actions in one concise checklist; no repeated approval requests.
13. A realistic ETA only if it can be derived from observed throughput and remaining dependencies; otherwise explicitly say not reliably estimable.
14. The next exact action if any work remains.

**Deliver the report in the repository** at the exact path above, commit it, and link it in the final GitHub PR/issue or campaign summary. Do not merely paste a report in chat. Do not return an interim report to the user while independent work remains.

## 17. Final response to the user

Return only after the campaign is exhausted. In the final response, provide:
- Link to the consolidated report in the repository.
- Concise summary of completed work and any remaining owner-only gates.
- Separate engineering and operational percentages with calculation basis.
- Exact statement that Production was or was not changed (it must remain unchanged under this mandate).
- No inflated launch/readiness claim.

**Begin now. Revalidate the live repository and integrations, then execute the full campaign continuously.**
