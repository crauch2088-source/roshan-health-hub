# Consolidated live migration source/disposition matrix — 2026-11-10

**Captured against Main:** `e1153f3fff07b75d93ac983d7a8a640d1b9236ab`

## Executive result

| Measure | Production | QA |
|---|---:|---:|
| Live ledger rows | 129 | 22 |
| Rows with a source path or explicit disposition | 129 | 22 |
| Latest migration | `20261102232941` — `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | `20261104065852` — `roshan_phase57_pharmacy_quantity_required_guard` |

All current rows now have a row-level source path or explicit non-replayable/environment-specific disposition. This closes **mapping coverage**, not semantic parity or migration-chain replayability.

## Production — 129 rows

| Version | Migration | Source/disposition | Evidence class |
|---|---|---|---|
| `20260818162003` | `fix_duplicate_unique_constraint` | `docs/recovered-migrations/sql/20260818162003_fix_duplicate_unique_constraint.sql` | normalized-source-text-match |
| `20260818191254` | `fix_patients_rls_and_admin_link` | `docs/recovered-migrations/sql/20260818191254_fix_patients_rls_and_admin_link.sql` | not-proven-match |
| `20260818191556` | `install_safe_visit_number_function` | `docs/recovered-migrations/sql/20260818191556_install_safe_visit_number_function.sql` | normalized-source-text-match |
| `20260818192452` | `fix_daily_queue_numbers_v4` | `docs/recovered-migrations/sql/20260818192452_fix_daily_queue_numbers_v4.sql` | normalized-source-text-match |
| `20260818194104` | `fix_daily_queue_numbering` | `docs/recovered-migrations/sql/20260818194104_fix_daily_queue_numbering.sql` | normalized-source-text-match |
| `20260818194429` | `repair_queue_and_harden_queue_security` | `docs/recovered-migrations/sql/20260818194429_repair_queue_and_harden_queue_security.sql` | normalized-source-text-match |
| `20260818194457` | `consolidate_queue_triggers` | `docs/recovered-migrations/sql/20260818194457_consolidate_queue_triggers.sql` | normalized-source-text-match |
| `20260818195753` | `fix_visit_queue_numbering` | `docs/recovered-migrations/sql/20260818195753_fix_visit_queue_numbering.sql` | normalized-source-text-match |
| `20260818195811` | `sync_existing_queue_tickets` | `docs/recovered-migrations/sql/20260818195811_sync_existing_queue_tickets.sql` | normalized-source-text-match |
| `20260818200206` | `fix_queue_numbering_authoritative` | `docs/recovered-migrations/sql/20260818200206_fix_queue_numbering_authoritative.sql` | normalized-source-text-match |
| `20260818200246` | `harden_visit_queue_rls_and_cleanup` | `docs/recovered-migrations/sql/20260818200246_harden_visit_queue_rls_and_cleanup.sql` | normalized-source-text-match |
| `20260818200336` | `finalize_non_recycling_queue_allocator` | `docs/recovered-migrations/sql/20260818200336_finalize_non_recycling_queue_allocator.sql` | normalized-source-text-match |
| `20260818202356` | `fix_appointments_rls_auth_and_audit` | `docs/recovered-migrations/sql/20260818202356_fix_appointments_rls_auth_and_audit.sql` | normalized-source-text-match |
| `20260818232848` | `harden_core_indexes_and_legacy_compatibility_v2` | `docs/recovered-migrations/sql/20260818232848_harden_core_indexes_and_legacy_compatibility_v2.sql` | normalized-source-text-match |
| `20260818233558` | `harden_security_definer_helpers_and_duplicate_index_v2` | `docs/recovered-migrations/sql/20260818233558_harden_security_definer_helpers_and_duplicate_index_v2.sql` | normalized-source-text-match |
| `20260818234039` | `harden_rls_permissions_and_public_grants_v1` | `docs/recovered-migrations/sql/20260818234039_harden_rls_permissions_and_public_grants_v1.sql` | normalized-source-text-match |
| `20260818234050` | `harden_services_rls_v1` | `docs/recovered-migrations/sql/20260818234050_harden_services_rls_v1.sql` | normalized-source-text-match |
| `20260818234146` | `repair_roshan_rbac_role_links_v1` | `docs/recovered-migrations/sql/20260818234146_repair_roshan_rbac_role_links_v1.sql` | normalized-source-text-match |
| `20260819000003` | `harden_public_defaults_and_sync_user_roles` | `docs/recovered-migrations/sql/20260819000003_harden_public_defaults_and_sync_user_roles.sql` | normalized-source-text-match |
| `20260819000016` | `tighten_public_default_privileges` | `docs/recovered-migrations/sql/20260819000016_tighten_public_default_privileges.sql` | normalized-source-text-match |
| `20260819100756` | `roshan_phase1_pagination_and_settings` | `docs/recovered-migrations/sql/20260819100756_roshan_phase1_pagination_and_settings.sql` | normalized-source-text-match |
| `20260819105146` | `roshan_settings_public_enforcement` | `docs/recovered-migrations/sql/20260819105146_roshan_settings_public_enforcement.sql` | normalized-source-text-match |
| `20260819123920` | `grant_authenticated_execute_next_mrn` | `docs/recovered-migrations/sql/20260819123920_grant_authenticated_execute_next_mrn.sql` | normalized-source-text-match |
| `20260819124045` | `fix_next_mrn_rpc_access` | `docs/recovered-migrations/sql/20260819124045_fix_next_mrn_rpc_access.sql` | normalized-source-text-match |
| `20260819125755` | `add_missing_audit_relationships` | `docs/recovered-migrations/sql/20260819125755_add_missing_audit_relationships.sql` | normalized-source-text-match |
| `20260819125807` | `add_followups_users_computed_relationship` | `docs/recovered-migrations/sql/20260819125807_add_followups_users_computed_relationship.sql` | normalized-source-text-match |
| `20260819130039` | `compat_patients_patient_number` | `docs/recovered-migrations/sql/20260819130039_compat_patients_patient_number.sql` | normalized-source-text-match |
| `20260819222434` | `add_prescription_ux_fields` | `docs/recovered-migrations/sql/20260819222434_add_prescription_ux_fields.sql` | normalized-source-text-match |
| `20260819223342` | `add_medical_certificates_soft_delete_columns` | `docs/recovered-migrations/sql/20260819223342_add_medical_certificates_soft_delete_columns.sql` | normalized-source-text-match |
| `20260820000007` | `add_medicines_2_stock_quantity_compatibility` | `docs/recovered-migrations/sql/20260820000007_add_medicines_2_stock_quantity_compatibility.sql` | normalized-source-text-match |
| `20260820000143` | `add_medicines_2_stock_quantity` | `docs/recovered-migrations/sql/20260820000143_add_medicines_2_stock_quantity.sql` | normalized-source-text-match |
| `20260820000336` | `fix_medicines_stock_quantity_schema_cache` | `docs/recovered-migrations/sql/20260820000336_fix_medicines_stock_quantity_schema_cache.sql` | normalized-source-text-match |
| `20260820000656` | `add_medicines_reorder_level` | `docs/recovered-migrations/sql/20260820000656_add_medicines_reorder_level.sql` | normalized-source-text-match |
| `20260820000725` | `add_medicines_expiry_date` | `docs/recovered-migrations/sql/20260820000725_add_medicines_expiry_date.sql` | normalized-source-text-match |
| `20260820005417` | `fix_followups_user_relationship` | `docs/recovered-migrations/sql/20260820005417_fix_followups_user_relationship.sql` | normalized-source-text-match |
| `20260820010030` | `fix_medicines_batch_number` | `docs/recovered-migrations/sql/20260820010030_fix_medicines_batch_number.sql` | normalized-source-text-match |
| `20260820150215` | `roshan_phase2_clinical_workflow` | `docs/recovered-migrations/sql/20260820150215_roshan_phase2_clinical_workflow.sql` | normalized-source-text-match |
| `20260822094358` | `roshan_workflow_performance_20260822` | `docs/recovered-migrations/sql/20260822094358_roshan_workflow_performance_20260822.sql` | normalized-source-text-match |
| `20260822094405` | `roshan_drop_duplicate_prescription_index_20260822` | `docs/recovered-migrations/sql/20260822094405_roshan_drop_duplicate_prescription_index_20260822.sql` | normalized-source-text-match |
| `20260906142737` | `roshan_phase3_allow_pharmacy_setting_public` | `docs/recovered-migrations/sql/20260906142737_roshan_phase3_allow_pharmacy_setting_public.sql` | normalized-source-text-match |
| `20260906142803` | `roshan_phase3_pharmacy_batches` | `docs/recovered-migrations/sql/20260906142803_roshan_phase3_pharmacy_batches.sql` | normalized-source-text-match |
| `20260906144008` | `roshan_phase4_finance_cashbox_debts` | `docs/recovered-migrations/sql/20260906144008_roshan_phase4_finance_cashbox_debts.sql` | normalized-source-text-match |
| `20260906161023` | `roshan_phase4_finance_security_verification_patch` | `docs/recovered-migrations/sql/20260906161023_roshan_phase4_finance_security_verification_patch.sql` | normalized-source-text-match |
| `20260906203143` | `roshan_phase3_pharmacy_runtime_hardening` | `docs/recovered-migrations/sql/20260906203143_roshan_phase3_pharmacy_runtime_hardening.sql` | normalized-source-text-match |
| `20260908210824` | `roshan_phase4_finance_v2` | `docs/recovered-migrations/sql/20260908210824_roshan_phase4_finance_v2.sql` | normalized-source-text-match |
| `20260909110657` | `roshan_phase5_insurance` | `docs/recovered-migrations/sql/20260909110657_roshan_phase5_insurance.sql` | normalized-source-text-match |
| `20260909110735` | `roshan_phase5_insurance_functions` | `docs/recovered-migrations/sql/20260909110735_roshan_phase5_insurance_functions.sql` | normalized-source-text-match |
| `20260909110753` | `roshan_phase5_insurance_permissions_rls` | `docs/recovered-migrations/sql/20260909110753_roshan_phase5_insurance_permissions_rls.sql` | normalized-source-text-match |
| `20260911120231` | `roshan_phase12_invoice_visit_unique` | `docs/recovered-migrations/sql/20260911120231_roshan_phase12_invoice_visit_unique.sql` | normalized-source-text-match |
| `20260911130749` | `harden_security_and_fk_indexes_20260911` | `docs/recovered-migrations/sql/20260911130749_harden_security_and_fk_indexes_20260911.sql` | normalized-source-text-match |
| `20260911130812` | `restrict_security_definer_api_execution_20260911` | `docs/recovered-migrations/sql/20260911130812_restrict_security_definer_api_execution_20260911.sql` | normalized-source-text-match |
| `20260911131456` | `deep_audit_branch_isolation_rpc_hardening` | `docs/recovered-migrations/sql/20260911131456_deep_audit_branch_isolation_rpc_hardening.sql` | normalized-source-text-match |
| `20260911133229` | `harden_mrn_invoice_number_concurrency` | `docs/recovered-migrations/sql/20260911133229_harden_mrn_invoice_number_concurrency.sql` | normalized-source-text-match |
| `20260911133255` | `enforce_branch_isolation_rls` | `docs/recovered-migrations/sql/20260911133255_enforce_branch_isolation_rls.sql` | normalized-source-text-match |
| `20260911133312` | `harden_insurance_branch_isolation` | `docs/recovered-migrations/sql/20260911133312_harden_insurance_branch_isolation.sql` | normalized-source-text-match |
| `20260911133319` | `harden_insurance_coverage_rpc_branch` | `docs/recovered-migrations/sql/20260911133319_harden_insurance_coverage_rpc_branch.sql` | normalized-source-text-match |
| `20260911133334` | `harden_finance_branch_context` | `docs/recovered-migrations/sql/20260911133334_harden_finance_branch_context.sql` | normalized-source-text-match |
| `20260911133353` | `fix_insurance_ledger_branch` | `docs/recovered-migrations/sql/20260911133353_fix_insurance_ledger_branch.sql` | normalized-source-text-match |
| `20260911134639` | `grant_next_invoice_number_authenticated` | `docs/recovered-migrations/sql/20260911134639_grant_next_invoice_number_authenticated.sql` | normalized-source-text-match |
| `20260911135036` | `grant_stock_movements_authenticated_access` | `docs/recovered-migrations/sql/20260911135036_grant_stock_movements_authenticated_access.sql` | normalized-source-text-match |
| `20260911135318` | `fix_dispense_prescription_nullable_join_lock` | `docs/recovered-migrations/sql/20260911135318_fix_dispense_prescription_nullable_join_lock.sql` | normalized-source-text-match |
| `20260911135417` | `fix_dispense_prescription_branch_resolution` | `docs/recovered-migrations/sql/20260911135417_fix_dispense_prescription_branch_resolution.sql` | normalized-source-text-match |
| `20260911135547` | `fix_dispense_batch_number_ambiguity` | `docs/recovered-migrations/sql/20260911135547_fix_dispense_batch_number_ambiguity.sql` | normalized-source-text-match |
| `20260911135644` | `add_medicines_updated_at_column` | `docs/recovered-migrations/sql/20260911135644_add_medicines_updated_at_column.sql` | normalized-source-text-match |
| `20260911135738` | `add_prescription_items_updated_at` | `docs/recovered-migrations/sql/20260911135738_add_prescription_items_updated_at.sql` | normalized-source-text-match |
| `20260911135858` | `add_prescriptions_updated_at` | `docs/recovered-migrations/sql/20260911135858_add_prescriptions_updated_at.sql` | normalized-source-text-match |
| `20260911140337` | `add_cashbox_reversal_columns` | `docs/recovered-migrations/sql/20260911140337_add_cashbox_reversal_columns.sql` | normalized-source-text-match |
| `20260911140514` | `allow_cashbox_reversal_transaction_type` | `docs/recovered-migrations/sql/20260911140514_allow_cashbox_reversal_transaction_type.sql` | normalized-source-text-match |
| `20260911141036` | `harden_cashbox_reversal_type` | `docs/recovered-migrations/sql/20260911141036_harden_cashbox_reversal_type.sql` | normalized-source-text-match |
| `20260911141142` | `fix_payment_ledger_transaction_type` | `docs/recovered-migrations/sql/20260911141142_fix_payment_ledger_transaction_type.sql` | normalized-source-text-match |
| `20260911141502` | `fix_medicines_generic_name_compatibility` | `docs/recovered-migrations/sql/20260911141502_fix_medicines_generic_name_compatibility.sql` | normalized-source-text-match |
| `20261011074344` | `harden_patient_invoice_number_rpc_permissions` | `docs/recovered-migrations/sql/20261011074344_harden_patient_invoice_number_rpc_permissions.sql` | normalized-source-text-match |
| `20261011074437` | `harden_insurance_coverage_rpc_permissions` | `docs/recovered-migrations/sql/20261011074437_harden_insurance_coverage_rpc_permissions.sql` | normalized-source-text-match |
| `20261011075101` | `harden_pharmacy_batch_branch_isolation` | `docs/recovered-migrations/sql/20261011075101_harden_pharmacy_batch_branch_isolation.sql` | normalized-source-text-match |
| `20261011080253` | `harden_supplier_bill_rpc_branch_and_search_path` | `docs/recovered-migrations/sql/20261011080253_harden_supplier_bill_rpc_branch_and_search_path.sql` | normalized-source-text-match |
| `20261011080319` | `harden_finance_pharmacy_rpc_search_paths` | `docs/recovered-migrations/sql/20261011080319_harden_finance_pharmacy_rpc_search_paths.sql` | normalized-source-text-match |
| `20261011080434` | `enforce_branch_isolation_on_clinical_child_tables` | `docs/recovered-migrations/sql/20261011080434_enforce_branch_isolation_on_clinical_child_tables.sql` | normalized-source-text-match |
| `20261011080524` | `preserve_super_admin_supplier_bill_compatibility` | `docs/recovered-migrations/sql/20261011080524_preserve_super_admin_supplier_bill_compatibility.sql` | normalized-source-text-match |
| `20261014164131` | `roshan_cashbox_reversal_concurrency` | `docs/recovered-migrations/sql/20261014164131_roshan_cashbox_reversal_concurrency.sql` | normalized-source-text-match |
| `20261016161923` | `roshan_phase18_dedupe_finance_audit_triggers_20261016` | `db/roshan_phase18_dedupe_finance_audit_triggers.sql` | normalized-source-text-match |
| `20261016162410` | `roshan_phase21_patient_registration_atomicity_20261016` | `db/roshan_phase21_patient_registration_atomicity.sql` | normalized-source-text-match |
| `20261016170816` | `roshan_security_privileged_role_guard_20261016` | `db/roshan_security_privileged_role_guard.sql` | normalized-source-text-match |
| `20261016172209` | `roshan_phase7_atomic_prescription_20261016` | `db/roshan_phase7_atomic_prescription.sql` | normalized-source-text-match |
| `20261016183123` | `roshan_phase8_atomic_invoice` | `db/roshan_phase8_atomic_invoice.sql` | normalized-source-text-match |
| `20261016183130` | `roshan_phase13_consolidated_visit_invoice` | `db/roshan_phase13_consolidated_visit_invoice.sql` | normalized-source-text-match |
| `20261016183136` | `roshan_phase14_dispense_invoice_atomic_compat` | `db/roshan_phase14_dispense_invoice_atomic.sql` | normalized-source-text-match |
| `20261016183145` | `roshan_phase15_manual_invoice_consolidation` | `db/roshan_phase15_manual_invoice_consolidation.sql` | normalized-source-text-match |
| `20261016183152` | `roshan_phase16_billing_idempotency` | `db/roshan_phase16_billing_idempotency.sql` | normalized-source-text-match |
| `20261016204859` | `roshan_phase21_patient_registration_privileges_20261016` | `db/roshan_phase21_patient_registration_privileges.sql` | normalized-source-text-match |
| `20261016211342` | `roshan_phase22_clinic_local_queue_date_20261016` | `db/roshan_phase22_clinic_local_queue_date.sql` | normalized-source-text-match |
| `20261016215806` | `roshan_phase23_legacy_queue_allocator_20261016` | `db/roshan_phase23_legacy_queue_allocator_20261016.sql` | normalized-source-text-match |
| `20261016221553` | `roshan_phase24_visit_form_options_20261016` | `db/roshan_phase24_visit_form_options.sql` | normalized-source-text-match |
| `20261016222009` | `roshan_phase25_current_app_profile_20261016` | `db/roshan_phase25_current_app_profile.sql` | normalized-source-text-match |
| `20261017125924` | `roshan_security_candidate_bundle_20261017` | `db/roshan_security_candidate_bundle_20261017.sql` | source-hash-only |
| `20261017125934` | `roshan_insurance_claim_amount_integrity_20261017` | `db/roshan_phase5_insurance_claim_amount_integrity.sql` | source-hash-only |
| `20261017125936` | `roshan_insurance_coverage_validity_20261017` | `db/roshan_phase5_insurance_coverage_validity.sql` | source-hash-only |
| `20261017133157` | `roshan_revoke_legacy_invoice_number_20261017` | `db/roshan_phase27_revoke_legacy_invoice_number.sql` | source-hash-only |
| `20261017225523` | `roshan_insurance_prior_authorization_branch_isolation` | `db/roshan_insurance_prior_authorization_branch_isolation.sql` | source-hash-only |
| `20261017225540` | `roshan_post_expense_finite_amount` | `db/roshan_post_expense_finite_amount.sql` | source-hash-only |
| `20261017230623` | `roshan_post_expense_money_precision` | `db/roshan_post_expense_money_precision.sql` | source-hash-only |
| `20261017230645` | `roshan_insurance_claim_money_precision` | `db/roshan_insurance_claim_money_precision.sql` | source-hash-only |
| `20261017231612` | `roshan_invoice_payment_money_precision` | `db/roshan_invoice_payment_money_precision.sql` | source-hash-only |
| `20261017231629` | `roshan_pharmacy_batch_money_precision` | `db/roshan_pharmacy_batch_money_precision.sql` | source-hash-only |
| `20261018061746` | `roshan_pharmacy_batch_receipt_idempotency` | `db/roshan_pharmacy_batch_receipt_idempotency.sql` | source-hash-only |
| `20261018062939` | `roshan_pharmacy_batch_receipt_guards` | `db/roshan_pharmacy_batch_receipt_guards.sql` | source-hash-only |
| `20261018063549` | `roshan_phase19_invoice_rpc_only_writes` | `db/roshan_phase19_invoice_rpc_only_writes.sql` | source-hash-only |
| `20261018064139` | `roshan_phase20_clinical_child_branch_isolation` | `db/roshan_phase20_clinical_child_branch_isolation.sql` | source-hash-only |
| `20261018064638` | `roshan_clinical_child_write_rpcs` | `db/roshan_phase28_clinical_child_write_rpcs.sql` | source-hash-only |
| `20261018065708` | `roshan_clinical_child_rpc_only_writes` | `db/roshan_phase29_clinical_child_rpc_only_writes.sql` | source-hash-only |
| `20261018201642` | `roshan_phase31_clinical_financial_security_hardening` | `db/roshan_phase31_clinical_financial_security_hardening.sql` | source-hash-only |
| `20261018201758` | `roshan_phase31_contract_security_cutover` | `db/roshan_phase31_contract_security_cutover.sql` | source-hash-only |
| `20261019061315` | `roshan_phase32_medical_certificate_visit_index` | `db/roshan_phase32_medical_certificate_visit_index.sql` | source-hash-only |
| `20261020090350` | `roshan_phase34_storage_guard_lab_verify_realtime` | `db/roshan_phase34_consolidated_storage_realtime_and_lab_verify.sql` | source-hash-only |
| `20261020111126` | `roshan_phase36_audit_coverage_and_visit_lifecycle_guards` | `db/roshan_phase36_audit_coverage_and_visit_lifecycle_guards.sql` | source-hash-only |
| `20261020232033` | `roshan_phase39_permissions_lab_catalog_and_audit_closure` | `db/roshan_phase39_permissions_lab_catalog_and_audit_closure.sql` | source-hash-only |
| `20261031071119` | `roshan_phase46_uat_schema_compatibility` | `db/roshan_phase46_uat_schema_compatibility.sql` | selected-direct-match-or-exact-source |
| `20261031071122` | `roshan_phase47_queue_branch_attribution` | `db/roshan_phase47_queue_branch_attribution.sql` | selected-direct-match-or-exact-source |
| `20261031103927` | `roshan_phase48_storage_entity_branch_binding` | `db/roshan_phase48_storage_entity_branch_binding.sql` | selected-direct-match-or-exact-source |
| `20261102122437` | `superseded_placeholder_phase49_atomic_pharmacy_dispense` | `No SQL source` | path-or-disposition-only |
| `20261102133658` | `superseded_placeholder_phase50_clinical_visit_bill_completion` | `No SQL source` | path-or-disposition-only |
| `20261102133734` | `superseded_placeholder_phase51_public_setup_required_anon` | `No SQL source` | path-or-disposition-only |
| `20261102140000` | `superseded_placeholder_phase52_reporting_analytics` | `No SQL source` | path-or-disposition-only |
| `20261102232813` | `roshan_remediation_archive_container` | `No tracked forward source` | path-or-disposition-only |
| `20261102232819` | `roshan_phase49_isolate_malformed_idempotency_table` | `docs/recovered-migrations/sql/20261102232819_roshan_phase49_isolate_malformed_idempotency_table.sql` | selected-direct-match-or-exact-source |
| `20261102232823` | `roshan_phase49_atomic_pharmacy_dispense_repaired` | `db/roshan_phase49_atomic_pharmacy_dispense.sql` | path-or-disposition-only |
| `20261102232849` | `roshan_phase50_clinical_visit_bill_completion_reconciled` | `db/roshan_phase50_clinical_visit_bill_completion.sql` | path-or-disposition-only |
| `20261102232852` | `roshan_phase51_public_setup_required_anon_reconciled` | `db/roshan_phase51_public_setup_required_anon.sql` | path-or-disposition-only |
| `20261102232855` | `roshan_phase52_reporting_analytics_reconciled` | `db/roshan_phase52_reporting_analytics.sql` | path-or-disposition-only |
| `20261102232941` | `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | `docs/recovered-migrations/sql/20261102232941_roshan_synthetic_patient_cleanup_and_stock_ledger_reversal.sql` | path-or-disposition-only |

## QA — 22 rows

| Version | Migration | Source/disposition | Evidence |
|---|---|---|---|
| `20261023182629` | `qa_schema_baseline_v112_platform_preserving` | `db/baseline/0000_roshan_pg17_baseline_v112.sql (related baseline only)` | No exact source/body equality claimed; QA-specific platform-preserving baseline |
| `20261023182742` | `roshan_phase34_consolidated_storage_realtime_lab_verify` | `db/roshan_phase34_consolidated_storage_realtime_and_lab_verify.sql` | Historical source-path mapping; no independent stored-body hash |
| `20261023182746` | `roshan_phase36_audit_coverage_and_visit_lifecycle_guards` | `db/roshan_phase36_audit_coverage_and_visit_lifecycle_guards.sql` | Source path present; no independent stored-body hash |
| `20261023182750` | `roshan_phase39_permissions_lab_catalog_and_audit_closure` | `db/roshan_phase39_permissions_lab_catalog_and_audit_closure.sql` | Source path present; no independent stored-body hash |
| `20261023182756` | `roshan_phase45_atomic_visit_queue_completion_retry` | `db/roshan_phase45_atomic_visit_queue_completion_retry.sql` | Source path present; no independent stored-body hash |
| `20261023182855` | `qa_phase31_contract_security_cutover` | `db/roshan_phase31_contract_security_cutover.sql` | Related source path; QA-specific variant not independently body-matched |
| `20261023183515` | `qa_acl_reconciliation_from_production_catalog` | `No tracked source file found` | Environment-specific QA ACL reconciliation; retain as a non-replayable historical event |
| `20261023183623` | `qa_authenticator_acl_and_default_privileges_reconciliation` | `No tracked source file found` | Environment-specific QA authenticator/default-privilege reconciliation; retain as a non-replayable historical event |
| `20261031065937` | `roshan_phase46_uat_schema_compatibility` | `db/roshan_phase46_uat_schema_compatibility.sql` | Stored fingerprint exactly matches Production Phase 46 under a different version |
| `20261031070544` | `roshan_phase47_queue_branch_attribution` | `db/roshan_phase47_queue_branch_attribution.sql` | Stored fingerprint exactly matches Production Phase 47 under a different version |
| `20261031071243` | `qa_restore_security_invoker_on_exposed_views` | `db/qa/20261030_restore_security_invoker_on_qa_views.sql` | QA-only view-option reconciliation; not a Production migration |
| `20261031103912` | `roshan_phase48_storage_entity_branch_binding` | `db/roshan_phase48_storage_entity_branch_binding.sql` | Stored fingerprint exactly matches Production Phase 48 under a different version |
| `20261102122437` | `roshan_phase51_public_setup_required_anon` | `db/roshan_phase51_public_setup_required_anon.sql` | SQL body/ACL statements match the source; QA copy omits three leading comments and one blank line |
| `20261102133658` | `roshan_phase49_atomic_pharmacy_dispense` | `db/roshan_phase49_atomic_pharmacy_dispense.sql` | Exact current source-file match documented in phase49-52-provenance.json |
| `20261102133734` | `roshan_phase50_clinical_visit_bill_completion` | `db/roshan_phase50_clinical_visit_bill_completion.sql` | Current source path mapped; separate QA fingerprint recorded; no new independent hash claim beyond the scoped provenance artifact |
| `20261102232858` | `superseded_duplicate_roshan_phase50_clinical_visit_bill_completion` | `db/roshan_phase50_clinical_visit_bill_completion.sql` | Same stored statement fingerprint as Production Phase 50 version 20261102232849 |
| `20261102232905` | `roshan_phase52_reporting_analytics_reconciled` | `db/roshan_phase52_reporting_analytics.sql` | Scoped normalized-source equality documented in phase49-52-provenance.json |
| `20261103114242` | `roshan_phase54_source_aware_financial_reversal` | `db/roshan_phase54_source_aware_financial_reversal.sql` | Source path present on main; no independent stored-body hash |
| `20261103114612` | `roshan_phase54b_payment_updated_at_compat` | `db/roshan_phase54b_payment_updated_at_compat.sql` | Source path present on main; no independent stored-body hash |
| `20261103115649` | `roshan_phase54c_branchless_receipt_integrity` | `db/roshan_phase54c_branchless_receipt_integrity.sql` | Source path present on main; no independent stored-body hash |
| `20261103155227` | `roshan_phase55_clinical_parent_guard_acl_reconciliation` | `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql` | Source path present on main; no independent stored-body hash |
| `20261104065852` | `roshan_phase57_pharmacy_quantity_required_guard` | `db/roshan_phase57_pharmacy_quantity_required_guard.sql (immutable original)` | Exact byte-for-byte match to QA stored SQL body: 10,954 bytes; MD5 921970d4d86b32dccd430a0ea0ef8745. Production has no Phase 57 row. |

## Selected stored-SQL comparisons

| Phase | Environment | Result |
|---|---|---|
| 46 | Production/QA | same serialized statement fingerprint under distinct version IDs; source path mapped; no raw body export in this addendum |
| 47 | Production/QA | same serialized statement fingerprint under distinct version IDs; source path mapped; no raw body export in this addendum |
| 48 | Production/QA | byte-for-byte exact stored SQL/source comparison recorded |
| 49 | Production/QA | Production terminal wrapper/whitespace delta; QA exact source match |
| 50 | Production/QA | Production terminal wrapper/whitespace delta; QA exact source match |
| 51 | Production/QA | normalized executable SQL equality; QA comments/wrapper differ |
| 52 | Production/QA | normalized executable SQL equality after comments/wrapper/whitespace normalization |
| 54 | QA | byte-for-byte exact stored SQL/source comparison recorded |
| 54B | QA | byte-for-byte exact stored SQL/source comparison recorded |
| 54C | QA | byte-for-byte exact stored SQL/source comparison recorded |
| 55 | QA | normalized executable SQL equality; one trailing newline differs |
| 57 | QA | byte-for-byte exact original Phase 57 source; Phase 57B remains candidate-only |

## Safety and limitations

- Metadata was re-read from both hosted migration ledgers using read-only SELECTs. The row counts, version/name pairs, serialized byte lengths and MD5 fingerprints match the companion fingerprint snapshot exactly.
- The 93-entry historical source report contains 92 normalized text matches and one redacted environment-specific identity mapping.
- The 22-entry forward delta maps later Production rows but does not independently prove live stored SQL equality for every row.
- The 14-row Production tail is explicitly classified; placeholders, archive/quarantine artifacts and redacted cleanup SQL are not replayable migration sources.
- QA rows have path mappings or explicit environment-specific dispositions. Selected Phase 46–57 stored SQL comparisons are separately recorded; these are not a full SQL-body comparison of all 151 rows.
- Production and QA have divergent histories: 129 versus 22 rows, only three shared version IDs, and all three shared IDs collide with different names and fingerprints.
- No migration was replayed, no ledger row was inserted/updated/deleted, and no hosted DDL/DML, business-row, permission, Auth, Storage, deployment or backup operation was performed in this reconciliation.
- Mapping does not prove effective catalog/function/ACL equivalence. The effective database state must be compared independently, object category by object category.

## Release consequence

Do not replay either environment's history into the other. Do not repair the ledger by manual insertion. Preserve the Production and QA histories, continue effective-catalog/function/ACL reconciliation, and require a separately reviewed forward-only rollout plan for each environment.

Companion machine-readable data: `LIVE_MIGRATION_CONSOLIDATED_SOURCE_MAP_2026-11-10.json`.