# Roshan Health Hub — V2 Execution Report

**Plan Reference:** `ROSHAN_APPROVED_ENGINEERING_PLAN_V2.md`
**Repository:** `crauch2088-source/roshan-health-hub`
**Baseline `main` SHA:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (`79d81f0`, 946 commits, unchanged)
**Last Verified:** 2026-11-20
**Production Changed:** NO
**PRs Merged:** NONE

## 1. Workstream Evidence & Governance Matrix

Each workstream is tracked across seven distinct gates: **Implemented**, **Tested**, **CI Verified**, **Independently Reviewed**, **Clinically Approved**, **Owner-Authorized**, and **Deployed**. No workstream is marked complete unless its evidence supports that gate.

| Workstream | Branch / PR | Head SHA (Full) | Latest Verified CI | Implemented | Tested | CI Verified | Independently Reviewed | Clinically Approved | Owner-Authorized | Deployed | Blocking Gate / Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **RHH-00** (Evidence, ACL, Backup/Restore, `main` Governance) | `docs/rhh00-v2-execution-report-20261120` / PR `#289` (Open) | Updated by this commit | Previous head `3a93f73`: 5/5 checks passing ([Run 44729240743](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44729240743)) | Partial (Report & `db/` ACL graph) | N/A (Docs) | Yes (prior head; re-verifying) | No | N/A | **No (Blocked)** | No | Remains **OPEN** until owner-authorized Production/QA catalog snapshots, backup-runner secret restoration (`#199`), decryption/isolated restore, Storage proof, and branch protection (`#253`) |
| **RHH-01** (Phase 62 Pharmacy Cancellation, Quarantine Return & Financial Compensation) | `feat/rhh01-pharmacy-cancellation-and-return` / PR `#293` (Open Draft) | `e9914dfc0702d9b9cb0d53cd443472024b754bcd` | [CI #2275 — Run 44760691721](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44760691721): **27 passed, 1 skipped, 0 failed** (`sql-pharmacy-cancellation-return` Passed, 17s) | Yes (SQL migration + PG17 test + CI job) | Yes (PG17 integration test) | **Yes** | No | No | No | No | Reconcile with PR `#250` (`pharmacist` boundary), independent security review, clinical/pharmacist acceptance, owner rollout authorization |
| **RHH-02** (Pediatric Prescription Safety & Decision Support) | `feat/rhh02-pediatric-safety-and-decision-support` / PR `#292` (Open) | `ef8c22167262de35ff32c8ac27e6a4891ee55715` | [CI #2270 — Run 44746924208](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44746924208): **30 passed, 1 skipped, 0 failed** (`31/31` PR checks green) | Yes (Scaffolding & guardrails) | Yes (Unit/guard tests) | **Yes** | No | **No (Required)** | No | No | Requires approved versioned clinical protocol source and clinical sign-off before production enablement |
| **RHH-03** (Phase 63 Inventory Ledger Controls, Quarantine, Write-Off & Audited Pricing) | `feat/rhh03-inventory-ledger-controls` / PR `#294` (Open Draft) | `326be10d912200209e597ffa8777008578b1fc2e` | [CI #2276 — Run 44763311605](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44763311605): **28/28 checks green** (`sql-inventory-ledger-controls` Passed, 21s; 20 CI jobs passed, 1 skipped) | Yes (SQL migration + PG17 test + CI job) | Yes (PG17 integration test; single-session) | **Yes** | No | No | No | No | Needs independent security review, two-session concurrency test coverage, reconciliation with PR `#210`, and owner authorization |
| **RHH-04** (Dataset-Backed ICD-10 Validation Scaffolding) | `feat/rhh04-icd10-validation-scaffolding` / PR `#291` (Open) | `a50e9e9202bd5bfeeda389dcc38a3896e8be3d9b` | [CI #2256 — Run 44727094440](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44727094440): **31/31 checks green** (Success) | Yes (Validation scaffolding) | Yes (Unit/guard tests) | **Yes** | No | **No (Required)** | No | No | Requires WHO ICD-10 vs national adaptation decision before catalogue import and DB RPC |
| **RHH-05** (Authenticated E2E, Mobile/RTL & Branch Protection `#253`) | Not started | — | — | No | No | No | No | N/A | No | No | Branch protection requires owner repo admin settings |
| **RHH-06** (Health/Readiness Probes & Redacted PHI Telemetry) | `feat/rhh06-health-readiness-and-phi-telemetry` / PR `#290` (Open) | `06791249d5f9012463ddb323c8809cd814665f1e` | [CI #2272 — Run 44751336439](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44751336439): **27 passed, 1 skipped, 0 failed** (`28/28` PR checks green) | Yes (Probes, telemetry, redaction tests) | Yes (Unit/redaction tests) | **Yes** | No | N/A | No | No | Manifest guard waits for RHH-00 ledger reconciliation; requires independent review and owner approval |
| **RHH-07** (Medicine Catalogue Identity & Pack-Attestation Audit of PR `#210`) | Audit of PR `#210` (`feat/medicine-catalogue-identity-rebased-20261109`) | `e53216a` (PR `#210`, unmerged Draft) | PR `#210` checks: 31 passed, 1 skipped (unmerged; **DO NOT MERGE**) | Audited (Not merged) | Partial (420-line SQL test not fully reviewed) | PR `#210` CI green (not acceptance) | Partial (Blockers open) | **No (Pharmacist UAT required)** | No | No | Blocked by 7 documented merge blockers in Section 5 |

## 2. RHH-00 — Detailed Verification & Reconciliation Record

- **Workstream ID & Scope:** RHH-00 — Release evidence, migration reconciliation, Issue `#218` ACL dependency graph, open PR reconciliation (`#250`, `#260`, `#287`, `#210`), and backup/restore gate tracking.
- **Starting `main` SHA:** `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (`docs(roshan): append late-session execution evidence`, 2026-11-15).
- **Working Branch:** `docs/rhh00-v2-execution-report-20261120`
- **Production Changed:** NO

### 2.1 Authenticated Open PR Reconciliation (Pre-Existing Draft PRs, Verified 2026-11-20)

| PR | Branch & Head SHA | State | Mergeability vs `main` | Files | CI Status | V2 Plan Treatment |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `#250` | `fix/phase61c-atomic-dispense-role-boundary-20261114` (`c43c025`) | Open Draft | No conflicts | 25 | Passing (34 passed, 1 skipped) | Reconcile & obtain independent security review for canonical `pharmacist` boundary before merge; do not duplicate. |
| `#260` | `test/218-phase55-helper-acl-20261116` (`ebb46d6`) | Open Draft | No conflicts | 1 | **Failing** (26 passed, 1 skipped, 1 failed: run `43847110127`) | **Do NOT merge standalone.** Intentionally reproduces Issue `#218`; must be paired with the verified wrapper/RLS fix in one green candidate branch. |
| `#287` | `perf/phase61d-correction-fk-indexes-20261117` (`983e5cd`) | Open Draft | No conflicts | 6 | Passing (27 passed, 1 skipped) | Independent performance candidate; NOT a functional gate for security correctness. |
| `#210` | `feat/medicine-catalogue-identity-rebased-20261109` (`e53216a`) | Open Draft | No conflicts | 13 | Passing (31 passed, 1 skipped) | Tracked under RHH-07; **DO NOT MERGE** until all 7 blockers in Section 5 are resolved. |

### 2.2 Issue `#218` / PR `#260` Complete `db/` ACL Dependency Graph

Inspected PR `#260` diff (`db/tests/phase55_clinical_parent_guard_assertions.sql`), GitHub Actions run `43847110127` (`phase55-clinical-parent-guard`), and all occurrences across `db/` on `main` (`79d81f0`):

1. **Exact Failure Reproduced by PR `#260` (Run `43847110127`):**
   - `psql:db/tests/phase55_clinical_parent_guard_assertions.sql:140: ERROR: permission denied for function app_has_claim_branch`
   - `CONTEXT: SQL statement "SELECT count(*) FROM public.phase55_test_insurance_claim_items"`
   - Cause: PR `#260` models 4 `TO authenticated` RLS policies (`SELECT` and `INSERT` on `insurance_claim_items` and `insurance_claim_payments`) invoking `(SELECT private.app_has_claim_branch(claim_id))`. After `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` revokes `EXECUTE` from `PUBLIC, anon, authenticated, service_role, authenticator`, `authenticated` RLS evaluation fails with `42501`.
2. **Complete `db/` Caller Graph on `main`:**
   - **`private.app_has_claim_branch(_claim_id uuid)`** — Defined in `db/roshan_phase31_clinical_financial_security_hardening.sql` (line 62). Called by `SECURITY DEFINER` RPCs `public.update_insurance_claim_status` and `public.post_insurance_claim_payment` in `db/roshan_insurance_claim_money_precision.sql` (lines 26, 104). No `CREATE POLICY` in `db/` on `main` references `private.app_has_claim_branch`; live Production RLS policies documented in `docs/INDEPENDENT_RELEASE_AUDIT_RECONCILIATION_2026-11-15.md` exist only in live catalog / historical migrations outside `main`'s `db/` policies. Therefore, **no speculative `DROP POLICY` / `GRANT` / `REVOKE` patch may be authored** until live Production and QA `pg_policies` are inspected read-only.
   - **`private.sync_user_role_text()`** — Trigger function (`SECURITY DEFINER`, `SET search_path TO ''`) bound to `trg_sync_user_role_text`. Safe under owner-only `EXECUTE` revocation.
   - **`private.phase36_guard_clinical_visit_links()`** — Trigger function (`SECURITY DEFINER`, `SET search_path TO ''`) attached via `phase36_visit_link_guard`. Safe under owner-only `EXECUTE` revocation.

### 2.3 Remaining RHH-00 Owner Dependencies (Keep RHH-00 Open)

1. **Owner-Authorized Read-Only Supabase Catalog Snapshots (Production `jewzonxplxhogqrnhosl` & QA `hopfohcnrtbiqjkgeukz`):** Exact `supabase_migrations.schema_migrations` rows, `pg_policies` names/predicates referencing `app_has_claim_branch`, `pg_proc` ACLs (`proacl`), and `private` schema `USAGE` grants.
2. **Backup Credential Restoration, Decryption, Isolated Restore & Storage Proof (Issue `#199`):** Owner must restore `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD` in `roshan-health-hub-backup-runner`, run a fresh encrypted backup, verify owner-side `age -d` decryption and isolated PG 17 restore, and verify Supabase Storage bucket backup/restore coverage.
3. **Repository Admin Branch Protection (Issue `#253`):** Owner admin configuration of `main` branch protection with verified stable required checks.

## 3. RHH-01 (PR #293) & Phase 61B Verification Evidence

- **Phase 61B Permission Verification:** `db/roshan_phase61b_clinical_role_boundary.sql` (lines 42, 110) already uses `pharmacy.correction.request` and (lines 46, 147) `prescriptions.correction.resolve`, consistent with `db/roshan_phase61_prescription_item_correction_workflow.sql`, `pharmacy.tsx`, `prescription-correction.tsx`, and tests.
- **PR `#293` (`feat/rhh01-pharmacy-cancellation-and-return`, Draft):**
  - **Final Head SHA:** `e9914dfc0702d9b9cb0d53cd443472024b754bcd`
  - **Fix Applied:** Supplied explicit `id` (`gen_random_uuid()`) to the 5-row `INSERT INTO public.prescription_items` fixture in `db/tests/phase62_pharmacy_cancellation_and_return_integration.sql` (line 111) to match `public.prescription_items.id uuid PRIMARY KEY` (no default in `db/tests/pharmacy_dispense_invoice_fixture.sql`), resolving CI `#2274` (`44755550204`) failure.
  - **CI Evidence:** [CI #2275 — Run 44760691721](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44760691721) — **27 passed, 1 skipped, 0 failed**; `sql-pharmacy-cancellation-return` (`Pharmacy cancellation, quarantine return, and compensation (PG17)`) **Passed in 17s**.
  - **Verified Phase 62 Controls:** RLS + `FORCE ROW LEVEL SECURITY` on 4 new tables (`financial_compensations`, `pharmacy_dispense_cancellations`, `pharmacy_returns`, `pharmacy_return_quarantine`); `SECURITY DEFINER SET search_path TO ''` RPCs enforcing `pharmacy.update` and `private.app_has_branch_access`; UUID `idempotency_key` uniqueness; deterministic `FOR UPDATE` locking; atomic transaction rollback; post-handover returns quarantined without automatic restock; immutable `financial_compensations` ledger without altering historical invoices or payments.

## 4. RHH-03 (Draft PR #294) — Inventory Mutation-Path Matrix & Evidence

- **Branch & Draft PR:** `feat/rhh03-inventory-ledger-controls` / [Draft PR #294](https://github.com/crauch2088-source/roshan-health-hub/pull/294)
- **Final Head SHA:** `326be10d912200209e597ffa8777008578b1fc2e`
- **CI Evidence:** [CI #2276 — Run 44763311605](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44763311605) — **28/28 checks green**; `sql-inventory-ledger-controls` (`Inventory ledger controls`) **Passed in 21s** (20 CI jobs passed, 1 skipped, 0 failed).
- **Files:** `db/roshan_phase63_inventory_ledger_controls.sql` (503 lines), `db/tests/phase63_inventory_ledger_controls_integration.sql` (237 lines), `.github/workflows/ci.yml` (`sql-inventory-ledger-controls`).

| RPC / Trigger / Table | Mutation Path | Ledger / Audit Target | Auth & Branch Gate | Idempotency |
| :--- | :--- | :--- | :--- | :--- |
| `public.adjust_inventory_batch_atomic(p_batch_id, p_delta, p_reason, p_idempotency_key)` | Locks `pharmacy_inventory` & `medicines` `FOR UPDATE`; blocks quarantined batches & negative stock (`22023`); updates `quantity_remaining` & `stock_quantity` | `public.stock_movements` (`movement_type = 'stock_adjustment'`) + `public.inventory_adjustment_idempotency` | `current_app_user_id()`, `app_has_perm('pharmacy.update')`, `app_has_branch_access(branch_id)` (`42501`) | `inventory_adjustment_idempotency` PK (`p_idempotency_key`) returns existing `movement_id` |
| `public.quarantine_expired_batch_atomic(p_batch_id, p_reason, p_idempotency_key)` | Locks `pharmacy_inventory` & `medicines` `FOR UPDATE`; sets `quantity_remaining = 0`, `is_quarantined = true`, `quarantined_at = clock_timestamp()`; decrements `medicines.stock_quantity` | `public.inventory_expiry_quarantine` (`status = 'quarantined'`) + `public.stock_movements` (`movement_type = 'expiry_quarantine'`, `quantity = -v_batch.quantity_remaining`) | `pharmacy.update` + `app_has_branch_access` (`42501`) | `inventory_expiry_quarantine.idempotency_key` (`UNIQUE`) |
| `public.record_inventory_writeoff_atomic(p_batch_id, p_quantity, p_writeoff_type, p_reason, p_idempotency_key)` | If quarantined: updates `inventory_expiry_quarantine.status` (`'returned_to_supplier'` or `'written_off'`), logs `0` qty movement. If not quarantined: decrements `pharmacy_inventory.quantity_remaining` & `medicines.stock_quantity`, logs `-p_quantity` | `public.inventory_writeoffs` + `public.stock_movements` (`'writeoff_' || p_writeoff_type`) | `pharmacy.update` + `app_has_branch_access` (`42501`) | `inventory_writeoffs.idempotency_key` (`UNIQUE`) |
| `public.update_medicine_selling_price_atomic(p_medicine_id, p_branch_id, p_new_selling_price, p_reason, p_idempotency_key)` | Locks `medicines` `FOR UPDATE`; validates `p_new_selling_price >= 0` & non-empty reason; updates `medicines.selling_price = ROUND(p_new_selling_price, 2)` | `public.medicine_price_history` (`old_selling_price`, `new_selling_price`, `reason`, `changed_by`) | `pharmacy.update` + `app_has_branch_access` (`42501`) | `medicine_price_history.idempotency_key` (`UNIQUE`) |
| `public.reconcile_medicine_stock_ledger(p_medicine_id, p_branch_id)` | Read-only reconciliation comparing `SUM(pharmacy_inventory.quantity_remaining)` (`deleted_at IS NULL`) vs `SUM(stock_movements.quantity)` | Returns `(batch_sum, ledger_net, is_balanced)` | `pharmacy.read` + `app_has_branch_access` (`42501`) | N/A (read-only) |
| `private.reject_phase63_ledger_mutation()` triggers | `BEFORE UPDATE OR DELETE FOR EACH ROW` on `stock_movements`, `inventory_writeoffs`, `medicine_price_history` | Raises SQLSTATE `55000` (`phase63 ledger table % is append-only`) | Trigger enforced for all roles | N/A |

- **Unresolved RHH-03 Risks:** Integration tests run inside a single-session `BEGIN ... ROLLBACK` block; true two-session concurrency harness testing is not yet implemented. Independent security review and reconciliation with PR `#210` remain open.

## 5. RHH-07 — PR #210 Audit Findings & Merge Blockers (DO NOT MERGE)

PR `#210` (`feat/medicine-catalogue-identity-rebased-20261109`, head `e53216a`, Draft) **must not be merged**. The following audit findings and unresolved review blockers remain open:

1. **Physical-pack attestation scope boundary:** Physical-pack attestation is **not** manufacturer or regulatory authenticity verification.
2. **Remaining catalogue identity scope gaps:** Pack size, dispensing unit, manufacturer, GTIN/barcode, and duplicate detection remain scope gaps.
3. **Database extension prerequisite:** `pgcrypto` availability must be verified in target environments before rollout.
4. **Uninspected UI diff:** Inventory UI modal and RPC handler diffs still require final line-by-line inspection.
5. **Unreviewed SQL integration test:** The 420-line SQL integration test requires full line-by-line review, not merely header inspection.
6. **Documentation reconciliation:** Old-base documentation changes in PR `#210` must be reconciled with current `main` (`79d81f0`) and the live migration history.
7. **Clinical / operational acceptance:** Formal pharmacist workflow UAT acceptance is required before merge or rollout.

**Production Changed:** NO
**Main Branch Modified:** NO
**PRs Merged:** NONE
