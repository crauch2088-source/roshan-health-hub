# Database Migration Reconciliation — Roshan Health Hub

Snapshot: 2026-10-15  
Production project ref: `jewzonxplxhogqrnhosl` (PostgreSQL 17.6, eu-west-1)

## Verified facts

- Supabase's migration ledger reports **79 applied migrations**. The newest entry is `20261014164131_roshan_cashbox_reversal_concurrency`.
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
2. **Capture source history.** Retrieve all 79 migration SQL files from the original migration source/CI artifacts/available Git history, and associate each ledger version with its exact SQL and checksum. Do not fabricate historical SQL from migration names.
3. **Compare, do not replay.** Compare historical migration files with the current schema, functions, policies, grants, triggers, constraints, and extensions. Record any missing source, drift, or superseded definitions. Treat function bodies and RLS policies as security-sensitive.
4. **Choose a baseline strategy after the comparison.**
   - Preferred: restore the original timestamped migration files in their original order, verifying they recreate a clean disposable database and that the final schema matches production.
   - If original migration SQL cannot be recovered: produce and review a schema-only baseline/snapshot from the verified production schema (no patient/business rows or secrets), document that the baseline represents the existing deployed schema, and establish a forward-only migration sequence after it. Prove clean-database replay in isolated PostgreSQL/Supabase before adopting it.
5. **Preserve the production ledger.** Never mark migrations applied, repair the migration ledger, or run historical DDL against production as a shortcut. Any ledger reconciliation requires an explicit, reviewed procedure and a recovery point.
6. **Validate in isolation.** Use a disposable PostgreSQL 17 environment for ordinary SQL contract tests; use an isolated Supabase environment for Supabase-specific behavior (auth roles, RLS, `auth.uid()`, grants, PostgREST schema cache, extensions). Do not assume a PostgreSQL fixture is a full substitute for Supabase.
7. **Gate PR #13 and #14.** After the migration source is canonical, apply each candidate to an isolated Supabase schema/project with current definitions, run SQL contract tests, inspect grants and function definitions, and verify rollback/recovery. Then obtain explicit production-release approval.

## Immediate next engineering task

Retrieve and inventory the actual 79 migration SQL sources. Build a reconciliation table with columns:

`version | migration_name | source_available | source_path | checksum | covered_by_repo_artifact | schema/function diff reviewed | clean replay status | notes`

Do not mark a row as covered based only on similar filenames. The migration count/name ledger is verified; full SQL parity is not yet verified.
