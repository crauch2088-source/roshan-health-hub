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

- 2026-10-15 follow-up: recovered all 79 SQL statement sets from the production ledger using read-only `SELECT`, joined statement strings with blank lines, and archived them under `docs/recovered-migrations/sql/` on draft PR [#26](https://github.com/crauch2088-source/roshan-health-hub/pull/26). Manifest preserves version/name and ledger MD5/byte counts. Total recovered SQL is 247,724 characters. A basic scan found no common private-key or token patterns, but follow-up review identified an environment-specific admin email and UUID in one one-time identity-linking update; the corresponding public archive file is redacted. This is not a complete secret/privacy audit. These are quarantine artifacts, not approved canonical migrations: no SQL was executed, and semantic diff, clean PostgreSQL replay, Supabase-specific RLS/auth validation, and review for destructive/data-dependent statements remain open.

- 2026-10-15 follow-up: performed a read-only exact-text comparison between 7 ledger migration bodies and same-name/likely `db/*.sql` artifacts, plus 4 additional name-related candidates. None of the 11 candidate pairs matched byte-for-byte after newline normalization. The candidate files may bundle multiple historical changes or differ in comments/formatting/content; this result is a proven exact-content mismatch, not yet a semantic equivalence judgment. Updated `docs/APPLIED_MIGRATION_INVENTORY.md` to record candidate paths and keep semantic diff/replay status unresolved. No historical SQL bodies were exported, committed, or executed.



- 2026-10-15 follow-up: Supabase branch inventory confirms only the production `main` branch exists; no disposable development branch is currently available. Supabase's current branch estimate for this organization is **US$0.01344/hour** (about **US$9.81/month** if left running continuously). Do not create the branch until the user explicitly confirms this cost. Until then, SQL integration tests remain a hard release gate and production stays unchanged.

- 2026-10-15 follow-up: a read-only pattern scan across all 79 stored SQL statement arrays found no matches for the checked credential-token patterns; the `service_role` hits were role identifiers in SQL, not evidence of a credential. One migration (`20260818191254_fix_patients_rls_and_admin_link`) contains an environment-specific admin email and UUID literal plus a one-time `users.auth_user_id` update. Several entries contain data-changing SQL. Do not publish or replay recovered SQL until each migration is individually reviewed for environment-bound values, data mutations, and replay safety. Exact-source recovery must not imply the original SQL is safe for a fresh environment. No source bodies were exported, committed, or executed.


## Read-only source comparison update — 2026-10-15

- Compared the live ledger `statements` for `roshan_phase12_invoice_visit_unique` with `db/roshan_phase12_invoice_visit_unique.sql`. Executable SQL matches after stripping comments and normalizing whitespace; comments differ. This mapping is now verified.
- For `roshan_phase2_clinical_workflow`, the ledger SQL is contained within the normalized repository file, but the file contains additional SQL; this is only a partial mapping, not a full content-parity claim.
- `roshan_phase1_pagination_and_settings`, `roshan_phase5_insurance`, and `roshan_cashbox_reversal_concurrency` did not normalize to exact or simple-subset matches in this comparison. Their source mappings remain unresolved pending statement-by-statement review.
- The comparison read only the production migration ledger and repository files. No production schema or data was changed.


- 2026-10-15 follow-up: a static operation scan of the 79 recovered SQL bodies found no `DROP TABLE`, `DELETE FROM`, or `ALTER TABLE ... DROP COLUMN` statements. The only `TRUNCATE` keyword is in migration `20260818234039_harden_rls_permissions_and_public_grants_v1`, where the SQL revokes the `TRUNCATE` privilege from `anon` and `authenticated`; it does not execute a truncate. Multiple `UPDATE`, `INSERT`, `DROP POLICY`, and `DROP FUNCTION` statements remain and require ordered semantic review before replay. This is a lexical scan, not proof of non-destructiveness.


## Semantic comparison log — 2026-10-15 (expanded verified cases)

### Applied ledger migration `20260819100756_roshan_phase1_pagination_and_settings`
- Compared the quarantined recovered ledger body with `db/roshan_phase1_pagination_and_settings.sql` after stripping SQL comments and normalizing whitespace.
- **Classification: partial match with material omissions in the repository candidate.** The recovered ledger body includes three standalone indexes not present in the candidate: `patients_mrn_idx`, `patients_phone_idx`, and `patients_national_id_idx`. The public-settings backfill is otherwise the same executable statement after whitespace normalization; the candidate has richer comments and a different statement layout.
- Do not treat the candidate as a complete replacement for the applied ledger body until the index difference is resolved against the live schema and earlier/later migrations.
- No SQL was executed; production was read-only.

### Applied ledger insurance migrations `20260909110657`, `20260909110735`, and `20260909110753`
- Compared the concatenated recovered statement sets (insurance schema, functions, and permissions/RLS) with `db/roshan_phase5_insurance.sql` after stripping comments and normalizing whitespace.
- **Classification: executable statement sets match under this normalization.** All normalized statements in each side had a counterpart on the other side; the repository artifact consolidates three timestamped ledger entries into one file and includes a transaction wrapper. This establishes statement-level source correspondence under the stated normalization, not safe replayability or approval to execute the bundle as a migration.
- Preserve the three original ledger versions as separate historical events; do not infer that the consolidated repository file should be replayed over the already-applied database.
- No SQL was executed; production was read-only.

### Applied ledger migration `20261014164131_roshan_cashbox_reversal_concurrency`
- Compared the recovered body with `db/roshan_phase4_cashbox_reversal_concurrency.sql`. After removing comments and normalizing whitespace, the executable statements match; the repository candidate additionally wraps the statements in `BEGIN`/`COMMIT` and has expanded formatting/comments.
- **Classification: executable-content match under comment/whitespace normalization, with a transaction-wrapper difference.** This does not establish safe replay against an existing database; the migration checks for duplicate `reversal_of` values and replaces a security-definer function, so schema/function state and execution context still require isolated validation.
- No SQL was executed; production was read-only.


### Applied finance migration `20260908210824_roshan_phase4_finance_v2`
- Compared function definitions by name between the recovered ledger body and `db/roshan_phase4_finance.sql`, stripping comments and normalizing whitespace/punctuation.
- All 14 functions defined in the recovered finance-v2 body are also present in the repository candidate. Thirteen function bodies match after normalization. The remaining difference is in `public.fn_ledger_post`: the recovered body specifies `ON CONFLICT (source_type, source_id) WHERE source_type IS NOT NULL AND source_id IS NOT NULL`, while the repository body specifies `WHERE source_id IS NOT NULL`.
- The repository's `uq_cashbox_source` partial unique index uses `WHERE source_id IS NOT NULL`. Under ordinary PostgreSQL unique-index NULL semantics, this predicate difference may not alter conflicts for rows with null `source_type`, but it is a real source-text difference and must not be silently classified as an exact function match. Confirm the deployed index predicate and intended null behavior before canonicalizing the history.
- The repository file also includes schema/table setup and additional statements beyond this single ledger entry, so this is function-level mapping, not whole-file equivalence. No SQL was executed; production was read-only.


### Applied security migration `20260911130749_harden_security_and_fk_indexes_20260911`
- Compared the recovered ledger body against the likely repository candidates `db/roshan_security_hardening.sql`, `db/roshan_phase4_finance.sql`, `db/roshan_security_privileged_role_guard.sql`, and `db/roshan_phase1_migration.sql` after comment/whitespace normalization.
- **Classification: partial mapping; statement-level equivalence is not established.** The recovered body contains a dynamic loop that changes `search_path` for public `SECURITY DEFINER` functions, explicit `ALTER FUNCTION` clauses for four named functions, cashbox/supplier policy cleanup and recreation, and a set of foreign-key indexes. The combined candidate files do not reproduce the same normalized statement set; some policies may be represented by later/consolidated definitions, so this is not proof that every unmatched statement is absent from the repository as a whole.
- Do not replay this ledger entry or declare it reconciled until the effective final policy definitions, function search paths, and index set are mapped across all later migrations and current repository artifacts.
- No SQL was executed; production was read-only.


### Applied concurrency migration `20260911133229_harden_mrn_invoice_number_concurrency`
- Compared both recovered function definitions with the baseline implementations in `db/roshan_phase1_migration.sql`.
- **Classification: confirmed function-level mismatch.** The recovered `next_mrn()` and `next_invoice_number()` take transaction-scoped advisory locks and compute the next numeric suffix using `MAX(...)`; the repository baseline uses `COUNT(*) + 1` and has no advisory lock. Under concurrent requests, the baseline can produce the same proposed number for multiple transactions and then fail against the unique constraints rather than allocating a number safely.
- The recovered function patch does not itself prove the live unique constraints are present; reconcile both the function bodies and the deployed `patients.mrn` / `invoices.invoice_number` uniqueness before replaying or editing the canonical baseline.
- No SQL was executed; production was read-only.


### Applied branch-isolation migration `20260911133255_enforce_branch_isolation_rls`
- Inspected the recovered body and searched the repository for `private.app_has_branch_access`. The recovered migration creates this `SECURITY DEFINER` helper with an empty `search_path`, then dynamically augments existing RLS policy `USING` and/or `WITH CHECK` expressions across 13 branch-scoped tables.
- **Classification: no exact repository source match found; effective-policy parity remains unresolved.** The likely `db/roshan_security_hardening.sql` candidate does not contain this helper or dynamic policy loop, and repository search found no exact `app_has_branch_access` occurrence. Other files may encode equivalent per-table conditions, so do not conclude every branch guard is absent without reviewing the effective policy set.
- This is a high-priority reconciliation gate because missing branch isolation can expose cross-branch patient and financial data. Verify current policies on a disposable/staging schema against each listed table before any release; do not run the recovered SQL on production as a shortcut.
- No SQL was executed; production was read-only.


### Applied RPC hardening migration `20260911131456_deep_audit_branch_isolation_rpc_hardening`
- Compared the recovered `public.post_invoice_payment` and `public.post_supplier_payment` definitions with their counterparts in `db/roshan_phase4_finance.sql`; both function bodies differ materially after normalization. The recovered definitions add branch authorization checks and outstanding-balance/overpayment guards (and preserve invoice-payment idempotency handling).
- The recovered migration also replaces `public.fn_dispense_prescription` with branch-aware, batch-aware dispensing logic, but no matching definition was found in the likely checked-in SQL candidates (`db/roshan_phase1_migration.sql`, finance, security hardening, and role-guard files).
- **Classification: high-priority partial mapping.** Verify the final deployed function definitions and locate or reconstruct the canonical source for dispensing before declaring pharmacy and finance hardening reconciled. Do not replay this patch on production as a shortcut.
- No SQL was executed; production was read-only.


### Applied privilege migration `20260911130812_restrict_security_definer_api_execution_20260911`
- The recovered migration dynamically revokes `EXECUTE` from `PUBLIC`, `anon`, and `authenticated` on every `SECURITY DEFINER` function in `public`, then grants `authenticated` execution to a specific allowlist of 14 application RPCs.
- The likely repository candidates do not contain this same global revoke-and-allowlist loop. `db/roshan_security_hardening.sql` grants a smaller set of helpers and hardens audit-log access; `db/roshan_security_privileged_role_guard.sql` is a different feature (triggers guarding the super-admin role), not a source equivalent for this privilege migration. Grants may be distributed across other SQL files, so effective privileges cannot be inferred from one file.
- **Classification: high-priority unresolved privilege mapping.** Build a signature-by-signature allowlist comparison against the current deployed catalog before changing canonical SQL; blindly replaying the broad revoke could break required RPC access, while missing the intended restrictions could expose privileged functions.
- No SQL was executed; production was read-only.


### Applied supplier-bill RPC migration `20261011080253_harden_supplier_bill_rpc_branch_and_search_path`
- Compared recovered `public.post_supplier_bill` with `db/roshan_phase4_finance.sql`.
- **Classification: confirmed material function mismatch.** The recovered body uses an empty `search_path`, validates positive subtotal and discount bounds, requires an active non-deleted supplier, resolves an active user's branch, and writes `branch_id`. The repository candidate uses `search_path = public`, does not validate the supplier or discount range (it clamps net amount to zero), and omits `branch_id` from the insert.
- **Important chronology:** this version requires a branch for super-admin too, but the later migration `20261011080524_preserve_super_admin_supplier_bill_compatibility` explicitly restores the ability for super-admin to create an unassigned bill when their branch is null. The final expected behavior must preserve all validation above while allowing `user_branch IS NULL` only for super-admin; the next section records that superseding behavior.
- No SQL was executed; production was read-only.

### Applied finance/pharmacy search-path migration `20261011080319_harden_finance_pharmacy_rpc_search_paths`
- The recovered migration sets `search_path = ''` on ten `SECURITY DEFINER` functions, including payment, claim, dispensing, cashbox, and expense RPCs.
- The repository finance candidate defines `post_invoice_payment` and `post_supplier_payment` with `search_path = public`, and no matching `fn_dispense_prescription` source was found in the likely candidates. This is a confirmed source mismatch; verify all ten deployed function signatures and preserve the empty-path hardening when updating canonical SQL.
- No SQL was executed; production was read-only.

### Applied clinical-child branch isolation migration `20261011080434_enforce_branch_isolation_on_clinical_child_tables`
- The recovered migration adds private helpers for visit, lab-result-item, and attachment branch access, then creates/updates RLS policies for `clinical_notes`, `diagnoses`, `vitals`, `lab_results`, and `attachments` based on their parent visit/order/patient branch.
- **Classification: no exact repository helper/policy source match found in the likely checked-in SQL candidates.** Equivalent direct predicates may exist elsewhere; compare the effective policies for all five tables before treating this as absent or reconciled.
- This remains a high-priority clinical privacy gate. No SQL was executed; production was read-only.


### Applied compatibility migration `20261011080524_preserve_super_admin_supplier_bill_compatibility`
- This later migration replaces `public.post_supplier_bill` again. It preserves the active-supplier check, positive subtotal, discount bounds, empty `search_path`, and branch assignment from the earlier hardening migration, while allowing `branch_id = NULL` for a super-admin whose own branch is unconfigured. Non-super-admins still require a configured branch.
- **Classification: final behavior is a two-step evolution, not the earlier migration alone.** The checked-in `db/roshan_phase4_finance.sql` baseline still differs materially: it omits branch assignment, supplier validation, and discount-range validation, and uses `search_path = public`. The canonical source should represent the final post-compatibility function, not the intermediate branch-required version.
- No SQL was executed; production was read-only.
