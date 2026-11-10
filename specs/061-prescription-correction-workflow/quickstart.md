# Quickstart: Prescription Correction Workflow

This is a candidate implementation plan. It does not authorize a hosted migration or clinical use.

## Local/disposable PostgreSQL 17

1. Start with the repository's canonical PostgreSQL 17 fixture and current baseline/forward migrations.
2. Apply the Phase 61 candidate migration only inside a disposable PostgreSQL 17 database.
3. Run the correction request integration script.
4. Run the two-session concurrency script and verify exactly one resolver commits.
5. Confirm no invoice, payment, cashbox or stock movement side effects.
6. Run the repository's focused Node source tests and full CI.

## Expected scenarios

- Pharmacist requests correction for an active unlinked item in a pending internal prescription.
- A retry returns the existing pending request.
- A same-branch responsible doctor sees and resolves the request.
- An unrelated same-branch doctor and wrong-branch doctor cannot read or resolve it.
- Rejection leaves the original order pending and all stock/financial state unchanged.
- Item replacement uses an explicit active catalogue ID and complete clinician-entered regimen.
- Cancel-and-reissue is atomic and leaves the old prescription history intact.
- External/cancelled/dispensed/deleted/stale prescriptions are rejected.
- Concurrent resolution commits once only.

## Hosted release

Do not apply to QA or Production until:
- independent SQL/security review passes;
- migration source/ledger and effective-catalog reconciliation is complete;
- backup and isolated restore are current and verified;
- a dedicated synthetic QA pharmacist and prescriber can be authorized safely;
- pharmacist/prescriber browser/mobile acceptance is recorded.
