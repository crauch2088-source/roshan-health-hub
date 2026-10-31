# Roshan UAT — Phase 46 schema compatibility

**Date:** 2026-10-31  
**Status:** Candidate prepared in source; not applied to QA or production.

## Field UAT evidence supplied by the operator

The live browser session reported successful Super Admin login, settings review, synthetic patient registration and MRN generation, outpatient visit creation with queue ticket, inventory listing, and real-time audit entries for patient and visit creation. These are operator-reported observations; this document does not claim independent replay of those authenticated actions.

The same session exposed two concrete PostgREST schema errors:
- Clinical consultation: `patients_1.allergies` does not exist.
- Pharmacy: `prescriptions.branch_id` does not exist.

## Independent read-only database verification

Projects inspected:
- Production: `jewzonxplxhogqrnhosl`, PostgreSQL 17.6.
- Isolated QA: `hopfohcnrtbiqjkgeukz`, PostgreSQL 17.11.

Both schemas lack `public.patients.allergies` and `public.prescriptions.branch_id`. Production's latest recorded migration is `20261020232033_roshan_phase39_permissions_lab_catalog_and_audit_closure` (ledger entry 115). QA has its isolated baseline/reconciliation ledger. The read-only prescription count was zero in both projects at inspection time. No business rows were read or changed by this inspection.

## Why the two-line patch is insufficient

Adding `prescriptions.branch_id uuid` alone would leave existing linked prescriptions unpopulated and future prescriptions without a reliable branch value: the current atomic prescription RPC inserts patient and visit links but does not explicitly write `branch_id`. The pharmacy screen selects this column, and Realtime also filters prescription events by branch.

## Phase 46 candidate

File: `db/roshan_phase46_uat_schema_compatibility.sql`

- Adds `patients.allergies text`; NULL continues to mean *not recorded*, not “no known allergies”.
- Adds nullable `prescriptions.branch_id uuid` and a foreign key to `branches(id)`.
- Preflights existing linked prescriptions. It aborts rather than guessing if a linked visit is missing, the patient does not match, or a non-null branch conflicts with the visit.
- Backfills only from the authoritative linked visit. Legacy unlinked prescriptions remain NULL rather than receiving an invented branch.
- Adds a private SECURITY DEFINER trigger function with empty search_path. New prescriptions must reference a live visit with a patient and non-null branch; the trigger derives branch_id and rejects patient/branch mismatches. Legacy unlinked rows may still receive non-identity updates but cannot be assigned an arbitrary branch.
- Adds a branch/status/created_at index for the pharmacy queue.
- Updates the generic missing-column/function error guidance so the UI no longer tells operators to rerun the old Phase 1 SQL file for every schema error.

## Regression coverage

Disposable PostgreSQL 17 fixture/assertions cover:
- Both columns and their expected types.
- Correct backfill for two branches and preservation of NULL for an unlinked legacy prescription.
- Valid new prescription inheriting the visit branch.
- Rejection of wrong branch, wrong patient, missing/deleted visit, and new unlinked prescription.
- Rejection of branch/patient reassignment.
- Legacy unlinked status update compatibility.
- FK, index, SECURITY DEFINER, fixed search_path, and browser-role EXECUTE revocation.

Dedicated workflow: `.github/workflows/ci-phase46-uat-schema-compatibility.yml`.

## Release boundary and retest

This is a forward candidate only. It must pass exact-head PostgreSQL 17 CI and code review before merge. It has **not** been applied to QA or production, and the current live database errors will persist until the approved migration is applied to the relevant database.

After production migration and deployment are confirmed, repeat only:
1. Open the affected visit in `/clinic`; verify allergies load as “not recorded” when NULL and the consultation renders without 42703.
2. Open `/pharmacy`; verify the prescription query returns without 42703 and the queue loads.
3. Create one synthetic prescription from a visit, confirm it appears in pharmacy, and confirm its branch attribution matches that visit.
4. Confirm the audit trail records the expected prescription mutation.

Do not create more patient/financial test rows, dispense medication, or modify inventory solely for this retest. Keep Issue #95 open until full staff acceptance is complete.
