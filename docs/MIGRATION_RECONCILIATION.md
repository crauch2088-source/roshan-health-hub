# Database Migration Reconciliation — Roshan Health Hub

Snapshot: 2026-10-15  
Production project ref: `jewzonxplxhogqrnhosl` (PostgreSQL 17.6, eu-west-1)

## Verified facts

- Supabase's migration ledger reports **79 applied migrations**. The newest entry is `20261014164131_roshan_cashbox_reversal_concurrency`. Read-only inspection confirms every row has a non-empty `statements` array (one SQL statement per row), no missing migration names/statements, and approximately **247,724 characters of SQL** are recoverable directly from the live ledger. This is a viable exact-source recovery path, but does not by itself prove the recovered files replay cleanly or match the current schema.
- The `main` repository tree has **no `supabase/` directory** and therefore no canonical `supabase/migrations/*.sql` history.
- The committed `db/` directory instead contains a small set of phase/patch SQL files, including:
  - `roshan_phase1_migration.sql`
  - `roshan_phase1_pagination_and_settings.sql`
  - `roshan_phase2_clinical_workflow.sql`
  - `roshan_phase4_finance.sql`
  - `roshan_phase4_cashbox_reversal_concurrency.sql`
  - `roshan_phase4_finance_pharmacist_grant.sql`
  - `roshan_phase5_insurance.sql`
  - `roshan_phase12_invoice_visit_unique.sql`
  - `roshan_security_hardening.sql`
  - `roshan_security_privileged_role_guard.sql`
  - plus SQL tests under `db/tests/`.
- The listed SQL files are not a one-to-one representation of the 79 timestamped migration records. Some may bundle, supersede, or predate multiple applied migrations; file names alone cannot prove parity.
- Production was only inspected read-only during this reconciliation. No migration, schema change, data repair, or reset was executed.

## Risk

The current state is operational but not yet reproducible from the repository alone. A developer cannot safely infer which historical SQL has already been applied, which file supersedes another, or what order is safe. Applying the phase files blindly to production could repeat DDL, replace functions with older definitions, or alter live permissions/data.

## Safe reconciliation plan

1. **Freeze production DDL.** Do not apply PR #13 or PR #14 SQL to production until the canonical workflow is established. The PR #14 inventory UI depends on the new `receive_pharmacy_stock` RPC; deploying only one side would break stock receiving.
2. **Capture source history.** Export the exact `statements` array for each of the 79 ledger entries (confirmed present in the live ledger), associate each version with its SQL and checksum, and inspect it for unsafe hard-coded data or environment assumptions before committing recovered files. Do not fabricate historical SQL from migration names.
3. **Compare, do not replay.** Compare historical migration files with the current schema, functions, policies, grants, triggers, constraints, and extensions. Record any missing source, drift, or superseded definitions. Treat function bodies and RLS policies as security-sensitive.
4. **Choose a baseline strategy after the comparison.**
   - Preferred: restore the original timestamped migration files in their original order, verifying they recreate a clean disposable database and that the final schema matches production.
   - If original migration SQL cannot be recovered: produce and review a schema-only baseline/snapshot from the verified production schema (no patient/business rows or secrets), document that the baseline represents the existing deployed schema, and establish a forward-only migration sequence after it. Prove clean-database replay in isolated PostgreSQL/Supabase before adopting it.
5. **Preserve the production ledger.** Never mark migrations applied, repair the migration ledger, or run historical DDL against production as a shortcut. Any ledger reconciliation requires an explicit, reviewed procedure and a recovery point.
6. **Validate in isolation.** Use a disposable PostgreSQL 17 environment for ordinary SQL contract tests; use an isolated Supabase environment for Supabase-specific behavior (auth roles, RLS, `auth.uid()`, grants, PostgREST schema cache, extensions). Do not assume a PostgreSQL fixture is a full substitute for Supabase.
7. **Gate PR #13 and #14.** After the migration source is canonical, apply each candidate to an isolated Supabase schema/project with current definitions, run SQL contract tests, inspect grants and function definitions, and verify rollback/recovery. Then obtain explicit production-release approval.

## Immediate next engineering task

The SQL source is recoverable from the live ledger, so the next step is to export it into a quarantined review artifact, scan it, and compare it with the current schema and `db/*.sql` content before deciding whether to commit timestamped files. Build a reconciliation table with columns:

`version | migration_name | source_available | source_path | checksum | covered_by_repo_artifact | schema/function diff reviewed | clean replay status | notes`

Do not mark a row as covered based only on similar filenames. The migration count/name ledger is verified; exact SQL statements are present in the live ledger, but repository mapping, safety review, replayability, and schema parity are not yet verified.

- 2026-10-15 follow-up: added a read-only byte-length and MD5 inventory for all 79 ledger `statements` values in `docs/APPLIED_MIGRATION_INVENTORY.md`. The checksum is over the stored JSON representation, not normalized SQL. This improves source-recovery verification but does not establish repository parity, safety, or replayability. No SQL bodies were exported or committed and no database writes were performed.

- 2026-10-15 follow-up: recovered all 79 SQL statement sets from the production ledger using read-only `SELECT`, joined statement strings with blank lines, and archived them under `docs/recovered-migrations/sql/` on draft PR [#26](https://github.com/crauch2088-source/roshan-health-hub/pull/26). Manifest preserves version/name and ledger MD5/byte counts. Total recovered SQL is 247,724 characters. A basic pattern scan found no matches for common private-key/token/literal-secret or hard-coded contact assignment patterns; this is not a complete secret audit. These are quarantine artifacts, not approved canonical migrations: no SQL was executed, and semantic diff, clean PostgreSQL replay, Supabase-specific RLS/auth validation, and review for destructive/data-dependent statements remain open.

- 2026-10-15 follow-up: performed a read-only exact-text comparison between 7 ledger migration bodies and same-name/likely `db/*.sql` artifacts, plus 4 additional name-related candidates. None of the 11 candidate pairs matched byte-for-byte after newline normalization. The candidate files may bundle multiple historical changes or differ in comments/formatting/content; this result is a proven exact-content mismatch, not yet a semantic equivalence judgment. Updated `docs/APPLIED_MIGRATION_INVENTORY.md` to record candidate paths and keep semantic diff/replay status unresolved. No historical SQL bodies were exported, committed, or executed.



- 2026-10-15 follow-up: Supabase branch inventory confirms only the production `main` branch exists; no disposable development branch is currently available. Supabase's current branch estimate for this organization is **US$0.01344/hour** (about **US$9.81/month** if left running continuously). Do not create the branch until the user explicitly confirms this cost. Until then, SQL integration tests remain a hard release gate and production stays unchanged.

- 2026-10-15 follow-up: a read-only pattern scan across all 79 stored SQL statement arrays found no matches for the checked credential-token patterns; the `service_role` hits were role identifiers in SQL, not evidence of a credential. One migration (`20260818191254_fix_patients_rls_and_admin_link`) contains an environment-specific admin email and UUID literal plus a one-time `users.auth_user_id` update. Several entries contain data-changing SQL. Do not publish or replay recovered SQL until each migration is individually reviewed for environment-bound values, data mutations, and replay safety. Exact-source recovery must not imply the original SQL is safe for a fresh environment. No source bodies were exported, committed, or executed.


## Read-only source comparison update — 2026-10-15

- Compared the live ledger `statements` for `roshan_phase12_invoice_visit_unique` with `db/roshan_phase12_invoice_visit_unique.sql`. Executable SQL matches after stripping comments and normalizing whitespace; comments differ. This mapping is now verified.
- For `roshan_phase2_clinical_workflow`, the ledger SQL is contained within the normalized repository file, but the file contains additional SQL; this is only a partial mapping, not a full content-parity claim.
- `roshan_phase1_pagination_and_settings`, `roshan_phase5_insurance`, and `roshan_cashbox_reversal_concurrency` did not normalize to exact or simple-subset matches in this comparison. Their source mappings remain unresolved pending statement-by-statement review.
- The comparison read only the production migration ledger and repository files. No production schema or data was changed.
