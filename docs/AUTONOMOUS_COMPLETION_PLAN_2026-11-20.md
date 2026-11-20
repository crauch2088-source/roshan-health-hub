# Roshan Health Hub — Consolidated Autonomous Engineering & Operational Completion Plan

**Date:** 2026-11-20
**Repository:** `crauch2088-source/roshan-health-hub`
**Verified `main` Baseline SHA:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (`79d81f0`, 946 commits, 5/5 checks passing)
**Target:** >=90% Verified Engineering Completion (Track A) AND >=90% Verified Operational Readiness (Track B)
**Status:** PLANNING ONLY — Awaiting Owner Review & Approval Before Any Implementation
**Production Changed:** NO | **Main Modified:** NO | **PRs Merged:** NONE

---

## A. Current-State Report (Live Verified 2026-11-20)

- **Repository `main` SHA:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (`docs(roshan): append late-session execution evidence`, Nov 16, 2026). `AGENTS.md` enforces Lovable-safe git rules: **never force-push, rebase, amend, or squash pushed commits**; skip Vercel builds on docs/SQL-only PRs.
- **Open Pull Requests (45 total) & Open Issues (4 total: `#253`, `#218`, `#217`, `#199`):**
  - **V2 Execution PRs (all CI-green, all unmerged):**
    - `#289` (`docs/rhh00-v2-execution-report-20261120`, head `3121ca828abf7754aa4789ceecdbfffde9c12a64`): 5/5 passing (CodeQL Run `44765626406`).
    - `#290` (`feat/rhh06-health-readiness-and-phi-telemetry`, head `06791249d5f9012463ddb323c8809cd814665f1e`): 27 passed, 1 skipped, 0 failed (CI `#2272`, Run `44751336439`).
    - `#291` (`feat/rhh04-icd10-validation-scaffolding`, head `a50e9e9202bd5bfeeda389dcc38a3896e8be3d9b`): 31/31 passing (CI `#2256`, Run `44727094440`).
    - `#292` (`feat/rhh02-pediatric-safety-and-decision-support`, head `ef8c22167262de35ff32c8ac27e6a4891ee55715`): 30 passed, 1 skipped, 0 failed (CI `#2270`, Run `44746924208`). **Finding:** Only 3 files (`pediatric-safety.ts`, unit test, `package.json`) — **0 UI callers wired**.
    - `#293` (Draft, `feat/rhh01-pharmacy-cancellation-and-return`, head `e9914dfc0702d9b9cb0d53cd443472024b754bcd`): 27 passed, 1 skipped, 0 failed (CI `#2275`, Run `44760691721`; `sql-pharmacy-cancellation-return` Passed, 17s).
    - `#294` (Draft, `feat/rhh03-inventory-ledger-controls`, head `326be10d912200209e597ffa8777008578b1fc2e`): 28/28 green (CI `#2276`, Run `44763311605`; `sql-inventory-ledger-controls` Passed, 21s). **Finding:** Integration test is single-session `BEGIN ... ROLLBACK`; no two-session concurrency proof yet.
  - **Pre-Existing Critical Functional/Security PRs:**
    - `#250` (Draft, `fix/phase61c-atomic-dispense-role-boundary-20261114`): 35/35 passing; canonical `pharmacist` boundary.
    - `#260` (Draft, `test/218-phase55-helper-acl-20261116`): 27/28 **Failing** intentionally (reproduces Issue `#218` `42501` on `private.app_has_claim_branch`).
    - `#287` (Draft, `perf/phase61d-correction-fk-indexes-20261117`): 28/28 passing.
    - `#210` (Draft, `feat/medicine-catalogue-identity-rebased-20261109`, head `e53216a`): 32/32 passing, 13 files changed (`inventory.tsx`, `phase60_medicine_catalogue_authority_integration.sql`, `roshan_phase60_medicine_catalogue_authority_and_pack_attestation.sql`, `MIGRATIONS_MANIFEST.md`, 3 old-base `docs/` files). **DO NOT MERGE** — 7 documented blockers.
    - Other open functional/infra PRs discovered: `#280` (idempotent invoice payment retries, 32/32), `#269` (Phase 61 correction tests, 28/28), `#261` (`docs/PARALLEL_ENGINEERING_CONTINUATION.md` & `docs/parallel-reports/TEMPLATE.md`, NOT yet on `main`), `#258` / `#179` (saved prescription printing), `#181` (invoice payment receipts, 32/32), `#256` (CI path filters, 31/31), `#254` (Repomix snapshots, 31/31), `#157` (Dependabot npm updates, 27/27), plus ~25 parallel window report PRs (`#262`–`#286`).
- **Deployment & Environment Status:**
  - Production app (`https://roshan-health-hub.vercel.app/`): Verified read-only — loads cleanly to `/auth` (RTL Arabic sign-in, public registration disabled).
  - Supabase Production (`jewzonxplxhogqrnhosl`, PG 17.6, latest reported `20261102232941`) vs QA (`hopfohcnrtbiqjkgeukz`, PG 17.11, latest reported `20261113232719`): Live catalog snapshot unavailable without owner-authorized read-only credentials; migration histories diverge and must never be replayed blindly into Production.
  - Browser E2E (`tests/e2e/public-routes.spec.ts` & `.github/workflows/browser-e2e.yml`): Unauthenticated public routes only (`workflow_dispatch` on `main`); **0 authenticated roles tested**.
- **Baseline Scores (Evidence-Based):**
  - **Track A (Engineering Completion): 61.5%** (Confidence: High, +/-4%). Strong SQL/unit guard foundation (27 workflows, 60+ `test:guard` suites, 75+ `db/tests/` files), held back by 45 unmerged PRs, zero authenticated E2E automation, unverified two-session concurrency for Phase 62/63, unwired RHH-02 UI, unreviewed PR `#210`, and unresolved Issue `#218` / `#253`.
  - **Track B (Operational Readiness): 26.0%** (Confidence: Medium-High, +/-5%). 27 authenticated screens exist in `src/routes/_authenticated/`, but 0 live authenticated browser E2E journeys across the 9 clinic roles have been executed on current QA, mobile/RTL (320–430px) live checks are unrun, and Issue `#199` backup/restore proof is blocked.

---

## B. Complete Task Inventory

| Task ID | Workstream | Exact Problem & Why It Matters | Affected Scope | Dependencies | Risk | Proposed Implementation & Tests | Acceptance Criteria | Autonomous? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **T-01** | Governance / PR Triage | 45 open PRs create drift & conflict risk; `PARALLEL_ENGINEERING_CONTINUATION.md` (`#261`) not on `main`. | PRs `#261`, `#262`–`#286`, `#256`, `#254`, `#157`, `#289` | None | Med (Ops) | Triage & consolidate superseded window report PRs; review & merge `#261` and `#256` cleanly (no force-push/rebase per `AGENTS.md`). | Continuation docs on `main`; PR backlog triaged with explicit disposition table. | Yes |
| **T-02** | RHH-01 / `#250` | Phase 61C pharmacist-only atomic dispense role boundary (`#250`) and Phase 61 correction tests (`#269`) unmerged. | `db/roshan_phase61c_*`, `src/routes/_authenticated/pharmacy.tsx`, PR `#250`, `#269`, `#287` | T-01 | High (Sec/Clin) | Perform full independent security review of `#250`, `#269`, `#287`; verify RLS/RPC grants and FK indexes; merge in order after CI & rollback doc check. | Security review recorded; all PG17 + UI guard tests green; merged to `main` (QA-ready). | Yes (code/QA); Owner for Prod |
| **T-03** | RHH-01 / `#293` | Phase 62 cancellation/quarantine return lacks two-session concurrency harness and UI workflow wiring. | `db/roshan_phase62_*`, `db/tests/phase62_*`, `src/routes/_authenticated/pharmacy.tsx`, `billing.tsx` | T-02 | High (Clin/Fin) | Add two-session bash concurrency harness (`phase62_pharmacy_cancellation_concurrency.sh`) testing racing cancel/handover/return & duplicate idempotency keys; wire pharmacist UI controls for pre-handover cancel, post-handover quarantine return, and disposition without auto-restock. | Two-session concurrency passes on PG17; UI tested in QA browser; zero historical invoice mutation. | Yes (code/QA); Clinician UAT for Prod |
| **T-04** | RHH-03 / `#294` | Phase 63 inventory ledger controls only tested in single-session `BEGIN ... ROLLBACK`; no UI wiring for quarantine/write-off/audited price change. | `db/roshan_phase63_*`, `db/tests/phase63_inventory_ledger_concurrency.sh`, `.github/workflows/ci.yml`, `src/routes/_authenticated/inventory.tsx` | T-01 | High (Fin/Ops) | Build true multi-connection PG17 harness (modeling `cashbox_reversal_concurrency_two_session.sh`) testing simultaneous adjustments, dispense vs quarantine, competing write-offs, duplicate idempotency keys, concurrent price updates, deadlock/rollback, negative-stock prevention, and post-contention `reconcile_medicine_stock_ledger`. Wire UI dialogs in `inventory.tsx`. | Multi-session PG17 concurrency job passes in CI; `is_balanced = true` after contention; UI verified in QA. | Yes |
| **T-05** | RHH-07 / `#210` | PR `#210` has 7 merge blockers: unreviewed `inventory.tsx` modal/RPC diff, unreviewed 420-line SQL test, old-base `docs/`, missing pack size/unit/manufacturer/GTIN/duplicate checks, `pgcrypto` verification. | All 13 files of PR `#210` + `db/roshan_phase60_*` + `src/routes/_authenticated/inventory.tsx` | T-04 (coordinate `inventory.tsx`) | High (Clin/Data) | Complete line-by-line review of all 13 files; reconcile on fresh branch from `main` (no force-push); add pack size, dispensing unit, manufacturer, GTIN/barcode validation, duplicate detection, and `pgcrypto` guard; enforce explicit UI wording that physical-pack attestation != manufacturer/regulatory authenticity. | All 6 technical blockers closed with PG17 + UI tests; pharmacist UAT remains explicitly gated. | Partial (Technical Yes; Pharmacist UAT = Clinician) |
| **T-06** | RHH-02 / `#292` | `pediatric-safety.ts` is completely unwired from UI callers; needs full edge-case validation without inventing unapproved clinical protocols. | `src/lib/medication-engine/pediatric-safety.ts`, `src/routes/_authenticated/clinic.tsx`, `clinic_.$visitId.tsx`, `pharmacy.tsx`, `tests/medication-pediatric-safety.test.ts` | T-01 | Critical (Clin) | Audit `pediatric-safety.ts` for missing/zero/negative/stale weight, invalid timestamps, mg/kg/dose vs mg/kg/day, mg->mL concentration, route/formulation, frequency, duplicate multiplication, and protocol version metadata; wire non-prescriptive safety warnings & explicit clinician confirmation banner into prescription UI while keeping unapproved dose ceilings safely gated; document WHO/BNFC/Sudanese protocol sources needed. | Wired in prescribing UI; unit + QA browser tests pass; zero invented dose limits; protocol approval explicitly gated. | Partial (Infra/UI Yes; Clinical Protocol Sign-off = Clinician) |
| **T-07** | RHH-04 / `#291` | ICD-10 validation scaffolding unmerged; diagnosis persistence & search need version-safe architecture pending WHO vs national adaptation decision. | `src/lib/icd10-validation.ts`, `src/routes/_authenticated/clinic_.$visitId.tsx`, `docs/ICD10_STANDARD_RECOMMENDATION.md` | T-01 | Med (Clin/Data) | Review & merge `#291`; prepare technical recommendation comparing WHO ICD-10 vs national adaptation (versioning, Arabic/English search, reporting, migration impact); keep diagnosis UI version-tagged and ready for dataset import without silently choosing standard. | `#291` merged; version-safe scaffolding tested; formal decision memo ready for clinician/owner sign-off. | Partial (Scaffolding Yes; Standard Selection = Clinician/Owner) |
| **T-08** | RHH-06 & Security / `#290` | Broad app/DB security audit, PHI redaction verification across all channels, `#290` merge, `#280`/`#181`/`#258` financial/print review. | PR `#290`, `#280`, `#181`, `#258`, `src/server.ts`, `.github/workflows/*`, `db/` RLS/RPC/Storage policies | T-01 | High (Sec) | Review & merge `#290` (probes + allowlist telemetry), `#280` (idempotent payment retries), `#181` (receipts), `#258` (safe printing); run full security audit (RLS, `SECURITY DEFINER`, `search_path`, Storage policies, PHI leakage in logs/URLs/storage/errors, GitHub Actions permissions, npm audit/`#157`). | Zero critical/high security defects; PHI redaction verified; probes verified in QA; `#290`/`#280`/`#181`/`#258` merged. | Yes |
| **T-09** | DB & Migration Reconciliation (`#218`/`#260`) | QA vs Prod migration divergence (`20261113232719` vs `20261102232941`); Issue `#218` / PR `#260` `private.app_has_claim_branch` ACL mismatch. | `db/MIGRATIONS_MANIFEST.md`, `db/roshan_phase55_*`, PR `#260`, `docs/DB_MIGRATION_RECONCILIATION.md` | T-02..T-05 | Critical (DB/Sec) | Build automated schema-drift & migration-order verification script for isolated PG17; prepare paired Issue `#218` wrapper + PR `#260` fix branch **gated on read-only live catalog snapshot** (never speculate `DROP POLICY`); document per-migration rollback plans. | Isolated PG17 replay + drift checker green; rollback plans documented; live Prod/QA snapshot step minimized to 1 owner read-only query pack. | Partial (Tooling/Prep Yes; Live Prod Snapshot = Owner) |
| **T-10** | RHH-05 Authenticated E2E & Browser QA (7 Cycles) | `browser-e2e.yml` tests only public routes; 0 authenticated browser workflows validated across 9 clinic roles & mobile viewports (320–430px). | `tests/e2e/*`, `.github/workflows/browser-e2e.yml`, all 27 routes in `src/routes/_authenticated/` | T-02..T-08 | Critical (Ops) | Execute all 7 browser QA cycles on QA environment across all 9 roles (Super Admin, Admin, Reception, GP, Dentist, Specialist, Lab Doctor, Lab Assistant, Pharmacist) with synthetic patients; build automated Playwright authenticated E2E suite (full patient journey, negative/RBAC/cross-branch/refresh/session-expiry, 320–430px RTL/LTR); fix all UI/UX/permission defects discovered and re-run regression. | Full patient journey + 9-role matrix + mobile RTL/LTR verified with screenshots/logs in QA; Playwright E2E suite passing. | Yes (if QA accounts available; else list exact missing creds) |
| **T-11** | Full Product Functional & UX Audit | Potential dead buttons, weak validation, missing loading/error states, or mobile/RTL overflow across 27 authenticated routes. | All 27 screens in `src/routes/_authenticated/` vs `docs/MASTER_PLAN.md` | T-10 Cycle 1 | Med (UX/Ops) | Audit every screen (Patients, Visits, Appointments, Queue, Pharmacy, Inventory, Lab, Billing, Payments, Finance, Accounting, Expenses, Insurance, Certificates, Follow-ups, Partners, Analytics, Reports, Settings, Branches, Users, Audit); fix defects without adding bloat; add regression guards. | Zero dead controls or broken mobile/RTL layouts on core clinic screens; phone-first UX verified. | Yes |
| **T-12** | Quality Tooling & CI Hardening | Evaluate free OSS tools (`actionlint`, `zizmor`, `knip`, `pgTAP`, Playwright axe-core) and remove CI waste. | `.github/workflows/*`, `package.json`, `docs/ENGINEERING_TOOLING_ROADMAP.md` | T-01, T-08 | Low-Med (DevOps) | Evaluate compatibility/licensing; adopt high-value zero-cost checks (e.g., `actionlint`/`zizmor` for workflow security, `@axe-core/playwright` already in `browser-e2e.yml`). | Adopted tools documented with license/security rationale; zero paid services added. | Yes |
| **T-13** | Backup & Restore Readiness (`#199`) — **LAST** | Encrypted backup, `age -d` decryption, isolated PG17 restore, and Storage backup proof blocked on owner secrets. | `roshan-health-hub-backup-runner`, `docs/BACKUP_RESTORE_RUNBOOK.md` | T-01..T-12 | Critical (DR) | Prepare complete automated verification scripts (checksums, row-count/catalog integrity checks, Storage bucket verification, RPO/RTO doc) so owner action is reduced to setting `SUPABASE_DB_ACCESS_TOKEN`/`SUPABASE_DB_PASSWORD` and running 1 command. | Turnkey restore verification pack ready; zero secrets exposed; exact owner checklist handed off. | Partial (Prep Yes; Secrets/Decryption = Owner) |
| **T-14** | Branch Protection & Final Release Closure (`#253`, `#289`) | `main` lacks branch protection (`#253`); final consolidated evidence report needed. | GitHub Settings (`#253`), `docs/ROSHAN_V2_EXECUTION_REPORT.md`, `docs/PARALLEL_ENGINEERING_CONTINUATION.md` | T-01..T-13 | High (Gov) | Reconcile all evidence, exact SHAs, CI links, browser screenshots, and final Track A / Track B scores into `docs/ROSHAN_V2_EXECUTION_REPORT.md`; provide exact required check list for owner to enable `#253`. | Reproducible >=90% / >=90% evidence report; exact owner steps for `#253` & Production go-live. | Partial (Report Yes; Repo Admin `#253` = Owner) |

---

## C. Prioritized Execution Roadmap

1. **Phase 1 — Critical Safety & Governance Foundations:** `T-01` (PR triage & `#261`/`#256` merge) -> `T-02` (`#250` pharmacist role boundary + `#269` + `#287` security review & merge).
2. **Phase 2 — Critical Security, Database & Concurrency Blockers:** `T-04` (RHH-03 two-session PG17 concurrency harness + UI) || `T-03` (RHH-01 two-session concurrency + UI) || `T-08` (RHH-06 `#290`, `#280`, `#181`, `#258` + full security/PHI audit) -> `T-09` (DB migration reconciliation, drift detection, rollback plans, `#218`/`#260` prep).
3. **Phase 3 — Clinical Safety & Catalogue Integrity:** `T-06` (RHH-02 pediatric safety UI wiring, strictly gated without unapproved protocols) || `T-07` (RHH-04 `#291` merge + ICD-10 standard decision memo) || `T-05` (RHH-07 `#210` complete 13-file review, reconciliation, pack/GTIN/duplicate/`pgcrypto` remediation).
4. **Phase 4 — Core End-to-End Browser Operational Validation (RHH-05) & UX Completion:** `T-10` (7-cycle live QA browser validation across all 9 roles + Playwright authenticated E2E suite) -> `T-11` (27-screen functional/mobile/RTL defect fixes & regression).
5. **Phase 5 — Quality Tooling, Performance & Release Readiness:** `T-12` (OSS CI/security tooling evaluation & adoption) -> `T-13` (Backup/restore turnkey verification pack — LAST) -> `T-14` (Final evidence closure & score audit).
6. **Phase 6 — Owner & Clinician Final Sign-Off Gates:** Read-only Production/QA catalog snapshot (`#218`), backup secret restoration + `age -d` restore proof (`#199`), `main` branch protection (`#253`), pediatric protocol & ICD-10 standard sign-off, pharmacist UAT (`#210`/`#293`), and Production rollout authorization.

---

## D. Parallelization Plan (Zero-Conflict Ownership)

All parallel work uses independent feature branches from `main` (never force-push/rebase pushed branches per `AGENTS.md` Lovable rule) and isolated workstream reports under `docs/parallel-reports/`:
- **Track 1 (Pharmacy & Inventory SQL/UI):** `T-02` -> `T-03` (`pharmacy.tsx`, Phase 61/62) | **Serialized** with `T-04` -> `T-05` (`inventory.tsx`, Phase 60/63) so `inventory.tsx` and `db/MIGRATIONS_MANIFEST.md` are never edited concurrently.
- **Track 2 (Clinical Decision Support & Coding):** `T-06` (`clinic_.$visitId.tsx`, `pediatric-safety.ts`) || `T-07` (`icd10-validation.ts`, decision memo) — zero file overlap with Track 1.
- **Track 3 (Security, Finance & Observability):** `T-08` (`src/server.ts`, `telemetry.ts`, `health-probes.ts`, `#280`, `#181`, `#258`) || `T-12` (`.github/workflows/*` linting/security).
- **Track 4 (Browser E2E & QA Validation):** `T-10` (`tests/e2e/*`, QA browser cycles) runs after Track 1–3 features land in QA, feeding isolated UI/UX fix branches in `T-11`.
- **Integration Gate:** Single coordinator merges validated PRs sequentially into `main` (updating `db/MIGRATIONS_MANIFEST.md` and `docs/ROSHAN_V2_EXECUTION_REPORT.md` in one serialized pass per milestone to avoid merge conflicts and wasted CI runs).

---

## E. Completion Scoring Model (Transparent, Weighted, Reproducible)

### Track A — Engineering Completion (Current: 61.5% | Target: >=90.0%)

| Criterion | Weight | Current | Status | Required for >=90% |
| :--- | :---: | :---: | :--- | :--- |
| 1. Core Schema, RLS & DB Integrity | 15 | 11.5 | Partial | Merge `#250`/`#287`/`#293`/`#294`, close `#210` technical blockers, drift checker green (Target: 14.0) |
| 2. App Security & Authorization Boundary | 15 | 10.0 | Partial | Complete full security/PHI audit, merge `#290`/`#250`, zero critical/high findings (Target: 13.5) |
| 3. Backend & Frontend Feature Completeness | 15 | 10.5 | Partial | Wire RHH-02 UI, RHH-01/03 UI controls, merge `#181`/`#280`/`#258`/`#291` (Target: 14.0) |
| 4. Multi-Session Concurrency & Financial Atomicity | 10 | 6.5 | Partial | Two-session PG17 harnesses passing for Phase 62 & Phase 63 (Target: 9.5) |
| 5. Automated Unit, Guard & PG17 SQL Tests | 10 | 8.5 | Mostly Met | All guard + PG17 + concurrency + PR `#210` tests verified green (Target: 9.5) |
| 6. Automated Browser E2E & Mobile/RTL Tests | 10 | 1.5 | Unmet | Authenticated Playwright E2E suite + mobile RTL/LTR checks passing in QA (Target: 9.0) |
| 7. Observability, Health/Readiness & Error Handling | 5 | 3.5 | Partial | Merge `#290`, verify `/health` & `/ready` + redacted logs in QA (Target: 4.5) |
| 8. Migration Reconciliation & Rollback Readiness | 10 | 4.5 | Partial | Isolated PG17 replay, drift detector, per-migration rollbacks; Prod snapshot remains owner-gated (Target: 8.0) |
| 9. CI/CD Hygiene, Supply Chain & Repo Governance | 5 | 2.5 | Partial | Triage 45 PRs, merge `#256`, audit workflows/deps; `#253` branch protection owner-gated (Target: 4.0) |
| 10. Documentation & Release Evidence | 5 | 2.5 | Partial | Merge `#261`, reconcile `#210` docs, maintain exact-SHA evidence in `#289` (Target: 5.0) |
| **TOTAL TRACK A** | **100** | **61.5%** | **Below Target** | **Achievable Autonomous Target: 91.0%** (Remaining ~9% strictly owner/clinician-gated) |

### Track B — Operational Readiness (Current: 26.0% | Target: >=90.0%)

| Criterion | Weight | Current | Status | Required for >=90% |
| :--- | :---: | :---: | :--- | :--- |
| 1. Full Authenticated E2E Patient Journey (QA Browser) | 20 | 2.0 | Unmet | Complete synthetic patient journey executed & evidenced end-to-end in QA browser (Target: 19.0) |
| 2. Reception, Registration, Queue & Appointments (QA) | 10 | 3.0 | Partial | Valid, duplicate, invalid, refresh, and queue transitions verified in QA browser (Target: 9.5) |
| 3. Doctor Consultation, Vitals, Diagnosis & Rx (QA) | 15 | 4.0 | Partial | Consultation, pediatric safety warnings, ICD-10 validation, lab/Rx ordering verified in QA (Target: 13.5) |
| 4. Pharmacy Dispense, Cancel/Return & Inventory (QA) | 15 | 4.5 | Partial | Pharmacist dispense, cancel, quarantine return, write-off, audited pricing verified in QA (Target: 14.0) |
| 5. Lab Order, Specimen, Result Entry & Review (QA) | 10 | 3.0 | Partial | Lab Doctor + Lab Assistant workflow verified end-to-end in QA browser (Target: 9.5) |
| 6. Billing, Payments, Receipts, Finance & Audit (QA) | 10 | 4.0 | Partial | Invoice, idempotent payment, receipt print, reversal, audit log verified in QA (Target: 9.5) |
| 7. 9-Role RBAC, Branch Isolation & Session Expiry (QA) | 5 | 1.5 | Partial | All 9 roles tested for allowed/forbidden actions, cross-branch block, session expiry (Target: 5.0) |
| 8. Mobile (320–430px), Arabic RTL / English LTR & UX | 5 | 2.0 | Partial | Verified at 320/360/375/390/430px in RTL & LTR with zero clipping/overflow (Target: 4.5) |
| 9. Reports, Analytics & Operational Visibility (QA) | 5 | 1.5 | Partial | Role-based dashboards/reports verified with real synthetic QA transactions (Target: 4.5) |
| 10. Backup, Decryption, Isolated Restore & Storage (`#199`) | 5 | 0.5 | Blocked | Turnkey scripts ready (1.5/5 autonomous); full 5/5 requires owner credentials & restore proof |
| **TOTAL TRACK B** | **100** | **26.0%** | **Below Target** | **Achievable Autonomous Target: 90.5%** (assuming authorized QA role accounts; otherwise exact missing credential reported) |

---

## F. Risk Register

| ID | Risk | Sev | Like | Impact | Detection | Mitigation | Rollback / Recovery |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| **R-01** | Production/QA migration divergence replayed blindly | Critical | Med | Schema corruption / outage | Catalog fingerprint & `schema_migrations` diff | Never touch Production; treat QA & Prod independently; require live read-only snapshot before `#218` patch | Documented per-migration down-scripts; never apply unverified DDL to Prod |
| **R-02** | Unapproved pediatric dosing or ICD-10 protocol activated | Critical | Med | Patient harm | Code review & clinical gate checklist | Gate all dose ceilings behind versioned protocol metadata; require explicit clinician confirmation | Feature-flag / revert commit; zero active invented rules |
| **R-03** | Concurrent inventory/pharmacy race causes negative stock or double refund | High | High | Financial/stock corruption | Two-session PG17 concurrency harnesses | Consistent `FOR UPDATE` lock ordering + UUID idempotency keys + append-only ledgers | Transaction rollback + immutable compensation entries |
| **R-04** | Lovable git history corruption from force-push/rebase | High | Low | Broken sync / lost commits | `AGENTS.md` pre-push rule | Strict forward-only commits & fresh branches from `main`; never force-push/rebase/amend pushed branches | Restore from untouched `main` SHA `79d81f0` |
| **R-05** | PHI leakage via logs, telemetry, URLs, or test artifacts | High | Med | Privacy breach | `ssr-log-redaction.test.ts` + security audit | Strict allowlist telemetry (`#290`), synthetic QA data only, redact screenshots/logs | Revert logging change + purge artifact |
| **R-06** | Unavailable QA role credentials block full 9-role browser matrix | Med | Med | Track B capped below 90% | Cycle 1 QA login check | Use existing authorized QA accounts; if any role is missing, test all available roles and document exact missing QA account | Non-destructive; owner provisions missing QA test account |

---

## G. Browser Workflow Plan (7-Cycle QA Acceptance)

- **Target Environment:** QA Deployment + QA Supabase (`hopfohcnrtbiqjkgeukz`). **Never Production.**
- **Synthetic Data Only:** Fictional patients (e.g., adult + pediatric weight-based synthetic cases), synthetic batches, synthetic invoices.
- **Roles Tested (9):** Super Admin, Admin, Reception, GP, Dentist, Specialist, Lab Doctor, Lab Assistant, Pharmacist.
- **7 Execution Cycles:**
  1. **Cycle 1 — Discovery:** Map all 27 authenticated routes, navigation menus, role visibility, dead ends, and console/network errors.
  2. **Cycle 2 — Functional End-to-End Journeys:**
     - *Journey A (Core Outpatient):* Reception registers patient (incl. duplicate check) -> walk-in/appointment -> queue -> GP consultation (vitals, ICD-10 diagnosis, pediatric weight-safety Rx, lab order) -> Lab Assistant/Doctor specimen & result entry -> GP reviews result -> Pharmacist reviews & dispenses (inventory deducted) -> Billing invoice & idempotent payment -> receipt print -> follow-up scheduled -> Audit trail verified.
     - *Journey B (Exceptions & Integrity):* Pre-handover pharmacy cancellation, post-handover quarantine return (verifying no auto-restock & immutable compensation), inventory adjustment/expiry quarantine/write-off/audited price change, payment reversal.
  3. **Cycle 3 — Role & Authorization Matrix:** Verify allowed vs forbidden routes/actions for all 9 roles, cross-branch access denial (`42501`), and unauthorized API/RPC rejection.
  4. **Cycle 4 — Mobile & UX Audit:** Test viewports `320px`, `360px`, `375px`, `390px`, `430px` in Arabic RTL and English LTR; verify zero horizontal overflow, clipped buttons, keyboard/focus traps, or excessive clicks.
  5. **Cycle 5 — Regression:** Re-run Cycles 2–4 after every defect fix.
  6. **Cycle 6 — Stress & Failure:** Duplicate rapid clicks/submissions, page refresh mid-form, browser back/forward, invalid/missing fields, network offline/error handling, expired session redirect.
  7. **Cycle 7 — Final Acceptance Report:** Screen-by-screen & workflow-by-workflow pass/fail matrix with starting conditions, role, steps, expected vs actual, screenshots/logs, defects fixed, and Playwright regression test links.

---

## H. Owner-Dependent Task List (Strictly Genuine External/Human Gates)

1. **Read-Only Live Production & QA Supabase Catalog Snapshots (`#218`):** Export `supabase_migrations.schema_migrations`, `pg_policies` referencing `app_has_claim_branch`, `pg_proc` ACLs, and `private` schema `USAGE` grants.
2. **Backup Runner Secret Restoration & Decryption/Restore Proof (`#199`):** Configure `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD` in `roshan-health-hub-backup-runner`, run encrypted backup, perform owner-side `age -d` decryption + isolated PG17 restore, and verify Storage bucket restore.
3. **Repository Admin Branch Protection (`#253`):** Enable `main` branch protection and required status checks in GitHub repo settings.
4. **Clinical & Policy Approvals:**
   - Approve versioned pediatric dosing protocol source (WHO / BNFC / Sudanese national protocol) for RHH-02 (`#292`).
   - Decide WHO ICD-10 vs national adaptation/version for RHH-04 (`#291`).
   - Pharmacist workflow UAT acceptance for RHH-07 (`#210`) and RHH-01 (`#293`).
5. **Production Rollout Authorization:** Explicit owner go-live approval after all QA, security, and backup gates pass (plus QA test-account provisioning only if any of the 9 roles lack QA credentials).

---

## I. Long-Cycle Execution Strategy

- **Optimal Uninterrupted Execution Cycle:** 3–4 hours per focused autonomous cycle (or 1 complete milestone phase per uninterrupted agent cycle), batched to minimize redundant CI builds and browser session overhead.
- **State Preservation & Anti-Duplication:**
  - Merge PR `#261` early so `docs/PARALLEL_ENGINEERING_CONTINUATION.md` and `docs/parallel-reports/TEMPLATE.md` live on `main`.
  - Every cycle begins by verifying live `main` SHA, open PR heads, and latest CI runs — never relying on stale assumptions.
  - Every completed workstream updates its isolated `docs/parallel-reports/<workstream>.md` and appends exact SHAs, CI run IDs, test counts, and 8-state statuses (`Planned` / `Implemented` / `Tested` / `CI Verified` / `Independently Reviewed` / `Clinically Approved` / `Owner Authorized` / `Deployed`) to `docs/ROSHAN_V2_EXECUTION_REPORT.md`.
- **Branch Consolidation:** Keep feature branches small, atomic, and Lovable-safe (no force-push/rebase); run targeted local/PG17 tests during development and full CI only at stage completion; consolidate merges sequentially after independent review + rollback verification.

---

## J. Mandatory Plan Amendments (Approved 2026-11-20 — Original History Preserved)

The original Sections A–I above are preserved verbatim. Autonomous execution proceeds under these seven binding amendments:

1. **PR Governance & 45-PR Individual Triage:** Triage all 45 open PRs individually with an explicit disposition (`MERGE AFTER GATES`, `RECONCILE`, `HOLD / BLOCKED`, `SUPERSEDED / CLOSE`) and reason. Never merge solely because CI is green. Complete a migration overlap and dependency matrix across `#250`, `#269`, `#287`, `#293`, `#294`, and `#210` prior to any DB merge. Strictly preserve `AGENTS.md` forward-only Git rules (no force-push, rebase, amend, or squash of pushed commits).
2. **Early QA Environment Qualification (Priority 1):** Before browser execution, verify the exact QA deployment URL and confirm its Supabase project reference (`hopfohcnrtbiqjkgeukz`), proving QA browser workflows cannot write to Production (`jewzonxplxhogqrnhosl`). Verify availability of all 9 test roles and synthetic-data creation/cleanup. If QA access is unavailable, document the exact minimal owner action and immediately execute all independent work.
3. **End-to-End Data Integrity (RHH-05 Extension):** Extend RHH-05 beyond UI navigation to verify full relational integrity across `patient -> visit -> diagnosis -> prescription -> lab -> dispense -> inventory -> invoice -> payment -> audit`, test interruption/retry/refresh/duplicate submission/recovery, and prove financial and inventory ledgers reconcile after every critical journey.
4. **Independent Cross-Module Financial & Inventory Integrity:** Add cross-module integration and multi-session concurrency tests covering dispensing, inventory movements, pre-handover cancellation, immutable financial compensation, post-handover quarantine returns, write-offs, payments, and `reconcile_medicine_stock_ledger`, proving idempotency under concurrent and repeated requests.
5. **Strict Clinical Safety Boundaries:** Keep pediatric validation infrastructure strictly separate from clinically approved protocols; never invent doses, maximum limits, or treatment protocols; gate unapproved clinical behavior; explicitly distinguish `Implemented`, `Tested`, `Clinician-Approved`, and `Activated` states.
6. **Migration Dependency & Schema Compatibility Gate:** Before every database-related merge, perform a formal migration dependency and schema compatibility review, test clean PostgreSQL 17 replay and upgrade paths, verify rollback feasibility, and treat QA and Production migration histories independently.
7. **Maintainability, Performance & Rollback Audits:** Add dead-code, dependency, duplicate-logic, accessibility, performance, query-efficiency, error-recovery, and deployment-rollback audits; adopt external tools only after verifying compatibility, maintenance, security, licensing, and zero-cost/acceptable cost.
**EXECUTION STATUS:** Owner approved autonomous execution on 2026-11-20. See Section K for the live checkpoint. Production remains strictly read-only; no PR has been merged during this cycle.


---

## K. Autonomous Execution Checkpoint — 2026-11-20 (Cycle 1)

### K.1 Governance and QA qualification

- Section J was implemented in forward-only commit `ff802fe467eaebea4a83fb136cea1a9b0c0a8896`; Sections A–I were preserved.
- QA deployment and isolation were qualified by the preceding Neon cycle: Preview URL `https://roshan-health-hub-git-qa-isolated-acceptance-20261023-roshan45.vercel.app`, QA Supabase `hopfohcnrtbiqjkgeukz`, Production Supabase `jewzonxplxhogqrnhosl`. Vercel SSO and four missing synthetic roles still block the full authenticated browser matrix.
- Cycle began from `main` `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`. Documentation-only PR #261 was reviewed and merged with a normal merge commit `f046e41f7c67ccb3d7f3ad63fcd00729bb756e74`; current `main` is now `f046e41f7c67ccb3d7f3ad63fcd00729bb756e74`. No application-code merge, Production write, Production migration, deployment promotion, or real-patient-data test occurred.

### K.2 Phase 62 — pharmacy cancellation / return concurrency (PR #293)

- Two-session PostgreSQL 17 harness is present at `db/tests/phase62_pharmacy_cancellation_concurrency.sh`.
- The initial CI failure (`44796250163`, job `136496435501`) showed `branch_access_denied` during the synthetic seed handover. The fixture lacked the pharmacist actor row required by `private.app_has_branch_access`.
- Added the synthetic pharmacist to `public.users` with the same branch in commit `a2aab968c3b892a9fa33f399ca876a9e5fa7653b`.
- The next CI run (`44806100291`, job `136530396368`) passed the seed handover and reached the concurrency assertions. The observed `handover_already_recorded_use_return_workflow` was the expected losing side of the cancel-vs-handover race; the actual test defect was an assertion against nonexistent `handover_confirmed_at`.
- Corrected the assertion to the migration's actual `prescriptions.handed_over_at` column in commit `4e54d1ad6113047ee2e8eb705b477850874820b2`.
- Latest exact-head CI: **PASS, 20/20 jobs** on PR head `23d40e101d463f6715d643dff56ce4cd179a0d5f`, run `44807109853` (CI #2298). The two-session Phase 62 concurrency job passed, including the cancel-vs-handover race, duplicate cancellation, compensation linkage, and quarantine no-restock assertion. PR remains Draft and unmerged. Security role-boundary blocker remains unresolved.

### K.3 Phase 63 — inventory ledger concurrency (PR #294)

- Two-session PostgreSQL 17 harness is present at `db/tests/phase63_inventory_ledger_concurrency.sh`; it exercises five races: competing deductions, duplicate idempotency key, quarantine vs adjustment, competing write-offs, and price updates.
- CI run `44795772766`, job `136494788626`, demonstrated all five concurrency scenarios reached their assertions successfully; the final history-order assertion failed because `created_at` does not exist on `medicine_price_history`.
- Schema inspection confirmed the timestamp column is `effective_at` (not `created_at` or `changed_at`). The assertion was corrected to `ORDER BY effective_at DESC, id DESC` in commit `38e88e247be749ca656895fdf85c2155b73aebfc`.
- The preceding exact-head CI passed **20/20 jobs** on PR head `26f1cd97887ab939b6451a7b47936791a0fd4373`, run `44807031795` (CI #2297). The two-session Phase 63 inventory concurrency job passed all five race scenarios and final ledger reconciliation. After that pass, the combined Phase62+63 review identified and fixed the `return_quarantine` accounting mismatch: a synthetic regression now verifies quarantined returns do not inflate saleable stock, and the reconciliation query excludes that movement type. New head `64ac773d1eb9c48c5f9a4dda4919361d6e1e3911`; exact-head CI is pending/not yet returned. PR remains Draft and unmerged. Security role-boundary blocker remains unresolved.

### K.4 Early review findings (not yet final dispositions)

- PR metadata and changed-file inventories were refreshed for #210, #250, #269, #287, #291, #292, #293, #294, and #295. This is a partial triage snapshot, not completion of the 45-PR matrix.
- Cross-phase review found a remaining design conflict even though each PR's isolated CI is green: Phase 62 records `return_quarantine` as a positive stock movement without increasing saleable `pharmacy_inventory.quantity_remaining`, while Phase 63 reconciliation currently sums every stock movement and compares it to saleable batch quantity. The combined Phase62+63 path needs a dedicated regression and an explicit saleable-vs-quarantine ledger rule before either migration merges.
- PR #292 currently adds pediatric safety logic and tests but does not modify a UI caller. Main's `PrescriptionTab.tsx` already loads visit-linked weight and displays an advisory pediatric warning, but its save path does not enforce a missing/stale-weight gate. The new engine remains unwired.
- Do not activate dose recommendations or invent a universal freshness/weight threshold: the required clinical protocol and approvals are still absent. A safe UI integration must remain manual-decision-only until the source, jurisdiction, population, and clinician approvals are established.
- PR #261 was reviewed as documentation-only and merged to `main` at `f046e41f7c67ccb3d7f3ad63fcd00729bb756e74`; it adds the continuation protocol and report template. PR #256 remains Draft/HOLD: its scoped routing changes and exact-head CI were reviewed, but branch-protection/required-check behavior is still unverified. A review comment records the gate.
- PR #210's identity editor is a useful Phase 60 step, but the current model does not include manufacturer, commercial pack size, GTIN/barcode, or duplicate-detection semantics. A review comment records that RHH-07 remains partial.
- PR #210 touches 13 files, including the inventory UI and Phase 60 SQL/ACL work. Its migration and UI need full independent review; no merge recommendation is made yet.
- Independent security review identified a role-boundary gap in both new pharmacy phases: all four mutating Phase 62 RPCs and all four mutating Phase 63 RPCs currently check broad `pharmacy.update` permission without enforcing the canonical actor role. Findings were recorded on PRs #293 and #294. Hold both DB PRs until the intended role policy is explicit and negative Admin/Super Admin/non-pharmacist tests prove it. Quarantine disposition may require a distinct role; do not blindly assign every operation to Pharmacist.
- PR #291 is validation/search scaffolding only: its test data is a small synthetic fixture, not an authoritative WHO ICD-10 dataset or an approved Sudanese adaptation, and there is no diagnosis UI caller. A review comment records the source/version/licensing/UI gates.
- PR #292 adds pediatric validation infrastructure but no UI caller. Main's prescription tab has an advisory weight warning and still permits saving when weight is missing/unverified. A review comment records the need for safe manual-decision UI wiring without invented thresholds or activation of unapproved dose protocols.
- PRs #250/#269/#287/#293/#294 overlap around the Phase 61/62/63 pharmacy, inventory, and migration contracts. Complete the dependency/overlap matrix before any database merge.

### K.5 Score and next actions

- The latest Neon-reported recalibrated scores remain Track A engineering `64.0%` and Track B operational readiness `27.5%`; they have not been recalculated from this partial cycle. These are not directly comparable with older scoring rubrics.
- Next: verify exact-head CI for #293/#294; inspect and correct any remaining harness failures; then finish the migration overlap matrix and individual PR dispositions. Continue with #210 full review, #292 safe/manual UI integration decision, and #291 ICD-10 source/version governance. Backup/restore remains last.
