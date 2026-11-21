# Roshan Health Hub — Focused P0 Security & Open PR Closure Mandate
**Date:** 2026-11-21  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Execution mode:** Continuous autonomous engineering campaign; evidence-driven closeout  
**Preceding campaign report:** `docs/parallel-reports/FINAL_CLOSURE_CAMPAIGN_REPORT_2026-11-21.md`  
**Standing mandate:** `docs/AUTONOMOUS_ENGINEERING_COMPLETION_MANDATE_2026-11-21.md`

> This is an execution mandate, not a request for another plan. Start by reconciling live repository state, then execute the highest-risk work continuously. Do not return after one PR or one green workflow.

## 0. Authority, execution interface, and hard boundaries

You are the primary executor. Use the user's connected **Composio MCP** integrations as the primary interface for GitHub, Supabase, Vercel, and QA. Discover exact tool slugs and schemas before invoking them; verify the correct active connections and project/account identities. Do not silently switch accounts or use unrelated credentials.

Standing authorization covers ordinary engineering: inspect, edit, test, commit, create/update branches and PRs, rerun CI, and use synthetic QA data. Do not request routine approvals or stop for intermediate status messages. If one task is blocked by a missing owner credential, approval, or physical action, record it once and continue independent work.

### Non-waivable boundaries

1. **Production Supabase project `jewzonxplxhogqrnhosl` is strictly read-only.** No writes, RPC mutations, DDL/DML, migrations, grants/revokes, role/account changes, secrets, configuration, storage changes, or destructive operations.
2. **Production Vercel is inspect-only.** No deployment, promotion, rollback, alias, environment-variable, or project-setting changes.
3. QA writes are allowed only after verifying the exact QA project reference and only with synthetic accounts/data. Never copy patient data from Production.
4. Do not merge source-code PRs into `main`. The default branch has automatic Production deployment behavior. Keep code changes in isolated branches and PRs until the owner explicitly authorizes a controlled release.
5. Do not bypass checks, weaken tests/fixtures, suppress lint, rewrite migration history, force-push over concurrent work, or claim a skipped/blocked test passed.
6. Do not expose secrets, tokens, backup keys, credentials, or PHI in output, logs, commits, or reports.
7. Do not activate clinical protocols or claim clinical approval without documented qualified clinician sign-off.

## 1. Mandatory live-state reconciliation

Before modifying anything, verify and record timestamps, exact SHAs, branch ancestry, open/closed state, exact-head CI, and current database migration history. Treat the following as the last reported baseline, **not as facts until revalidated**:

- `main`: `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.
- PR #295 docs branch: `docs/autonomous-completion-plan-20261120`, report commit `3ea8cbbc8d7e9d90861cc6e7535aac3f7226c676`.
- PR #250 P0 boundary candidate: `26dbc1b`.
- PR #260 Phase 55B: `b963d7a`.
- PR #291 WHO ICD-10 2019: `6c5cda7`; CI run `44873193303` and Insurance UI run `44873193284` were reported failed.
- PR #293 Pharmacy Lifecycle: `3eb2253`; reported 332/332 guard tests and PostgreSQL 17 integration checks passed, while Prettier failed on four files.
- PR #210 Medicine Identity: `e53216a`; Draft with seven reported blockers and stale base.
- Production P0: `public.atomic_pharmacy_dispense` reported executable by `authenticated` without canonical pharmacist-role enforcement.
- Production migration history reportedly lacks Phase 61B, while QA has it. Verify exact migration IDs, hashes, dependencies, and actual objects.
- Production and Vercel must remain unchanged.

Read `docs/MASTER_PLAN.md`, `AGENTS.md`, the standing mandate, the latest closure report, the parallel continuation guide, the report template, relevant PR descriptions/diffs, and all referenced migrations/tests before implementation. Check whether another actor has already updated any target branch. Never overwrite newer work.

## 2. P0 — Close the atomic pharmacy dispense authorization vulnerability

**This is the first priority.** The report states that the Production exposure is still active. Do not minimize this because a candidate SQL migration exists.

### 2.1 Independent source and runtime-boundary review

Inspect every callable entry point and dependency involved in pharmacy dispensing, including at minimum:

- `public.atomic_pharmacy_dispense`
- `public.fn_dispense_prescription_with_invoice`
- the candidate unchecked implementation `private.atomic_pharmacy_dispense_unchecked`
- `private.app_has_role_permission`
- Phase 55B helper ACL changes in PR #260
- Phase 57 / 57B and Phase 61B / 61C migrations, their actual filenames/IDs, prerequisites, grants, and function signatures
- all UI, RPC, trigger, and legacy call sites that can reach dispensing.

Prove whether the authorization check is enforced at the database boundary for direct RPC calls, not merely in the UI. Confirm the check uses the canonical authenticated role and intended permissions, is not spoofable through user-editable claims or test GUCs, and cannot be bypassed through a legacy wrapper, overloaded signature, SECURITY DEFINER chain, PUBLIC/anon/authenticated/service_role EXECUTE grant, or stale function body.

The reported policy explicitly permits only the canonical `pharmacist` role for direct dispensing and excludes `admin`, `super_admin`, `legacy_pharmacist`, doctor, receptionist, lab roles, and anon. Verify that this is the approved intended policy in the source and test matrix; do not broaden it for convenience. Document the Super Admin decision as an explicit security policy, not an accidental side effect.

### 2.2 Migration dependency chain

The report says Phase 61C depends on Phase 61B, and Phase 61B is absent from Production. It also identifies an ordered chain:

`Phase 55B → Phase 57/57B → Phase 61B → Phase 61C`

Do not assume this sequence is complete or correctly named. Verify the actual dependency graph from SQL and migration ledger. Determine whether Phase 57 and 57B are both required, whether they depend on 55B, and whether any additional prerequisite exists. Verify forward-only behavior and idempotence. Identify any duplicate migration identifiers or hash collisions between QA and Production.

Do not apply any of these migrations to Production. Do not change Production's migration ledger. Build a deployment/runbook sequence with explicit preflight assertions, exact migration filenames and hashes, expected catalog/ACL/function state after each step, abort conditions, and read-only post-deployment verification queries. Any proposed Production application remains a separate owner-controlled release action.

### 2.3 Tests required before calling the code fix complete

Create or strengthen isolated PostgreSQL 17 tests that exercise the actual database boundary:

- canonical pharmacist with required permissions: allowed.
- admin and super_admin: denied.
- legacy_pharmacist: denied.
- doctor, receptionist, lab roles, anon, and unauthenticated: denied.
- permission-only claims without the canonical role: denied.
- direct calls to every public wrapper/overload: denied or allowed exactly according to policy.
- direct invocation of the private unchecked function: denied to every non-owner role.
- cross-branch, cross-patient, cross-visit, and invoice ownership mismatches: fail closed.
- replay/idempotency and concurrent duplicate requests: one valid effect only.
- transaction rollback and exception paths do not leave partial dispense/invoice/stock mutations.
- existing legitimate pharmacist workflow remains functional.

Use true PostgreSQL 17 database tests and role/ACL inspection. Test fixtures must set the real intended role explicitly; never weaken production checks to accommodate an incomplete fixture. Include regression coverage for Phase 55B compatibility and Phase 57/57B/61B/61C ordering.

### 2.4 Delivery and review

Update PR #250 on its existing branch if safe; otherwise create a clearly named successor branch/PR and explain why. Sync with current `main` using a non-destructive method; do not force-push. Keep the original evidence and history. Request or perform a genuinely independent second review if the available process supports it. Report exact SHA, changed files, test commands/run IDs, and unresolved concerns.

**P0 exit criterion:** source-level review, migration dependency proof, PostgreSQL 17 role/ACL regression, and all relevant CI on the exact current head pass. Even then, state clearly that Production remains exposed until the owner applies the complete approved migration chain in a controlled release. Do not claim the live Production vulnerability is fixed.

## 3. PR #293 — Pharmacy cancellation, return, and inventory reconciliation

Re-fetch the PR head and exact workflow logs. Do not assume the four-file formatting list is still current. Run the repository-pinned Prettier version/lockfile script, preferably in the project's supported Node environment; do not use an arbitrary latest formatter version. Format only the necessary files and preserve behavior.

Last reported files:
- `src/lib/pharmacy-lifecycle.ts`
- `tests/phase39-permissions-and-schema-consistency.test.ts`
- `tests/phase62-pharmacy-lifecycle-ui.test.ts`
- `src/routes/_authenticated/pharmacy.tsx`

Then run the repository's canonical format check, typecheck, lint, build, all relevant unit tests, PostgreSQL 17 integration tests, Insurance UI validation, and CI. Re-run all failed workflows on the final SHA.

Re-review the business invariants, not just formatting:

- idempotency key is bound to canonical payload, actor, and branch; same key with changed payload/actor/branch fails closed.
- cancellation and return never erase immutable dispensing history.
- cumulative returned quantity cannot exceed dispensed quantity, including concurrent transactions.
- invoice/compensation association is scoped to the correct patient, visit, and branch; NULL visit behavior is explicit and ambiguous matches fail closed.
- compensation uses the actual canonical schema fields and preserves financial auditability.
- quarantined returned stock cannot become saleable until an authorized release path.
- multi-visit and multi-branch tests prove no cross-association.
- Phase 60 → 62 → 63 combined regression passes against a canonical PostgreSQL 17 schema.

Do not fix lint by weakening tests or changing unrelated code.

## 4. PR #291 — WHO ICD-10 2019 diagnosis versioning

Inspect exact failed CI and Insurance UI logs first. Identify the root cause; do not assume it is formatting. Fix all code, type, lint, test, schema, or UI failures found.

Verify:
- the UI validation is syntactic and does not misrepresent syntax validation as clinical diagnosis confirmation.
- coding system/version are persisted with the diagnosis and historical snapshots remain stable.
- WHO ICD-10 2019 is represented accurately; do not substitute ICD-10-CM.
- legacy free-text diagnoses remain readable and unchanged.
- coding version changes do not silently recode historical diagnoses.
- search, reports, and exports preserve the coding-system/version context.
- migration is forward-only, safe on the supported baseline, and tested against PostgreSQL 17.

Document authoritative WHO source/version/date and known limitations. Clinical adoption remains gated pending clinician approval.

## 5. PR #210 — Medicine identity blockers

After the P0 and immediate CI failures are addressed, reconcile the seven blockers in the latest report with the actual PR diff and current base. Reproduce each blocker or mark it resolved with evidence. Review branch scoping, pack size, GTIN, duplicate detection, normalized ingredient/strength/form identity, catalogue provenance, and stale-base conflicts as applicable to the actual seven findings.

Do not collapse medicines that share a name but differ in strength, concentration, dosage form, route, or pack identity. Do not make unsafe fuzzy matches authoritative. Add regression tests for each resolved blocker. Keep the PR Draft if any identity or data-integrity blocker remains.

## 6. Cross-workstream regression and repository quality

Once #293 and #291 are green, run the combined relevant regression across Phase 55B, 57/57B, 60, 61B/61C, 62, 63, and ICD-10 persistence where dependencies permit. Verify current migration IDs and checksums; never edit migration history to manufacture parity.

Inspect #260 compatibility and PR #294's latest exact-head CI. Do not reopen completed work without a reproducible regression. Review open related PRs/issues for duplicate or superseded work, but preserve unique evidence and do not bulk-close issues merely to reduce counts.

## 7. Owner-only and environment gates

The last report identified these owner/environment dependencies. Recheck current status without repeatedly asking the user:

- #199 backup runner: secret metadata previously showed `SUPABASE_ACCESS_TOKEN` only, while the workflow preflight expects exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`. Inspect the actual workflow code and secret names. Do not read or print secret values, do not rename blindly, and do not change secrets unless the exact authorized owner workflow permits it. A successful archive is not a restore test; require offline `age` decrypt and isolated restore evidence.
- #253 branch protection: previously `protected: false`. Record current state. Do not circumvent permissions or weaken required checks. If enabling protection is owner-only, list the exact owner action once.
- QA: previously 5/9 synthetic roles, with missing role identities and preview SSO blocking E2E. Recheck exact QA project and role matrix. Create only synthetic QA users if the existing authorization and tool permissions support it. Do not create Production users.
- Clinical: pediatric protocols and ICD-10 adoption remain inactive until documented clinician approval.
- Physical printer tests and staff acceptance cannot be marked complete without actual on-site execution.

Do not let these gates prevent autonomous code/test work.

## 8. Required reporting and documentation

Use `docs/parallel-reports/TEMPLATE.md` for the next round report. Create:

`docs/parallel-reports/FOCUSED_P0_AND_OPEN_PR_CLOSURE_REPORT_2026-11-21.md`

Update `docs/MASTER_PLAN.md` and the relevant continuation/checkpoint files with current evidence. The report must distinguish:
- verified current Production exposure from candidate code fixes;
- source-level review from live Production remediation;
- implementation from technical testing;
- evidence verification from clinical review/approval;
- exact-head CI success from historical workflow success;
- autonomous work completed from owner-only blockers.

Include a table for #250, #293, #291, #210, #260, #294, #199, and #253 with current state, exact SHA, test/CI evidence, blockers, and next action. Include migration chain names/IDs/checksums and a deployment runbook for owner review, but no Production execution.

Recalculate engineering and operational percentages only if the rubric and evidence justify it. Explain weights and avoid counting blocked, skipped, unrun, or owner-only tasks as completed. Give an ETA only if it is evidence-based; otherwise state that it is not reliably estimable.

## 9. Completion condition

Do not return after producing a plan, a report-only commit, or one successful PR.

Return only after:
1. P0 source review, migration-chain analysis, and PostgreSQL 17 regression work are complete as far as safely possible.
2. #293 formatting and exact-head validation are complete.
3. #291 CI/UI failures are diagnosed and fixed or explicitly blocked with evidence.
4. #210 blockers have been individually reconciled and as many as possible resolved.
5. all related exact-head checks have been rerun.
6. the next-round report and project documentation are committed on a non-production branch.
7. Production Supabase and Production Vercel are confirmed unchanged.

If an owner gate blocks the final live fix, state prominently: **PRODUCTION P0 REMAINS OPEN — NO-GO**. Give one consolidated list of owner actions, not repeated approval requests.

Final response to the user must be concise and include the report link, relevant PR links, exact SHAs, CI evidence, current engineering/operational percentages with rubric caveat, Production safety statement, and the remaining owner/clinical gates.
