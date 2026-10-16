# Supabase migration reconciliation inventory

**Snapshot date:** 2026-10-16  
**Target:** Connected Roshan Health Hub Supabase project (read-only inventory)  
**Applied migration rows returned:** 79  
**Committed SQL files in `db/` on `main`:** 10  
**Exact basename matches:** 4  
**Exact basename matches do not prove full semantic equivalence.** No migration was applied, rolled back, or edited in the database during this inventory.

## Purpose and safety

This file records the live migration version/name list so source reconciliation can proceed deterministically. It is not a replayable migration chain and must not be used to bootstrap a new database. The `main` branch has no `supabase/` directory, so the current repo layout does not provide a canonical timestamped migration sequence. A same-name SQL file is only a candidate source until its full content is compared with the deployed migration effects.

Do not reconstruct missing migrations from guessed SQL, do not mark partial filename matches as exact, and do not test replay against production. Recover exact source content from Git history, deployment artifacts, or Supabase migration history where available; then validate the ordered chain in a disposable environment.

## Live applied migration inventory

| Live version | Live migration name | Repository mapping |
|---|---|---|
| 20260818162003 | `fix_duplicate_unique_constraint` | Not exact-matched; source mapping pending |
| 20260818191254 | `fix_patients_rls_and_admin_link` | Not exact-matched; source mapping pending |
| 20260818191556 | `install_safe_visit_number_function` | Not exact-matched; source mapping pending |
| 20260818192452 | `fix_daily_queue_numbers_v4` | Not exact-matched; source mapping pending |
| 20260818194104 | `fix_daily_queue_numbering` | Not exact-matched; source mapping pending |
| 20260818194429 | `repair_queue_and_harden_queue_security` | Not exact-matched; source mapping pending |
| 20260818194457 | `consolidate_queue_triggers` | Not exact-matched; source mapping pending |
| 20260818195753 | `fix_visit_queue_numbering` | Not exact-matched; source mapping pending |
| 20260818195811 | `sync_existing_queue_tickets` | Not exact-matched; source mapping pending |
| 20260818200206 | `fix_queue_numbering_authoritative` | Not exact-matched; source mapping pending |
| 20260818200246 | `harden_visit_queue_rls_and_cleanup` | Not exact-matched; source mapping pending |
| 20260818200336 | `finalize_non_recycling_queue_allocator` | Not exact-matched; source mapping pending |
| 20260818202356 | `fix_appointments_rls_auth_and_audit` | Not exact-matched; source mapping pending |
| 20260818232848 | `harden_core_indexes_and_legacy_compatibility_v2` | Not exact-matched; source mapping pending |
| 20260818233558 | `harden_security_definer_helpers_and_duplicate_index_v2` | Not exact-matched; source mapping pending |
| 20260818234039 | `harden_rls_permissions_and_public_grants_v1` | Not exact-matched; source mapping pending |
| 20260818234050 | `harden_services_rls_v1` | Not exact-matched; source mapping pending |
| 20260818234146 | `repair_roshan_rbac_role_links_v1` | Not exact-matched; source mapping pending |
| 20260819000003 | `harden_public_defaults_and_sync_user_roles` | Not exact-matched; source mapping pending |
| 20260819000016 | `tighten_public_default_privileges` | Not exact-matched; source mapping pending |
| 20260819100756 | `roshan_phase1_pagination_and_settings` | Exact basename: `db/roshan_phase1_pagination_and_settings.sql` |
| 20260819105146 | `roshan_settings_public_enforcement` | Not exact-matched; source mapping pending |
| 20260819123920 | `grant_authenticated_execute_next_mrn` | Not exact-matched; source mapping pending |
| 20260819124045 | `fix_next_mrn_rpc_access` | Not exact-matched; source mapping pending |
| 20260819125755 | `add_missing_audit_relationships` | Not exact-matched; source mapping pending |
| 20260819125807 | `add_followups_users_computed_relationship` | Not exact-matched; source mapping pending |
| 20260819130039 | `compat_patients_patient_number` | Not exact-matched; source mapping pending |
| 20260819222434 | `add_prescription_ux_fields` | Not exact-matched; source mapping pending |
| 20260819223342 | `add_medical_certificates_soft_delete_columns` | Not exact-matched; source mapping pending |
| 20260820000007 | `add_medicines_2_stock_quantity_compatibility` | Not exact-matched; source mapping pending |
| 20260820000143 | `add_medicines_2_stock_quantity` | Not exact-matched; source mapping pending |
| 20260820000336 | `fix_medicines_stock_quantity_schema_cache` | Not exact-matched; source mapping pending |
| 20260820000656 | `add_medicines_reorder_level` | Not exact-matched; source mapping pending |
| 20260820000725 | `add_medicines_expiry_date` | Not exact-matched; source mapping pending |
| 20260820005417 | `fix_followups_user_relationship` | Not exact-matched; source mapping pending |
| 20260820010030 | `fix_medicines_batch_number` | Not exact-matched; source mapping pending |
| 20260820150215 | `roshan_phase2_clinical_workflow` | Exact basename: `db/roshan_phase2_clinical_workflow.sql` |
| 20260822094358 | `roshan_workflow_performance_20260822` | Not exact-matched; source mapping pending |
| 20260822094405 | `roshan_drop_duplicate_prescription_index_20260822` | Not exact-matched; source mapping pending |
| 20260906142737 | `roshan_phase3_allow_pharmacy_setting_public` | Not exact-matched; source mapping pending |
| 20260906142803 | `roshan_phase3_pharmacy_batches` | Not exact-matched; source mapping pending |
| 20260906144008 | `roshan_phase4_finance_cashbox_debts` | Not exact-matched; source mapping pending |
| 20260906161023 | `roshan_phase4_finance_security_verification_patch` | Not exact-matched; source mapping pending |
| 20260906203143 | `roshan_phase3_pharmacy_runtime_hardening` | Not exact-matched; source mapping pending |
| 20260908210824 | `roshan_phase4_finance_v2` | Partial mapping; live effective-state audit recorded below |
| 20260909110657 | `roshan_phase5_insurance` | Exact basename; 20 normalized statements match the legacy Phase 5 script |
| 20260909110735 | `roshan_phase5_insurance_functions` | Partial candidate; 3 normalized statements match the legacy Phase 5 script |
| 20260909110753 | `roshan_phase5_insurance_permissions_rls` | Partial candidate; 27 normalized statements match the legacy Phase 5 script |
| 20260911120231 | `roshan_phase12_invoice_visit_unique` | Exact basename: `db/roshan_phase12_invoice_visit_unique.sql` |
| 20260911130749 | `harden_security_and_fk_indexes_20260911` | Not exact-matched; source mapping pending |
| 20260911130812 | `restrict_security_definer_api_execution_20260911` | Not exact-matched; source mapping pending |
| 20260911131456 | `deep_audit_branch_isolation_rpc_hardening` | Not exact-matched; source mapping pending |
| 20260911133229 | `harden_mrn_invoice_number_concurrency` | Not exact-matched; source mapping pending |
| 20260911133255 | `enforce_branch_isolation_rls` | Not exact-matched; source mapping pending |
| 20260911133312 | `harden_insurance_branch_isolation` | Not exact-matched; source mapping pending |
| 20260911133319 | `harden_insurance_coverage_rpc_branch` | Later override of the coverage function; adds explicit branch isolation |
| 20260911133334 | `harden_finance_branch_context` | Not exact-matched; source mapping pending |
| 20260911133353 | `fix_insurance_ledger_branch` | Not exact-matched; source mapping pending |
| 20260911134639 | `grant_next_invoice_number_authenticated` | Not exact-matched; source mapping pending |
| 20260911135036 | `grant_stock_movements_authenticated_access` | Not exact-matched; source mapping pending |
| 20260911135318 | `fix_dispense_prescription_nullable_join_lock` | Not exact-matched; source mapping pending |
| 20260911135417 | `fix_dispense_prescription_branch_resolution` | Not exact-matched; source mapping pending |
| 20260911135547 | `fix_dispense_batch_number_ambiguity` | Not exact-matched; source mapping pending |
| 20260911135644 | `add_medicines_updated_at_column` | Not exact-matched; source mapping pending |
| 20260911135738 | `add_prescription_items_updated_at` | Not exact-matched; source mapping pending |
| 20260911135858 | `add_prescriptions_updated_at` | Not exact-matched; source mapping pending |
| 20260911140337 | `add_cashbox_reversal_columns` | Not exact-matched; source mapping pending |
| 20260911140514 | `allow_cashbox_reversal_transaction_type` | Not exact-matched; source mapping pending |
| 20260911141036 | `harden_cashbox_reversal_type` | Not exact-matched; source mapping pending |
| 20260911141142 | `fix_payment_ledger_transaction_type` | Not exact-matched; source mapping pending |
| 20260911141502 | `fix_medicines_generic_name_compatibility` | Not exact-matched; source mapping pending |
| 20261011074344 | `harden_patient_invoice_number_rpc_permissions` | Not exact-matched; source mapping pending |
| 20261011074437 | `harden_insurance_coverage_rpc_permissions` | Later override of the coverage function; adds permission check and empty search_path |
| 20261011075101 | `harden_pharmacy_batch_branch_isolation` | Not exact-matched; source mapping pending |
| 20261011080253 | `harden_supplier_bill_rpc_branch_and_search_path` | Not exact-matched; source mapping pending |
| 20261011080319 | `harden_finance_pharmacy_rpc_search_paths` | Not exact-matched; source mapping pending |
| 20261011080434 | `enforce_branch_isolation_on_clinical_child_tables` | Not exact-matched; source mapping pending |
| 20261011080524 | `preserve_super_admin_supplier_bill_compatibility` | Not exact-matched; source mapping pending |
| 20261014164131 | `roshan_cashbox_reversal_concurrency` | Not exact-matched; source mapping pending |

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
