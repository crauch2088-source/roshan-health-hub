# Phase 49 quarantined remediation fixture hardening — 2026-11-10

## Scope

This change strengthens only the disposable PostgreSQL 17 test-only equivalent in `db/tests/phase49_quarantine_remediation_fixture.sql`. It does not reconstruct, execute or claim equivalence to the unavailable original production SQL for migration `20261102232941`. The exact rename artifact `20261102232819` continues to run only inside the dedicated disposable `roshan_quarantine` database.

## Added negative coverage

- NULL and empty target arrays.
- Duplicate patient IDs and missing target patients.
- NULL medicine and reference identifiers.
- A matching +1 adjustment already present in the wrong branch.
- Duplicate matching adjustment rows.
- A same-branch reversal with stock still at the pre-reversal value.
- Stock already restored without its matching ledger reversal.

The test helper now counts matching adjustment rows, rejects duplicates, and rejects a wrong-branch matching reversal before it can create a second movement or soft-delete linked rows. It still accepts only the two explicit idempotent states: stock 49 with no matching reversal (perform the one-time synthetic correction), or stock 50 with exactly one same-branch matching reversal (no-op). All other states fail closed.

## Verification boundary

- All identifiers and records in the fixture are synthetic.
- The existing main CI job `Phase 49 quarantined remediation contracts (PostgreSQL 17)` replays the exact rename artifact and then tests the parameterized helper; it does not execute the redacted production cleanup SQL.
- No Supabase project, migration ledger, production row, QA row, patient record, stock record or invoice was changed.
- The fixture does not prove that the original redacted `20261102232941` statement was safe or that its fixed production targets were synthetic.

## Next

Continue the current source-to-ledger/effective-catalog reconciliation. Any future decision about the original cleanup migration requires owner review of its unavailable unredacted SQL; do not replay or reconstruct it from production data.
