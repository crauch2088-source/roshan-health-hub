# Final Release Readiness & Remediation Report — 2026-11-21

> **PRODUCTION P0 REMAINS OPEN — NO-GO.**
> **Production Supabase (`jewzonxplxhogqrnhosl`) and Production Vercel (`prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`) were NOT modified in any way during this campaign.**

> Follows `docs/parallel-reports/TEMPLATE.md` and `docs/FINAL_RELEASE_READINESS_AND_REMEDIATION_MANDATE_2026-11-21.md` Section 12.

## 1. Executive Verdict & Timestamp

- **Timestamp (UTC):** `2026-11-21T06:28Z`
- **Verdict:** **PASS WITH OWNER/CLINICAL GATES — PRODUCTION P0 REMAINS OPEN — NO-GO**
- **Controlled-Release Dossier:** `docs/CONTROLLED_RELEASE_DOSSIER_2026-11-21.md` (plan & evidence only; not executed).
- **Status Vocabulary Applied Strictly:** *implemented*, *tested*, *evidence-verified*, *independently reviewed*, *clinically approved*, *owner-approved*, *released*.

## 2. Exact Branch, PR & CI State Matrix (Live Verified 2026-11-21)

| Item | State | Exact Head SHA | Base SHA | Exact-Head CI Run IDs & Result | Strict Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`main`** | Default (unprotected) | `3bc317b` | — | Vercel Prod `CANCELED` (docs-only) | Untouched; `protected: False` (`#253`) |
| **PR `#250`** (P0 Phase 61C) | Draft (synced) | `832a8d3` | `3bc317b` | **12/12 PASS** (`CI` [`44874136237`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44874136237), `UI` [`44874136238`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44874136238), `PG17` [`44874136348`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44874136348)) | *implemented*, *tested*, *evidence-verified* (awaiting 2nd *independently reviewed* & *owner-approved*) |
| **PR `#260`** (Phase 55B ACL) | Draft | `b963d7a` | `79d81f0` | **PASS** (`Phase 55 PG17` [`44872527243`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872527243), `CI` [`44872527195`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872527195)) | *implemented*, *tested*, *evidence-verified* |
| **PR `#294`** (Phase 63 Inv) | Draft | `88417c6` | `79d81f0` | **6/6 PASS** (`CI` [`44872286953`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872286953), `UI` [`44872286949`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872286949)) | *implemented*, *tested*, *evidence-verified* |
| **PR `#292`** (Pediatric UI) | Ready | `89763d2` | `79d81f0` | **8/8 PASS** (`CI` [`44872721682`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872721682), `UI` [`44872721655`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44872721655)) | *implemented*, *tested* (**NOT** *clinically approved*; `protocol: null`) |
| **PR `#291`** (WHO ICD-10) | Ready | `804302f` | `79d81f0` | **8/8 PASS** (`CI` [`44874100001`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44874100001), `UI` [`44874099883`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44874099883)) | *implemented*, *tested* (**NOT** *clinically approved*) |
| **PR `#210`** (Phase 60/60B) | Draft (synced) | `84b328e` | `3bc317b` | 8/8 PASS (`CI` `44875289855`: `completed/success`, `UI` `44875289799`: `completed/success`; prior `36d929d` 8/8 PASS) | *implemented*, *tested* (remains Draft; awaits pharmacist pack acceptance) |
| **PR `#293`** (Phase 62) | Draft | `3eb2253` | `79d81f0` | 0 TS errors, 332/332 PASS, PG17 PASS; `UI` [`44871070791`](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/44871070791) FAIL (Prettier only on 4 files) | *implemented*, partially *tested* (blocked on pinned `npx prettier --write`) |

## 3. P0 Dispense Authorization Boundary — Call Graph, ACLs & Status

- **Live Production Status:** **EXPOSED (OPEN).** `public.atomic_pharmacy_dispense` on `jewzonxplxhogqrnhosl` grants `authenticated=X` and checks only `pharmacy.update` + `billing.create` (Admin-class bypass). `private.app_has_claim_branch` and `private.sync_user_role_text` have `proacl = NULL` (`PUBLIC EXECUTE`).
- **Candidate Call Graph (PR `#250` `832a8d3` + PR `#260` `b963d7a`):**
  - `public.atomic_pharmacy_dispense(uuid,boolean,uuid)` (`SECURITY DEFINER SET search_path TO ''`) -> checks `private.app_has_role_permission(ARRAY['pharmacist'], 'pharmacy.update') AND private.app_has_role_permission(ARRAY['pharmacist'], 'billing.create')` -> delegates to `private.atomic_pharmacy_dispense_unchecked` (owner-only).
  - `public.fn_dispense_prescription_with_invoice(uuid,boolean)` -> same canonical `pharmacist` gate -> delegates to `private.fn_dispense_prescription_with_invoice_unchecked`.
  - **Explicit Policy:** `admin`, `super_admin`, `legacy_pharmacist`, `doctor`, `receptionist`, `lab_tech`, `anon`, and unauthenticated callers are all **DENIED (`42501`)**.
  - **Migration Dependency Chain:** 6-file ordered chain verified with exact SHA-256 checksums in `docs/CONTROLLED_RELEASE_DOSSIER_2026-11-21.md`.

## 4. PR `#210` Blocker-by-Blocker Disposition Table (Section 6)

| Blocker | Original Finding (Comment `7049299356` & Review) | Resolution / Action Taken | Exact Commit / Evidence | Residual Risk / Status |
| :--- | :--- | :--- | :--- | :--- |
| **B-01: Stale base** | Based on older `main` (`f8c8b2d`) | Non-destructively merged current `main` (`3bc317b`) with 0 conflicts | `36d929d` (8/8 CI PASS) | **Resolved** (*tested*) |
| **B-02: Pack size & dispensing unit** | Missing explicit commercial pack size / base dispensing unit | Added `pack_size numeric(10,2) CHECK (> 0)` and `dispensing_unit text` in Phase 60B SQL (`roshan_phase60b_medicine_pack_identity_and_duplicate_guard.sql`) | `84b328e` + `tests/phase60b-medicine-pack-identity.test.ts` | **Implemented & contract-tested**; UI editor fields & backfill pending |
| **B-03: Manufacturer & route** | Missing manufacturer and route identity dimensions | Added `manufacturer_name text` and `route text` on `public.medicines` | `84b328e` | **Implemented**; UI form wiring pending |
| **B-04: GTIN/barcode validation** | No GTIN/barcode format validation or uniqueness scope | Added `gtin_barcode text CHECK (~ '^[0-9]{8,14}$')` + `idx_medicines_active_gtin_unique` with explicit comment that GTIN never proves regulatory authenticity | `84b328e` | **Implemented**; scanner UI pending |
| **B-05: Duplicate detection** | No duplicate-detection key preventing exact duplicates without collapsing distinct strengths/forms | Added `private.normalize_medicine_identity_key(...)` + `idx_medicines_active_exact_identity_unique` across all 7 dimensions | `84b328e` | **Implemented**; PG17 duplicate-insert integration test recommended next |
| **B-06: Historical prescription safety** | Identity edits must not corrupt historical prescriptions/dispensing | Phase 60B is additive-only (`ADD COLUMN IF NOT EXISTS`); existing 9 Prod rows & historical joins untouched | `84b328e` | **Preserved** (*evidence-verified*) |
| **B-07: Pharmacist pack acceptance** | Human physical-pack verification cannot be automated | Explicitly preserved as separate human gate; PR `#210` kept **Draft** | Policy + PR `#210` Draft | **Owner / Pharmacist UAT required** |

## 5. PR `#293`, `#291`, `#292`, `#260`, `#294` & Cross-Phase Summary

- **PR `#293` (`3eb2253`):** 0 TS errors, 332/332 unit guard tests PASS, all PG17 Phase 62 integration, multi-visit invoice-isolation, and concurrency workflows PASS. Remaining blocker is strictly pinned `npx prettier --write` on 4 files (`src/lib/pharmacy-lifecycle.ts`, `src/routes/_authenticated/pharmacy.tsx`, `tests/phase39-permissions-and-schema-consistency.test.ts`, `tests/phase62-pharmacy-lifecycle-ui.test.ts`) because the remote sandbox has no `npx`/project `node_modules`.
- **PR `#291` (`804302f`, 8/8 PASS):** WHO ICD-10 Version 2019 (`coding_system = 'WHO-ICD-10'`, `coding_version = '2019'`, `coding_label_snapshot`); explicitly prohibits `ICD-10-CM` substitution; preserves legacy free-text diagnoses. UI syntax check is explicitly syntactic only, NOT clinical confirmation. *Clinically approved* = **PENDING**.
- **PR `#292` (`89763d2`, 8/8 PASS):** `PediatricSafetyPanel.tsx` wired into `PrescriptionTab.tsx` with explicit `mg/kg/dose` vs `mg/kg/day` selector, weight/route/concentration checks, manual clinician confirmation, and `protocol: null` activation lock. *Clinically approved* = **PENDING**.
- **PR `#260` (`b963d7a`, PASS) & PR `#294` (`88417c6`, 6/6 PASS):** Revalidated green; no regressions. Combined Phase `60 -> 62 -> 63` regression awaits `#293` Prettier pass and `#210` merge alignment.

## 6. Operational Readiness (Backup, Branch Protection, QA, Mobile/WCAG, Printer/Staff)

- **Backup & Restore (`#199`):** Live secrets metadata confirms `roshan-health-hub-backup-runner` has only `SUPABASE_ACCESS_TOKEN`; neither `SUPABASE_DB_ACCESS_TOKEN` nor `SUPABASE_DB_PASSWORD` exists -> run `43764265014` (2026-11-15) failed preflight. Last encrypted Drive archive: `roshan-production-backup-43183851731.zip` (2026-11-12, 305,284 bytes). Offline Android `age` decryption & fresh isolated restore rehearsal remain **NOT RUN / OWNER-BLOCKED**.
- **Branch Protection (`#253`):** Live API confirms `main` has `protected: False`, `required_status_checks.enforcement_level: off`.
- **QA Role Coverage (5/9 Active):** Live QA (`hopfohcnrtbiqjkgeukz`) has `admin` (1), `doctor` (1), `lab_tech` (1), `pharmacist` (1), `receptionist` (1). Missing 4: `super_admin`, `dentist`, `specialist`, `lab_doctor`/`lab_assistant`.
- **Authenticated E2E (27 screens) / Mobile (`320–430px`) / RTL-LTR / WCAG 2.2 AA / Printer / Staff UAT:** **0% executed live** (blocked by 4 missing QA accounts, preview SSO, and on-site physical hardware/staff).

## 7. Recalculated Progress & ETA (Explicit Rubric)

- **Track A — Engineering Completion: `79.5%`** (numerator `79.5 / 100` across 10 weighted workstreams: `#250` 12/12 green + SHA-256 dossier [9.5/10], `#260` green [10/10], `#294` 6/6 green [9.5/10], `#292` 8/8 green [9/10], `#291` 8/8 green [9/10], `#293` TS+PG17 green minus Prettier [7.5/10], `#210` synced + Phase 60B SQL/test [7/10], `#290` green [8/10], governance/provenance/dossier [10/10], combined 60->62->63 regression [0/10]).
- **Track B — Operational Readiness: `29.0%`** (numerator `29.0 / 100`: live catalog/provenance/ACL audit [15/20], Vercel non-deploy verification [5/5], historical Nov 12 archive + runner diagnosis [5/25], QA 5/9 roles [4/15], live authenticated E2E [0/15], mobile/RTL/WCAG [0/10], printer/staff/clinical UAT [0/10]).
- **ETA:** **Not reliably estimable** for Production Go-Live because remaining critical-path gates are owner-, clinician-, and on-site-dependent.

## 8. Consolidated Owner-Only Action List

1. **Backup Runner Secret & Restore Proof (`#199`):** Set **exactly one** of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD` in `roshan-health-hub-backup-runner`, run a fresh encrypted backup, and verify offline Android `age` decryption + isolated PG17 restore.
2. **Enable `main` Branch Protection (`#253`):** Protect `main` and require verified CI status checks.
3. **Run Pinned Prettier on PR `#293`:** Execute `npx prettier --write src/lib/pharmacy-lifecycle.ts src/routes/_authenticated/pharmacy.tsx tests/phase39-permissions-and-schema-consistency.test.ts tests/phase62-pharmacy-lifecycle-ui.test.ts`.
4. **Provision 4 Missing Synthetic QA Accounts:** Create `super_admin`, `dentist`, `specialist`, and `lab_doctor`/`lab_assistant` in QA (`hopfohcnrtbiqjkgeukz`).
5. **Independent 2nd Review & Controlled Production Release (`#250` / `#260`):** Review `docs/CONTROLLED_RELEASE_DOSSIER_2026-11-21.md`, confirm Super Admin exclusion policy, and authorize the 6-file Production migration window only after all preflight gates pass.
6. **Clinical, Printer & Staff Acceptance:** Qualified clinician approval for `#292` (Pediatric Safety) and `#291` (WHO ICD-10 2019), physical thermal/A4 printer verification, and real clinic staff UAT.
