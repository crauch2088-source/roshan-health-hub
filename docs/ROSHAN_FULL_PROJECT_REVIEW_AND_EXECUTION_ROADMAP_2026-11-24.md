# Roshan Health Hub — Full Project Review & Consolidated Execution Roadmap

**Review date:** 2026-11-24  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Review baseline:** `main` @ `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`  
**Scope:** repository, open PR/issue portfolio, application route inventory, Supabase Production/QA read-only catalog checks, GitHub Actions, Vercel deployment metadata, and backup/restore evidence  
**Delivery type:** documentation-only review and roadmap; no implementation or hosted-environment changes  
**Status:** **REVIEW COMPLETE — OWNER REVIEW REQUESTED — PRODUCTION NO-GO**

> This document is a dated evidence snapshot and execution supplement. It does not replace `docs/MASTER_PLAN.md`, `AGENTS.md`, the Roshan Constitution, existing release dossiers, or the individual PR acceptance criteria. Where older reports conflict with evidence checked on 2026-11-24, this document records the newer state and links the older record rather than silently rewriting history.

---

## 1. Executive decision

Roshan has a substantial application and database foundation, but it is **not yet approved for live clinical/financial operation as the system of record**.

The decisive blockers are not missing screens. They are:
1. The Production pharmacy authorization boundary and related private-helper ACL discrepancy are still open in the live database; candidate fixes exist in unmerged PRs.
2. QA-only fixes and feature work have not been promoted through a controlled, reconciled release path.
3. The repository has a large open-PR backlog and branch protection could not be re-verified through the current GitHub integration.
4. Authenticated acceptance across all nine clinic roles, mobile RTL/LTR, accessibility, printing, and real staff workflows is incomplete.
5. Backup database restore evidence has materially improved, but full disaster recovery, Storage object recovery, control-plane reconstruction, and owner acceptance of the recovery policy remain open.

**Recommendation:** continue non-production engineering and QA; keep Production read-only until the P0 security chain, migration reconciliation, backup/restore preconditions, independent review, and explicit owner release approval are all satisfied.

### 1.1 Evidence confidence

| Area | Current conclusion | Confidence |
|---|---|---|
| Mainline source and PR inventory | Read directly from GitHub on 2026-11-24 | High |
| Application route inventory | Generated route tree inspected on main | High for route existence; not proof every workflow works |
| Production/QA RLS catalog | Read-only PostgreSQL catalog queries | High for the queried table counts |
| SECURITY DEFINER inventory | Read-only PostgreSQL catalog query | High for counts; not a substitute for body-by-body authorization review |
| PR checks | Exact-head runs inspected where available; older reports clearly marked historical | Medium-high |
| Live browser UAT | Not completed across all roles/routes | Low / incomplete |
| DR | Newer restore evidence recorded in PR #297; full DR gate remains open | Medium-high for database restore claims; incomplete for full service recovery |

## 2. Repository and deployment baseline

### 2.1 Mainline

- Current `main` observed: `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a` — commit message: `docs(roshan): add autonomous engineering completion mandate`.
- Latest main push workflow inspected for this SHA: [run 44872060499](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872060499) — success.
- Finance-only RPC write-isolation workflow on the same SHA: [run 44872060315](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872060315) — success.
- Dependabot update workflows also completed successfully on the same SHA. These are dependency-update checks, not substitutes for authenticated clinic UAT.
- No source changes are proposed by this review.

### 2.2 Vercel deployment drift

The newest READY Production-target deployment returned by the connected Vercel query was built from `a9040601702972bdf144fc96b9658eebd5a6d31a`, while GitHub `main` is `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.

This is a **deployment-source divergence requiring explicit reconciliation**, not proof by itself that the canonical alias serves the older build. The deployment list is not sufficient to establish the exact canonical-domain alias target. Before any release, inspect the canonical alias and deployment metadata, then confirm the intended application SHA. No deployment, promotion, rollback, alias change, or project setting was performed in this review.

### 2.3 Git governance

- GitHub search returned **46 open PRs** and **4 open issues** on 2026-11-24.
- The branch-protection endpoint returned HTTP 403 to the connected integration. This is an access limitation, not evidence that protection is enabled or disabled today.
- Issue [#253](https://github.com/crauch2088-source/roshan-health-hub/issues/253) contains the last documented finding that `main` was unprotected with no required status checks. Re-verify through a repository administrator before release.
- The current workflow policy in `AGENTS.md` remains binding: one atomic commit per logical task, no force-push/rebase/amend of published work, docs-only changes must skip frontend builds, and no Production migrations without explicit owner authorization.

## 3. Application and functional coverage

The generated route tree contains **30 registered route entries**, including the public/authentication routes and authenticated application routes. The existence of a route is not evidence of complete functionality, permissions, or acceptance.

The authenticated application surface covers the following domains:

| Domain | Current evidence | Remaining acceptance |
|---|---|---|
| Patients / registration | Route and patient workflows exist; PR #296 adds duplicate-detection improvements | Server-wide duplicate protection, concurrent registration behavior, family/shared-phone false-positive handling |
| Visits / queue | Reception-to-visit path has passed QA smoke after a QA-only branch RLS adjustment | Production migration path, role matrix, repeat/parallel submission and full browser journey |
| Consultation / diagnosis | Clinical note and diagnosis scaffolding exist; PR #291 is open and non-Draft | Clinical adoption decision, diagnosis persistence/search acceptance and dataset/version governance |
| Prescriptions / medication | Medication engine and pediatric safety UI candidate exist in PR #292 | Clinical validation, unknown-age fail-closed behavior, current weight validation, concentration-to-volume correctness, explicit prescriber sign-off |
| Pharmacy / dispensing | Atomic dispense and lifecycle work exist in PR #250 and #293 | Production authorization remains open; full lifecycle concurrency and pharmacist UAT |
| Inventory / catalogue | Ledger controls candidate in PR #294; identity/pack attestation candidate in PR #210 | Integrated regression, identity completeness, independent security review and physical pharmacist acceptance |
| Laboratory | Orders/results and verification workflows exist | Full Lab Doctor/Lab Assistant separation, catalogue create/edit regression, critical-result and physical workflow acceptance |
| Billing / payments / finance | Atomic billing foundation and finance workflows exist; PR #280/181 remain in backlog | Receipt/print acceptance, idempotent retry, reconciliation and role-specific end-to-end tests |
| Expenses / accounting | PR #296 contains calendar-safe date-range and localization fixes | QA-only candidate must be reviewed, integrated and regression-tested |
| Reports / analytics | Routes and reporting surfaces exist | Source data correctness, permissions, export/print and acceptance with realistic synthetic data |
| Users / roles / branches / audit | RBAC, RLS and audit foundations exist | Nine-role and cross-branch negative testing, owner/admin controls and complete audit verification |
| Appointments / certificates / follow-ups / partners / insurance | Routes/features exist | Full role-specific workflow and integration acceptance |

### 3.1 Clinical safety boundary

PR #292 is no longer accurately described by the older 2026-11-20 plan as “unwired”: the later candidate revision includes `PediatricSafetyPanel` wired into `PrescriptionTab`, with manual clinician confirmation and protocol activation locked (`protocol: null`). Its UI and unit-test work is candidate-only until merged and accepted.

A concrete edge case remains: the current age classification uses a condition equivalent to `patientAge != null && patientAge < 18`. When date of birth is absent, the patient is not classified as pediatric by that condition. Unknown age must be a distinct state and must not silently fall through to an adult-safe path. The panel's calculated mg-to-mL display must also be demonstrably connected to the persisted prescription value before users can assume it was applied.

No pediatric protocol, dose ceiling, or treatment recommendation is clinically approved by the existence of this UI. Required review includes weight validity/freshness, mg/kg/dose versus mg/kg/day, maximum dose, frequency, duration, route, formulation, concentration, rounding, age, renal/hepatic modifiers where relevant, duplicate multiplication, and local guideline provenance. A qualified clinician must approve the actual clinical content.

## 4. Database and security findings

### 4.1 RLS coverage

Read-only PostgreSQL catalog checks returned:

| Environment | Public base tables | RLS enabled | RLS disabled |
|---|---:|---:|---:|
| Production `jewzonxplxhogqrnhosl` | 56 | 56 | 0 |
| QA `hopfohcnrtbiqjkgeukz` | 58 | 58 | 0 |

This confirms RLS is enabled on the queried public base tables. It does **not** prove that every policy is correct, restrictive, branch-safe, or tested for every role. Policy behavior and privileged RPCs must be reviewed separately.

### 4.2 SECURITY DEFINER inventory

Read-only catalog results:

| Measure | Production | QA |
|---|---:|---:|
| SECURITY DEFINER functions | 53 | 58 |
| SECURITY DEFINER functions with empty fixed search_path | 35 | 57 |
| SECURITY DEFINER functions with non-empty search_path | 18 | 1 |
| SECURITY DEFINER functions executable by authenticated | 26 | 30 |
| SECURITY DEFINER functions executable by anon | 1 | 1 |

These are inventory counts, not vulnerability counts. Empty `search_path` is generally a safer pattern, but each function still requires review of its body, grants, caller chain, role checks, branch binding, overloads, and data returned.

### 4.3 P0 — Production pharmacy authorization

**Status: OPEN — Production NO-GO.**

The live Production dispense boundary has not been replaced by the candidate pharmacist-only guard. The current evidence and controlled release dossier describe the Production RPC as callable by `authenticated` with checks that allow a broader Admin-class path through general pharmacy/billing permissions. PR #250 supplies the intended pharmacist role boundary, but remains unmerged and unapplied.

Required sequence is not optional:
1. Reconcile and review the Phase 55 parent guard and private-helper ACL dependencies.
2. Review Phase 55B ACL correction in PR #260.
3. Confirm Phase 57 quantity-required guard and Phase 57B free-text external-prescription guard from exact repository sources and live migration history.
4. Review Phase 61B clinical role boundary and Phase 61C atomic dispense boundary in PR #250.
5. Run clean-baseline and supported-upgrade PostgreSQL 17 regression.
6. Verify every relevant signature, owner, grant, fixed search_path, caller, idempotency contract, branch/patient/visit/invoice binding and failure behavior.
7. Obtain independent security review and explicit owner approval.
8. Only then prepare the separate owner-controlled Production change window; read-only post-apply checks must prove the new boundary.

Do not apply this sequence or modify grants under this documentation task.

### 4.4 P1 — Phase 55 private helper ACL discrepancy

Issue [#218](https://github.com/crauch2088-source/roshan-health-hub/issues/218) records Production `proacl = NULL` for:
- `private.app_has_claim_branch(uuid)`
- `private.sync_user_role_text()`

The current review's read-only privilege check also found that these helpers inherit PostgreSQL's default PUBLIC EXECUTE behavior in Production, unlike the owner-only ACLs documented for QA. PR #260 contains the forward-only ACL correction and PG17 regression coverage. It must be reviewed together with its SECURITY INVOKER/RLS dependencies; do not blindly revoke or replay migrations without the exact call-graph and migration reconciliation.

### 4.5 QA-only branch RLS remediation

PR #296 states that its branch SELECT/RLS adjustment was applied and verified on QA to unblock Reception visit creation and the GP workflow. PR #296 also contains patient duplicate checks, expenses date-range handling, and localization fixes. It is Draft and not merged. Production was explicitly left untouched. Treat these as QA candidate improvements, not as Production fixes.

### 4.6 Migration reconciliation

Production and QA migration histories have known divergence and placeholder/superseded migration records. The correct process is:
- obtain one authoritative read-only catalog and migration-ledger snapshot per environment;
- map every candidate migration to its exact source file, checksum, dependency and already-applied state;
- classify each as applied, missing, superseded placeholder, or environment-only;
- generate a forward-only Production sequence with preflight, abort criteria and post-apply assertions;
- rehearse the sequence on disposable PostgreSQL 17 and QA only where authorized;
- never bulk-replay QA history, manually insert migration-ledger rows, or edit historical migrations to manufacture parity.

## 5. Open PR and issue portfolio

### 5.1 Priority PRs

The following table summarizes the PRs most relevant to release safety. Statuses are snapshots; re-check exact head SHA, base SHA, review threads and exact-head checks before any merge.

| PR | Scope | State observed | Current disposition |
|---|---|---|---|
| #250 | Phase 61B/61C pharmacist-only dispense boundary | Draft, open | P0 candidate; independent security review + ordered dependency chain required |
| #260 | Phase 55B private-helper ACL | Draft, open | P1 security dependency; PG17 evidence exists; Production remains open |
| #292 | Pediatric safety UI and protocol governance | Open, non-Draft | Candidate UI wired; unknown-age and prescription-value wiring review; clinician approval required |
| #291 | ICD-10 dataset-backed validation scaffolding | Open, non-Draft | Technical candidate; clinical dataset/version/adoption decision remains |
| #293 | Phase 62 pharmacy cancellation/return | Draft, open | Hold: exact-head workflow failure and formatting/test blockers require correction |
| #294 | Phase 63 inventory ledger controls | Draft, open | Candidate with passing CI and multi-session test evidence; integrate with #293/#210 before acceptance |
| #296 | QA branch RLS, expenses, duplicate guard and localization fixes | Draft, open | QA-only changes; review and integrated QA acceptance required |
| #297 | Independent Production backup restore evidence and DR runbook | Draft, open | Database restore evidence improved; full DR policy/control-plane/Storage gate remains |
| #210 | Medicine catalogue identity / physical-pack attestation | Draft, open | Keep Draft until independent review, remaining identity gaps and pharmacist acceptance |
| #290 | Liveness/readiness and PHI-safe telemetry | Open, non-Draft | Review PHI-safe allowlist, operational signals and exact-head CI |
| #280 | Idempotent invoice payment retries | Draft, open | Financial-integrity review and integration acceptance |
| #181 | Invoice payment receipts | Draft, open | Receipt integrity, permissions, print and finance acceptance |
| #258 / #179 | Saved prescription/document printing | Draft, open | Review safe print contract and test real printer output |
| #217 | Pharmacist-to-prescriber correction workflow | Issue open | Keep fail-closed dispensing blocker; design auditable clarification workflow |
| #253 | Main branch protection | Issue open | Repository administrator action required |
| #199 | Backup/restore and clinical acceptance gates | Issue open | Continue tracking full release/DR/UAT gates |
| #218 | Phase 55 private-helper ACL gap | Issue open | Close only after exact ACL/call-chain evidence and authorized release |

### 5.2 Backlog hygiene

The 46 open PRs include older parallel-window reports and documentation branches as well as functional changes. Do not attempt to merge them as a batch. Classify each into:
- required functional/security change;
- required test or evidence;
- superseded report with unique findings to preserve;
- duplicate/superseded PR safe to close after comparing contents;
- blocked owner/clinical action;
- obsolete candidate.

The older PR #295 contains a consolidated plan, but it is based on an older `main` SHA and includes stale findings (for example, its claim that the pediatric UI was unwired and the Phase 63 test lacked multi-session evidence). Do not merge PR #295 wholesale. Preserve its unique useful work and reconcile it into this roadmap or the appropriate canonical docs.

## 6. Backup, restore and disaster recovery

**Database backup/restore: evidence improved; full DR remains OPEN.**

PR #297 records a newer independent Production backup drill:
- encrypted Production database archive and independent PostgreSQL 17 restore;
- ciphertext integrity/checksum verification and private off-site Google Drive copy/read-back;
- critical row-count checks and namespace-filtered structural comparison;
- reported parity across 10 schemas, 99 tables, 394 indexes, 359 constraints, 78 triggers, 226 RLS policies and 246 functions/procedures, with zero invalid indexes and the same single NOT VALID Realtime constraint;
- current Storage/Vault zero-object/zero-secret boundary and control-plane inventory.

These results are evidence recorded in PR #297, not an owner-approved DR service-level commitment. The full gate remains open pending:
1. independent review and owner acceptance of the drill evidence;
2. formal RPO, RTO, retention and backup cadence approval;
3. timed end-to-end control-plane re-provisioning and application recovery rehearsal;
4. documented Storage object-byte backup/restore before the first real Storage object is stored;
5. Vault/secret restoration and secure key custody procedure;
6. repeatable scheduled backup execution, alerting and artifact retention;
7. a current run record whose dates, workflow IDs, checksums and outcomes agree with the runbook.

The 2026-11-23 session record still refers to an older 2026-11-12 archive in some sections, while PR #297 records the newer 2026-11-22 drill. Reconcile this documentary inconsistency before closing the DR gate.

Proposed policy in the DR runbook (not yet owner-approved): daily backup, RPO 24 hours, RTO 4 hours, 30 daily copies, quarterly DR exercise.

## 7. Prioritized execution plan

### Phase 0 — Baseline and portfolio reconciliation

**Estimate:** 1–2 focused working days  
**Dependencies:** none  
**Owner:** engineering lead / repository executor

Actions:
- freeze the review baseline SHA and record exact PR/issue inventory;
- compare every release-relevant PR with current main; check head/base ancestry, changed files, exact-head workflows and review threads;
- triage the 46 open PRs into merge, revise, supersede, preserve, or owner-blocked;
- identify the canonical status of PR #295 and reconcile its unique findings;
- verify the canonical Vercel alias source SHA and current deployment drift;
- re-check branch protection through an administrator-capable path.

Acceptance:
- one authoritative PR disposition matrix;
- no duplicate implementation branches;
- exact current source/deployment identities documented;
- required branch rules and exact CI contexts identified.

### Phase 1 — P0 security and repository governance

**Estimate:** 3–5 focused working days  
**Dependencies:** Phase 0  
**Owner:** engineering/security reviewer; repository owner for settings and Production approval

Actions:
- independently review PR #260 and PR #250, including all function signatures, grants, role/claim spoofing, mutable GUCs, branch context, SECURITY DEFINER search_path and wrapper bypasses;
- reconcile Phase 55, 55B, 57, 57B, 61B and 61C SQL and checksums;
- run clean-install and supported-upgrade PostgreSQL 17 regression;
- verify legitimate billing/insurance callers are not broken by least-privilege ACLs;
- prepare a controlled Production migration dossier, rollback/abort plan and post-apply read-only assertions;
- enable main branch protection and required checks through a repository administrator.

Acceptance:
- no unresolved critical/high source-level security finding;
- exact-head CI green;
- independent security approval;
- branch protection configured and verified;
- Production still unchanged until explicit release authorization.

### Phase 2 — Pharmacy and inventory integrity

**Estimate:** 4–6 focused working days  
**Dependencies:** Phase 1 source review; QA-only testing available  
**Owner:** pharmacy workflow engineer + database reviewer + pharmacist for UAT

Actions:
- resolve PR #293's exact-head test failure and Prettier failure; add/re-run cancellation, handover, return, duplicate idempotency and no-side-effect tests;
- integrate PR #294's Phase 63 ledger controls with Phase 62 lifecycle and medicine catalogue authority;
- verify true two-session concurrency for cancellation, return, inventory adjustment, write-off, quarantine, dispense and price updates;
- complete PR #210 identity validation: pack size, dispensing unit, manufacturer/GTIN/barcode and duplicate rules, with explicit limits of physical-pack attestation;
- preserve historical invoices and stock movements; ensure returns go to quarantine rather than silently restocking;
- review and design the PR #217 prescriber clarification workflow without weakening fail-closed dispensing.

Acceptance:
- clean and upgrade PG17 integration pass;
- no negative stock, duplicate stock movement, invoice mutation or idempotency collision under contention;
- UI and permissions verified in QA;
- pharmacist acceptance recorded; PR #210 stays Draft until physical-pack acceptance is complete.

### Phase 3 — Clinical correctness and diagnosis governance

**Estimate:** 3–5 focused working days engineering, plus clinician review time  
**Dependencies:** Phase 0; may run in parallel with Phase 2 where files do not conflict  
**Owner:** clinical software engineer; qualified clinician/medical director for clinical approval

Actions:
- review and correct PR #292 unknown-age behavior, missing/invalid/stale weight, dose units, concentration conversion, route/formulation, frequency, duration, maximum dose, rounding, and persisted prescription values;
- keep all unapproved protocols disabled; use warnings/confirmation only until clinician approval;
- review PR #291 ICD-10 dataset source, version, licensing, Arabic/English terminology, local adaptation and migration strategy;
- obtain a documented owner/clinician decision on the ICD-10 edition and national adaptation;
- reconcile clinical guideline policy and medicine catalogue source provenance.

Acceptance:
- automated regression for all unsafe/missing-input cases;
- no unapproved dose protocol activated;
- clinician sign-off explicitly recorded for clinical content;
- ICD-10 standard/version decision documented before live adoption.

### Phase 4 — Finance, laboratory, printing and cross-module integration

**Estimate:** 3–5 focused working days  
**Dependencies:** Phases 1–3 for release-relevant flows  
**Owner:** finance, laboratory and application engineers

Actions:
- review #280 payment retry idempotency and #181 receipt persistence/printing;
- review #258/#179 prescription and document printing;
- verify laboratory catalogue writes use the actual `lab_parameters` and `lab_reference_ranges` model rather than stale `lab_tests` fields;
- validate expenses half-open date ranges and patient duplicate checks from #296;
- execute integrated patient → visit → queue → consultation → lab → pharmacy → billing → audit regression;
- test failures, retries, cancellations and cross-branch isolation.

Acceptance:
- no duplicate invoice/payment/receipt under retry;
- no missing or misleading lab reference ranges;
- calendar-safe expense reporting;
- printed receipts/prescriptions/certificates match saved records;
- end-to-end regression passes on disposable PG17 and QA.

### Phase 5 — Full authenticated QA and usability acceptance

**Estimate:** 5–8 focused working days, excluding account/SSO provisioning wait  
**Dependencies:** core functional fixes from Phases 1–4  
**Owner:** QA lead + real clinic role holders

Required roles:
1. Super Admin
2. Admin
3. Reception
4. GP
5. Dentist
6. Specialist
7. Lab Doctor
8. Lab Assistant
9. Pharmacist

Actions:
- provision/verify dedicated synthetic QA identities for all nine roles;
- run positive and negative RBAC tests, cross-branch access tests and session-expiry/refresh tests;
- exercise every authenticated route and all high-risk workflows;
- test 320–430px mobile widths, Arabic RTL and English LTR, keyboard navigation and WCAG 2.2 AA;
- test physical A4 and thermal printers, including offline/retry behavior where applicable;
- collect screenshots, traces, test data IDs and signed staff acceptance;
- resolve all P0/P1 defects and re-run regression.

Acceptance:
- every required role completes its allowed journey and is denied prohibited actions;
- zero unresolved P0/P1 defects in core clinic workflows;
- mobile, RTL/LTR and accessibility checks have evidence;
- physical print output is accepted;
- real staff UAT is signed off.

### Phase 6 — DR closure and controlled release

**Estimate:** 2–4 focused working days of engineering, plus owner scheduling and recovery rehearsal  
**Dependencies:** Phases 1–5  
**Owner:** repository/project owner + backup operator + independent reviewer

Actions:
- reconcile PR #297, the DR runbook and the 2026-11-23 session record;
- approve RPO/RTO/retention/cadence;
- complete timed control-plane and Storage/Vault recovery rehearsal;
- verify the latest encrypted backup, offline decryption, restore, checksums and structural parity;
- confirm canonical Vercel alias source SHA matches the approved release commit;
- assemble one release dossier with migration checksums, exact CI, security review, backup ID, rollback plan, QA evidence and owner approvals;
- schedule a maintenance window and obtain explicit written authorization before Production writes or deployment.

Acceptance:
- all security, database, DR and operational gates are PASS;
- independent reviewer and owner approvals recorded;
- release candidate and deployed SHA are identical;
- post-release read-only checks and smoke tests pass;
- rollback/abort criteria are available and rehearsed.

## 8. Calendar schedule and critical path

The schedule below is a planning estimate, not a promise of a fixed launch date. It assumes one focused engineering stream, prompt review, and no unexpected schema drift.

| Calendar window | Planned work | Duration estimate | Gate |
|---|---|---:|---|
| Week 1 | Phase 0 baseline + Phase 1 security/governance | 4–7 working days | P0 source fix independently reviewed; repo governance verified |
| Week 2 | Phase 2 pharmacy/inventory integrity | 4–6 working days | Phase 62/63 integrated PG17 + QA acceptance |
| Week 3 | Phase 3 clinical correctness + Phase 4 finance/lab integration | 4–7 working days | Clinical sign-off plan + integrated finance/lab regression |
| Week 4 | Phase 5 authenticated role journeys, mobile, accessibility and printing | 5–8 working days | Nine-role and real-staff acceptance |
| Week 5 | Phase 6 DR rehearsal and controlled-release dossier | 2–4 working days | Owner/independent reviewer approval and release window |
| Week 6 (buffer) | Rework, blocked-account access, on-site UAT, or failed-gate remediation | 3–5 working days | No open P0/P1 or unaccepted owner gate |

**Estimated active engineering effort:** approximately **18–30 focused working days**, depending on how much existing PR work is reusable and whether regressions emerge.  
**Estimated elapsed calendar time:** approximately **5–7 weeks** if owner and clinic dependencies are available promptly; **longer or indeterminate** if credentials, independent review, clinical sign-off, printer access, repository administration, or a Production maintenance window are delayed.

The critical path is:

`P0 security + migration reconciliation → pharmacy/inventory integration → authenticated QA + clinical/finance acceptance → DR and owner release approval`

Clinical guideline approval and ICD-10 adoption can proceed in parallel with non-conflicting engineering, but neither may be treated as complete without a qualified reviewer.

## 9. Owner-only decisions and access dependencies

These are explicit dependencies, not tasks to be simulated by engineering:

| Owner action | Why required | What must be returned as evidence |
|---|---|---|
| Appoint independent security reviewer for #250/#260 | Separation of duties on privileged dispense/ACL changes | Review approval and resolved comments |
| Confirm Super Admin pharmacy policy | Defines the intended exception/boundary | Written role-policy decision |
| Enable and verify main branch protection | Current integration cannot read the protected-branch endpoint | Screenshot/API result and exact required check names |
| Provide four missing QA role identities / approved SSO path | Full nine-role authenticated browser tests | Successful login evidence for each role |
| Approve pediatric guideline sources and ICD-10 edition | Clinical content cannot be invented by engineering | Signed clinical decision and source/version |
| Accept RPO/RTO/retention/cadence | These are proposed, not approved service levels | Written policy acceptance |
| Verify offline age-key custody and DR rehearsal | Database archive alone is not full recovery | Decryption/restore evidence without exposing private key |
| Provide physical printers and staff for UAT | Cannot be proven by source tests | Signed print/staff acceptance |
| Authorize Production maintenance window | No standing authorization for Production mutation | Explicit written release authorization |

## 10. Release gates — non-waivable

Production remains **NO-GO** until all are true:

- [ ] Phase 55 / 55B / 57 / 57B / 61B / 61C dependencies are reconciled, independently reviewed, and tested on PostgreSQL 17.
- [ ] Production pharmacy dispense RPC enforces the approved role boundary at the database layer.
- [ ] Private helper ACLs and all relevant SECURITY DEFINER call paths are verified.
- [ ] Production and QA migration histories are reconciled without manual ledger edits or blind replay.
- [ ] All P0/P1 PRs are merged or formally dispositioned; exact-head CI and reviews are green.
- [ ] Main branch protection and required checks are enabled and verified.
- [ ] Nine-role authenticated QA, cross-branch negative tests, mobile RTL/LTR, accessibility and print acceptance are complete.
- [ ] Pediatric/ICD-10 clinical decisions are approved by qualified reviewers.
- [ ] Backup restore, offline decryption, Storage/Vault and control-plane recovery are proven; RPO/RTO policy is accepted.
- [ ] Canonical Vercel alias points to the approved release SHA.
- [ ] Owner approves the exact migration bundle, maintenance window, rollback plan and release.

A checkbox may be marked only with an evidence link, exact SHA or workflow/run identifier, and reviewer/owner where applicable.

## 11. Progress reporting and percentage policy

Older project documents report different engineering/operational percentages because they use different baselines and weighting models (for example, the 2026-11-20 autonomous plan and the 2026-11-21 release report). The previous conversational review also used a separate provisional score. These values are **not directly comparable** and must not be averaged.

For this roadmap:
- keep Engineering Completion and Operational Readiness as separate tracks;
- publish a percentage only after defining weights and mapping every denominator item to evidence;
- do not count open PRs, green historical workflows, route existence, or candidate migrations as completed production work;
- do not count owner-blocked, skipped, unrun, or candidate-only items as PASS;
- recalculate both tracks at each phase gate using the same rubric.

**Current percentage status:** a new unified weighted score is intentionally **not certified in this document**. The last conversational provisional baseline was 69.8% engineering / 28.0% operational; the repository's older release report used a different rubric and reported 79.5% / 29.0%. Re-score from a single agreed denominator before using either number for launch decisions.

## 12. Risks and mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Production dispense authorization remains broader than intended | Critical | Hold release; ordered migration chain, PG17 negative tests, independent review and owner-controlled apply |
| Private helper ACL differs between Prod and QA | High | Call-graph analysis, forward-only ACL migration, regression of legitimate privileged callers |
| QA fixes are mistaken for Production fixes | High | Explicit environment labels and no-go release checklist |
| Migration histories diverge | High | One read-only reconciliation pack and checksummed forward-only release bundle |
| PR backlog causes stale-base/conflicting changes | High | Triage, dependency order, one logical PR per workstream, no bulk merges |
| Pediatric dose UI is mistaken for approved decision support | Critical | Fail closed on unknown age/unsafe inputs; no protocol activation without clinical sign-off |
| Backup archive is mistaken for full DR | High | Timed control-plane, Storage/Vault and application recovery rehearsal |
| Main/deployment SHA drift | High | Verify canonical alias and exact approved SHA before release |
| Incomplete role/mobile/print acceptance | High | Nine-role QA matrix, device viewport tests, physical printer and staff sign-off |

## 13. Review evidence and references

### Repository and governance
- [Main repository](https://github.com/crauch2088-source/roshan-health-hub)
- [MASTER_PLAN.md](https://github.com/crauch2088-source/roshan-health-hub/blob/main/docs/MASTER_PLAN.md)
- [AGENTS.md](https://github.com/crauch2088-source/roshan-health-hub/blob/main/AGENTS.md)
- [Open PR inventory](https://github.com/crauch2088-source/roshan-health-hub/pulls)
- [Issue #253 — branch protection](https://github.com/crauch2088-source/roshan-health-hub/issues/253)

### Security and functional work
- [PR #250 — atomic dispense role boundary](https://github.com/crauch2088-source/roshan-health-hub/pull/250)
- [PR #260 — Phase 55B private helper ACL](https://github.com/crauch2088-source/roshan-health-hub/pull/260)
- [Issue #218 — Production helper ACL gap](https://github.com/crauch2088-source/roshan-health-hub/issues/218)
- [PR #292 — pediatric safety](https://github.com/crauch2088-source/roshan-health-hub/pull/292)
- [PR #291 — ICD-10 validation](https://github.com/crauch2088-source/roshan-health-hub/pull/291)
- [PR #293 — pharmacy lifecycle](https://github.com/crauch2088-source/roshan-health-hub/pull/293)
- [PR #294 — inventory ledger controls](https://github.com/crauch2088-source/roshan-health-hub/pull/294)
- [PR #296 — QA remediation](https://github.com/crauch2088-source/roshan-health-hub/pull/296)
- [Issue #217 — prescriber correction workflow](https://github.com/crauch2088-source/roshan-health-hub/issues/217)

### Release and recovery
- [PR #297 — independent backup restore and DR runbook](https://github.com/crauch2088-source/roshan-health-hub/pull/297)
- [Issue #199 — backup, restore and clinical acceptance](https://github.com/crauch2088-source/roshan-health-hub/issues/199)
- [PR #295 — older consolidated plan; reconcile, do not merge wholesale](https://github.com/crauch2088-source/roshan-health-hub/pull/295)
- [2026-11-21 release readiness report](https://github.com/crauch2088-source/roshan-health-hub/blob/main/docs/parallel-reports/FINAL_RELEASE_READINESS_AND_REMEDIATION_REPORT_2026-11-21.md)
- [Controlled release dossier](https://github.com/crauch2088-source/roshan-health-hub/blob/main/docs/CONTROLLED_RELEASE_DOSSIER_2026-11-21.md)

### Live systems
- [Supabase Production](https://supabase.com/dashboard/project/jewzonxplxhogqrnhosl)
- [Supabase QA](https://supabase.com/dashboard/project/hopfohcnrtbiqjkgeukz)
- [Vercel Production](https://roshan-health-hub.vercel.app/)

## 14. Session closeout

- Review baseline: `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.
- Work performed: read-only repository/PR/issue inspection, source/route inspection, read-only Production/QA catalog checks, workflow/deployment metadata review, and authoring this roadmap.
- Files changed by this review: this document only.
- Production/QA data, migrations, grants, policies, secrets, Vercel settings and deployments: **not changed**.
- PRs merged or issues closed: **none**.
- Next action after owner review: revise this document against the owner's comments, then execute Phase 0/Phase 1 on isolated feature branches under the existing AGENTS.md rules. Do not apply Production changes without a separate explicit authorization.
