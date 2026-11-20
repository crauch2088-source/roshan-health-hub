# Roshan Health Hub — V2 Execution Report

**Plan Reference:** `ROSHAN_APPROVED_ENGINEERING_PLAN_V2.md`  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Baseline `main` SHA:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (`79d81f0`, 946 commits)  
**Last Verified:** 2026-11-20  
**Production Changed:** NO

---

## 1. Workstream Status Matrix

| Workstream | Title | Status | Starting `main` SHA | Working Branch / PR | Production Changed | Blocking Gate / Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **RHH-00** | Release evidence, migration reconciliation, ACL review, backup/restore proof & `main` governance | **IN PROGRESS** | `79d81f0` | `docs/rhh00-v2-execution-report-20261120` | NO | Awaiting owner-authorized read-only Production/QA `pg_policies` & ledger snapshots + backup-runner secret restoration (`#199`) |
| **RHH-01** | Phase 61/61B permission contract, pharmacist-only atomic dispense & safe cancellation/reversal | **NOT STARTED** | `79d81f0` | Reconciles PR `#250` | NO | Ready to start in feature branch after RHH-00 permission/PR `#250` review |
| **RHH-02** | Medication decision support & pediatric prescription safety | **NOT STARTED** | `79d81f0` | — | NO | Requires approved versioned clinical protocol source |
| **RHH-03** | Inventory adjustment, quarantine/write-off & audited price changes | **NOT STARTED** | `79d81f0` | Coordinates with PR `#210` | NO | Parallelizable with RHH-02 |
| **RHH-04** | Validated bilingual ICD-10 catalogue & controlled diagnosis writes | **NOT STARTED** | `79d81f0` | — | NO | Requires WHO ICD-10 vs national adaptation classification decision |
| **RHH-05** | Authenticated E2E, mobile/RTL testing & branch protection (`#253`) | **NOT STARTED** | `79d81f0` | — | NO | Branch protection requires owner repository admin settings |
| **RHH-06** | Redacted telemetry, health/readiness checks & documentation hygiene | **NOT STARTED** | `79d81f0` | — | NO | Independent; manifest guard waits for RHH-00 ledger reconciliation |
| **RHH-07** | Medicine catalogue identity & pack-attestation acceptance | **NOT STARTED** | `79d81f0` | Reconciles PR `#210` | NO | Requires pharmacist UAT & precise scope boundary |

---

## 2. RHH-00 — Detailed Verification & Reconciliation Record

- **Workstream ID & Scope:** RHH-00 — Release evidence, migration reconciliation, Issue `#218` ACL dependency graph, open PR reconciliation (`#250`, `#260`, `#287`, `#210`), and backup/restore gate tracking.
- **Starting `main` SHA:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (`docs(roshan): append late-session execution evidence`, 2026-11-15).
- **Working Branch:** `docs/rhh00-v2-execution-report-20261120`
- **Production Changed:** NO

### 2.1 Authenticated Open PR Reconciliation (Verified 2026-11-20)

| PR | Branch & Head SHA | State | Mergeability vs `main` | Files | CI Status | V2 Plan Treatment |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `#250` | `fix/phase61c-atomic-dispense-role-boundary-20261114` (`c43c025`) | Open Draft | No conflicts (auto-mergeable once ready) | 25 | Passing (34 passed, 1 skipped) | Reconcile & obtain independent security review for canonical `pharmacist` boundary before merge; do not duplicate. |
| `#260` | `test/218-phase55-helper-acl-20261116` (`ebb46d6`) | Open Draft | No conflicts (auto-mergeable once ready) | 1 | **Failing** (26 passed, 1 skipped, 1 failed: run `43847110127`) | **Do NOT merge standalone.** Intentionally reproduces Issue `#218`; must be paired with the verified wrapper/RLS fix in one green candidate branch. |
| `#287` | `perf/phase61d-correction-fk-indexes-20261117` (`983e5cd`) | Open Draft | No conflicts (auto-mergeable once ready) | 6 | Passing (27 passed, 1 skipped) | Independent performance candidate; NOT a functional gate for security correctness. |
| `#210` | `feat/medicine-catalogue-identity-rebased-20261109` (`e53216a`) | Open Draft | No conflicts (auto-mergeable once ready) | 13 | Passing (31 passed, 1 skipped) | Tracked under RHH-07; requires pharmacist acceptance and explicit scope wording (pack attestation is not authenticity/barcode verification). |

### 2.2 Issue `#218` / PR `#260` Complete `db/` ACL Dependency Graph

Inspected PR `#260` diff (`db/tests/phase55_clinical_parent_guard_assertions.sql`), GitHub Actions run `43847110127` (`phase55-clinical-parent-guard`), and all occurrences across `db/` on `main` (`79d81f0`):

1. **Exact Failure Reproduced by PR `#260` (Run `43847110127`):**
   - `psql:db/tests/phase55_clinical_parent_guard_assertions.sql:140: ERROR: permission denied for function app_has_claim_branch`
   - `CONTEXT: SQL statement "SELECT count(*) FROM public.phase55_test_insurance_claim_items"`
   - Cause: PR `#260` models 4 `TO authenticated` RLS policies (`SELECT` and `INSERT` on `insurance_claim_items` and `insurance_claim_payments`) invoking `(SELECT private.app_has_claim_branch(claim_id))`. After `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` executes `REVOKE ALL ON FUNCTION private.app_has_claim_branch(uuid) FROM PUBLIC, anon, authenticated, service_role, authenticator;`, `authenticated` RLS evaluation fails with `42501`.
2. **Complete `db/` Caller Graph on `main`:**
   - **`private.app_has_claim_branch(_claim_id uuid)`** — Defined in `db/roshan_phase31_clinical_financial_security_hardening.sql` (line 62). Called by `SECURITY DEFINER` RPCs `public.update_insurance_claim_status` and `public.post_insurance_claim_payment` in `db/roshan_insurance_claim_money_precision.sql` (lines 26, 104) — those RPCs remain functional under owner-only ACLs. **Crucial finding:** No `CREATE POLICY` in `db/` on `main` references `private.app_has_claim_branch`; the 4 live Production RLS policies documented in `docs/INDEPENDENT_RELEASE_AUDIT_RECONCILIATION_2026-11-15.md` exist only in live catalog / historical migrations outside `main`'s `db/` policies. Therefore, **no speculative `DROP POLICY` / `GRANT` / `REVOKE` patch may be authored** until live Production and QA `pg_policies` are inspected read-only.
   - **`private.sync_user_role_text()`** — Trigger function (`RETURNS trigger`, `SECURITY DEFINER`, `SET search_path TO ''`) bound to `trg_sync_user_role_text` (`BEFORE UPDATE OF role_id ON public.users`). Safe under owner-only `EXECUTE` revocation.
   - **`private.phase36_guard_clinical_visit_links()`** — Trigger function (`RETURNS trigger`, `SECURITY DEFINER`, `SET search_path TO ''`) defined in `db/roshan_phase36_audit_coverage_and_visit_lifecycle_guards.sql` (line 21) and `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` (line 5), attached via `phase36_visit_link_guard` on clinical child tables. Safe under owner-only `EXECUTE` revocation.

### 2.3 Remaining RHH-00 Blockers (Exact Missing Evidence / Permissions)

1. **Read-only Live Supabase Catalog Snapshot (Production `jewzonxplxhogqrnhosl` & QA `hopfohcnrtbiqjkgeukz`):** Needed to capture exact `supabase_migrations.schema_migrations` rows, exact `pg_policies` names/predicates referencing `app_has_claim_branch`, `pg_proc` ACLs (`proacl`), and `private` schema `USAGE` grants before authoring the paired Issue `#218` wrapper migration + PR `#260` test.
2. **Encrypted Backup & Storage Restore Proof (Issue `#199`):** Owner must configure `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD` in `roshan-health-hub-backup-runner`, run a fresh encrypted backup, verify owner-side `age -d` decryption + isolated PG 17 restore, and verify Supabase Storage bucket backup/restore coverage.
3. **Repository Admin Branch Protection (Issue `#253`):** Requires repository owner admin access to configure `main` branch protection with verified stable required checks.
## 3. Session Update — PR #290, PR #291 & Phase 61B Permission Verification (2026-11-20)

- **PR #289 CI:** Passed (5/5 checks, Vercel skipped via `ignoreCommand`).
- **RHH-01 Verified Line-Level Correction:** `db/roshan_phase61b_clinical_role_boundary.sql` (lines 42, 110) ALREADY uses `pharmacy.correction.request` and (lines 46, 147) `prescriptions.correction.resolve`, 100% consistent with `db/roshan_phase61_prescription_item_correction_workflow.sql`, `pharmacy.tsx`, `prescription-correction.tsx`, and tests (closing the earlier suspected permission-code mismatch).
- **RHH-04 (`IN PROGRESS` — scaffolding complete & CI green):** PR `#291` (`feat/rhh04-icd10-validation-scaffolding`, head `a50e9e9`, `src/lib/icd10-validation.ts`, `tests/icd10-validation.test.ts`, `package.json`), **30/30 CI checks passed** (1 skipped, 0 failing); awaiting clinical classification/version decision before catalogue import & DB RPC.
- **RHH-06 (`IN PROGRESS` — probes & telemetry complete):** PR `#290` (`feat/rhh06-health-readiness-and-phi-telemetry`, head `81bde1c`, `src/lib/health-probes.ts`, `src/lib/telemetry.ts`, `src/server.ts`, `tests/ssr-log-redaction.test.ts`), final completed CI status: **25 passed, 2 failed, 1 skipped** (28 total checks; failing: `CI / Install, audit, typecheck, lint, build (pull_request)` and `Insurance claim UI validation / Insurance claim validation regression (pull_request)`; skipped: `CI / Canonical PG17 baseline replay and authenticated clinical acceptance (pull_request)`).

**Production Changed: NO**
