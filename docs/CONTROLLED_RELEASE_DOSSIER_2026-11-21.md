# Roshan Health Hub — Controlled-Release Dossier (2026-11-21)

> **PLAN AND EVIDENCE PACKAGE ONLY — NOT EXECUTED.**
> **PRODUCTION P0 REMAINS OPEN — NO-GO** until every preflight gate below is satisfied and the owner explicitly authorizes a controlled maintenance window.

## 1. Proposed Merge & Release Sequence (Owner-Authorized Only)

| Step | PR / Branch | Exact Head SHA | Exact-Head CI Status | Scope & Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| 1 | PR `#260` (`test/218-phase55-helper-acl-20261116`) | `b963d7a3b3d1502d9d72a6eb101a202bb537de46` | **PASS** (`44872527243`, `44872527195`) | Phase 55B private-helper ACL + `public.app_has_claim_branch` RLS wrapper (SQL/tests only — skips Vercel Prod build) |
| 2 | PR `#250` (`fix/phase61c-atomic-dispense-role-boundary-20261114`) | `832a8d38fba10409a44cd9eac7a4e34760aceaac` | **12/12 PASS** (`44874136237`, `44874136238`) | P0 Phase 61C pharmacist-only dispense boundary; requires Phase 55B + 57/57B + 61B in DB first |
| 3 | PR `#293` (`feat/rhh01-pharmacy-cancellation-and-return`) | `3eb2253367bd7396e6251f82e6dfec6544ef3590` | 0 TS errors, 332/332 PASS, PG17 PASS; Prettier FAIL | Phase 62 pharmacy lifecycle (requires pinned Prettier pass before merge) |
| 4 | PR `#294` (`feat/rhh03-inventory-ledger-controls`) | `88417c6d8b374a28502c84b2a858a1f6fe23de34` | **6/6 PASS** (`44872286953`, `44872286949`) | Phase 63 inventory ledger UI + SQL drift-clamping fix |
| 5 | PR `#292` (`feat/rhh02-pediatric-safety-and-decision-support`) | `89763d257af465037ba329641cb8ec8dc7ea3291` | **8/8 PASS** (`44872721682`, `44872721655`) | PediatricSafetyPanel wired (`protocol: null` activation lock) |
| 6 | PR `#291` (`feat/rhh04-icd10-validation-scaffolding`) | `804302fc159d44a986d6443b6d4ded27aebd8119` | **8/8 PASS** (`44874100001`, `44874099883`) | WHO ICD-10 2019 UI validation + forward-only versioning SQL |
| 7 | PR `#210` (`feat/medicine-catalogue-identity-rebased-20261109`) | `84b328e9e6ebe7f4b444db6c228b710cf9052828` | Keep **Draft** | Phase 60/60B physical-pack identity & exact duplicate guard; awaits pharmacist physical-pack acceptance |

## 2. Production P0 Migration Chain (Exact Filenames & SHA-256 Checksums)

| Order | Migration File | Source Ref | Bytes | SHA-256 |
| :--- | :--- | :--- | ---: | :--- |
| 1 | `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` | `main` | 2,305 | `bfe18f78771b7d19f228543a2c77958b3e53b36b035f9d3e8cd28e19323f3447` |
| 2 | `db/roshan_phase55b_private_helper_acl_reconciliation.sql` | PR `#260` (`b963d7a`) | 2,232 | `1a2bf061cb32934a9c6d3d9012acee4106767c76e3fcfc7f0df3c07fc3e1d306` |
| 3 | `db/roshan_phase57_pharmacy_quantity_required_guard.sql` | `main` | 10,954 | `bebfb63d546be437bd77f442c0477b30fa53ffefebfb9b62cb08e7f7ac96496f` |
| 4 | `db/roshan_phase57b_free_text_external_prescription_guard.sql` | `main` | 11,943 | `907b6f453ea8af1fa983fe6d8ede7b51f7cc75fe2eebba1dd009f72484c22661` |
| 5 | `db/roshan_phase61b_clinical_role_boundary.sql` | PR `#250` (`832a8d3`) | 8,844 | `d5125f2ddaac72df63394b74cb6ed65dd43711e521b33c1824c7ec52785f3280` |
| 6 | `db/roshan_phase61c_atomic_dispense_role_boundary.sql` | PR `#250` (`832a8d3`) | 4,277 | `15ea4e08a1b13274c77240283bd1b60a237558b16e7c8146500681299c479639` |

## 3. Mandatory Preflight Checklist (Abort Immediately if Any Item Fails)

- [ ] Fresh encrypted Production backup completed in `roshan-health-hub-backup-runner` (after setting exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`).
- [ ] Offline Android `age` decryption of the fresh archive verified by owner.
- [ ] Isolated PostgreSQL 17 restore rehearsal + row-count/integrity smoke passed on non-production container.
- [ ] Exact target confirmed: `jewzonxplxhogqrnhosl` (PG `17.6.1.155`); `supabase_migrations.schema_migrations` NOT manually edited; QA migrations NOT bulk-replayed.
- [ ] GitHub `main` branch protection enabled (`#253`) and independent 2nd review signed off on PR `#250` (including Super Admin exclusion policy).
- [ ] Maintenance window announced and owner authorization logged.

## 4. Read-Only Post-Release Verification SQL

```sql
-- 1. Verify private helpers are strictly owner-only (no NULL proacl / no PUBLIC EXECUTE)
SELECT n.nspname, p.proname, p.proacl::text
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'private'
  AND p.proname IN ('app_has_claim_branch', 'sync_user_role_text', 'atomic_pharmacy_dispense_unchecked');

-- 2. Verify public wrappers enforce canonical pharmacist role and preserve setup_required()
SELECT n.nspname, p.proname, p.proacl::text, pg_get_functiondef(p.oid) LIKE '%ARRAY[''pharmacist'']%' AS enforces_pharmacist
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('atomic_pharmacy_dispense', 'fn_dispense_prescription_with_invoice', 'setup_required');
```

## 5. Abort Criteria, Forward-Recovery & Vercel Non-Deploy Proof

- **Abort Criteria:** Any prerequisite exception (`Phase 61B role permission helper is missing`), unexpected `42501` on `insurance_claim_items`/`insurance_claim_payments` for authorized billing staff, or failure of a legitimate pharmacist dispense smoke test.
- **Recovery Strategy:** Forward-fix only inside the maintenance window (never edit migration ledger history). If catastrophic failure occurs, restore from the preflight-verified encrypted backup into a clean instance per `roshan-health-hub-backup-runner` recovery runbook.
- **Vercel Production Non-Deploy Proof:** `prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk` uses `commandForIgnoringBuildStep: "git diff --quiet HEAD^ HEAD -- src/ public/ index.html package.json package-lock.json vercel.json vite.config.ts tsconfig*.json"`. Docs/SQL-only commits to `main` exit 0 (`CANCELED`); `src/` merges WILL trigger Production deployment and therefore remain gated on owner authorization.
