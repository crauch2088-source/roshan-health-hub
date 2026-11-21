# Roshan Health Hub — QA Operational Blockers Remediation & Acceptance Report (2026-11-21)

## Scope & Environment Boundaries
- **Target QA Supabase:** `hopfohcnrtbiqjkgeukz` (`roshan-health-hub-qa`) — ONLY QA database touched.
- **Target QA Preview:** `https://roshan-health-ay58tt7s5-roshan45.vercel.app` (branch `qa/isolated-acceptance-20261023`, commit `d8f494be773ab766bf6781d4a8297a4d581153e7`).
- **Production Confirmation:** Production Supabase (`jewzonxplxhogqrnhosl`) and Production Vercel (`roshan-health-hub.vercel.app`) were **strictly untouched** (zero SQL writes, zero migrations, zero deployments, zero environment changes).
- **Security Note:** Temporary QA password (`Admin123456`) is weak, strictly for isolated QA accounts only, and must never be reused in Production or for real users.
- **Release Posture:** QA acceptance only — **NOT a Production readiness claim**.

## 1. Root Causes & Corrective Changes

| Priority | Defect | Verified Root Cause | Files / DB Objects Changed | Verification Status |
|---|---|---|---|---|
| **P0** | Visit creation failed with `visit branch must be active` (Reception) & failed silently (GP) | `private.phase47_visit_branch_attribution()` is intentionally `SECURITY INVOKER` (enforced by `phase47_queue_branch_assertions.sql`), while `public.branches` RLS policy `branches_select` restricted `SELECT` exclusively to `app_has_perm('admin.full')`, hiding the active branch `ROS-MAIN` (`274db95c-12f4-4d7b-a772-8228c572a692`) from non-admin staff. | `db/roshan_qa_operational_blockers_20261121.sql` (`branches_select` RLS updated to `app_has_perm('admin.full') OR private.app_has_branch_access(id)`); `src/routes/_authenticated/visits.tsx` (inline `ErrorBox` + localized error mapping). | **QA DB applied + QA Browser verified + Automated test verified** |
| **P1** | `/expenses` SQL error `date/time field value out of range: "2026-11-31"` | `expenses.tsx` hardcoded `.lte("expense_date", `${month}-31`)`, breaking Feb, Apr, Jun, Sep, and Nov. | `src/lib/medical.ts` (`monthDateRange()`), `src/routes/_authenticated/expenses.tsx` (half-open `.gte` / `.lt` next-month range). | **Implemented + Automated test verified** |
| **P1** | Patient duplicate registration allowed without warning + missing Address field on initial registration | `patients.tsx` had no duplicate check or address input, and `create_patient_atomic` accepted 5 params without `_address`. | `db/roshan_qa_operational_blockers_20261121.sql` (optional `_address text DEFAULT NULL`), `src/lib/patient-duplicate.ts`, `src/routes/_authenticated/patients.tsx` (normalized phone/name duplicate warning, explicit override checkbox, double-submit guard, address field). | **QA DB applied + Implemented + Automated test verified** |
| **P2** | Pharmacy raw backend errors (`medicine_stock_is_rpc_managed`, `pharmacy_batch_expiry_required`) & missing `*` on Expiry Date | `inventory.tsx` forwarded raw `error.message` to toast and omitted `*` on `expiry_date`. | `src/lib/error-messages.ts`, `src/routes/_authenticated/inventory.tsx`. | **Implemented + Automated test verified** |
| **P2** | Bilingual localization leaks (Arabic in English `/accounting` & role labels; raw keys `lab_revenue`, `stock_overview`, `stock_value`, lowercase `diagnosis`, `outstanding`) | Missing dictionary entries in `src/lib/i18n.tsx`, hardcoded Arabic strings in `accounting.tsx`, and raw Arabic `roles.name` rendered in `app-shell.tsx` and `dashboard.tsx`. | `src/lib/i18n.tsx` (+ `localizeRoleLabel`), `src/components/app-shell.tsx`, `src/routes/_authenticated/dashboard.tsx`, `src/routes/_authenticated/accounting.tsx`. | **Implemented + Automated test verified** |

## 2. Live QA Browser Verification Evidence (`https://roshan-health-ay58tt7s5-roshan45.vercel.app`)
- **Auth (5/5 Passed):** All 5 QA accounts (`reception`, `gp`, `lab`, `pharmacy`, `adminbilling`) logged in on 1st attempt after switching from feature branch preview to `qa/isolated-acceptance-20261023`.
- **Reception (Post-P0 Fix Passed):** Registered synthetic patient `مريض تجريبي QA-20261121` (`RMC000001`), edited address (`تعديل تجريبي QA`), created visit on `ROS-MAIN` with **zero** `visit branch must be active` error, auto-assigned queue ticket `Q1` (`Waiting`).
- **GP (Post-P0 Fix Passed):** Called & started `Q1` (`/clinic/ab7cc71b-4e25-4342-aafa-96b223802225`), saved clinical note (`QA E2E synthetic note`), WHO ICD-10 diagnosis (`J06.9` Acute upper respiratory infection), vitals (`120/80`, `78`, `37.2`, `98%`, `72 kg`), and prescription (`QA Test Paracetamol 500mg`, Qty `2`).
- **Pharmacy (Guard Verified):** Inventory add medicine + batch receive (`QA-BATCH-001`, 10 units, expiry `2026-12-12`) passed; dispensing of unlinked free-text prescription correctly failed closed (`prescription contains a free-text item that cannot be dispensed from pharmacy; link it to an active catalogue medicine first`), preserving stock at `10` and `0` spurious invoices.
- **Admin Audit Log (Passed):** `/audit` recorded `INSERT/UPDATE patients`, `INSERT/UPDATE visits`, `INSERT clinical_notes`, `INSERT diagnoses`, `INSERT vitals`, `INSERT prescriptions`, `INSERT prescription_items`, and `UPDATE users`.
- **Newly Discovered QA Blocker (Lab Catalogue):** Adding a synthetic lab test (`QA Synthetic CBC`) on `/lab-catalog` failed with `Could not find the 'normal_max' column of 'lab_tests' in the schema cache` because the older `qa/isolated-acceptance-20261023` frontend sends `normal_min`/`normal_max` columns absent from QA `lab_tests`.

## 3. Missing QA Roles & Responsive RTL/LTR Status
- **Canonical QA Roles Present (5):** `admin`, `doctor`, `lab_tech`, `pharmacist`, `receptionist`.
- **Missing QA Accounts (4):** `super_admin`, `dentist`, `specialist`, `lab_doctor`/`lab_assistant` (in `public.roles`, `dentist`, `specialist`, `lab_doctor`, `lab_assistant` exist only as `legacy_*` codes while `super_admin` is canonical).
- **Desktop RTL/LTR:** Verified clean mirroring on `/inventory` via header language toggle (`العربية` / `English`).
- **Mobile Viewports (320px / 360px / 390px / 430px):** Not verifiable in the managed browser environment (no viewport-resize control available); flagged transparently for owner mobile-device verification.
