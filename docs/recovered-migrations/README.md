# Recovered applied migration SQL — quarantine only

Recovered on 2026-10-15 from a read-only query against the live Supabase migration ledger for project `jewzonxplxhogqrnhosl`.

- These files reconstruct SQL statement strings stored in each ledger row, joined with blank lines. They are recovered artifacts, not original migration files byte-for-byte.
- The manifest preserves each ledger version/name and original ledger checksum/byte count.
- Migration `20260818191254_fix_patients_rls_and_admin_link.sql` contains an environment-specific admin email and user UUID in a one-time `users.auth_user_id` update. Its public file is **redacted**; the original identity literals are not reproduced in this public repository. Its ledger checksum and byte count refer to the original ledger row, while the public file intentionally differs.
- A basic scan found no common private-key or token patterns. This is not a complete secret/privacy audit.
- **Do not execute or move these files into `supabase/migrations` yet.** They have not been semantically reviewed against the current schema or replayed in a clean PostgreSQL/Supabase environment.
- This is a quarantine/recovery artifact only. Production was queried read-only; no SQL was applied and no data was changed.

Next gates: review migration bodies in order; compare to current `db/*.sql` artifacts; inspect environment-specific data and destructive assumptions; test full replay in disposable PostgreSQL 17; then test Supabase-specific auth/RLS/grants in an isolated Supabase environment before deciding on a canonical migration directory.


## Replay-safe policy-only variant for the redacted migration

- The original applied migration `20260818191254_fix_patients_rls_and_admin_link` remains redacted in the public source archive. Its one-time Auth-to-app-user identity mapping must not be restored to public source control.
- `replay-safe/20260818191254_fix_patients_rls_and_admin_link.sql` is a deliberately separate, non-canonical test variant. It removes the identity UPDATE entirely and preserves the four patient RLS policy changes. It includes no environment email or identity UUID.
- `db/tests/redacted_migration_policy_replay_fixture.sql` and `db/tests/redacted_migration_policy_replay_integration.sql` validate this policy portion on an isolated PostgreSQL 17 fixture through free GitHub Actions. The job passed on `ed1218e35121d9de08845fcc943fb8a3252717a6`.
- This does not reconstruct the missing pre-migration baseline and does not establish full-chain replay. Do not move the replay-only file into `supabase/migrations` or use it for production deployment.


## Final verification status — 2026-10-17

The replay-safe policy-only variant is covered by a synthetic PostgreSQL 17 integration test. CI verifies the four patient policy operations and confirms the replay variant contains no email/identity UUID and no identity UPDATE. Main SHA `ddf7d3b5b72d18bbfd13598472ce4db480c09bca` passed all 15 checks. The original migration remains redacted; the replay variant is not canonical deployment SQL and does not prove full-chain replay because the pre-migration baseline is still missing.

## Current parity scope — 2026-10-18

The adjacent `source-parity-report.json` is the **historical 93-entry snapshot** (92 normalized source matches, one redacted identity-link migration), generated before four later live-ledger entries were reconciled. The current live ledger has 97 entries and the latest `docs/DB_MIGRATION_RECONCILIATION.md` records 96/97 exact source matches, with zero unmapped versions. This recovered directory and its JSON report are not a replayable canonical migration chain. The pre-migration baseline is still missing, so full replay remains blocked.


## Phase 49–52 live provenance addendum — 2026-11-03

- A scoped read-only SHA-256 reconciliation is recorded in `phase49-52-provenance.json`. It covers the production Phase 49–52 migration rows, the two unmapped remediation rows, the superseded placeholder rows, and the corresponding QA rows. It is not a full 129-row migration-chain parity report.
- Production ledger statements for `20261102232823`, `20261102232849`, `20261102232852`, and `20261102232855` match their current `db/roshan_phase49...` through `db/roshan_phase52...` source files byte-for-byte after removing only the terminal `COMMIT;` wrapper and trailing whitespace.
- `20261102232819` has no canonical source file; its exact 223-byte table/index rename statement is preserved in the quarantine directory.
- `20261102232941` has no canonical source file and contains fixed production UUID literals. Its public artifact replaces all nine occurrences (four distinct identifiers) with invalid placeholders; the original ledger SHA-256 is retained, but the public copy is intentionally not byte-identical or executable.
- The four 134-byte production placeholder rows are not the Phase 49–52 SQL migrations. The private remediation archive contains one malformed pharmacy-idempotency row and four placeholder ledger rows, not the complete SQL bodies.
- Static review of `20261102232941` found a broad soft-delete sweep and a stock-reversal guard, but the SQL does not itself prove its fixed targets are synthetic. No patient/business rows were read to verify those targets.
- `manifest.json` remains the historical 79-row recovery snapshot from 2026-10-15; `source-parity-report.json` remains the historical 93-row snapshot from 2026-10-17. Do not treat either as a complete current ledger report.
- All recovered SQL in this directory is quarantine evidence only. Do not copy it into a migration directory, execute it, repair the migration ledger manually, or infer that backup/restore and authenticated clinical acceptance gates have passed.
