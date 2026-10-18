## Current live ledger state — 2026-10-18 08:00 UTC

- Connected production project `jewzonxplxhogqrnhosl` is ACTIVE_HEALTHY on PostgreSQL 17.6. The live migration ledger remains **109 entries**, latest `20261018065708_roshan_clinical_child_rpc_only_writes`.
- Phase 29 is confirmed live: authenticated direct INSERT/UPDATE/DELETE is denied on `prescriptions`, `prescription_items`, `patient_discounts`, and `insurance_prior_authorizations`; SELECT remains granted and RLS is enabled.
- Phase 30 is still staged. `lab_order_items` and `medical_certificates` retain authenticated direct INSERT/UPDATE/DELETE/REFERENCES/TRIGGER; `anon` has no SELECT or write grants. `complete_lab_order_item(uuid)` and `create_medical_certificate(uuid,text,date,date)` are SECURITY DEFINER with fixed empty `search_path`, executable by authenticated and not anon.
- Clinical PostgreSQL 17 regression passed on commit `84c3d1fcef1c6213367e59103204d9c0403fc7d5`. Workflow push filters now include both RPC frontend routes and their contract tests. Documentation updates are on current main after that commit; verify the current SHA/checks before future release actions.
- Canonical production alias `https://roshan-health-hub.vercel.app/` remains READY on older deployment commit `631abf83415b2c878569d34df1360936f5a9d158`. Vercel rejected a pinned deployment with HTTP 402 `api-deployments-free-per-day` and retry-after 86,400 seconds. Do not apply Phase 30 until current-main deployment is verified and both workflows pass synthetic-data smoke tests.
- Security Advisor shows one extension-in-public warning, 22 authenticated-callable SECURITY DEFINER warnings, and Performance Advisor shows 89 unused-index findings. These are not authorization to bulk-revoke functions, move `pg_trgm`, or drop indexes. Classify each item and add behavior regression coverage before any privilege/schema/index change.
- Full historical replay and persisted live SQL hash parity remain unproven; `live_sql_hash_verified=false` must remain explicit where live SQL cannot be read back.

---

## Current live ledger state — 2026-10-18 07:20 UTC

The connected live Supabase ledger has **109 rows**, latest `20261018065708_roshan_clinical_child_rpc_only_writes`. The forward-source delta contains **16 mappings** above the frozen 93-row historical snapshot. The verifier checks repository-source/blob hashes and version mappings; it does **not** query persisted SQL hashes from Supabase. Full historical replay remains unproven because the reviewed initial-schema baseline is missing and one environment-specific identity-link migration remains deliberately redacted.

### Current read-back and rollout state

- **56/56** public base tables have RLS enabled; **44/56** also force RLS. **Zero** public base tables grant SELECT, INSERT, UPDATE, or DELETE to `anon`.
- The catalog contains **47 public + 34 private SECURITY DEFINER routines**; all 81 have an explicit fixed `search_path`. No public SECURITY DEFINER routine is executable by `anon`. Two private helpers inherit PUBLIC EXECUTE, but `anon` lacks `USAGE` on the `private` schema; one helper is required by authenticated branch-aware RLS policies and the other is trigger-only.
- Phase 28 RPCs are live with fixed empty `search_path`, branch/permission guards, and authenticated-only execution. Phase 29 is live as `20261018065708_roshan_clinical_child_rpc_only_writes`; direct DML is revoked on `prescriptions`, `prescription_items`, `patient_discounts`, and `insurance_prior_authorizations`. SELECT remains available, RLS remains enabled, and the four tables were empty before/after.
- Finance read-back confirms authenticated direct INSERT/UPDATE/DELETE is denied on `cashbox_transactions` and `payments`; INSERT is denied on `expenses`, `supplier_bills`, and `supplier_payments`. The validated cashbox, invoice-payment, and supplier-bill RPCs remain executable by `authenticated`, not `anon`; the legacy `add_cashbox_entry` is executable by neither browser role. The live invoice-payment function retains its two-decimal precision guard. The Phase 27 finance RPC-only migration remains a source/test candidate and was **not applied** to production.
- PR #77 merged as `8530995f8560e2cd050a5e12ea1e1b3cb59ce57f` after its exact-head checks passed. It adds source/test hardening and a two-session invoice-payment idempotency regression; no production SQL or business rows were changed by that PR. The applied security-candidate bundle source was amended to retain the current invoice precision guard for replay. The manifest records repository source hashes only: `live_sql_hash_verified=false` remains explicit, so this is **not proof** that the amended bundle equals the historical SQL originally applied. Do not apply the candidate bundle to production again.
- Phase 30 remains deployment-gated: authenticated direct writes to `lab_order_items` and `medical_certificates` remain temporarily available until the current-main RPC frontend is deployed to `https://roshan-health-hub.vercel.app/` and lab completion/certificate creation are smoke-tested. The canonical alias still points to a deployment predating the current-main frontend; Vercel's free API deployment quota resets **2026-10-19 08:52 Africa/Khartoum**, with a one-time continuation task scheduled for **09:00**. No preview environment was promoted.

---

# Historical Supabase migration reconciliation inventory (snapshot 2026-10-17)


**Historical snapshot date:** 2026-10-17  
**Target:** Connected Roshan Health Hub Supabase project (read-only inventory)  
**Applied migration rows in the original snapshot:** 93 (historical; see the current 105-entry ledger summary above)  
**Latest migration in original snapshot:** `20261016222009_roshan_phase25_current_app_profile_20261016`; current live latest is `20261017125936_roshan_insurance_coverage_validity_20261017`.  
**Top-level migration SQL files in `db/` on `main`:** 26  
**Exact basename matches among the 26 top-level `db/` candidates:** 4  
**Normalized source-content matches in the original 93-row snapshot:** 92; current live delta adds four exact source matches for 96 of 97 total entries, with 1 intentionally redacted environment-specific identity mapping and 0 unmapped versions.  
These are distinct measures: basename matching counts names in the top-level directory, while `docs/recovered-migrations/source-parity-report.json` records the per-version content-hash comparison across the timestamped recovery directory and `db/`. The text-level normalization ignores comments and whitespace and is not a SQL-parser semantic proof. No migration was applied, rolled back, or edited in the database during this inventory.

## Purpose and safety

This file records the live migration version/name list so source reconciliation can proceed deterministically. It is not a replayable migration chain and must not be used to bootstrap a new database. The `main` branch has no `supabase/` directory, so the current repo layout does not provide a canonical timestamped migration sequence. A same-name SQL file is only a candidate source until its full content is compared with the deployed migration effects.

Do not reconstruct missing migrations from guessed SQL, do not mark partial filename matches as exact, and do not test replay against production. Recover exact source content from Git history, deployment artifacts, or Supabase migration history where available; then validate the ordered chain in a disposable environment.

## Live applied migration inventory

| Live version | Live migration name | Repository mapping |
|---|---|---|
| 20260818162003 | `fix_duplicate_unique_constraint` | Normalized text match: `docs/recovered-migrations/sql/20260818162003_fix_duplicate_unique_constraint.sql` |
| 20260818191254 | `fix_patients_rls_and_admin_link` | Intentionally redacted placeholder: `docs/recovered-migrations/sql/20260818191254_fix_patients_rls_and_admin_link.sql` (identity-specific UPDATE omitted) |
| 20260818191556 | `install_safe_visit_number_function` | Normalized text match: `docs/recovered-migrations/sql/20260818191556_install_safe_visit_number_function.sql` |
| 20260818192452 | `fix_daily_queue_numbers_v4` | Normalized text match: `docs/recovered-migrations/sql/20260818192452_fix_daily_queue_numbers_v4.sql` |
| 20260818194104 | `fix_daily_queue_numbering` | Normalized text match: `docs/recovered-migrations/sql/20260818194104_fix_daily_queue_numbering.sql` |
| 20260818194429 | `repair_queue_and_harden_queue_security` | Normalized text match: `docs/recovered-migrations/sql/20260818194429_repair_queue_and_harden_queue_security.sql` |
| 20260818194457 | `consolidate_queue_triggers` | Normalized text match: `docs/recovered-migrations/sql/20260818194457_consolidate_queue_triggers.sql` |
| 20260818195753 | `fix_visit_queue_numbering` | Normalized text match: `docs/recovered-migrations/sql/20260818195753_fix_visit_queue_numbering.sql` |
| 20260818195811 | `sync_existing_queue_tickets` | Normalized text match: `docs/recovered-migrations/sql/20260818195811_sync_existing_queue_tickets.sql` |
| 20260818200206 | `fix_queue_numbering_authoritative` | Normalized text match: `docs/recovered-migrations/sql/20260818200206_fix_queue_numbering_authoritative.sql` |
| 20260818200246 | `harden_visit_queue_rls_and_cleanup` | Normalized text match: `docs/recovered-migrations/sql/20260818200246_harden_visit_queue_rls_and_cleanup.sql` |
| 20260818200336 | `finalize_non_recycling_queue_allocator` | Normalized text match: `docs/recovered-migrations/sql/20260818200336_finalize_non_recycling_queue_allocator.sql` |
| 20260818202356 | `fix_appointments_rls_auth_and_audit` | Normalized text match: `docs/recovered-migrations/sql/20260818202356_fix_appointments_rls_auth_and_audit.sql` |
| 20260818232848 | `harden_core_indexes_and_legacy_compatibility_v2` | Normalized text match: `docs/recovered-migrations/sql/20260818232848_harden_core_indexes_and_legacy_compatibility_v2.sql` |
| 20260818233558 | `harden_security_definer_helpers_and_duplicate_index_v2` | Normalized text match: `docs/recovered-migrations/sql/20260818233558_harden_security_definer_helpers_and_duplicate_index_v2.sql` |
| 20260818234039 | `harden_rls_permissions_and_public_grants_v1` | Normalized text match: `docs/recovered-migrations/sql/20260818234039_harden_rls_permissions_and_public_grants_v1.sql` |
| 20260818234050 | `harden_services_rls_v1` | Normalized text match: `docs/recovered-migrations/sql/20260818234050_harden_services_rls_v1.sql` |
| 20260818234146 | `repair_roshan_rbac_role_links_v1` | Normalized text match: `docs/recovered-migrations/sql/20260818234146_repair_roshan_rbac_role_links_v1.sql` |
| 20260819000003 | `harden_public_defaults_and_sync_user_roles` | Normalized text match: `docs/recovered-migrations/sql/20260819000003_harden_public_defaults_and_sync_user_roles.sql` |
| 20260819000016 | `tighten_public_default_privileges` | Normalized text match: `docs/recovered-migrations/sql/20260819000016_tighten_public_default_privileges.sql` |
| 20260819100756 | `roshan_phase1_pagination_and_settings` | Normalized text match: `docs/recovered-migrations/sql/20260819100756_roshan_phase1_pagination_and_settings.sql` |
| 20260819105146 | `roshan_settings_public_enforcement` | Normalized text match: `docs/recovered-migrations/sql/20260819105146_roshan_settings_public_enforcement.sql` |
| 20260819123920 | `grant_authenticated_execute_next_mrn` | Normalized text match: `docs/recovered-migrations/sql/20260819123920_grant_authenticated_execute_next_mrn.sql` |
| 20260819124045 | `fix_next_mrn_rpc_access` | Normalized text match: `docs/recovered-migrations/sql/20260819124045_fix_next_mrn_rpc_access.sql` |
| 20260819125755 | `add_missing_audit_relationships` | Normalized text match: `docs/recovered-migrations/sql/20260819125755_add_missing_audit_relationships.sql` |
| 20260819125807 | `add_followups_users_computed_relationship` | Normalized text match: `docs/recovered-migrations/sql/20260819125807_add_followups_users_computed_relationship.sql` |
| 20260819130039 | `compat_patients_patient_number` | Normalized text match: `docs/recovered-migrations/sql/20260819130039_compat_patients_patient_number.sql` |
| 20260819222434 | `add_prescription_ux_fields` | Normalized text match: `docs/recovered-migrations/sql/20260819222434_add_prescription_ux_fields.sql` |
| 20260819223342 | `add_medical_certificates_soft_delete_columns` | Normalized text match: `docs/recovered-migrations/sql/20260819223342_add_medical_certificates_soft_delete_columns.sql` |
| 20260820000007 | `add_medicines_2_stock_quantity_compatibility` | Normalized text match: `docs/recovered-migrations/sql/20260820000007_add_medicines_2_stock_quantity_compatibility.sql` |
| 20260820000143 | `add_medicines_2_stock_quantity` | Normalized text match: `docs/recovered-migrations/sql/20260820000143_add_medicines_2_stock_quantity.sql` |
| 20260820000336 | `fix_medicines_stock_quantity_schema_cache` | Normalized text match: `docs/recovered-migrations/sql/20260820000336_fix_medicines_stock_quantity_schema_cache.sql` |
| 20260820000656 | `add_medicines_reorder_level` | Normalized text match: `docs/recovered-migrations/sql/20260820000656_add_medicines_reorder_level.sql` |
| 20260820000725 | `add_medicines_expiry_date` | Normalized text match: `docs/recovered-migrations/sql/20260820000725_add_medicines_expiry_date.sql` |
| 20260820005417 | `fix_followups_user_relationship` | Normalized text match: `docs/recovered-migrations/sql/20260820005417_fix_followups_user_relationship.sql` |
| 20260820010030 | `fix_medicines_batch_number` | Normalized text match: `docs/recovered-migrations/sql/20260820010030_fix_medicines_batch_number.sql` |
| 20260820150215 | `roshan_phase2_clinical_workflow` | Normalized text match: `docs/recovered-migrations/sql/20260820150215_roshan_phase2_clinical_workflow.sql` |
| 20260822094358 | `roshan_workflow_performance_20260822` | Normalized text match: `docs/recovered-migrations/sql/20260822094358_roshan_workflow_performance_20260822.sql` |
| 20260822094405 | `roshan_drop_duplicate_prescription_index_20260822` | Normalized text match: `docs/recovered-migrations/sql/20260822094405_roshan_drop_duplicate_prescription_index_20260822.sql` |
| 20260906142737 | `roshan_phase3_allow_pharmacy_setting_public` | Normalized text match: `docs/recovered-migrations/sql/20260906142737_roshan_phase3_allow_pharmacy_setting_public.sql` |
| 20260906142803 | `roshan_phase3_pharmacy_batches` | Normalized text match: `docs/recovered-migrations/sql/20260906142803_roshan_phase3_pharmacy_batches.sql` |
| 20260906144008 | `roshan_phase4_finance_cashbox_debts` | Normalized text match: `docs/recovered-migrations/sql/20260906144008_roshan_phase4_finance_cashbox_debts.sql` |
| 20260906161023 | `roshan_phase4_finance_security_verification_patch` | Normalized text match: `docs/recovered-migrations/sql/20260906161023_roshan_phase4_finance_security_verification_patch.sql` |
| 20260906203143 | `roshan_phase3_pharmacy_runtime_hardening` | Normalized text match: `docs/recovered-migrations/sql/20260906203143_roshan_phase3_pharmacy_runtime_hardening.sql` |
| 20260908210824 | `roshan_phase4_finance_v2` | Normalized text match: `docs/recovered-migrations/sql/20260908210824_roshan_phase4_finance_v2.sql` |
| 20260909110657 | `roshan_phase5_insurance` | Normalized text match: `docs/recovered-migrations/sql/20260909110657_roshan_phase5_insurance.sql` |
| 20260909110735 | `roshan_phase5_insurance_functions` | Normalized text match: `docs/recovered-migrations/sql/20260909110735_roshan_phase5_insurance_functions.sql` |
| 20260909110753 | `roshan_phase5_insurance_permissions_rls` | Normalized text match: `docs/recovered-migrations/sql/20260909110753_roshan_phase5_insurance_permissions_rls.sql` |
| 20260911120231 | `roshan_phase12_invoice_visit_unique` | Normalized text match: `docs/recovered-migrations/sql/20260911120231_roshan_phase12_invoice_visit_unique.sql` |
| 20260911130749 | `harden_security_and_fk_indexes_20260911` | Normalized text match: `docs/recovered-migrations/sql/20260911130749_harden_security_and_fk_indexes_20260911.sql` |
| 20260911130812 | `restrict_security_definer_api_execution_20260911` | Normalized text match: `docs/recovered-migrations/sql/20260911130812_restrict_security_definer_api_execution_20260911.sql` |
| 20260911131456 | `deep_audit_branch_isolation_rpc_hardening` | Normalized text match: `docs/recovered-migrations/sql/20260911131456_deep_audit_branch_isolation_rpc_hardening.sql` |
| 20260911133229 | `harden_mrn_invoice_number_concurrency` | Normalized text match: `docs/recovered-migrations/sql/20260911133229_harden_mrn_invoice_number_concurrency.sql` |
| 20260911133255 | `enforce_branch_isolation_rls` | Normalized text match: `docs/recovered-migrations/sql/20260911133255_enforce_branch_isolation_rls.sql` |
| 20260911133312 | `harden_insurance_branch_isolation` | Normalized text match: `docs/recovered-migrations/sql/20260911133312_harden_insurance_branch_isolation.sql` |
| 20260911133319 | `harden_insurance_coverage_rpc_branch` | Normalized text match: `docs/recovered-migrations/sql/20260911133319_harden_insurance_coverage_rpc_branch.sql` |
| 20260911133334 | `harden_finance_branch_context` | Normalized text match: `docs/recovered-migrations/sql/20260911133334_harden_finance_branch_context.sql` |
| 20260911133353 | `fix_insurance_ledger_branch` | Normalized text match: `docs/recovered-migrations/sql/20260911133353_fix_insurance_ledger_branch.sql` |
| 20260911134639 | `grant_next_invoice_number_authenticated` | Normalized text match: `docs/recovered-migrations/sql/20260911134639_grant_next_invoice_number_authenticated.sql` |
| 20260911135036 | `grant_stock_movements_authenticated_access` | Normalized text match: `docs/recovered-migrations/sql/20260911135036_grant_stock_movements_authenticated_access.sql` |
| 20260911135318 | `fix_dispense_prescription_nullable_join_lock` | Normalized text match: `docs/recovered-migrations/sql/20260911135318_fix_dispense_prescription_nullable_join_lock.sql` |
| 20260911135417 | `fix_dispense_prescription_branch_resolution` | Normalized text match: `docs/recovered-migrations/sql/20260911135417_fix_dispense_prescription_branch_resolution.sql` |
| 20260911135547 | `fix_dispense_batch_number_ambiguity` | Normalized text match: `docs/recovered-migrations/sql/20260911135547_fix_dispense_batch_number_ambiguity.sql` |
| 20260911135644 | `add_medicines_updated_at_column` | Normalized text match: `docs/recovered-migrations/sql/20260911135644_add_medicines_updated_at_column.sql` |
| 20260911135738 | `add_prescription_items_updated_at` | Normalized text match: `docs/recovered-migrations/sql/20260911135738_add_prescription_items_updated_at.sql` |
| 20260911135858 | `add_prescriptions_updated_at` | Normalized text match: `docs/recovered-migrations/sql/20260911135858_add_prescriptions_updated_at.sql` |
| 20260911140337 | `add_cashbox_reversal_columns` | Normalized text match: `docs/recovered-migrations/sql/20260911140337_add_cashbox_reversal_columns.sql` |
| 20260911140514 | `allow_cashbox_reversal_transaction_type` | Normalized text match: `docs/recovered-migrations/sql/20260911140514_allow_cashbox_reversal_transaction_type.sql` |
| 20260911141036 | `harden_cashbox_reversal_type` | Normalized text match: `docs/recovered-migrations/sql/20260911141036_harden_cashbox_reversal_type.sql` |
| 20260911141142 | `fix_payment_ledger_transaction_type` | Normalized text match: `docs/recovered-migrations/sql/20260911141142_fix_payment_ledger_transaction_type.sql` |
| 20260911141502 | `fix_medicines_generic_name_compatibility` | Normalized text match: `docs/recovered-migrations/sql/20260911141502_fix_medicines_generic_name_compatibility.sql` |
| 20261011074344 | `harden_patient_invoice_number_rpc_permissions` | Normalized text match: `docs/recovered-migrations/sql/20261011074344_harden_patient_invoice_number_rpc_permissions.sql` |
| 20261011074437 | `harden_insurance_coverage_rpc_permissions` | Normalized text match: `docs/recovered-migrations/sql/20261011074437_harden_insurance_coverage_rpc_permissions.sql` |
| 20261011075101 | `harden_pharmacy_batch_branch_isolation` | Normalized text match: `docs/recovered-migrations/sql/20261011075101_harden_pharmacy_batch_branch_isolation.sql` |
| 20261011080253 | `harden_supplier_bill_rpc_branch_and_search_path` | Normalized text match: `docs/recovered-migrations/sql/20261011080253_harden_supplier_bill_rpc_branch_and_search_path.sql` |
| 20261011080319 | `harden_finance_pharmacy_rpc_search_paths` | Normalized text match: `docs/recovered-migrations/sql/20261011080319_harden_finance_pharmacy_rpc_search_paths.sql` |
| 20261011080434 | `enforce_branch_isolation_on_clinical_child_tables` | Normalized text match: `docs/recovered-migrations/sql/20261011080434_enforce_branch_isolation_on_clinical_child_tables.sql` |
| 20261011080524 | `preserve_super_admin_supplier_bill_compatibility` | Normalized text match: `docs/recovered-migrations/sql/20261011080524_preserve_super_admin_supplier_bill_compatibility.sql` |
| 20261014164131 | `roshan_cashbox_reversal_concurrency` | Normalized text match: `docs/recovered-migrations/sql/20261014164131_roshan_cashbox_reversal_concurrency.sql` |


## Full live-ledger SQL source comparison — 2026-10-17

A read-only comparison was run against the current connected Supabase migration API and the tracked source tree on `main`.

- Retrieved all **93/93** applied migration records and their exact stored SQL statement bodies from the Supabase migration-history API; no database mutation was performed.
- Inspected **105 tracked migration-source SQL files**: 79 timestamped recovered historical files under `docs/recovered-migrations/sql/` plus 26 top-level migration candidates under `db/`. Test fixtures were excluded from source matching.
- A conservative text comparison that ignores SQL comments and whitespace found **92/93 normalized source matches**. There were **zero completely unmapped ledger entries**. The 79 historical versions have timestamped recovered-source paths; later applied versions were matched against current `db/` candidates by content rather than filename alone.
- The single non-match is `20260818191254_fix_patients_rls_and_admin_link`. The live ledger body contains an environment-specific one-time admin identity-linking UPDATE plus four patient RLS policy statements. The public recovered file is deliberately a redaction placeholder because it omits the environment-specific email and user UUID; this is a privacy safeguard, not an accidental filename miss. The exact live SQL was inspected through the authorized read-only API, but the identity literals are intentionally not copied into this document or public source control.
- This is **source-body parity evidence**, not proof of clean replay, semantic equivalence under every PostgreSQL version, or equivalence of the one-time identity-link data effect. The normalization is comment/whitespace-insensitive text comparison, not a SQL parser. Do not execute the redacted placeholder.
- Clean replay remains blocked until a replay-safe migration variant is explicitly defined for the redacted identity-link step and the pre-migration baseline schema/roles/functions are reconstructed or recovered. The earliest migrations alter pre-existing objects, so the 93 rows alone are not a self-contained empty-database bootstrap. No disposable full-chain replay has yet been claimed or performed.

### Exact next actions

1. Build a replay-only variant of the redacted migration that retains the schema/policy changes but deliberately omits the environment-specific identity-link UPDATE; document that fresh environments must provision their own administrative Auth-to-app-user linkage through a separate controlled setup step.
2. Recover or synthesize a reviewed pre-migration bootstrap schema (tables, roles, auth helpers, extensions, grants and baseline functions) without production row data. Do not use the current post-migration schema as though it were the pre-migration baseline.
3. Run the complete ordered 93-step chain against disposable PostgreSQL 17 using synthetic fixtures, then compare resulting schema/policies/functions against the live inventory. Preserve per-migration failure output and a rollback/reset strategy.
4. Only after replay passes, reassess PRs #50–#54 and assemble a canonical timestamped chain; none of their SQL has been applied to production as part of this comparison.

## Next reconciliation steps

1. Compare each exact-name file with its actual deployed effect; record hashes and differences.
2. For every non-exact row, search Git history, old branches, deployment artifacts, and migration logs; assign a source only when content/effects support it.
3. Preserve separate entries where the live database contains successive patches to the same feature; do not collapse them just because filenames are similar.
4. After all rows are mapped or explicitly classified as unrecovered, assemble an ordered migration chain and test a clean replay in disposable PostgreSQL/Supabase.
5. Run a schema diff and targeted behavioral tests against a non-production instance before proposing any production reconciliation.


## Focused content comparison — 2026-10-16

A read-only, comment/whitespace-insensitive text comparison was run for four likely source candidates. This is a preliminary text comparison, not a parser-based semantic proof.

| Legacy repository file (main) | Recovered applied migration | Result | Action |
|---|---|---|---|
| db/roshan_phase12_invoice_visit_unique.sql | 20260911120231_roshan_phase12_invoice_visit_unique.sql | **Normalized SQL text matches** | Candidate content-confirmed match for this migration only; preserve comments/context separately |
| db/roshan_phase2_clinical_workflow.sql | 20260820150215_roshan_phase2_clinical_workflow.sql | **Different** (1267 vs 637 characters before normalization) | Legacy file contains extra statements; compare statement-by-statement, do not substitute |
| db/roshan_phase4_cashbox_reversal_concurrency.sql | 20261014164131_roshan_cashbox_reversal_concurrency.sql | **Matches after removing explicit BEGIN/COMMIT wrapper** | Remaining normalized SQL text matches; replay and transaction-boundary behavior still need isolated validation |
| db/roshan_phase4_finance.sql | 20260908210824_roshan_phase4_finance_v2.sql | **Different** (30999 vs 24044 characters before normalization) | Treat as legacy/current script vs a successive deployed patch, not a direct match |

The comparison removed SQL line/block comments, removed whitespace, and lowercased text before equality checks. For the cashbox candidate, the comparison also separately removed the outer explicit BEGIN/COMMIT wrapper before comparing the remaining statement text. It did not parse SQL, normalize literals, or prove equivalent runtime effects. Two differences remain unresolved; the two normalized content matches do not validate the other 77 migration rows or a clean replay.


## Follow-up comparison — cashbox wrapper isolated — 2026-10-16

The initial cashbox mismatch was rechecked. The legacy file starts with an explicit `BEGIN;` and ends with `COMMIT;`, while the recovered migration statement set does not contain those wrapper statements. Once that outer wrapper is removed, the normalized SQL bodies are equal (1907 characters each after normalization). Classification: content-confirmed body match with transaction-wrapper difference. Do not infer that replay is safe until a disposable database replay confirms migration-runner transaction behavior and dependencies.


## Read-only current-state check — laboratory parameters — 2026-10-16

A read-only aggregate query against the connected Supabase project returned:

- Undeleted lab tests: **12**
- Undeleted lab tests with no parameter rows: **0**
- Undeleted lab tests with no active parameter row: **0**

The current database state satisfies this narrow lab-parameter invariant. This does **not** prove the backfill `INSERT` present in `db/roshan_phase2_clinical_workflow.sql` was part of the applied migration: the recovered ledger statement set for version `20260820150215` contains the five index statements but not that backfill. No rows were changed. Recheck after any catalog migration and keep source-history provenance unresolved until the original statement source is found.


## Finance-v2 live-state comparison — read-only — 2026-10-16 (updated)

The live Supabase state was inspected with read-only catalog queries after comparing the repository baseline `db/roshan_phase4_finance.sql` against recovered applied migration `20260908210824_roshan_phase4_finance_v2.sql`. This is an effective-state observation, not authorization to replay either source.

Confirmed observations:
- The recovered finance-v2 source is a successive patch, not a complete replacement for the repository baseline: it begins by redefining three views and finance functions, while the repository baseline also creates/extends supplier, supplier-bill, supplier-payment, and cashbox tables/columns/indexes and contains additional setup.
- Live versions of `post_invoice_payment`, `post_expense`, `post_cashbox_entry`, `post_supplier_bill`, `post_supplier_payment`, and `reverse_cashbox_entry` are SECURITY DEFINER, have an empty `search_path`, are executable by `authenticated`, and are not executable by `anon` or `PUBLIC` according to `has_function_privilege`. This is a useful privilege/config snapshot, not a complete adversarial security review.
- The live finance RPC definitions contain branch-context checks and use `private.*` helpers in at least the supplier-bill path; the repository baseline shown here uses `public.*` helpers and omits some live branch checks. Do not overwrite live functions with the baseline without reconciling the later migrations.
- The live `fn_ledger_from_payment()` writes transaction type `customer_payment`, which differs from the repository baseline and finance-v2 migration body (`income`). Follow-up migration `20260911141142_fix_payment_ledger_transaction_type.sql` explicitly sets `customer_payment` and matches the live function body. This is therefore a confirmed later migration override, not an unexplained live drift; reporting/UI consumers should still be checked before any canonicalization.
- The live `fn_ledger_post` conflict predicate is `where source_type is not null and source_id is not null`; the repository baseline uses `where source_id is not null`. A read-only `pg_indexes` check confirms the live `uq_cashbox_source` index uses the exact same two-column predicate as the live function, so the live function/index pair is consistent. The older repository predicate must not be copied back without a disposable PostgreSQL `ON CONFLICT` inference test. The live function has `search_path=public`, whereas later RPC functions use an empty path; review the older helper separately from the already-hardened RPCs.
- Read-only catalog inspection confirms `audit_row_change()` and `fn_finance_audit()` both write equivalent event payloads to `public.audit_logs`. Both trigger families are attached to five finance tables: `cashbox_transactions`, `expenses`, `payments`, `supplier_bills`, and `supplier_payments`.
- An aggregate-only query of the last 30 days found 20 near-identical audit pairs within one second: 10 `cashbox_transactions INSERT`, 9 `payments INSERT`, and 1 `payments DELETE`. No row payloads or patient identifiers were returned. No matching pairs were observed for the other overlapping tables in this window.
- `audit_logs` has RLS enabled and forced; its only authenticated SELECT policy requires `app_has_perm('audit.read')`. No direct client INSERT policy was found.
- Authenticated currently has direct `INSERT/UPDATE/DELETE` grants on `cashbox_transactions`, `expenses`, `payments`, `supplier_bills`, and `supplier_payments`. This can bypass RPC business checks: `post_supplier_payment` locks the bill and rejects amounts above the outstanding balance, while the table constraint only requires `amount > 0`. Direct update/delete may also bypass the insert-only ledger trigger.
- The same read-only grant inventory found direct authenticated `INSERT/UPDATE` on `insurance_claims` and `INSERT` on `insurance_claim_items` / `insurance_claim_payments`. The client wrapper in `src/lib/insurance.ts` uses `create_insurance_claim`, `update_insurance_claim_status`, and `post_insurance_claim_payment` RPCs, so direct table writes are unnecessary for the current app flow and could bypass status/amount validation and the insurance-settlement ledger side effect. Draft PR #31 has been expanded to revoke these grants while preserving authenticated RPC execution; it remains unmerged.
- Main's `src/routes/_authenticated/expenses.tsx` still used direct `expenses.insert` in the audited snapshot, omitting branch assignment. Draft [PR #30](https://github.com/crauch2088-source/roshan-health-hub/pull/30) switches to `post_expense`; stacked draft [PR #31](https://github.com/crauch2088-source/roshan-health-hub/pull/31) proposes RPC-only table write privileges and aligns two RPC permission gates. Neither is merged, and no production SQL was changed.
- Validate trigger cleanup and the proposed grants migration against the complete applied-migration sequence and a disposable PostgreSQL/Supabase environment before release.
- `trg_sync_supplier_bill_payment` and `trg_recompute_supplier_bill` both recalculate the same supplier bill on INSERT/UPDATE, but use different formulas: the sync trigger clamps `paid_amount` to `total_amount` and updates `updated_by`, while the recompute trigger stores the raw sum and recalculates on DELETE too. This overlapping behavior needs regression tests for overpayment, soft-delete, UPDATE, and DELETE; do not change production triggers before the intended invariant is settled.

Classification: **partial mapping with live effective-state evidence; not replay-safe and not production-change authorization**. Next steps are to inspect the remaining relevant migration versions around finance-v2, compare exact function bodies and grants by signature, and validate trigger interactions plus view dependencies in a disposable PostgreSQL/Supabase environment. No production SQL was written.


## Security-migration statement-level mapping follow-up — 2026-10-16

The recovered `20260911130749_harden_security_and_fk_indexes_20260911.sql` was compared against all ten top-level legacy SQL files on `main`. No complete source-file match was found; only isolated statements overlap. Its dynamic SECURITY DEFINER revoke loop, several explicit search-path alterations, policy consolidation, and FK-index statements remain a **partial/unmapped source** rather than proof of missing live protections.

The recovered `20260911130812_restrict_security_definer_api_execution_20260911.sql` also has no full legacy-file match. Six individual EXECUTE grant statements were found in the legacy corpus, while its dynamic PUBLIC/anon revoke loop and several RPC grants do not match a single legacy source as a complete statement set. The live catalog still shows a narrower callable surface than the legacy baseline; preserve the recovered files as quarantine evidence and do not replay them to reconstruct history.


## Proposed finance audit trigger cleanup — CI status — 2026-10-16

Draft [PR #32](https://github.com/crauch2088-source/roshan-health-hub/pull/32) proposes dropping only `trg_audit_*` from the five finance tables and retaining `trg_finance_audit`. Its disposable PostgreSQL 17 integration test verifies one audit row for INSERT/UPDATE/DELETE on each of the five finance tables and verifies that the generic audit trigger remains on a non-finance control table. The integration, guard tests, typecheck, lint, and build passed on head `a626104e616a5d19857db4b819099be55aad4e6c`. This remains a draft; no production triggers were changed.


## Proposed finance audit trigger cleanup — CI status — 2026-10-16

Draft [PR #32](https://github.com/crauch2088-source/roshan-health-hub/pull/32) proposes dropping only `trg_audit_*` from the five finance tables and retaining `trg_finance_audit`. Its disposable PostgreSQL 17 integration test verifies one audit row for INSERT/UPDATE/DELETE on each of the five finance tables and verifies that the generic audit trigger remains on a non-finance control table. The integration, guard tests, typecheck, lint, and build passed on head `a626104e616a5d19857db4b819099be55aad4e6c`. This remains a draft; no production triggers were changed.


## Clinical child-row branch isolation — read-only catalog audit — 2026-10-16

- Live `invoice_items_select` checks `billing.read` / `billing.view` but has no parent-invoice branch predicate. `invoice_items` has no `branch_id`, so a user with billing read permission could query line items for an invoice outside their branch if they know the invoice ID. The parent `invoices` table itself has branch-scoped policies. Draft PR #33 (stacked on the atomic invoice PR) adds a parent-branch check to invoice-item SELECT and proposes revoking direct invoice table DML after the atomic wrappers are available.
- The recovered `20261011080434_enforce_branch_isolation_on_clinical_child_tables.sql` updates `clinical_notes`, `diagnoses`, `vitals`, `lab_results`, and `attachments`, but it does not update the live policies on `prescriptions`, `prescription_items`, or `lab_order_items`. Current policies for those three tables check permissions only; none has `branch_id`. This is a confirmed policy gap, not evidence that the recovered migration failed to apply.
- Draft PR #34 adds parent-branch helpers for prescriptions and lab orders, then adds branch checks to SELECT/INSERT/UPDATE/DELETE policies for those child tables and related medical-certificate, patient-discount, and prior-authorization records. Its fixture initially failed because it omitted policy tables and grants; those dependencies and cross-branch tests were added. PostgreSQL 17 integration plus guard/typecheck/lint/build passed on head `d17ddbc54e565c5965d2278c43ac847e5156a2c4` in run #38885187149. It is not merged and was not applied to production.
- Keep both changes gated on the full migration-history reconciliation and isolated branch-access testing; no live policies or patient data were changed during this audit.


## Insurance claim reference semantics — read-only catalog check — 2026-10-16

The live `public.insurance_claim_items` schema shows:
- `reference_id`: nullable UUID, no foreign-key constraint.
- `service_type`: required text, no foreign-key constraint.
- `coverage_rule_id`: nullable UUID with a foreign-key constraint.
- `gross_amount`, `covered_amount`, and `patient_amount`: numeric columns with defaults of zero; no table-level check constraint was returned by the catalog inventory for their relationship.

The current live `create_insurance_claim` RPC accepts a nullable `reference_id`, verifies patient-insurance/invoice patient matching and branch access, then inserts claim items. It rejects negative amounts but does not enforce `covered_amount + patient_amount = gross_amount` at the database boundary. Draft PRs #12 and #13 propose UI and RPC-level protections, but reference semantics still require an explicit business decision before introducing a foreign key or deriving references automatically.

No production data was changed by this inspection.


## Cashbox reversal concurrency — disposable PostgreSQL 17 — 2026-10-16

The prior single-session test explicitly noted that a true two-session race was still missing. Draft PR #36 adds a separate PostgreSQL 17 service-container job that:
- starts two independent `psql` sessions against the same original transaction with overlapping reversal attempts;
- requires exactly one call to succeed and the competing call to be rejected;
- asserts exactly one reversal row, `is_reversed = true` on the original, and original plus reversal amounts net to zero.

The test waits for session A to be visible in `pg_stat_activity` inside the controlled `pg_sleep` trigger while it holds the original-row lock, then starts session B. The two-session race and full repository CI passed on head `c7a12408dcd154af65ba0726a59455436d5ea5af` in run [#38887494366](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38887494366). This is disposable PostgreSQL evidence only; the proposed migration has not been replayed against an isolated Supabase branch or applied to production.


### Supplier-payment trigger overlap — data limitation — read-only 2026-10-16

- The live trigger catalog confirms `trg_recompute_supplier_bill` runs on INSERT/UPDATE/DELETE and `trg_sync_supplier_bill_payment` runs on INSERT/UPDATE. The two functions both update `supplier_bills.paid_amount/status`; the sync function clamps the sum to `total_amount`, while the recompute function stores the raw active-payment sum and also runs on DELETE.
- An aggregate-only live query found **0 non-deleted supplier bills** at the time of inspection. Consequently, the current live dataset cannot validate the balance/status invariant or establish whether this overlapping behavior has caused a real production failure. Treat this as a structural edge-case risk requiring disposable PostgreSQL tests, not a claim of observed supplier-bill corruption.
- The supported `post_supplier_payment` RPC locks the bill row and rejects a payment above the outstanding balance. However, live grants/policies also permit authenticated direct DML on supplier-payment tables; the separate draft PR #31 proposes RPC-only financial writes. Keep the change unmerged until its tests, UI consumers, and migration history are reviewed.


### Invoice-payment permission contract — read-only + proposed regression — 2026-10-16

- Live `public.post_invoice_payment(uuid,numeric,text,text,text)` accepts `payments.create` or `billing.create`, but the accounting screen exposes collection when either `payments.create` **or** `accounting.create` is present. Thus an accounting-only user can see the action but the RPC rejects it.
- Draft PR #31 now proposes aligning the RPC gate with the exposed UI contract by also accepting `accounting.create`; it preserves the live row lock, invoice existence check, branch check, outstanding-balance validation, and idempotency lookup.
- Disposable PostgreSQL 17 regression coverage exercises an accounting-only caller, rejects a payment greater than the outstanding balance, and verifies that retrying the same idempotency key returns the original payment ID. Full CI passed on PR #31 head `190b12f844d85efc4d9a0187458a8016404201d7` (run #38887826478). This remains a draft proposal; production schema/function state is unchanged.


- Follow-up to the invoice-payment permission check: the live `post_invoice_payment` returns an existing payment for any previously seen `idempotency_key` without checking that the actor, invoice, amount, method, or reference matches the new request. A disposable PostgreSQL regression reproduced the silent acceptance of a changed amount. Draft PR #31 now compares these request fields and fails closed on mismatches while returning the original ID for an identical retry. PostgreSQL 17 integration plus guard/typecheck/lint/build passed on head `49ae949f70b40c2c09b9378e5fe8f459e43ae9b3` (run #38888211717); no production function or data was changed.


### Pharmacy inventory eligibility recheck — read-only — 2026-10-16

A fresh aggregate-only query against the live Supabase project reconfirmed:
- `public.medicines`: 9 active/non-deleted rows with nonzero legacy `stock_quantity`; sum = 4,484.
- `public.pharmacy_inventory`: 1 non-deleted batch row; its `branch_id` is NULL, its expiry date is before the database's current date, and its remaining quantity is 498.
- Branch-assigned non-deleted batches: **0**. Therefore there is currently no confirmed unexpired, branch-assigned batch stock available for the batch-only FEFO dispense path.
- `public.medicines_2` has 0 rows in the live project, supporting—but not by itself proving—that it is not the active stock source.
- `public.stock_movements` still has 8 rows: four purchase movements totaling +1,025, all with NULL branch IDs; four dispense movements totaling -4, including both batch-linked and unlinked records. This ledger does not reconcile the 4,484 legacy catalog quantity.

Safety implication: keep PR #23's batch-only/branch-matched rejection behavior; do not restore legacy-stock fallback to make dispensing appear functional. The clinic must first identify whether the legacy balances are test seeds, real stock, or historic balances, and document branch ownership, expiry, supplier provenance, and auditable opening-balance adjustments. No inventory or movement rows were changed.


### Phase 5 insurance source comparison — statement-level — 2026-10-16

A SQL-aware statement comparison of `db/roshan_phase5_insurance.sql` (51 top-level statements, split while respecting dollar-quoted function bodies) found **50 normalized statement matches** across the three early recovered migrations:
- `20260909110657_roshan_phase5_insurance.sql`: 20 matches.
- `20260909110735_roshan_phase5_insurance_functions.sql`: 3 matches.
- `20260909110753_roshan_phase5_insurance_permissions_rls.sql`: 27 matches.

The single unmatched legacy statement is `public.fn_calculate_insurance_coverage(...)`. This is explained by later recovered overrides: `20260911133319_harden_insurance_coverage_rpc_branch.sql` adds explicit branch isolation, and `20261011074437_harden_insurance_coverage_rpc_permissions.sql` adds an `insurance.read` permission gate and `search_path = ''`. Classification: strong partial mapping with a documented later replacement; not an exact replayable source file.

### Unversioned pharmacist supplier-permission supplement — read-only — 2026-10-16

`db/roshan_phase4_finance_pharmacist_grant.sql` is a standalone, non-timestamped one-statement supplement rather than one of the 79 recovered ledger files. A read-only aggregate query confirmed the live pharmacist role currently has `suppliers.read`, `suppliers.create`, and `suppliers.update`. This verifies the intended effective permission state, but not whether this exact file was the source of the change. Do not replay it or treat it as a canonical migration without reconstructing its history.

### Privileged-role guard candidate — read-only — 2026-10-16

The live trigger catalog contains no `trg_guard_super_admin_users`, `trg_guard_super_admin_roles`, or `trg_guard_super_admin_role_permissions` triggers. The prepared file `db/roshan_security_privileged_role_guard.sql` is therefore not reflected in the current live trigger set. Draft [PR #38](https://github.com/crauch2088-source/roshan-health-hub/pull/38) adds an isolated PostgreSQL 17 integration job and static guard checks for the prepared SQL; CI passed on commit `dc6301732093abc4a28aeedcff2a1d1738405552` (run [#38892744625](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38892744625)). It is test-only and does not apply the migration to production.


### Insurance workflow readiness snapshot — aggregate-only, read-only — 2026-10-16

A fresh query of the live database returned:
- Insurance plans: **0** total; plans with non-zero default coverage: **0**.
- Insurance coverage rules: **0**.
- Patient insurance policies: **0**.
- Insurance claims and claim items: **0**; there is no historic claim-item population to migrate or compare.
- Invoice items: **6** total, all non-deleted: 4 `consultation`, 2 `laboratory`.
- Existing check constraints restrict claim item `service_type` to `consultation`, `lab`, or `medicine`, but the live invoice item categories currently use `consultation` and `laboratory`. The mismatch should be handled explicitly in the business mapping rather than by string assumptions.

No claim item has a live `reference_id` because there are no claim items. `insurance_claim_items.reference_id` still has no foreign key, and coverage rules have no rows to establish the intended target. Consequently, the reference model and coverage/override policy remain business decisions. Do not infer that `reference_id` must be an invoice item ID, and do not enable insurance billing until plans/rules and the mapping have been defined and tested. No data was changed.


## Insurance UI/RPC compatibility check — read-only — 2026-10-16

The current `main` UI in `src/routes/_authenticated/insurance.tsx` still builds free-form claim items with `reference_id: null` and calls `createInsuranceClaim({ patientInsuranceId, invoiceId: null, items })`. The live `public.create_insurance_claim` RPC looks up the supplied invoice and raises `invoice not found` when no invoice row is found; therefore this current main-branch workflow cannot successfully create a claim through that RPC.

Draft PR #12 (`fix/insurance-claim-invoice-link`, head `175216a4b929b23690f979a7d234899d3e25a71c`) has been independently checked: its branch removes the null-invoice call, adds invoice selection and stale-item clearing, and the claim helper now requires a non-null invoice ID. This fixes the immediate UI/RPC mismatch but does **not** settle the separate business/schema gate: the live claim-item `reference_id` is nullable UUID without a foreign key, free-form descriptions are allowed, and gross amounts are not yet tied to actual invoice line IDs/amounts. PR #13 adds server-side amount/eligibility validation but its own review note correctly leaves invoice-line linkage and override policy unresolved.

Classification: **immediate UI/RPC incompatibility has a draft code fix; not in main and not released. Invoice-line reference semantics and authoritative coverage/override rules remain unresolved.** Do not treat PR #12/#13 as production-fixed until reviewed, migration history reconciled, and authenticated workflow tested.


## Privileged-role guard trusted-context correction — 2026-10-16

The prepared `db/roshan_security_privileged_role_guard.sql` originally treated `auth.uid() IS NULL` as proof of a trusted migration/service context. A PostgreSQL 17 regression fixture intentionally granted `anon` table DML and proved that an anonymous JWT with no user ID could insert a user assigned to `super_admin`; this reproduced the bypass in CI run [#38896579035](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38896579035).

Draft PR #38 now uses `private.is_trusted_role_guard_context()`: bypass is permitted only for a `service_role` JWT, or a direct trusted database session whose JWT role claim is absent and whose `session_user` is `postgres` or `supabase_admin`. The fixture now distinguishes `auth.role()` from `auth.uid()`, and the anonymous test passes with the hardened helper. Full PostgreSQL 17 integration, security audit, guard tests, typecheck, lint, and build passed on head `523f7a0f9cc1359d9ed162eede9e75dd388a5d31` in [run #38897148980](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38897148980).

This is a source-branch correction only. Production currently has no direct `anon` INSERT/UPDATE grants on `users`, `roles`, or `role_permissions`, and no guard triggers are installed. The test demonstrates a structural bypass if grants/policies change; it is not evidence of a current anonymous write path. The prepared guard remains unapplied pending migration-history reconciliation, isolated Supabase validation, rollback review, and explicit release approval.


## Follow-up verification — PR tests and live row counts — 2026-10-16

- PR #32 (finance audit-trigger deduplication) remains open/draft and unmerged. Its GitHub Actions CI run `38878206233` completed successfully, including both the general verification job and the PostgreSQL behavioral test job `Finance audit trigger deduplication`. The proposed migration is still only a repository change; it has not been applied to production.
- PR #31 (finance RPC-only writes) remains open/draft and unmerged. Its CI run `38893892959` completed successfully, including the finance RPC-only write integration and two-session invoice-payment idempotency jobs. This is branch-level test evidence only.
- Re-read the live trigger catalog: all five finance tables (`cashbox_transactions`, `expenses`, `payments`, `supplier_bills`, `supplier_payments`) currently have both `trg_audit_*` and `trg_finance_audit`, confirming the proposed PR #32 migration targets real live objects.
- Read-only row counts: `payments=10`, `expenses=1`, `supplier_bills=0`, `supplier_payments=0` (all extant rows in these tables are undeleted). Therefore the supplier-bill/payment reconciliation query returned zero active bills and cannot validate the competing recomputation logic against production records. The edge-case behavior must be proven in the isolated SQL fixture, not inferred from the empty live supplier tables.
- Vercel's commit status remains a build-rate-limit failure for the reviewed finance branches; GitHub Actions CI passed as noted above. Do not equate the Vercel status with a code test failure, and do not claim a deployment succeeded.


## Insurance live-data limitation — read-only — 2026-10-16

The live schema confirms `insurance_claims.invoice_id` is nullable and `insurance_claim_items.reference_id` is nullable; claim items separately store `gross_amount`, `covered_amount`, and `patient_amount`. Aggregate-only queries returned **zero active claims and zero claim items**. Therefore current production data cannot validate invoice linkage or amount-split invariants, and the absence of mismatches is not evidence that the workflow is correct. PR #12 and PR #13 each have successful GitHub Actions CI (PR #12 general verification; PR #13 general verification plus insurance-claim integrity integration), but remain unmerged. Keep the business meaning of `reference_id` and the allowed manual service/amount workflow unresolved until the intended policy is explicit; do not infer it from an empty table.


## Patient-registration RPC and private-helper privilege follow-up — 2026-10-16

- PR #39 was corrected after its first CI run exposed a real mismatch between the proposed test and the typed `rpc<T>()` helper, followed by two Prettier-only failures. The latest run `38903131578` is green: general install/audit/typecheck/lint/build plus PostgreSQL atomic-registration and two-session MRN concurrency tests. The migration remains proposed and unapplied; PR #39 remains unmerged.
- The patient RPC keeps MRN allocation and insertion under the same transaction-scoped advisory lock, rejects missing permission/user/branch context, and sets branch and actor fields server-side. The CI concurrency test confirms two overlapping registrations succeed with distinct MRNs.
- A read-only privilege check found `private.app_has_branch_access(uuid)` executable by `anon` according to PostgreSQL function ACLs, while `anon` has no USAGE on schema `private`; this currently blocks direct schema-level invocation through normal PostgREST exposure, but is still unnecessary PUBLIC/anon execute privilege. PR #34 proposes revoking PUBLIC/anon and granting authenticated for RLS use, with a privilege integration assertion; its latest CI run `38903566507` passed both general verification and clinical child branch-isolation integration.
- The same catalog scan found other private helpers with anon EXECUTE ACLs (`app_has_claim_branch`, `app_has_invoice_branch`, `app_has_patient_branch`, `sync_user_role_text`). Because the private schema currently has no anon USAGE, this is defense-in-depth/least-privilege debt rather than evidence of current PostgREST reachability. Track a separate, dependency-aware privilege sweep; do not blindly revoke trigger or RLS dependencies without checking each helper's callers.


## Duplicate finance audit trigger remediation proposal — 2026-10-16

Draft PR #40 proposes an idempotent migration at `db/roshan_phase4_finance_audit_trigger_dedup.sql` to remove only the older generic audit trigger on four finance tables while preserving the finance-specific trigger. The dedicated PostgreSQL 17 integration workflow passed on a disposable database for INSERT/UPDATE/DELETE audit cardinality and migration idempotency. This is not production authorization. Before merge, review whether `fn_finance_audit()` preserves required user attribution and audit-retention semantics for all callers.

The read-only aggregate of current production insurance data returned zero active claims and zero active claim items, with six active invoices and six active invoice items. Because no claim history currently exists, the item-to-invoice reference semantics and coverage override policy remain business-rule decisions; no schema or production data was changed.

- Additional aggregate-only comparison of the same 20 near-identical audit pairs found `same_user_pairs=20`, `different_user_pairs=0`, and `both_null_user_pairs=3`. Thus no attribution mismatch was observed in this sample; the three null/null pairs and service-role/noninteractive cases still warrant review before merge.

- Deduplication follow-up: a second draft PR (#40) was closed as redundant after discovering the earlier, broader PR #32. Prefer PR #32 because it covers all five finance tables including supplier bills, retains a non-finance control table, and tests user-attribution behavior; PR #40 is closed and must not be merged.


## Clinical child branch isolation — legacy branchless lab orders — 2026-10-16

A read-only aggregate query against production found 9 non-deleted `lab_orders` rows, all with `branch_id IS NULL`. Only one has a patient with a non-null branch available as fallback; eight have neither a patient nor visit branch fallback. No row-level patient-identifying values were selected.

The proposed PR #34 migration originally used `COALESCE(lo.branch_id, v.branch_id, p.branch_id)` for child-row access while the parent `lab_orders` policies used only `app_has_branch_access(lab_orders.branch_id)`. That allowed an inconsistency for branchless orders whose patient/visit belongs to the user's branch. A disposable PostgreSQL 17 regression was added first and failed as expected on head `bf473c63a67e45d08a7146a9e2308989cc3e3af0` with `lab_order_items SELECT leaked or hid a branch-local row`, confirming the edge case rather than assuming it.

The proposed helper was then changed to use the explicit `lo.branch_id`, matching the parent policy's fail-closed behavior for ordinary branch-scoped users; a NULL branch does not inherit patient/visit access implicitly. Tests now cover (1) branchless order with patient/visit fallback, (2) branchless order without any fallback, (3) ordinary branch user cannot see the parent or child rows in either case, and (4) super-admin can still see the legacy records. The updated PR #34 head is `b01b036af5aa35e13adc1816425031a24827779c`; the corresponding GitHub Actions run was not yet visible as completed at the time this note was written. Keep this change unmerged until the latest CI is green and review confirms that fail-closed behavior is the intended handling of legacy records. Do not backfill production rows without a separately approved data-repair decision.


## SECURITY DEFINER helper grants — PR #34 — 2026-10-16

A read-only production catalog check found that `private.app_has_patient_branch(uuid)` is SECURITY DEFINER with an empty `search_path`, but `has_function_privilege('anon', ...)` returned true. This helper is called directly by the proposed RLS policies for `medical_certificates` and `patient_discounts`, and by the prior-authorization helper. The proposed migration revoked PUBLIC/anon execution from `private.app_has_branch_access(uuid)` but initially omitted the existing patient-branch helper.

A regression test was added and the fixture was changed so it no longer pre-hardens that function before the migration under test. The test failed on head `69945084c67a088c9f7e793daa150866c129398d` with `anonymous role must not execute private patient-branch helper`. The migration now explicitly revokes PUBLIC/anon and grants execution to authenticated for `private.app_has_patient_branch(uuid)`.

The latest PR #34 head `0e18974ebfc588cbf605b62cdc5d4169f93fcca7` passed both jobs in GitHub Actions run [38906930251](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38906930251): the PostgreSQL 17 clinical child branch-isolation integration test and the full install/audit/role-guard/typecheck/lint/build job. This is draft-branch evidence only. The migration remains unapplied; keep PR #34 open/draft until the broader schema, legacy branchless data behavior, and migration sequence have been reviewed.


## Invoice RPC-only write migration — production parity gate — 2026-10-16

Read-only checks against the connected production project were completed before considering draft PR #33. No production data, grants, policies, or functions were changed.

- [x] **Function inventory:** the three proposed write RPCs (create_billing_invoice_atomic, create_visit_consultation_invoice_atomic, and create_lab_order_with_invoice_atomic) are absent from the live catalog. This confirms PR #33 cannot safely be promoted alone; PR #23's RPC/UI migration must be reviewed and released first, then the privilege migration.
- [x] **Privilege inventory:** authenticated currently has SELECT, INSERT, UPDATE, and DELETE on both invoices and invoice_items; anon has no INSERT privilege on either table. The proposed migration removes all direct DML/structural table privileges from PUBLIC, anon, and authenticated while preserving SELECT.
- [x] **RLS parity:** live invoices SELECT is constrained by private.app_has_branch_access(invoices.branch_id), but live invoice_items SELECT checks only billing.read/billing.view and has no parent-invoice branch predicate. The proposed migration's EXISTS join to the parent invoice addresses this policy mismatch; it remains untested against the exact production policy dependencies until run in a disposable schema clone.
- [x] **Aggregate data integrity:** live snapshot contains 6 invoices and 6 invoice items; all 6 invoices have NULL branch_id; no invoice items are orphaned and all join to an existing invoice. Do not auto-assign branches: prior branchless-data gate remains open until the owner confirms whether these are synthetic or operational records.
- [x] **Privilege boundary distinction:** live next_invoice_number() is executable by authenticated but not anon and uses an empty search_path; post_invoice_payment(uuid,numeric,text,text,text) is SECURITY DEFINER, uses an empty search_path, and is executable by authenticated but not anon. These existing RPCs do not substitute for the three missing create-invoice RPCs and should not be revoked by the proposed migration.

**Release ordering:** review and validate PR #23's atomic invoice RPC definitions and client paths first; then validate PR #33's exact function signatures against that result. Run the fixture/integration workflow against a disposable PostgreSQL 17 database and test both branch-visible and cross-branch invoice items. Keep both PRs draft/unmerged until migration-source reconciliation and the branchless legacy-data decision are complete. No production SQL was executed beyond SELECT-only catalog/aggregate queries.


## Patient registration atomicity — production parity review — 2026-10-16

Read-only production checks and draft PR #39 review. No production data or privileges changed.

- [x] **MRN format parity:** the live public.next_mrn() uses prefix RMC and the same transaction advisory-lock key ('roshan:mrn') as proposed public.create_patient_atomic(). The new function retains that prefix and lock key, so the intended sequence remains compatible with the deployed generator.
- [x] **Existing MRN aggregate:** production has 10 patient rows; 5 use RMC numeric MRNs, 1 has a TEST-prefixed MRN, and 4 have NULL MRN. No patient names, phone numbers, IDs, or row-level records were retrieved. The new generator calculates only from RMC numeric values, matching the existing next_mrn() behavior; the legacy NULL/TEST rows remain a separate data-quality issue.
- [x] **Permission/branch behavior:** proposed RPC derives user and branch server-side, checks patients.create, requires an active application user and non-NULL branch, and writes created_by/registered_by/updated_by from the authenticated application user. It does not accept a client-supplied branch or MRN.
- [x] **Atomicity/concurrency test coverage:** PR #39 contains a disposable PostgreSQL 17 fixture, permission/invalid-input/branch failure rollback checks, and a two-session concurrency script that waits for the first insert to enter a controlled delay before starting the second registration. Both concurrent registrations must succeed with distinct MRNs.
- [x] **CI evidence:** PR #39 head 8fa3ae58ffc8964ce5e4397e4a34a3c2618b3a1a passed full CI in run 38903131578. This validates the disposable fixture and repository guards only; it does not prove the migration against the exact production schema or authorize deployment.

**Release gates remain:** reconcile the applied migration chain, validate the SQL against a disposable copy of the live schema, confirm branch assignment/readiness, and complete authenticated smoke tests before merge or production application. PR #39 remains draft/unmerged.


## Follow-up batch: ledger and invoice release ordering — 2026-10-16

- Read-only query of `supabase_migrations.schema_migrations` returned **79 rows**, minimum version `20260818162003`, maximum version `20261014164131`. This confirms count/range only; it does not prove semantic parity between repository SQL files and production-applied SQL.
- Master-plan CI run [38908548869](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38908548869) completed successfully for security checks, role guard, typecheck, lint, and build.
- PR #23 remains OPEN/DRAFT on `main`, head `14e0b167a9b80c989184a60f35a2b8ab449df62e`; CI run [38872711903](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38872711903) succeeded.
- PR #33 remains OPEN/DRAFT, based on `fix/invoice-atomicity`, head `863dae0f482a06882f6b3740e8cdde673e869c9c`; CI run [38880644006](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38880644006) succeeded. Keep release order #23 then #33 after source reconciliation, disposable-schema validation, and authenticated smoke tests.
- Read-only ACL recheck found effective anon EXECUTE for five SECURITY DEFINER helpers in `private`, while anon has no USAGE on that schema. This is a least-privilege hardening lead, not proof of direct API reachability. Map RLS policy and trigger dependencies before any targeted revocation; do not blanket-revoke.

No production SQL, grants, data, merge, or deployment was changed in this batch.


## Private helper dependency map — read-only — 2026-10-16

Catalog dependency counts:
- `private.app_has_branch_access(uuid)`: 50 RLS policies across 13 tables (patients, visits, appointments, invoices, payments, cashbox, pharmacy inventory, stock movements, supplier bills/payments, users, and related operational tables).
- `private.app_has_claim_branch(uuid)`: 4 policies across `insurance_claim_items` and `insurance_claim_payments`.
- `private.app_has_invoice_branch(uuid)`: 3 policies on `insurance_claims`.
- `private.app_has_patient_branch(uuid)`: 3 policies on `patient_insurance`.
- `private.sync_user_role_text()`: one trigger dependency, no RLS policy dependency in this query.

These dependencies show why broad permission changes would be unsafe without context-specific tests. Any targeted change needs isolated-schema validation for affected policies/triggers. This was catalog-only inspection; no privileges or application data were changed.


## Current live-ledger status after Phase 21 privileges and Phases 22–25 rollout

A fresh read-only query of `supabase_migrations.schema_migrations` now returns **93 applied entries**, from `20260818162003` through `20261016222009`. The earlier 79-row inventory remains a historical source-reconciliation baseline; the nine tracked billing/security migrations previously raised the total to 88, and five later tracked migrations raised it to 93.

| Version | Live migration name | Repository SQL source | Verification status |
|---|---|---|---|
| 20261016204859 | `roshan_phase21_patient_registration_privileges_20261016` | Normalized text match: `db/roshan_phase21_patient_registration_privileges.sql` | Applied and included in the green patient-registration CI suite; historical full-ledger parity remains open |
| 20261016211342 | `roshan_phase22_clinic_local_queue_date_20261016` | Normalized text match: `db/roshan_phase22_clinic_local_queue_date.sql` | Applied; clinic-local date regression passed in CI and browser smoke |
| 20261016215806 | `roshan_phase23_legacy_queue_allocator_20261016` | Normalized text match: `db/roshan_phase23_legacy_queue_allocator_20261016.sql` | Applied; legacy collision regression passed in PostgreSQL 17 and synthetic browser test |
| 20261016221553 | `roshan_phase24_visit_form_options_20261016` | Normalized text match: `db/roshan_phase24_visit_form_options.sql` | PR #47 merged; CI passed; simulated authenticated receptionist received 11 departments and one same-branch doctor; anon EXECUTE denied |
| 20261016222009 | `roshan_phase25_current_app_profile_20261016` | Normalized text match: `db/roshan_phase25_current_app_profile.sql` | PR #48 merged; CI passed; simulated authenticated receptionist received own profile and 20 permissions while direct RLS reads remained empty; anon EXECUTE denied |

The Phase 24/25 migrations are narrow additive SECURITY DEFINER RPCs with empty `search_path`, authenticated-only EXECUTE, and branch/self scoping. They were applied only after their PostgreSQL 17 regression suites passed, and post-application checks were run in rolled-back, read-only transactions. They do not establish that the 79 historical migrations are a clean replayable baseline.

The post-deployment revocation SQL `db/roshan_phase17_revoke_legacy_dispense_rpc.sql` remains **not applied**. Keep it unapplied until authenticated browser/UI smoke tests pass, because the current deployed UI may still call the legacy dispense RPC.

The billing migration sequence passed isolated PostgreSQL 17 integration tests and a rollback-only live-schema/behavior dry run before application. After application, simulated-auth smoke tests verified consultation + lab consolidation, idempotent retry, and explicit secondary invoice creation; all synthetic rows were removed. The historical source mapping, clean replay, and live-schema parity remain unresolved. The current production UI smoke test for Phases 24/25 is still pending because Vercel production deployment is blocked by the account build-rate limit; do not describe the frontend changes as live until a new READY production deployment and authenticated smoke test succeed.


## Verified executable-source parity for the latest five ledger entries — 2026-10-17

A read-only query retrieved the stored `statements` array for each applied migration below. These comparisons are limited to these five rows; they do not establish parity for the earlier 88 entries or prove that a clean replay is safe.

| Version | Applied migration | Source candidate | Live statement chars | Stored statement MD5 (array joined with LF) | Comparison |
|---|---|---|---:|---|---|
| `20261016204859` | `roshan_phase21_patient_registration_privileges_20261016` | `db/roshan_phase21_patient_registration_privileges.sql` | 242 | `d144550991750e1da0038b0abe736467` | Executable statements match; explanatory comments differ |
| `20261016211342` | `roshan_phase22_clinic_local_queue_date_20261016` | `db/roshan_phase22_clinic_local_queue_date.sql` | 1530 | `e00a14d7e2e85c0b8758b25530461cd7` | Exact size match; source body inspected |
| `20261016215806` | `roshan_phase23_legacy_queue_allocator_20261016` | `db/roshan_phase23_legacy_queue_allocator_20261016.sql` | 1020 | `3834801544bdb05811970fe960e3815a` | Exact size match; source body inspected |
| `20261016221553` | `roshan_phase24_visit_form_options_20261016` | `db/roshan_phase24_visit_form_options.sql` | 1584 | `d0db6a224a6996ef36bd885c6357b17d` | Source differs by one trailing character/newline; function and grant statements match on inspection |
| `20261016222009` | `roshan_phase25_current_app_profile_20261016` | `db/roshan_phase25_current_app_profile.sql` | 2012 | `bc446eaaafd5b080ce00a5b53d713174` | Source differs by one trailing character/newline; function and grant statements match on inspection |

The fingerprint is `md5(array_to_string(statements, E'\\n'))` over the live `supabase_migrations.schema_migrations.statements` array. All five live rows have one stored statement and no stored rollback body. This adds reproducible live fingerprints and partial source mapping, not a claim of full migration parity. The full 93-row ledger still requires mapping, semantic diff, dependency ordering, and disposable clean-replay validation before any historical replay or new RLS rollout.


## Additional executable-source comparison — 2026-10-17

The live `statements` arrays for the following applied entries were inspected read-only and compared with their named repository candidates. The stored SQL fingerprint is `md5(array_to_string(statements, E'\\n'))`. Matching character counts support the comparison but are not a cryptographic source-to-ledger match by themselves; statuses below distinguish exact-size matches from comment-only differences.

| Version | Applied migration | Repository source | Live SQL chars | Live SQL MD5 | Comparison |
|---|---|---|---:|---|---|
| `20261016161923` | `roshan_phase18_dedupe_finance_audit_triggers_20261016` | `db/roshan_phase18_dedupe_finance_audit_triggers.sql` | 488 | `85508b85692a7e7afde5b9d95bc710a7` | Executable DROP TRIGGER statements match; candidate contains additional explanatory comments |
| `20261016162410` | `roshan_phase21_patient_registration_atomicity_20261016` | `db/roshan_phase21_patient_registration_atomicity.sql` | 2719 | `b4def56bc1051561e0fd050d8bc68c2e` | Exact size match |
| `20261016170816` | `roshan_security_privileged_role_guard_20261016` | `db/roshan_security_privileged_role_guard.sql` | 9007 | `821e577820db96b6aae38a8f85d87c21` | Exact size match |
| `20261016172209` | `roshan_phase7_atomic_prescription_20261016` | `db/roshan_phase7_atomic_prescription.sql` | 6122 | `7c98f8352ebb8fc3828b27f32eed4ee1` | Function and grants match; live ledger includes additional deployment/rollback header comments |
| `20261016183123` | `roshan_phase8_atomic_invoice` | `db/roshan_phase8_atomic_invoice.sql` | 5873 | `22e6a70963e0b2ef883f8e7223b38bfe` | Exact size match |
| `20261016183130` | `roshan_phase13_consolidated_visit_invoice` | `db/roshan_phase13_consolidated_visit_invoice.sql` | 16827 | `58ab88398b767ece8b4d7841ddf9b244` | Exact size match |
| `20261016183136` | `roshan_phase14_dispense_invoice_atomic_compat` | `db/roshan_phase14_dispense_invoice_atomic.sql` | 10609 | `fabc2d706bba136ef7f6e2daa10fb9af` | Exact size match |
| `20261016183145` | `roshan_phase15_manual_invoice_consolidation` | `db/roshan_phase15_manual_invoice_consolidation.sql` | 4133 | `c58f615ca007f1ed9a51d02e1df00a0b` | Exact size match |
| `20261016183152` | `roshan_phase16_billing_idempotency` | `db/roshan_phase16_billing_idempotency.sql` | 5001 | `e6cb5067237f10e45bb8955a62254cd2` | Exact size match |

Together with the preceding five-entry comparison, this adds source mapping for fourteen recent ledger entries, including the important atomic prescription/invoice and privileged-role guard changes. It still does not reconcile the earlier historical migration sequence or replace a clean disposable replay. Do not replay any migration or promote the proposed RLS candidates on this evidence alone.


## Replay-safe validation of the redacted historical migration — 2026-10-17

The public source for `20260818191254_fix_patients_rls_and_admin_link` remains a comment-only placeholder because the applied migration contains a one-time Auth identity mapping. A separate replay-only variant is now tracked at `docs/recovered-migrations/replay-safe/20260818191254_fix_patients_rls_and_admin_link.sql`. It omits that one-time `UPDATE public.users SET auth_user_id = ...` entirely, contains no email or identity UUID, and preserves the four patient RLS policy definitions.

A free GitHub Actions PostgreSQL 17 job applies this variant to a synthetic fixture and verifies the four policy operations and predicates, fixture DML behavior, and that no identity link is created. The job passed on main commit `ed1218e35121d9de08845fcc943fb8a3252717a6`; all 14 checks on that commit were successful. This is an isolated test of the policy-repair portion, **not** proof that the complete 93-entry migration chain replays cleanly.

The full-chain replay gate remains open because a trustworthy pre-migration schema baseline is still missing. Do not use a guessed baseline or production as a replay target. No paid Supabase resource was created.


## Final replay-safe validation status — 2026-10-17

The replay-only policy variant and synthetic PostgreSQL 17 integration are now enforced by CI. The source-parity verifier also rejects an email, identity UUID, or `UPDATE public.users SET auth_user_id` in the replay variant, and checks that all four patient policy definitions remain present. Latest main SHA `ddf7d3b5b72d18bbfd13598472ce4db480c09bca` passed all 15 checks, including both CodeQL language analyses.

This is evidence for the policy portion of the redacted migration only. It does not supply the missing pre-migration baseline or prove a clean replay of the full 93-entry chain. Production remains unchanged and no paid database branch was created.

## Live verification addendum — 2026-10-18

At the 2026-10-17 22:18 UTC read-only audit, the Supabase migration ledger contained 97 entries through `20261017133157_roshan_revoke_legacy_invoice_number_20261017`. The exact current GitHub `main` SHA `868ea341b281f1218de490b603bf8d4632093a35` had 14/14 successful GitHub checks and a matching READY production deployment. Better Stack monitor `5086672` reported UP against `https://roshan-health-hub.vercel.app/`.

Policy-expression review found all 40 policies across 10 targeted child tables include parent/branch helper checks. A distinct residual gap remains on `public.insurance_prior_authorizations`: its SELECT, INSERT, and UPDATE policies only call `app_has_perm(...)` and do not check the associated patient's branch. The FK chain is `insurance_prior_authorizations.patient_insurance_id` → `patient_insurance.id` → `patient_insurance.patient_id`; the patient-branch helper exists. This finding is read-only and no SQL was applied to production. Add a tracked source migration and PostgreSQL 17 synthetic cross-branch regression before any production change.

The original 93-row snapshot had 92/93 normalized source matches. The current 97-entry live ledger has 96/97 exact source matches, with the single remaining entry intentionally redacted because it contains an environment-specific Auth identity link. Full historical replay remains unproven because the reviewed initial schema baseline is still missing. The live Security Advisor returned 20 authenticated-callable SECURITY DEFINER warnings plus one public-schema extension warning; review individually. See the latest live continuation in [the master plan](MASTER_PLAN.md).

## Post-merge status — 2026-10-18

PR [#64](https://github.com/crauch2088-source/roshan-health-hub/pull/64) merged as `580f4a4ef6b8745eaff9eb6e7f012a1e4afdd68e` after 27/27 exact-head checks passed. It adds a source-only RLS migration and synthetic PostgreSQL 17 regression for `insurance_prior_authorizations`; the source branch was deleted. No SQL was applied to Supabase production. The live ledger remains 97 entries through `20261017133157_roshan_revoke_legacy_invoice_number_20261017`, so the three existing prior-authorization policies remain a live branch-isolation gap pending a reviewed production migration. The post-merge CI and Vercel build were still running at the last check. See [MASTER_PLAN.md](MASTER_PLAN.md) for next steps.

## 2026-10-18 continuation — focused candidates merged, not yet applied

- PR #65 merged as `ae5140f608c3f00e4dee7060408a6d5c14590675`; it adds a parent-reassignment denial regression for prior authorizations. Exact PR head passed 26/26 checks.
- PR #66 merged as `e8b9ada207eca147f586fc360275f3926721f306`; it adds the source-only `post_expense` finite-amount guard and PostgreSQL 17 regression for NaN/±Infinity/zero/negative values. Exact PR head passed 20/20 checks.
- Live read-only checks show 97 tracked migrations through `20261017133157_roshan_revoke_legacy_invoice_number_20261017`, zero rows in `patient_insurance` and `insurance_prior_authorizations`, and the three prior-authorization policies still permission-only. The live `post_expense` body also remains unchanged. No production SQL was executed for either candidate.
- Canonical Vercel deployment for `e8b9ada207eca147f586fc360275f3926721f306` reached `READY`/`PROMOTED`, alias assigned with no error.
- Release gates remain: write/read a rollback plan, reconcile migration naming/order against the live ledger, apply only after exact-target preflight, and then re-read the migration history and live function/policy catalog. Full replay remains unproven because the initial baseline is missing and one environment-specific identity-link migration is deliberately redacted.

## Live forward migrations applied — 2026-10-18

Two tested source candidates were applied to Supabase project `jewzonxplxhogqrnhosl` with explicit rollback SQL and then read back from the live catalog:

- `roshan_insurance_prior_authorization_branch_isolation` version `20261017225523`: three `insurance_prior_authorizations` RLS policies now combine the existing insurance permission with the parent-branch helper. Helper fixed search path is empty; `anon` cannot execute it; `authenticated` can. The affected table remains empty.
- `roshan_post_expense_finite_amount` version `20261017225540`: live `post_expense` now guards NULL/NaN/±Infinity/zero/negative values and retains its security-definer/search-path/execution posture. No data writes were performed by the migration.
- The live ledger has 99 entries through version `20261017225540`; both new migration names are recorded once. Rollback SQL and operational verification are in [docs/PRODUCTION_MIGRATION_ROLLBACKS_2026-10-18.md](PRODUCTION_MIGRATION_ROLLBACKS_2026-10-18.md).
- The earlier source-parity report is not current for 99 entries. Rerun the migration source-parity workflow and update the current reconciliation result. Full historical replay remains blocked by the missing reviewed initial baseline and the intentionally redacted environment-specific identity-link migration.

## Superseding live-ledger update — 2026-10-18 (101 entries)

Two additional precision migrations were applied after the 99-entry state above:

- `roshan_post_expense_money_precision` version `20261017230623`: `post_expense` now rejects any amount not representable to two decimal places, while retaining the prior finite/non-positive guards.
- `roshan_insurance_claim_money_precision` version `20261017230645`: approval/payment RPCs reject non-finite and over-precision amounts; payment storage and ledger amounts now use the same validated two-decimal value, and the claim row is selected with an exact row shape before locking.

Read-back confirms **101 ledger entries** through `20261017230645`. The current source-delta JSON and verifier cover eight later source mappings plus the frozen 93-entry hash snapshot. No claims, payments, expenses, or prior authorizations existed at preflight/postflight, and no business rows were modified by these migrations. The delta workflow validates source files and mapping metadata, not persisted SQL hashes. Full historical replay remains unproven because the initial baseline is missing and the environment-specific identity mapping remains intentionally redacted.

## Final live-ledger update — 2026-10-18 (103 entries)

Two additional forward migrations were applied and read back after the 101-entry state above:
- `roshan_invoice_payment_money_precision` version `20261017231612`: invoice payment RPC rejects non-finite/non-positive/over-precision amounts before writes, preserving branch and idempotency checks.
- `roshan_pharmacy_batch_money_precision` version `20261017231629`: pharmacy batch receipt rejects invalid quantity and purchase/effective selling price precision before inserting inventory or stock-movement rows.

The live ledger is now **103 entries** through `20261017231629`. The source delta lists ten later source files and retains the frozen 93-entry hash snapshot separately. Payments, inventory batches, stock movements, claims, claim payments, expenses, and prior authorizations remain empty; all nine medicine master price pairs have at most two decimal places. No business rows were changed. Full historical replay remains unproven because the reviewed initial schema baseline is missing and one environment-specific identity mapping is intentionally redacted.

## Post-hardening Supabase SQL security advisor review — 2026-10-18

The current SQL advisor returned 21 findings: 20 generic `SECURITY DEFINER`-callable-by-authenticated warnings and one `extension_in_public` warning for `pg_trgm`. This review distinguishes intended RPC exposure from unresolved compatibility work:

- Catalog read-back confirms all 20 authenticated-callable public `SECURITY DEFINER` RPCs have `search_path = ''`; none is executable by `anon`. App-facing functions retain their permission checks and/or explicit self/branch scope. `get_my_app_profile` is self-scoped through `auth.uid()`. `fn_calculate_insurance_coverage` retains permission and patient-branch checks.
- Repository call-site review found active usage for the atomic billing/patient/visit/lab/prescription workflows; insurance claim/coverage/status/payment flows; `get_my_app_profile`; `get_visit_form_options`; `post_cashbox_entry`; `post_expense`; `post_invoice_payment`; `post_supplier_bill`; `post_supplier_payment`; and `reverse_cashbox_entry`. The new invoice/pharmacy/expense/claim amount guards are covered by PostgreSQL 17 tests.
- No direct frontend call site was found for legacy `fn_receive_pharmacy_batch` or `fn_dispense_prescription` in the reviewed pharmacy modules; the current UI uses `fn_dispense_prescription_with_invoice`. Do **not** revoke the legacy functions yet: the existing plan gates revocation on complete pharmacy workflow, retry/idempotency, and cleanup verification.
- `pg_trgm` remains installed in `public`. Existing indexes use `gin_trgm_ops`, and historical migrations contain unqualified operator-class references. Moving the extension without a reviewed baseline and replay-safe source update could break clean replay or future index creation. Defer relocation until that compatibility work is designed and tested; this is a known advisor warning, not an unexamined failure.
- Paid-only leaked-password protection remains unavailable on the current free plan and is still explicitly unresolved.

The review does not claim full historical replay. The live ledger remains 103 entries through `20261017231629`; the ten-entry source delta verifies source/mapping metadata, not persisted SQL hashes.


## Current live/source reconciliation — 2026-10-18, after Phase 20

- The verified live ledger contains **107 entries** through `20261018064139_roshan_phase20_clinical_child_branch_isolation`. The forward-source delta has **14 mappings** above the frozen 93-entry historical hash snapshot. The source verifier validates repository-file hashes and ledger mapping metadata only; it does not query stored SQL hashes from Supabase.
- The clean clinical child branch-isolation migration is applied and read back. The next staged change is deliberately separate: add two narrowly scoped RPCs first, migrate the frontend to them, then revoke direct client DML only after the deployed UI no longer uses those writes.
- The new PostgreSQL 17 test workflow for this staged rollout passed on commit `ef6858e7eb6d7386a3e962aae4b7f51e020d36dd`. Its fixture verifies same-branch writes, cross-branch denial, permission checks, direct-DML denial, retained SELECT access, and RLS remaining enabled. The production RPC and DML-revocation migrations are still **not applied** at this point.
- Full historical replay remains unproven because the reviewed initial schema baseline is missing and one environment-specific identity-link migration remains deliberately redacted.






## Current live/source reconciliation — after Phase 29, 2026-10-18

- Live Supabase ledger: **109 entries** through `20261018065708_roshan_clinical_child_rpc_only_writes`. The forward-source delta has **16 mappings** above the frozen 93-entry historical snapshot. Repository-source hashes are verified; the Supabase API does not expose persisted live SQL hashes, and full historical replay remains unproven.
- Phase 28 RPCs remain live with fixed empty `search_path`, permission/branch guards, and authenticated-only execution.
- Phase 29 is applied and verified: direct INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER privileges are false for `authenticated` on `prescriptions`, `prescription_items`, `patient_discounts`, and `insurance_prior_authorizations`; SELECT remains true and RLS remains enabled. The four tables remain empty.
- `lab_order_items` and `medical_certificates` intentionally retain their current authenticated direct-write grants until the new frontend is deployed. The canonical production alias has not been switched because the free Vercel API deployment quota is exhausted; no preview build was promoted because preview environment variables may differ. Phase 30 remains gated.


## Read-only global access-control audit — 2026-10-18

- **56/56** public base tables have RLS enabled; **44/56** also force RLS. No public base table grants SELECT, INSERT, UPDATE, or DELETE to `anon`.
- The current catalog contains **47 public and 34 private SECURITY DEFINER routines**. All 81 have an explicit fixed `search_path`; no public SECURITY DEFINER routine is executable by `anon`.
- Two private functions inherit default PUBLIC EXECUTE: `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()`. The `private` schema does not grant USAGE to `anon`, so these are not callable through the anonymous API role. The former is used by authenticated branch-aware policies; the latter is a trigger function. This was a read-only audit; no ACL changes were made to these helpers.
