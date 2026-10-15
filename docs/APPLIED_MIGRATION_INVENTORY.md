# Applied Supabase Migration Inventory

Snapshot date: 2026-10-15  
Project: `jewzonxplxhogqrnhosl` (Roshan Production)  
Source: live Supabase migration ledger, read-only.

This table records the exact version/name pairs returned by Supabase. A read-only query on 2026-10-15 computed the byte length and MD5 checksum of each ledger `statements` value to make later source recovery verifiable. The checksums cover the stored JSON representation of `statements`, not normalized SQL text. This inventory is still not a claim of repository parity: Git history contains no `supabase/migrations` or `supabase/config.toml`, and the existing `db/*.sql` files must be content-compared before deciding which ledger entries they cover. No SQL was written back to the repository in this step.

| Version | Applied migration name | SQL bytes | Ledger SQL MD5 | Repository SQL mapping | Content parity |
|---|---|---:|---|---|---|
| `20260818162003` | `fix_duplicate_unique_constraint` | 103 | `61a0f9e47443649d4616936ff42f79ca` | Not yet mapped | Not yet checked |
| `20260818191254` | `fix_patients_rls_and_admin_link` | 1084 | `f4e22a4ed44c5f423cb11cac897d06e0` | Not yet mapped | Not yet checked |
| `20260818191556` | `install_safe_visit_number_function` | 737 | `07cffd7a16337644b1585d6bc74de0aa` | Not yet mapped | Not yet checked |
| `20260818192452` | `fix_daily_queue_numbers_v4` | 1565 | `88910b769fcf4e9de21116221f7113d2` | Not yet mapped | Not yet checked |
| `20260818194104` | `fix_daily_queue_numbering` | 2180 | `49b6db1c9c75724444676a9f627b15ee` | Not yet mapped | Not yet checked |
| `20260818194429` | `repair_queue_and_harden_queue_security` | 4892 | `80a66f6704da724185a7ce5be3da0b61` | Not yet mapped | Not yet checked |
| `20260818194457` | `consolidate_queue_triggers` | 3157 | `d6755cb678b0566deed766ad3a482ed4` | Not yet mapped | Not yet checked |
| `20260818195753` | `fix_visit_queue_numbering` | 2292 | `89d78b1689ad934b4f4484a500bd5656` | Not yet mapped | Not yet checked |
| `20260818195811` | `sync_existing_queue_tickets` | 285 | `116e6960f69905e86691f47e58ff25e0` | Not yet mapped | Not yet checked |
| `20260818200206` | `fix_queue_numbering_authoritative` | 2689 | `1788f1c5c07c56f1524639c40c408687` | Not yet mapped | Not yet checked |
| `20260818200246` | `harden_visit_queue_rls_and_cleanup` | 2096 | `2723798f30e0c66149f9dece79c4ffc6` | Not yet mapped | Not yet checked |
| `20260818200336` | `finalize_non_recycling_queue_allocator` | 1368 | `08d337b9dc9add2d77091e79c2d087b2` | Not yet mapped | Not yet checked |
| `20260818202356` | `fix_appointments_rls_auth_and_audit` | 828 | `bf439a86b9fd31c5282a61361ad96f7a` | Not yet mapped | Not yet checked |
| `20260818232848` | `harden_core_indexes_and_legacy_compatibility_v2` | 7636 | `e8813fabc4451694071ab43f76e8ae7a` | Not yet mapped | Not yet checked |
| `20260818233558` | `harden_security_definer_helpers_and_duplicate_index_v2` | 5656 | `2a5cd75eac385055a01dd3db53cfdf05` | db/roshan_security_hardening.sql (candidate; name differs) | Mismatch; semantic diff pending |
| `20260818234039` | `harden_rls_permissions_and_public_grants_v1` | 29681 | `7a20a1b456d5ac28b7939264cd85fb0c` | Not yet mapped | Not yet checked |
| `20260818234050` | `harden_services_rls_v1` | 676 | `0736405983339e302a4363ae83b7aa43` | Not yet mapped | Not yet checked |
| `20260818234146` | `repair_roshan_rbac_role_links_v1` | 2174 | `33a9375f8f84f73b213b256d52257840` | Not yet mapped | Not yet checked |
| `20260819000003` | `harden_public_defaults_and_sync_user_roles` | 1739 | `83601720d0bd6443dc85b3c463b39794` | Not yet mapped | Not yet checked |
| `20260819000016` | `tighten_public_default_privileges` | 389 | `c7abfd29bad141caa28cf0d901438c7c` | Not yet mapped | Not yet checked |
| `20260819100756` | `roshan_phase1_pagination_and_settings` | 1129 | `33e550dacd27b9007897dbaa1fd42bd4` | db/roshan_phase1_pagination_and_settings.sql (name match) | Partial match: three patient indexes in recovered body are absent from candidate; see semantic review section |
| `20260819105146` | `roshan_settings_public_enforcement` | 942 | `5fc9082104fc8cdf9b65776478895a36` | Not yet mapped | Not yet checked |
| `20260819123920` | `grant_authenticated_execute_next_mrn` | 65 | `8997024e51ab6ffc93be3ffb4aef3032` | Not yet mapped | Not yet checked |
| `20260819124045` | `fix_next_mrn_rpc_access` | 494 | `3febc123265bfaf81d777533064f65f9` | Not yet mapped | Not yet checked |
| `20260819125755` | `add_missing_audit_relationships` | 1052 | `c409776a912a1f55c4fd961d5325e65e` | Not yet mapped | Not yet checked |
| `20260819125807` | `add_followups_users_computed_relationship` | 455 | `388272b5e71cb49ac177945f32384edd` | Not yet mapped | Not yet checked |
| `20260819130039` | `compat_patients_patient_number` | 254 | `652a89bec1fe269fbafc5e7ac936fb68` | Not yet mapped | Not yet checked |
| `20260819222434` | `add_prescription_ux_fields` | 358 | `a86f52c024524c8fa937fcfc88b413e2` | Not yet mapped | Not yet checked |
| `20260819223342` | `add_medical_certificates_soft_delete_columns` | 290 | `a3c703eb0319e1f1ef98a4156120cd3d` | Not yet mapped | Not yet checked |
| `20260820000007` | `add_medicines_2_stock_quantity_compatibility` | 956 | `a49ef8d739e6cb267888a0c1b7ec9a73` | Not yet mapped | Not yet checked |
| `20260820000143` | `add_medicines_2_stock_quantity` | 102 | `1d32e0cc340a46f6d5bf252caec99d24` | Not yet mapped | Not yet checked |
| `20260820000336` | `fix_medicines_stock_quantity_schema_cache` | 356 | `241bbbb27bf3edafeb60191bdaa0a630` | Not yet mapped | Not yet checked |
| `20260820000656` | `add_medicines_reorder_level` | 99 | `1e478733e1e978283a4fb06bc0dde2ee` | Not yet mapped | Not yet checked |
| `20260820000725` | `add_medicines_expiry_date` | 75 | `34caa91bdc2b6b1051202d380336d4ca` | Not yet mapped | Not yet checked |
| `20260820005417` | `fix_followups_user_relationship` | 507 | `75d47f32e8627e2d587990284791fa63` | Not yet mapped | Not yet checked |
| `20260820010030` | `fix_medicines_batch_number` | 190 | `857c21fd0dff64de9f3a8c5cb6555e8b` | Not yet mapped | Not yet checked |
| `20260820150215` | `roshan_phase2_clinical_workflow` | 640 | `3b13a90d96e8d878c97be72b8c21c905` | db/roshan_phase2_clinical_workflow.sql (candidate) | Partial match: candidate adds lab-parameter seeding absent from recovered body; see semantic review section |
| `20260822094358` | `roshan_workflow_performance_20260822` | 2230 | `a47d2b6af7e90cf6c9375af0308ae32f` | Not yet mapped | Not yet checked |
| `20260822094405` | `roshan_drop_duplicate_prescription_index_20260822` | 64 | `013b6f046a1cc5d09636d142232ce8b1` | Not yet mapped | Not yet checked |
| `20260906142737` | `roshan_phase3_allow_pharmacy_setting_public` | 1199 | `2c21995b7a241df642b44c06d8202eb9` | Not yet mapped | Not yet checked |
| `20260906142803` | `roshan_phase3_pharmacy_batches` | 9097 | `5af0b31a2ae1998a57a4dd3e8f510759` | Not yet mapped | Not yet checked |
| `20260906144008` | `roshan_phase4_finance_cashbox_debts` | 14679 | `bc611918fa30c7aa33622350d63c4f1e` | db/roshan_phase4_finance.sql (candidate; name differs) | Mismatch; semantic diff pending |
| `20260906161023` | `roshan_phase4_finance_security_verification_patch` | 3589 | `49626f4e7b252184c147402f4639f3ba` | db/roshan_phase4_finance.sql (candidate; name differs) | Mismatch; semantic diff pending |
| `20260906203143` | `roshan_phase3_pharmacy_runtime_hardening` | 6980 | `a7a95cc25eb5e395af595ab2192c9d34` | Not yet mapped | Not yet checked |
| `20260908210824` | `roshan_phase4_finance_v2` | 24052 | `4be9232e7e06b03ff5827ae9af046ec0` | db/roshan_phase4_finance.sql (candidate; name differs) | Function-level map: all 14 functions exist; 13 bodies match, while `fn_ledger_post` differs in conflict predicate; see semantic review section |
| `20260909110657` | `roshan_phase5_insurance` | 7616 | `0270b37760a90ace769c63cee95d7bfa` | db/roshan_phase5_insurance.sql (combined candidate) | Combined three-ledger statement set matches after comment/whitespace normalization; not standalone-file equivalence |
| `20260909110735` | `roshan_phase5_insurance_functions` | 10859 | `20fa5cff06280170d2d4a2cb85e63e0b` | db/roshan_phase5_insurance.sql (combined candidate) | Combined three-ledger statement set matches after comment/whitespace normalization; not standalone-file equivalence |
| `20260909110753` | `roshan_phase5_insurance_permissions_rls` | 4922 | `0eacc16749f50f8401dfdeb48699c486` | db/roshan_phase5_insurance.sql (combined candidate) | Combined three-ledger statement set matches after comment/whitespace normalization; not standalone-file equivalence |
| `20260911120231` | `roshan_phase12_invoice_visit_unique` | 425 | `5182147d2ed12b1a7df402b763c5a1c5` | db/roshan_phase12_invoice_visit_unique.sql | Verified: executable SQL matches after comment/whitespace normalization; comments differ |
| `20260911130749` | `harden_security_and_fk_indexes_20260911` | 7111 | `2cbc5a3b8a370baae854dc1883604aa2` | db/roshan_security_hardening.sql (candidate; name differs) | Mismatch; semantic diff pending |
| `20260911130812` | `restrict_security_definer_api_execution_20260911` | 2164 | `52b0166fba689c66bf81454aa91b200c` | db/roshan_security_privileged_role_guard.sql (candidate; name differs) | Mismatch; semantic diff pending |
| `20260911131456` | `deep_audit_branch_isolation_rpc_hardening` | 8077 | `2e229e263b04b6144047fcabbbd87d94` | Not yet mapped | Not yet checked |
| `20260911133229` | `harden_mrn_invoice_number_concurrency` | 1009 | `0fd7b0b1afb1ef6cb390a0b6657de5d2` | Not yet mapped | Not yet checked |
| `20260911133255` | `enforce_branch_isolation_rls` | 1566 | `7cb965a4218bb2772115ac51c62ade30` | Not yet mapped | Not yet checked |
| `20260911133312` | `harden_insurance_branch_isolation` | 10214 | `807b9c4f3b44051dfcce405d9134ea91` | Not yet mapped | Not yet checked |
| `20260911133319` | `harden_insurance_coverage_rpc_branch` | 3256 | `729d5bcf5413cd22f9e55cf567339536` | Not yet mapped | Not yet checked |
| `20260911133334` | `harden_finance_branch_context` | 5439 | `a71cfe441881bc3b5c446d278004f141` | Not yet mapped | Not yet checked |
| `20260911133353` | `fix_insurance_ledger_branch` | 2412 | `69c264478ac420a24e4f220628991008` | Not yet mapped | Not yet checked |
| `20260911134639` | `grant_next_invoice_number_authenticated` | 76 | `689073830d971ea3797b9134cf742e54` | Not yet mapped | Not yet checked |
| `20260911135036` | `grant_stock_movements_authenticated_access` | 74 | `1f8872b32f0155a028f92f6fe7abf63a` | Not yet mapped | Not yet checked |
| `20260911135318` | `fix_dispense_prescription_nullable_join_lock` | 4530 | `f19b9e9be96dd1576bcea4a5905466f6` | Not yet mapped | Not yet checked |
| `20260911135417` | `fix_dispense_prescription_branch_resolution` | 4942 | `245bb5f291ab0d66a3b50a1cf67d384f` | Not yet mapped | Not yet checked |
| `20260911135547` | `fix_dispense_batch_number_ambiguity` | 4514 | `b97b78aebc298b59968f5b61ed4f0fc5` | Not yet mapped | Not yet checked |
| `20260911135644` | `add_medicines_updated_at_column` | 202 | `fe9d4a0aeab1f2d43387afe8fc75ee42` | Not yet mapped | Not yet checked |
| `20260911135738` | `add_prescription_items_updated_at` | 209 | `6ec0de79ef268dde821bc900141f4d5a` | Not yet mapped | Not yet checked |
| `20260911135858` | `add_prescriptions_updated_at` | 199 | `7ef79eb4301246c5d8ccd11e0c98f36c` | Not yet mapped | Not yet checked |
| `20260911140337` | `add_cashbox_reversal_columns` | 352 | `7ee3c7aa0e90cdef42c673ddb1400c79` | Not yet mapped | Not yet checked |
| `20260911140514` | `allow_cashbox_reversal_transaction_type` | 458 | `8902149a901a8b8d98d17d7c81025995` | Not yet mapped | Not yet checked |
| `20260911141036` | `harden_cashbox_reversal_type` | 2019 | `43ebb562e681f2573d5da1b18cc88eeb` | Not yet mapped | Not yet checked |
| `20260911141142` | `fix_payment_ledger_transaction_type` | 463 | `bfa156ad16dc182f9c0f6d12db669d0e` | Not yet mapped | Not yet checked |
| `20260911141502` | `fix_medicines_generic_name_compatibility` | 1205 | `7cd494cb4719e2aea283093afa056648` | Not yet mapped | Not yet checked |
| `20261011074344` | `harden_patient_invoice_number_rpc_permissions` | 1369 | `fa85bc51d4fe743b5a5762718e46e736` | Not yet mapped | Not yet checked |
| `20261011074437` | `harden_insurance_coverage_rpc_permissions` | 3835 | `8504c98d1e4d3cee48826e41e5d69408` | Not yet mapped | Not yet checked |
| `20261011075101` | `harden_pharmacy_batch_branch_isolation` | 2639 | `2e632526be6a5021352adcb533d20b09` | Not yet mapped | Not yet checked |
| `20261011080253` | `harden_supplier_bill_rpc_branch_and_search_path` | 2418 | `5d6254563c77eba7445c7cd441761598` | Not yet mapped | Not yet checked |
| `20261011080319` | `harden_finance_pharmacy_rpc_search_paths` | 971 | `c03361836985e996c05206b78f0b5127` | Not yet mapped | Not yet checked |
| `20261011080434` | `enforce_branch_isolation_on_clinical_child_tables` | 6804 | `78010a0852d06cdae5d19c7743387478` | Not yet mapped | Not yet checked |
| `20261011080524` | `preserve_super_admin_supplier_bill_compatibility` | 2439 | `f057895df5f103ba2dd6740e5dbc8152` | Not yet mapped | Not yet checked |
| `20261014164131` | `roshan_cashbox_reversal_concurrency` | 2217 | `ae4f73ae273554f14fc0f5cf8052f9ef` | db/roshan_phase4_cashbox_reversal_concurrency.sql (name match) | Executable-content match after comment/whitespace normalization; repo candidate adds transaction wrapper; see semantic review section |


## Source mapping results (semantic review update — 2026-10-15)

These results supplement the 79-row source inventory. “Executable-content match” means statement text matched after comments/whitespace normalization; it is not authorization to replay a migration.

| Applied ledger version(s) | Repository candidate | Result | Remaining caution |
|---|---|---|---|
| `20260819100756` `roshan_phase1_pagination_and_settings` | `db/roshan_phase1_pagination_and_settings.sql` | Partial match: recovered ledger body contains additional indexes `patients_mrn_idx`, `patients_phone_idx`, and `patients_national_id_idx` absent from the candidate. | Verify whether indexes exist from another applied migration and reconcile the candidate before claiming parity. |
| `20260820150215` `roshan_phase2_clinical_workflow` | `db/roshan_phase2_clinical_workflow.sql` | Partial match: candidate adds a default lab-result-parameter `INSERT ... SELECT` absent from the recovered body. | Do not substitute one file for the other; determine where/when the seeding behavior was applied. |
| `20260909110657`, `20260909110735`, `20260909110753` (insurance foundation/functions/permissions) | `db/roshan_phase5_insurance.sql` | Combined recovered statement sets match the candidate after comments/whitespace normalization. | One repository file consolidates three historical ledger entries and adds a transaction wrapper; do not replay it merely because the statements correspond. |
| `20260911120231` `roshan_phase12_invoice_visit_unique` | `db/roshan_phase12_invoice_visit_unique.sql` | Executable SQL match after comment removal and whitespace normalization. | Formatting/comments differ; replayability remains a separate gate. |
| `20261014164131` `roshan_cashbox_reversal_concurrency` | `db/roshan_phase4_cashbox_reversal_concurrency.sql` | Executable-content match after comment/whitespace normalization. | Candidate adds `BEGIN`/`COMMIT`; duplicate-reversal precondition and function security/runtime state still require isolated validation. |


| `20260908210824` `roshan_phase4_finance_v2` (function-level comparison) | `db/roshan_phase4_finance.sql` | All 14 recovered function names exist in the candidate; 13 function bodies match after normalization. `fn_ledger_post` differs in the partial-index predicate of its `ON CONFLICT` clause. | Confirm the deployed unique index predicate and intended NULL semantics; this is function-level mapping only because the candidate includes additional schema/setup SQL. |

All comparisons above were source-only. No SQL was executed and no production schema or data was changed. Recovered SQL remains quarantined under `docs/recovered-migrations/sql/`.
