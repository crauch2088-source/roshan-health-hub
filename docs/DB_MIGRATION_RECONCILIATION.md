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
| 20260909110657 | `roshan_phase5_insurance` | Exact basename: `db/roshan_phase5_insurance.sql` |
| 20260909110735 | `roshan_phase5_insurance_functions` | Not exact-matched; source mapping pending |
| 20260909110753 | `roshan_phase5_insurance_permissions_rls` | Not exact-matched; source mapping pending |
| 20260911120231 | `roshan_phase12_invoice_visit_unique` | Exact basename: `db/roshan_phase12_invoice_visit_unique.sql` |
| 20260911130749 | `harden_security_and_fk_indexes_20260911` | Not exact-matched; source mapping pending |
| 20260911130812 | `restrict_security_definer_api_execution_20260911` | Not exact-matched; source mapping pending |
| 20260911131456 | `deep_audit_branch_isolation_rpc_hardening` | Not exact-matched; source mapping pending |
| 20260911133229 | `harden_mrn_invoice_number_concurrency` | Not exact-matched; source mapping pending |
| 20260911133255 | `enforce_branch_isolation_rls` | Not exact-matched; source mapping pending |
| 20260911133312 | `harden_insurance_branch_isolation` | Not exact-matched; source mapping pending |
| 20260911133319 | `harden_insurance_coverage_rpc_branch` | Not exact-matched; source mapping pending |
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
| 20261011074437 | `harden_insurance_coverage_rpc_permissions` | Not exact-matched; source mapping pending |
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
