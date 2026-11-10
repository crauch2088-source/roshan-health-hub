# Quickstart: Prescription Correction Workflow

Future isolated-QA path only; not permission to write to hosted QA or Production.

## Preconditions
1. Spec and authorization policy approved.
2. Candidate SQL reconciled with canonical schema and migration ledger.
3. Disposable PostgreSQL 17 fixture and synthetic pharmacist/original-prescriber identities exist.
4. No Production records or users are used.

## Pharmacist
1. Create synthetic patient, active visit and pending internal prescription with one linked and one free-text item.
2. Sign in as same-branch pharmacist (including strict branch equality for super-admin) with pharmacy.read/update.
3. Submit a correction request for the free-text item.
4. Retry same request key and verify same request id; submit a different key and verify one-open-request conflict.
5. Verify queue still blocks dispensing and no stock/invoice/ledger state changes.

## Prescriber
1. Sign in as the original prescribed_by doctor with emr.read/update.
2. Inspect request and immutable item snapshot.
3. Replace with an explicitly selected active catalogue medicine.
4. Verify resolved event with before/after snapshots; prescription remains pending.
5. Verify queue refreshes and revalidates every active item.

## Denial scenarios
Other doctor; pharmacist attempting resolution; admin/super-admin without original-prescriber identity; wrong branch; external/cancelled/dispensed/deleted prescription; linked/deleted item; inactive/deleted medicine; stale snapshot; concurrent dispense; invalid/empty cancel-and-reissue payload.

## Required evidence
Exact commit and PostgreSQL 17 workflow URL; all integration assertions pass with zero inventory/financial side effects; browser evidence on mobile/desktop in Arabic RTL and English LTR; authenticated QA acceptance.
