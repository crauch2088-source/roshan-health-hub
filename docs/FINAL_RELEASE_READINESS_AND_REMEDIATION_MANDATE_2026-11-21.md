# Roshan Health Hub — Final Release Readiness & Remediation Mandate
**Date:** 2026-11-21  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Execution owner:** Neon (primary autonomous executor)  
**Independent supervisor:** ChatGPT (evidence-based review; not the implementation owner)  
**Execution mode:** One continuous, evidence-driven campaign; no routine progress interruptions  
**Supersedes for execution sequencing:** the immediate next-step sequencing in `docs/FOCUSED_P0_AND_OPEN_PR_CLOSURE_MANDATE_2026-11-21.md`. It does NOT weaken any standing safety boundary or grant Production release authorization.

> **This is an execution mandate, not a request to write another plan.** Reconcile live state, execute every safe and authorized task in priority order, validate exact final heads, update project documentation, and return once with one consolidated evidence report. Do not stop after one PR, one green workflow, a report-only commit, or a list of recommendations.

## 1. Mission and success definition

Drive Roshan from the reported 77% engineering / 29% operational baseline toward the highest defensible state of release readiness. Close the live pharmacy authorization P0 at source and test level, finish the pharmacy lifecycle and medicine-identity work, stabilize ICD-10 and pediatric safety features without activating unapproved clinical protocols, complete cross-phase regression, close backup/restore and QA evidence gaps as far as access permits, and prepare a controlled-release package for owner review.

There are two distinct outcomes. Report them separately:
- **Engineering completion:** source changes, migrations authored, tests, CI, security review, documentation and release artifacts.
- **Operational readiness:** verified backup and restore, protected repository, authenticated role journeys, mobile/RTL/LTR accessibility checks, physical printer tests, real staff acceptance and clinical sign-off.

A green CI suite is not operational readiness. A candidate migration is not a Production fix. A protocol UI is not clinical approval. Never convert an unknown or blocked state into a pass.

## 2. Authority, collaboration, and hard safety boundaries

Neon is the primary executor for repository discovery, implementation, SQL/migration authoring, tests, CI, QA, debugging, PR maintenance, and documentation. Use the connected Composio integrations for GitHub, Supabase, Vercel and other authorized systems; inspect exact tool schemas and confirm account/project identities before acting.

ChatGPT is the independent supervisor/reviewer. Do not wait for ChatGPT to perform ordinary implementation. Do not hand back after each small task. If ChatGPT has previously made documentation-only changes, treat them as inputs to reconcile rather than reasons to duplicate work. If an independent review identifies a concrete defect, fix it on the relevant branch, rerun only the necessary checks, and include the correction in the same campaign.

Standing authorization covers ordinary non-production engineering: inspect, edit, test, commit, create/update feature branches and PRs, run QA with synthetic data, and update documentation. Do not ask for routine intermediate approvals. If an owner-only dependency blocks one task, record it once and continue all independent work.

### Non-waivable boundaries

1. **Production Supabase `jewzonxplxhogqrnhosl` is strictly read-only.** No DDL/DML, RPC mutations, migrations, grants/revokes, role/account changes, secrets, configuration, storage writes, or destructive operations.
2. **Production Vercel is inspect-only.** No deployment, promotion, rollback, alias, environment-variable, project-setting or domain changes.
3. **Do not merge source-code PRs into `main`.** Keep implementation on feature branches and PRs. The default branch may trigger Production deployment. Documentation-only changes on the existing documentation branch are allowed.
4. **Do not execute the Production migration chain.** Do not alter the Production migration ledger. A release runbook may be prepared, but actual Production application requires a separate explicit owner authorization after all preconditions are proven. This mandate does not contain that authorization.
5. QA writes are permitted only after verifying exact QA project `hopfohcnrtbiqjkgeukz`, and only with synthetic users/data. Never copy patient data from Production.
6. Do not bypass CI, branch protection, review requirements, RLS, authorization checks, or migration safeguards. Never force-push, rewrite published history, or overwrite another actor's newer work.
7. Do not weaken or delete tests to obtain a green result. Do not claim skipped, flaky, inaccessible, or unrun checks passed.
8. Never expose tokens, credentials, secret values, backup keys, patient-identifiable data, or PHI in logs, commits, PRs, screenshots, or reports.
9. Do not activate pediatric, diagnostic, prescribing, ICD-10 clinical workflow, or other consequential clinical protocols without documented qualified clinician approval. Keep activation disabled/guarded.
10. No paid service, subscription, infrastructure upgrade, or unapproved external spend.

## 3. First action: reconcile the live repository and evidence

Before changing anything, fetch the current state from GitHub and the connected systems. Do not trust the previous report as current truth. Record UTC timestamps and exact SHAs.

Read and reconcile at minimum:
- `docs/MASTER_PLAN.md`
- `AGENTS.md`
- `docs/AUTONOMOUS_ENGINEERING_COMPLETION_MANDATE_2026-11-21.md` if present
- `docs/FOCUSED_P0_AND_OPEN_PR_CLOSURE_MANDATE_2026-11-21.md`
- the latest focused closure report
- `docs/parallel-reports/TEMPLATE.md`
- `docs/PARALLEL_ENGINEERING_CONTINUATION.md` if present
- relevant PR descriptions, diffs, review threads, migration files, workflow definitions, test fixtures and current branch heads.

If a referenced file is absent, record that fact; do not silently substitute a similarly named file. Inspect open PRs/issues and branch ancestry. For every relevant PR, verify current state, draft/ready status, exact head SHA, base SHA, mergeability, changed files, unresolved review threads, and checks attached to that exact head. Historical green runs do not count if the head changed afterwards.

Revalidate the following as *reported starting points only*:
- `main`: `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`
- documentation branch: `docs/autonomous-completion-plan-20261120`
- PR #250: `832a8d38fba10409a44cd9eac7a4e34760aceaac`
- PR #260: `b963d7a`
- PR #291: `804302f`
- PR #293: `3eb2253`
- PR #294: `88417c6`
- PR #292: `89763d2`
- PR #210: `36d929d6663c89af5e9983bec905f5caf33d985c`
- latest report commit on docs branch: `5df36bc6173150cec5137e15418e7e52b4667bd5` (verify; do not assume).

Do not redo closed phases without a reproducible regression or changed dependency. Preserve all useful work and review evidence.

## 4. Priority 0 — pharmacy dispensing authorization boundary

Treat this as the critical security item until proven otherwise. The previous report says Production remains exposed because the live database has not received the candidate fix. Do not describe Production as fixed.

### Required source review

Independently inspect the complete call graph and all grants/ACLs for:
- `public.atomic_pharmacy_dispense`
- `public.fn_dispense_prescription_with_invoice`
- `private.atomic_pharmacy_dispense_unchecked`
- `private.app_has_role_permission`
- `private.app_has_claim_branch`
- `private.sync_user_role_text`
- all overloaded signatures, wrappers, triggers, SECURITY DEFINER functions, grants to PUBLIC/anon/authenticated/service_role, and UI/RPC callers.
- PR #250 Phase 61B/61C and PR #260 Phase 55B, plus Phase 57/57B and every actual prerequisite.

Prove that authorization is enforced inside the database boundary for direct RPC calls. UI-only checks are insufficient. Check claim spoofing, mutable session settings/GUCs, stale function bodies, search_path safety, owner bypass assumptions, wrapper bypasses, overloaded signatures, and whether private helpers are executable by non-owner roles.

The last stated policy is: only the canonical authenticated `pharmacist` role with the intended permission may directly dispense; `admin`, `super_admin`, `legacy_pharmacist`, doctors, receptionists, lab roles, anon and unauthenticated callers must be denied. Verify this is the approved policy in code/docs/tests; do not broaden it. Explicitly document the Super Admin exclusion.

### Migration chain

The last report listed this proposed order:
1. Phase 55 parent guard ACL reconciliation
2. Phase 55B private helper ACL reconciliation
3. Phase 57 pharmacy quantity-required guard
4. Phase 57B free-text external prescription guard
5. Phase 61B clinical role boundary
6. Phase 61C atomic dispense role boundary

Treat the order, filenames, dependencies, IDs, and checksums as unverified until re-read from repository files and migration metadata. Confirm whether any additional dependency exists; verify exact function signatures, owners, grants, idempotence, forward-only behavior, rollback/abort strategy, and QA/Production migration-history differences. Never manually edit migration history to manufacture parity.

### Mandatory PostgreSQL 17 regression matrix

Use a real isolated PostgreSQL 17 environment and actual role/ACL behavior, not mocks alone:
- canonical pharmacist + required permission: allowed.
- admin, super_admin, legacy_pharmacist, doctor, receptionist, lab roles: denied.
- anon and unauthenticated: denied.
- permission-only claims without canonical pharmacist role: denied.
- direct invocation of every public wrapper/overload: correct allow/deny result.
- direct call of private unchecked function by every non-owner role: denied.
- wrong branch, patient, visit, prescription, invoice ownership: fail closed.
- replay/idempotency and concurrent duplicate requests: one valid effect only.
- transaction rollback and exception paths: no partial stock, dispense, visit or invoice mutation.
- legitimate pharmacist flow remains functional.
- Phase 55B/57/57B/61B/61C sequence tested against clean baseline and upgrade path.

Add regression tests for every discovered bypass. Do not rely on a single CI summary: capture exact test commands, workflow IDs, final SHA, and test outputs.

### P0 exit criteria

Source review, dependency analysis, PG17 role/ACL regression, and exact-head CI must all pass before calling the *candidate code fix* complete. The live Production vulnerability remains open until a separately authorized owner-controlled release is executed and read-only post-release verification proves the new boundary. Under this mandate, Production remains unchanged.

## 5. Finish PR #293 — Phase 62 pharmacy lifecycle

Re-fetch the latest PR head and workflow logs. The previous four-file Prettier list is only a hint; discover the actual current failure. Use the repository-pinned package manager, lockfile and Prettier version. Do not install an arbitrary latest formatter or modify unrelated files.

Previously reported targets:
- `src/lib/pharmacy-lifecycle.ts`
- `src/routes/_authenticated/pharmacy.tsx`
- `tests/phase39-permissions-and-schema-consistency.test.ts`
- `tests/phase62-pharmacy-lifecycle-ui.test.ts`

After correction, run canonical format check, typecheck, lint, build, relevant unit tests, PG17 integration tests, UI tests and exact-head CI. Preserve the reported 332/332 guard tests only if rerun or verified against unchanged exact head.

Recheck domain invariants:
- idempotency key bound to canonical payload, actor and branch; payload/actor/branch mismatch fails closed.
- immutable dispensing history; cancellation/return does not erase or rewrite the original dispense.
- cumulative returned quantity never exceeds dispensed quantity, including concurrent transactions.
- invoice/compensation scoped to correct patient, visit and branch; NULL visit behavior explicit; ambiguous matches fail closed.
- compensation uses canonical schema fields and remains auditable.
- returned/quarantined stock is not saleable until authorized release.
- multi-visit and multi-branch tests exclude cross-association.
- combined Phase 60 → 62 → 63 regression passes.

Keep PR Draft if any critical behavior, security, data-integrity or required review remains unresolved.

## 6. Resolve PR #210 — medicine identity and catalogue integrity

Reconcile every remaining blocker individually against current PR comments, review threads, diff, tests and current `main`. Do not rely on the earlier shorthand list alone.

At minimum, verify where relevant:
- ingredient, strength, concentration, dosage form, route and pack-size are distinct identity dimensions.
- GTIN/barcode validation and uniqueness scope are correct.
- duplicate detection does not merge clinically distinct products.
- fuzzy matches remain suggestions and cannot silently become authoritative.
- catalogue source/provenance, branch scope and audit trail are preserved.
- import/update paths cannot mutate identity in a way that corrupts historical prescriptions or dispensing records.
- pharmacist physical-pack acceptance is explicitly outstanding until actually performed.

Create a blocker-by-blocker table: original finding, reproduction, fix, regression test, exact commit, evidence, residual risk. Keep PR Draft if any material identity blocker remains.

## 7. PR #291 — WHO ICD-10 2019; PR #292 — pediatric safety UI

For #291, verify exact-head CI, UI and schema persistence. Ensure the implementation is WHO ICD-10 2019, not ICD-10-CM. Preserve coding-system/version with historical diagnosis records; do not silently recode old records. Legacy free-text diagnoses remain readable. Search, reports and exports preserve coding context. Document WHO source, release/version/date, licensing/attribution considerations and limitations. UI syntax validation must not be described as diagnostic confirmation. Clinical adoption remains gated.

For #292, verify the PediatricSafetyPanel wiring and safe null/disabled behavior. Review dose calculations, weight units, mg/kg/dose versus mg/kg/day, frequency, duration, max dose, concentration/formulation, age/renal/hepatic considerations and rounding. Ensure clinician approval is required and unsafe/missing inputs fail closed. No medication protocol is activated by this work. Validate the referenced guideline evidence and its date/population/setting; distinguish code implementation, technical tests, evidence verification and clinician approval.

## 8. PR #260 / #294 and cross-phase integration

Revalidate #260 ACL and #294 inventory exact-head CI; do not reopen them without a concrete regression. Inspect their interaction with #250 and #293.

Run the integrated PG17 regression over all applicable dependencies: Phase 55B, 57/57B, 60, 61B/61C, 62, 63, ICD-10 persistence, inventory, dispensing, cancellation, returns, invoices, branch isolation and RLS. Test both clean installation and upgrade from the supported baseline. Check migration checksums and ledger alignment; do not change historical migration files.

Review open related PRs/issues for duplicate/superseded work and dependencies. Close an issue/PR only when the acceptance criteria are genuinely met and evidence is attached. Preserve unique findings and review threads.

## 9. Operational readiness — backup, branch protection, QA, UX and physical acceptance

### Backup and restore (#199)

Inspect workflow code and secret *names/metadata only*. The previous report says the runner expected exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`, while only `SUPABASE_ACCESS_TOKEN` was present. Do not read or print secret values and do not rename/configure secrets unless the connected owner-authorized workflow explicitly supports it. If owner action is required, state the exact action once and continue other work.

A backup is not proven until:
- a fresh encrypted backup is created successfully;
- integrity/checksum is verified;
- offline `age` decryption is tested without exposing key material;
- restore succeeds in an isolated non-production PostgreSQL 17 environment;
- restore integrity and application-level smoke tests pass;
- recovery time and recovery point are recorded.
Do not use Production as the restore target.

### Branch protection (#253)

Read current GitHub protection/ruleset state. Do not bypass permissions. If the owner must enable protection, specify exact required checks and owner action once. Never weaken required checks or make a protection claim from a local config file.

### QA role coverage

Verify exact QA project ref before writes. Reconcile the nine-role matrix against current application roles and permissions. The earlier report said only five of nine synthetic role identities existed and listed missing super_admin, dentist, specialist, lab_doctor/lab_assistant; confirm the canonical matrix rather than blindly creating duplicates. Provision only synthetic QA identities where authorized. Do not create Production users.

Run authenticated end-to-end workflows for all nine roles, including denied-path tests. Include login/session, branch context, patient search/registration, queue, encounter, diagnosis, prescriptions, pharmacy dispense, lab order/result, billing, inventory, reports, audit trail, permissions and logout as applicable to each role. Capture failures and screenshots without PHI.

### Mobile, accessibility and language

Verify the authenticated app on widths 320, 360, 375, 390 and 430 px; Arabic RTL and English LTR; keyboard navigation; focus visibility; labels; contrast; responsive dialogs/tables; touch targets; overflow; WCAG 2.2 AA checks. Test real flows, not only static snapshots. Record unsupported browser/device limitations.

### Printer and staff acceptance

Do not claim physical printer acceptance from mocked output. Prepare a concise test sheet for receipt/queue/lab labels as relevant, but mark physical execution blocked until on-site staff actually test the available printer/device. Real staff UAT requires actual users at the center; simulated accounts do not count.

## 10. Clinical evidence and approval policy

Sudan-specific guidance may be unavailable, incomplete or outdated. Do not block clinically useful work solely because a Sudanese protocol cannot be located. Prefer current WHO guidance, then current relevant specialty/national guidelines (e.g., NICE, CDC, IDSA, AAP, ACOG, RCOG, ESC as applicable), then high-quality systematic reviews/primary evidence.

For every clinical decision-support item, record source URL, issuing body, title, publication/update date, population, setting, dose units, contraindications, limitations and local feasibility. Distinguish ideal recommendations from evidence-supported alternatives where diagnostics, medicines, referral or monitoring are unavailable. Never invent a dose or threshold. Keep clinician approval and activation as separate explicit gates.

## 11. Controlled-release package — prepare only, do not execute

Prepare an owner-review release dossier containing:
- exact PRs and commits proposed for eventual release, dependencies and merge order;
- complete migration filenames, IDs, SHA-256 checksums, prerequisites and expected post-migration catalog/ACL/function state;
- preflight checklist: fresh encrypted backup, offline decrypt, isolated restore rehearsal, migration-ledger reconciliation, database snapshot, owner approval and maintenance window;
- execution sequence and responsible owner;
- read-only post-release verification SQL for function definitions, owners, ACLs, role behavior, RLS, triggers and migration ledger;
- smoke tests for pharmacist authorization and legitimate dispense;
- explicit abort criteria, rollback/forward-fix strategy, incident contacts/communications and recovery decision points;
- proof that the planned release cannot unintentionally deploy frontend changes or trigger unauthorized Vercel production deployment.

This is a *plan and evidence package only*. Do not apply migrations, alter Production, merge to main, deploy, promote or change Vercel settings.

## 12. Documentation and report requirements

Use `docs/parallel-reports/TEMPLATE.md`. Create one final campaign report:

`docs/parallel-reports/FINAL_RELEASE_READINESS_AND_REMEDIATION_REPORT_2026-11-21.md`

Update `docs/MASTER_PLAN.md`, relevant continuation/checkpoint docs, and PR descriptions where necessary. Keep one logical documentation commit where practical. Do not overwrite unrelated changes or the existing historical report.

The final report must include:
1. Executive verdict and timestamp.
2. Exact `main`, branch and PR SHAs; PR state, base/head, review state, exact-head workflow run IDs and results.
3. P0: source call graph, role matrix, function ACLs, migration dependency graph, PG17 regression evidence, residual risk and explicit Production status.
4. #293 formatting/functional/PG17/CI status.
5. #210 blocker-by-blocker disposition.
6. #291 and #292 clinical evidence, technical test status and approval gates.
7. #260/#294 and combined cross-phase regression.
8. Backup/decrypt/restore evidence, branch protection, QA nine-role coverage, mobile/RTL/LTR/WCAG, printer and staff UAT.
9. Controlled-release dossier location and owner-only actions.
10. Security/privacy review and any unresolved review threads.
11. Engineering and operational percentages with rubric, weights, numerator/denominator, and proof. Do not count blocked, skipped, unrun, mocked-only or owner-only items as complete.
12. ETA only if supported by actual remaining work and dependencies; otherwise state not reliably estimable.
13. Explicit confirmation that Production Supabase and Production Vercel were not changed.

Use a status vocabulary consistently: **implemented**, **tested**, **evidence-verified**, **independently reviewed**, **clinically approved**, **owner-approved**, **released**. These are not interchangeable.

## 13. Completion and stop conditions

Continue autonomously until all work that can be completed within the boundaries above is complete. If one owner gate blocks a task, document it and move on. Do not ask the user multiple times for the same permission or secret. Do not stop after a plan or partial PR.

Return only after:
- P0 candidate fix has independent source review, verified migration dependency chain, PG17 regression and exact-head CI, or a precisely evidenced residual blocker;
- #293 is formatted and validated on its final head;
- #210 blockers are individually reconciled and resolved as far as possible;
- #291/#292/#260/#294 and cross-phase tests have exact-head evidence;
- backup/restore and QA/operational gaps have been completed where authorized, with owner-only blockers consolidated;
- controlled-release dossier and final report are committed on a non-production branch;
- project docs and PR descriptions are consistent;
- Production Supabase and Vercel are confirmed unchanged.

If the live P0 has not been remediated through a separately authorized release, the report and final response must prominently state:

**PRODUCTION P0 REMAINS OPEN — NO-GO.**

Final user response: concise Arabic, one consolidated summary, report link, relevant PR links, exact SHAs, exact-head CI evidence, current engineering/operational percentages with rubric caveat, Production unchanged statement, and one consolidated list of owner/clinical/on-site gates. Do not claim the project is launch-ready unless every operational and release gate is evidenced.
