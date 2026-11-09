# Live Supabase migration-ledger reconciliation — 2026-11-09

## Scope and safety

Read-only comparison of live Production and QA `supabase_migrations.schema_migrations` ledgers. Only version, migration name, byte length and MD5 of `statements::text` were retrieved. **No migration SQL bodies were read or exported.** No DDL/DML, privilege changes or migration repairs were performed.

The MD5 is a fingerprint of the stored JSON serialization, not a security attestation or normalized-source hash. Different hashes prove different serialized representations; matching hashes support exact serialized equality but do not replace independent source review.

## Executive result

| Measure | Production | QA |
|---|---:|---:|
| PostgreSQL | 17.6 | 17.11 |
| Ledger rows | 129 | 22 |
| Latest version | `20261102232941` | `20261104065852` |
| Latest name | `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | `roshan_phase57_pharmacy_quantity_required_guard` |

- Shared version IDs: **3**; Production-only: **126**; QA-only: **19**.
- All 3 shared version IDs have different names and different statement fingerprints across environments.
- Phase 50 and Phase 52 have matching stored statement fingerprints under different version IDs (table below).
- These environments use different baselines and selected forward migrations. The ledgers must not be made identical by blind replay or manual ledger insertion.

## Shared version IDs — all mismatched

| Version | Production name | QA name | Production bytes / MD5 | QA bytes / MD5 |
|---|---|---|---|---|
| `20261102122437` | `superseded_placeholder_phase49_atomic_pharmacy_dispense` | `roshan_phase51_public_setup_required_anon` | 138 / `99219a63dc008c857c674f0a198fac42` | 556 / `f5ee887188ec948f083aba0f0e87b02a` |
| `20261102133658` | `superseded_placeholder_phase50_clinical_visit_bill_completion` | `roshan_phase49_atomic_pharmacy_dispense` | 138 / `99219a63dc008c857c674f0a198fac42` | 19159 / `12ddaceff592d8e7559056a47ce178b7` |
| `20261102133734` | `superseded_placeholder_phase51_public_setup_required_anon` | `roshan_phase50_clinical_visit_bill_completion` | 138 / `99219a63dc008c857c674f0a198fac42` | 4488 / `5db588886b2741e4759479dc9e9a0b1f` |

The three shared IDs are Production placeholder rows (138 bytes, MD5 `99219a63dc008c857c674f0a198fac42`) at version IDs QA used for real Phase 51, Phase 49 and Phase 50 migrations.

## Same serialized statement content under different versions

| Logical migration | Production version | QA version | Bytes | MD5 |
|---|---|---|---:|---|
| Phase 50 | `20261102232849` | `20261102232858` | 4478 | `381936b092c5c5a85983b198cb2524c1` |
| Phase 52 | `20261102232855` | `20261102232905` | 14310 | `f3e301313a7541d087264f50083e99bb` |

## Production-only rows (126)

| Version | Migration name | JSON bytes | MD5 |
|---|---|---:|---|
| `20260818162003` | `fix_duplicate_unique_constraint` | 103 | `61a0f9e47443649d4616936ff42f79ca` |
| `20260818191254` | `fix_patients_rls_and_admin_link` | 1084 | `f4e22a4ed44c5f423cb11cac897d06e0` |
| `20260818191556` | `install_safe_visit_number_function` | 737 | `07cffd7a16337644b1585d6bc74de0aa` |
| `20260818192452` | `fix_daily_queue_numbers_v4` | 1565 | `88910b769fcf4e9de21116221f7113d2` |
| `20260818194104` | `fix_daily_queue_numbering` | 2180 | `49b6db1c9c75724444676a9f627b15ee` |
| `20260818194429` | `repair_queue_and_harden_queue_security` | 4892 | `80a66f6704da724185a7ce5be3da0b61` |
| `20260818194457` | `consolidate_queue_triggers` | 3157 | `d6755cb678b0566deed766ad3a482ed4` |
| `20260818195753` | `fix_visit_queue_numbering` | 2292 | `89d78b1689ad934b4f4484a500bd5656` |
| `20260818195811` | `sync_existing_queue_tickets` | 285 | `116e6960f69905e86691f47e58ff25e0` |
| `20260818200206` | `fix_queue_numbering_authoritative` | 2689 | `1788f1c5c07c56f1524639c40c408687` |
| `20260818200246` | `harden_visit_queue_rls_and_cleanup` | 2096 | `2723798f30e0c66149f9dece79c4ffc6` |
| `20260818200336` | `finalize_non_recycling_queue_allocator` | 1368 | `08d337b9dc9add2d77091e79c2d087b2` |
| `20260818202356` | `fix_appointments_rls_auth_and_audit` | 828 | `bf439a86b9fd31c5282a61361ad96f7a` |
| `20260818232848` | `harden_core_indexes_and_legacy_compatibility_v2` | 7636 | `e8813fabc4451694071ab43f76e8ae7a` |
| `20260818233558` | `harden_security_definer_helpers_and_duplicate_index_v2` | 5656 | `2a5cd75eac385055a01dd3db53cfdf05` |
| `20260818234039` | `harden_rls_permissions_and_public_grants_v1` | 29681 | `7a20a1b456d5ac28b7939264cd85fb0c` |
| `20260818234050` | `harden_services_rls_v1` | 676 | `0736405983339e302a4363ae83b7aa43` |
| `20260818234146` | `repair_roshan_rbac_role_links_v1` | 2174 | `33a9375f8f84f73b213b256d52257840` |
| `20260819000003` | `harden_public_defaults_and_sync_user_roles` | 1739 | `83601720d0bd6443dc85b3c463b39794` |
| `20260819000016` | `tighten_public_default_privileges` | 389 | `c7abfd29bad141caa28cf0d901438c7c` |
| `20260819100756` | `roshan_phase1_pagination_and_settings` | 1129 | `33e550dacd27b9007897dbaa1fd42bd4` |
| `20260819105146` | `roshan_settings_public_enforcement` | 942 | `5fc9082104fc8cdf9b65776478895a36` |
| `20260819123920` | `grant_authenticated_execute_next_mrn` | 65 | `8997024e51ab6ffc93be3ffb4aef3032` |
| `20260819124045` | `fix_next_mrn_rpc_access` | 494 | `3febc123265bfaf81d777533064f65f9` |
| `20260819125755` | `add_missing_audit_relationships` | 1052 | `c409776a912a1f55c4fd961d5325e65e` |
| `20260819125807` | `add_followups_users_computed_relationship` | 455 | `388272b5e71cb49ac177945f32384edd` |
| `20260819130039` | `compat_patients_patient_number` | 254 | `652a89bec1fe269fbafc5e7ac936fb68` |
| `20260819222434` | `add_prescription_ux_fields` | 358 | `a86f52c024524c8fa937fcfc88b413e2` |
| `20260819223342` | `add_medical_certificates_soft_delete_columns` | 290 | `a3c703eb0319e1f1ef98a4156120cd3d` |
| `20260820000007` | `add_medicines_2_stock_quantity_compatibility` | 956 | `a49ef8d739e6cb267888a0c1b7ec9a73` |
| `20260820000143` | `add_medicines_2_stock_quantity` | 102 | `1d32e0cc340a46f6d5bf252caec99d24` |
| `20260820000336` | `fix_medicines_stock_quantity_schema_cache` | 356 | `241bbbb27bf3edafeb60191bdaa0a630` |
| `20260820000656` | `add_medicines_reorder_level` | 99 | `1e478733e1e978283a4fb06bc0dde2ee` |
| `20260820000725` | `add_medicines_expiry_date` | 75 | `34caa91bdc2b6b1051202d380336d4ca` |
| `20260820005417` | `fix_followups_user_relationship` | 507 | `75d47f32e8627e2d587990284791fa63` |
| `20260820010030` | `fix_medicines_batch_number` | 190 | `857c21fd0dff64de9f3a8c5cb6555e8b` |
| `20260820150215` | `roshan_phase2_clinical_workflow` | 640 | `3b13a90d96e8d878c97be72b8c21c905` |
| `20260822094358` | `roshan_workflow_performance_20260822` | 2230 | `a47d2b6af7e90cf6c9375af0308ae32f` |
| `20260822094405` | `roshan_drop_duplicate_prescription_index_20260822` | 64 | `013b6f046a1cc5d09636d142232ce8b1` |
| `20260906142737` | `roshan_phase3_allow_pharmacy_setting_public` | 1199 | `2c21995b7a241df642b44c06d8202eb9` |
| `20260906142803` | `roshan_phase3_pharmacy_batches` | 9097 | `5af0b31a2ae1998a57a4dd3e8f510759` |
| `20260906144008` | `roshan_phase4_finance_cashbox_debts` | 14679 | `bc611918fa30c7aa33622350d63c4f1e` |
| `20260906161023` | `roshan_phase4_finance_security_verification_patch` | 3589 | `49626f4e7b252184c147402f4639f3ba` |
| `20260906203143` | `roshan_phase3_pharmacy_runtime_hardening` | 6980 | `a7a95cc25eb5e395af595ab2192c9d34` |
| `20260908210824` | `roshan_phase4_finance_v2` | 24052 | `4be9232e7e06b03ff5827ae9af046ec0` |
| `20260909110657` | `roshan_phase5_insurance` | 7616 | `0270b37760a90ace769c63cee95d7bfa` |
| `20260909110735` | `roshan_phase5_insurance_functions` | 10859 | `20fa5cff06280170d2d4a2cb85e63e0b` |
| `20260909110753` | `roshan_phase5_insurance_permissions_rls` | 4922 | `0eacc16749f50f8401dfdeb48699c486` |
| `20260911120231` | `roshan_phase12_invoice_visit_unique` | 425 | `5182147d2ed12b1a7df402b763c5a1c5` |
| `20260911130749` | `harden_security_and_fk_indexes_20260911` | 7111 | `2cbc5a3b8a370baae854dc1883604aa2` |
| `20260911130812` | `restrict_security_definer_api_execution_20260911` | 2164 | `52b0166fba689c66bf81454aa91b200c` |
| `20260911131456` | `deep_audit_branch_isolation_rpc_hardening` | 8077 | `2e229e263b04b6144047fcabbbd87d94` |
| `20260911133229` | `harden_mrn_invoice_number_concurrency` | 1009 | `0fd7b0b1afb1ef6cb390a0b6657de5d2` |
| `20260911133255` | `enforce_branch_isolation_rls` | 1566 | `7cb965a4218bb2772115ac51c62ade30` |
| `20260911133312` | `harden_insurance_branch_isolation` | 10214 | `807b9c4f3b44051dfcce405d9134ea91` |
| `20260911133319` | `harden_insurance_coverage_rpc_branch` | 3256 | `729d5bcf5413cd22f9e55cf567339536` |
| `20260911133334` | `harden_finance_branch_context` | 5439 | `a71cfe441881bc3b5c446d278004f141` |
| `20260911133353` | `fix_insurance_ledger_branch` | 2412 | `69c264478ac420a24e4f220628991008` |
| `20260911134639` | `grant_next_invoice_number_authenticated` | 76 | `689073830d971ea3797b9134cf742e54` |
| `20260911135036` | `grant_stock_movements_authenticated_access` | 74 | `1f8872b32f0155a028f92f6fe7abf63a` |
| `20260911135318` | `fix_dispense_prescription_nullable_join_lock` | 4530 | `f19b9e9be96dd1576bcea4a5905466f6` |
| `20260911135417` | `fix_dispense_prescription_branch_resolution` | 4942 | `245bb5f291ab0d66a3b50a1cf67d384f` |
| `20260911135547` | `fix_dispense_batch_number_ambiguity` | 4514 | `b97b78aebc298b59968f5b61ed4f0fc5` |
| `20260911135644` | `add_medicines_updated_at_column` | 202 | `fe9d4a0aeab1f2d43387afe8fc75ee42` |
| `20260911135738` | `add_prescription_items_updated_at` | 209 | `6ec0de79ef268dde821bc900141f4d5a` |
| `20260911135858` | `add_prescriptions_updated_at` | 199 | `7ef79eb4301246c5d8ccd11e0c98f36c` |
| `20260911140337` | `add_cashbox_reversal_columns` | 352 | `7ee3c7aa0e90cdef42c673ddb1400c79` |
| `20260911140514` | `allow_cashbox_reversal_transaction_type` | 458 | `8902149a901a8b8d98d17d7c81025995` |
| `20260911141036` | `harden_cashbox_reversal_type` | 2019 | `43ebb562e681f2573d5da1b18cc88eeb` |
| `20260911141142` | `fix_payment_ledger_transaction_type` | 463 | `bfa156ad16dc182f9c0f6d12db669d0e` |
| `20260911141502` | `fix_medicines_generic_name_compatibility` | 1205 | `7cd494cb4719e2aea283093afa056648` |
| `20261011074344` | `harden_patient_invoice_number_rpc_permissions` | 1369 | `fa85bc51d4fe743b5a5762718e46e736` |
| `20261011074437` | `harden_insurance_coverage_rpc_permissions` | 3835 | `8504c98d1e4d3cee48826e41e5d69408` |
| `20261011075101` | `harden_pharmacy_batch_branch_isolation` | 2639 | `2e632526be6a5021352adcb533d20b09` |
| `20261011080253` | `harden_supplier_bill_rpc_branch_and_search_path` | 2418 | `5d6254563c77eba7445c7cd441761598` |
| `20261011080319` | `harden_finance_pharmacy_rpc_search_paths` | 971 | `c03361836985e996c05206b78f0b5127` |
| `20261011080434` | `enforce_branch_isolation_on_clinical_child_tables` | 6804 | `78010a0852d06cdae5d19c7743387478` |
| `20261011080524` | `preserve_super_admin_supplier_bill_compatibility` | 2439 | `f057895df5f103ba2dd6740e5dbc8152` |
| `20261014164131` | `roshan_cashbox_reversal_concurrency` | 2217 | `ae4f73ae273554f14fc0f5cf8052f9ef` |
| `20261016161923` | `roshan_phase18_dedupe_finance_audit_triggers_20261016` | 492 | `e98df7f7d58a48ca7e0b02d1b1539ef7` |
| `20261016162410` | `roshan_phase21_patient_registration_atomicity_20261016` | 2723 | `18635b1e9bd434a14eb12fe10b2332af` |
| `20261016170816` | `roshan_security_privileged_role_guard_20261016` | 9015 | `387ec6e2f1e7e3611f39ec23c8d85aba` |
| `20261016172209` | `roshan_phase7_atomic_prescription_20261016` | 6126 | `77f316403d348341afc746352460f044` |
| `20261016183123` | `roshan_phase8_atomic_invoice` | 5877 | `649c7e2823b07eda341b54f48a1305b3` |
| `20261016183130` | `roshan_phase13_consolidated_visit_invoice` | 16831 | `d8b64bfde09ec8a62edc83e70e7fd641` |
| `20261016183136` | `roshan_phase14_dispense_invoice_atomic_compat` | 10613 | `ff0da5cccabdd3b1029e02bdfea39e3e` |
| `20261016183145` | `roshan_phase15_manual_invoice_consolidation` | 4137 | `12c8bc97d2491185fe66fde0992b6716` |
| `20261016183152` | `roshan_phase16_billing_idempotency` | 5005 | `3846e3e7cd2692b0c65aca5fd5d2c7b1` |
| `20261016204859` | `roshan_phase21_patient_registration_privileges_20261016` | 246 | `f8b6284f3e72e8b231e755ab5817776a` |
| `20261016211342` | `roshan_phase22_clinic_local_queue_date_20261016` | 1534 | `4674f5bca39b8a3c81e1c869df905d3f` |
| `20261016215806` | `roshan_phase23_legacy_queue_allocator_20261016` | 1024 | `c500691c6c6dec3ea92f90c785d79854` |
| `20261016221553` | `roshan_phase24_visit_form_options_20261016` | 1588 | `c866539de52f70644cfd9226e42f23da` |
| `20261016222009` | `roshan_phase25_current_app_profile_20261016` | 2016 | `8f321030af405a2e54627a0bc0511396` |
| `20261017125924` | `roshan_security_candidate_bundle_20261017` | 29978 | `60269c5efa4d8be85581f14849f1667d` |
| `20261017125934` | `roshan_insurance_claim_amount_integrity_20261017` | 7361 | `4473480eafeaf155dde074db1782ec71` |
| `20261017125936` | `roshan_insurance_coverage_validity_20261017` | 7338 | `563596abd9ac7cab76e7e5cd8523558f` |
| `20261017133157` | `roshan_revoke_legacy_invoice_number_20261017` | 260 | `5d7259780affcb29ec995858a6d3c520` |
| `20261017225523` | `roshan_insurance_prior_authorization_branch_isolation` | 1894 | `39bc12e5dc47ddf445211f4777b20430` |
| `20261017225540` | `roshan_post_expense_finite_amount` | 1482 | `9736250e430c712c687d46b0840812b5` |
| `20261017230623` | `roshan_post_expense_money_precision` | 1570 | `bed511038aad5ece9d06bf743b79108a` |
| `20261017230645` | `roshan_insurance_claim_money_precision` | 5293 | `9799a03e105c1465fda2805e10594df9` |
| `20261017231612` | `roshan_invoice_payment_money_precision` | 3652 | `5955bd258f9c9f4e0ba8eaf3f534033f` |
| `20261017231629` | `roshan_pharmacy_batch_money_precision` | 3078 | `d799b199850edb28c4a4c064746046ed` |
| `20261018061746` | `roshan_pharmacy_batch_receipt_idempotency` | 5701 | `34f4a16b5fbab81a0c4f892bb7f95ba1` |
| `20261018062939` | `roshan_pharmacy_batch_receipt_guards` | 8353 | `683571b0350a9ea2e17f376f16d26c7e` |
| `20261018063549` | `roshan_phase19_invoice_rpc_only_writes` | 2164 | `086f07c62117660dd5012dca353b41fa` |
| `20261018064139` | `roshan_phase20_clinical_child_branch_isolation` | 13474 | `4b0c2e855ce08879c9cf9bc074c39897` |
| `20261018064638` | `roshan_clinical_child_write_rpcs` | 3613 | `690778a46c97d3886cbb203599b6584d` |
| `20261018065708` | `roshan_clinical_child_rpc_only_writes` | 520 | `737b78e71cb5d5f0fd6cb7323f5d9f9b` |
| `20261018201642` | `roshan_phase31_clinical_financial_security_hardening` | 18493 | `b49393f160d5c097973bbbe3ea3499ed` |
| `20261018201758` | `roshan_phase31_contract_security_cutover` | 1197 | `9ed77769bf921a7c7c397e16b8372ba7` |
| `20261019061315` | `roshan_phase32_medical_certificate_visit_index` | 107 | `8ffa48d50ddc55eedd19e9ebce224090` |
| `20261020090350` | `roshan_phase34_storage_guard_lab_verify_realtime` | 20212 | `704c7a6127d9a2f7056f42d8ba35ae85` |
| `20261020111126` | `roshan_phase36_audit_coverage_and_visit_lifecycle_guards` | 4116 | `709b9cde24364271cab45c801cf256da` |
| `20261020232033` | `roshan_phase39_permissions_lab_catalog_and_audit_closure` | 3211 | `1739b0eb57bfd70d978955bebd603378` |
| `20261031071119` | `roshan_phase46_uat_schema_compatibility` | 5239 | `c762c78af47bc2521fa21af0f07fe739` |
| `20261031071122` | `roshan_phase47_queue_branch_attribution` | 6568 | `dc616222eae5d6e5d2c6b9de5aa47ffc` |
| `20261031103927` | `roshan_phase48_storage_entity_branch_binding` | 5663 | `f5ee865d0429bf532977924ef60978fa` |
| `20261102140000` | `superseded_placeholder_phase52_reporting_analytics` | 138 | `99219a63dc008c857c674f0a198fac42` |
| `20261102232813` | `roshan_remediation_archive_container` | 443 | `a39956f8bbc2fe44fb6c4bc10fcab39a` |
| `20261102232819` | `roshan_phase49_isolate_malformed_idempotency_table` | 227 | `34856827a2ac18a01d5065e5fa896a00` |
| `20261102232823` | `roshan_phase49_atomic_pharmacy_dispense_repaired` | 19149 | `5e9082b7f8efa2733eac3463080552bc` |
| `20261102232849` | `roshan_phase50_clinical_visit_bill_completion_reconciled` | 4478 | `381936b092c5c5a85983b198cb2524c1` |
| `20261102232852` | `roshan_phase51_public_setup_required_anon_reconciled` | 792 | `ce740f50fdf5f0d3d6f279c427e65fca` |
| `20261102232855` | `roshan_phase52_reporting_analytics_reconciled` | 14310 | `f3e301313a7541d087264f50083e99bb` |
| `20261102232941` | `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | 3289 | `eedfc4ec43dc90edf1765a23790516b0` |

## QA-only rows (19)

| Version | Migration name | JSON bytes | MD5 |
|---|---|---:|---|
| `20261023182629` | `qa_schema_baseline_v112_platform_preserving` | 430993 | `f3a1dede1deddcfe74b8cba3e9566932` |
| `20261023182742` | `roshan_phase34_consolidated_storage_realtime_lab_verify` | 20610 | `1c77a2ce8d9134d9ed43a24b5ee4af7e` |
| `20261023182746` | `roshan_phase36_audit_coverage_and_visit_lifecycle_guards` | 4069 | `dc53f0787d2d1883c4fff492fc8b9b1e` |
| `20261023182750` | `roshan_phase39_permissions_lab_catalog_and_audit_closure` | 2524 | `42d8f6df5f1cb9625569a9056a2cfd22` |
| `20261023182756` | `roshan_phase45_atomic_visit_queue_completion_retry` | 2926 | `960988cf6d716604a65d6b1ef5a7363a` |
| `20261023182855` | `qa_phase31_contract_security_cutover` | 1213 | `d9bf16614626e5bce2715caa6182eb2a` |
| `20261023183515` | `qa_acl_reconciliation_from_production_catalog` | 15171 | `d9a60abdff07ae8f6ed84b15ebe31b9b` |
| `20261023183623` | `qa_authenticator_acl_and_default_privileges_reconciliation` | 16190 | `227ec9804038d39c92988a32d571f699` |
| `20261031065937` | `roshan_phase46_uat_schema_compatibility` | 5239 | `c762c78af47bc2521fa21af0f07fe739` |
| `20261031070544` | `roshan_phase47_queue_branch_attribution` | 6568 | `dc616222eae5d6e5d2c6b9de5aa47ffc` |
| `20261031071243` | `qa_restore_security_invoker_on_exposed_views` | 2410 | `c81b917f1665ec105ff4ba1166472ff2` |
| `20261031103912` | `roshan_phase48_storage_entity_branch_binding` | 5663 | `f5ee865d0429bf532977924ef60978fa` |
| `20261102232858` | `superseded_duplicate_roshan_phase50_clinical_visit_bill_completion` | 4478 | `381936b092c5c5a85983b198cb2524c1` |
| `20261102232905` | `roshan_phase52_reporting_analytics_reconciled` | 14310 | `f3e301313a7541d087264f50083e99bb` |
| `20261103114242` | `roshan_phase54_source_aware_financial_reversal` | 7817 | `8329dbfe9a51b588a3c0244e21736726` |
| `20261103114612` | `roshan_phase54b_payment_updated_at_compat` | 4983 | `8fef1495c28875c149ace54c133b61b2` |
| `20261103115649` | `roshan_phase54c_branchless_receipt_integrity` | 10409 | `78baf5a4d3f03d1af45ebdcaf3a858cc` |
| `20261103155227` | `roshan_phase55_clinical_parent_guard_acl_reconciliation` | 2308 | `6b8e017911641a60ec1599362d4351bd` |
| `20261104065852` | `roshan_phase57_pharmacy_quantity_required_guard` | 10958 | `7bffc0d979d925cc3633a21e7292625d` |

## Source mapping and parity blockers

1. Repository source currently contains 65 root `db/*.sql` files, one PG17 baseline in `db/baseline/`, and one QA-only SQL file in `db/qa/`; no top-level `supabase/` migration tree is present.
2. `db/MIGRATIONS_MANIFEST.md` still records a catalog fingerprint at v115 (`20261020232033`). Its scoped Phase 49–52 provenance maps Production versions `20261102232823`, `20261102232849`, `20261102232852`, `20261102232855` after terminal COMMIT/trailing-whitespace normalization; this is not a full chain replay.
3. `docs/APPLIED_MIGRATION_INVENTORY.md` has 94 version rows and ends at `20261017133157`; it is historical, not the current 129-row Production ledger.
4. Four Production placeholders (`20261102122437`, `20261102133658`, `20261102133734`, `20261102140000`) are all 138 bytes with the same MD5. They are not executable Phase 49–52 migration bodies.
5. Production `20261102232819` is a quarantined table/index rename. Production `20261102232941` is a cleanup/reversal DO block with environment-specific identifiers; its public recovered copy is redacted and non-replayable.
6. QA has a separate v112 baseline, ACL/default-privilege reconciliation and view-security repair, plus QA-only Phases 54/54B/54C/55/57. These are not an instruction to replay them on Production.
7. Phase 57 is applied in QA at `20261104065852`, but its source file is only on Draft PR #191 head `bcb0371860e4497510b8651fe84197e3aa3f5cd5`, not main. PR #191 is 12 commits ahead/5 behind main and dirty.
8. Main CI `Migration source parity manifest` passed in [run 42576306597](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42576306597). This validates the tracked subset; it does not establish parity for all 129 Production rows, 22 QA rows or QA-only Phase 57.

## Next reconciliation work

- Synchronize Draft PR #191 with current main using a normal conflict-resolved merge commit; keep it Draft until a synthetic pharmacist identity and isolated QA acceptance exist.
- Track the QA-applied Phase 57 source and its exact ledger provenance in the canonical inventory through reviewed PR work; do not apply it to Production in this step.
- Continue historical reconstruction for branch/RLS, queue allocator, pharmacy receive/dispense and finance RPC evolutions. Compare final effective functions, policies, triggers and grants—not intermediate migration text alone.
- Produce a reviewed forward-only Production rollout sequence. Never replay the historical ledger wholesale, placeholder rows, or redacted `20261102232941`.

## Complete Production ledger — 129 rows

| Version | Migration name | JSON bytes | MD5 |
|---|---|---:|---|
| `20260818162003` | `fix_duplicate_unique_constraint` | 103 | `61a0f9e47443649d4616936ff42f79ca` |
| `20260818191254` | `fix_patients_rls_and_admin_link` | 1084 | `f4e22a4ed44c5f423cb11cac897d06e0` |
| `20260818191556` | `install_safe_visit_number_function` | 737 | `07cffd7a16337644b1585d6bc74de0aa` |
| `20260818192452` | `fix_daily_queue_numbers_v4` | 1565 | `88910b769fcf4e9de21116221f7113d2` |
| `20260818194104` | `fix_daily_queue_numbering` | 2180 | `49b6db1c9c75724444676a9f627b15ee` |
| `20260818194429` | `repair_queue_and_harden_queue_security` | 4892 | `80a66f6704da724185a7ce5be3da0b61` |
| `20260818194457` | `consolidate_queue_triggers` | 3157 | `d6755cb678b0566deed766ad3a482ed4` |
| `20260818195753` | `fix_visit_queue_numbering` | 2292 | `89d78b1689ad934b4f4484a500bd5656` |
| `20260818195811` | `sync_existing_queue_tickets` | 285 | `116e6960f69905e86691f47e58ff25e0` |
| `20260818200206` | `fix_queue_numbering_authoritative` | 2689 | `1788f1c5c07c56f1524639c40c408687` |
| `20260818200246` | `harden_visit_queue_rls_and_cleanup` | 2096 | `2723798f30e0c66149f9dece79c4ffc6` |
| `20260818200336` | `finalize_non_recycling_queue_allocator` | 1368 | `08d337b9dc9add2d77091e79c2d087b2` |
| `20260818202356` | `fix_appointments_rls_auth_and_audit` | 828 | `bf439a86b9fd31c5282a61361ad96f7a` |
| `20260818232848` | `harden_core_indexes_and_legacy_compatibility_v2` | 7636 | `e8813fabc4451694071ab43f76e8ae7a` |
| `20260818233558` | `harden_security_definer_helpers_and_duplicate_index_v2` | 5656 | `2a5cd75eac385055a01dd3db53cfdf05` |
| `20260818234039` | `harden_rls_permissions_and_public_grants_v1` | 29681 | `7a20a1b456d5ac28b7939264cd85fb0c` |
| `20260818234050` | `harden_services_rls_v1` | 676 | `0736405983339e302a4363ae83b7aa43` |
| `20260818234146` | `repair_roshan_rbac_role_links_v1` | 2174 | `33a9375f8f84f73b213b256d52257840` |
| `20260819000003` | `harden_public_defaults_and_sync_user_roles` | 1739 | `83601720d0bd6443dc85b3c463b39794` |
| `20260819000016` | `tighten_public_default_privileges` | 389 | `c7abfd29bad141caa28cf0d901438c7c` |
| `20260819100756` | `roshan_phase1_pagination_and_settings` | 1129 | `33e550dacd27b9007897dbaa1fd42bd4` |
| `20260819105146` | `roshan_settings_public_enforcement` | 942 | `5fc9082104fc8cdf9b65776478895a36` |
| `20260819123920` | `grant_authenticated_execute_next_mrn` | 65 | `8997024e51ab6ffc93be3ffb4aef3032` |
| `20260819124045` | `fix_next_mrn_rpc_access` | 494 | `3febc123265bfaf81d777533064f65f9` |
| `20260819125755` | `add_missing_audit_relationships` | 1052 | `c409776a912a1f55c4fd961d5325e65e` |
| `20260819125807` | `add_followups_users_computed_relationship` | 455 | `388272b5e71cb49ac177945f32384edd` |
| `20260819130039` | `compat_patients_patient_number` | 254 | `652a89bec1fe269fbafc5e7ac936fb68` |
| `20260819222434` | `add_prescription_ux_fields` | 358 | `a86f52c024524c8fa937fcfc88b413e2` |
| `20260819223342` | `add_medical_certificates_soft_delete_columns` | 290 | `a3c703eb0319e1f1ef98a4156120cd3d` |
| `20260820000007` | `add_medicines_2_stock_quantity_compatibility` | 956 | `a49ef8d739e6cb267888a0c1b7ec9a73` |
| `20260820000143` | `add_medicines_2_stock_quantity` | 102 | `1d32e0cc340a46f6d5bf252caec99d24` |
| `20260820000336` | `fix_medicines_stock_quantity_schema_cache` | 356 | `241bbbb27bf3edafeb60191bdaa0a630` |
| `20260820000656` | `add_medicines_reorder_level` | 99 | `1e478733e1e978283a4fb06bc0dde2ee` |
| `20260820000725` | `add_medicines_expiry_date` | 75 | `34caa91bdc2b6b1051202d380336d4ca` |
| `20260820005417` | `fix_followups_user_relationship` | 507 | `75d47f32e8627e2d587990284791fa63` |
| `20260820010030` | `fix_medicines_batch_number` | 190 | `857c21fd0dff64de9f3a8c5cb6555e8b` |
| `20260820150215` | `roshan_phase2_clinical_workflow` | 640 | `3b13a90d96e8d878c97be72b8c21c905` |
| `20260822094358` | `roshan_workflow_performance_20260822` | 2230 | `a47d2b6af7e90cf6c9375af0308ae32f` |
| `20260822094405` | `roshan_drop_duplicate_prescription_index_20260822` | 64 | `013b6f046a1cc5d09636d142232ce8b1` |
| `20260906142737` | `roshan_phase3_allow_pharmacy_setting_public` | 1199 | `2c21995b7a241df642b44c06d8202eb9` |
| `20260906142803` | `roshan_phase3_pharmacy_batches` | 9097 | `5af0b31a2ae1998a57a4dd3e8f510759` |
| `20260906144008` | `roshan_phase4_finance_cashbox_debts` | 14679 | `bc611918fa30c7aa33622350d63c4f1e` |
| `20260906161023` | `roshan_phase4_finance_security_verification_patch` | 3589 | `49626f4e7b252184c147402f4639f3ba` |
| `20260906203143` | `roshan_phase3_pharmacy_runtime_hardening` | 6980 | `a7a95cc25eb5e395af595ab2192c9d34` |
| `20260908210824` | `roshan_phase4_finance_v2` | 24052 | `4be9232e7e06b03ff5827ae9af046ec0` |
| `20260909110657` | `roshan_phase5_insurance` | 7616 | `0270b37760a90ace769c63cee95d7bfa` |
| `20260909110735` | `roshan_phase5_insurance_functions` | 10859 | `20fa5cff06280170d2d4a2cb85e63e0b` |
| `20260909110753` | `roshan_phase5_insurance_permissions_rls` | 4922 | `0eacc16749f50f8401dfdeb48699c486` |
| `20260911120231` | `roshan_phase12_invoice_visit_unique` | 425 | `5182147d2ed12b1a7df402b763c5a1c5` |
| `20260911130749` | `harden_security_and_fk_indexes_20260911` | 7111 | `2cbc5a3b8a370baae854dc1883604aa2` |
| `20260911130812` | `restrict_security_definer_api_execution_20260911` | 2164 | `52b0166fba689c66bf81454aa91b200c` |
| `20260911131456` | `deep_audit_branch_isolation_rpc_hardening` | 8077 | `2e229e263b04b6144047fcabbbd87d94` |
| `20260911133229` | `harden_mrn_invoice_number_concurrency` | 1009 | `0fd7b0b1afb1ef6cb390a0b6657de5d2` |
| `20260911133255` | `enforce_branch_isolation_rls` | 1566 | `7cb965a4218bb2772115ac51c62ade30` |
| `20260911133312` | `harden_insurance_branch_isolation` | 10214 | `807b9c4f3b44051dfcce405d9134ea91` |
| `20260911133319` | `harden_insurance_coverage_rpc_branch` | 3256 | `729d5bcf5413cd22f9e55cf567339536` |
| `20260911133334` | `harden_finance_branch_context` | 5439 | `a71cfe441881bc3b5c446d278004f141` |
| `20260911133353` | `fix_insurance_ledger_branch` | 2412 | `69c264478ac420a24e4f220628991008` |
| `20260911134639` | `grant_next_invoice_number_authenticated` | 76 | `689073830d971ea3797b9134cf742e54` |
| `20260911135036` | `grant_stock_movements_authenticated_access` | 74 | `1f8872b32f0155a028f92f6fe7abf63a` |
| `20260911135318` | `fix_dispense_prescription_nullable_join_lock` | 4530 | `f19b9e9be96dd1576bcea4a5905466f6` |
| `20260911135417` | `fix_dispense_prescription_branch_resolution` | 4942 | `245bb5f291ab0d66a3b50a1cf67d384f` |
| `20260911135547` | `fix_dispense_batch_number_ambiguity` | 4514 | `b97b78aebc298b59968f5b61ed4f0fc5` |
| `20260911135644` | `add_medicines_updated_at_column` | 202 | `fe9d4a0aeab1f2d43387afe8fc75ee42` |
| `20260911135738` | `add_prescription_items_updated_at` | 209 | `6ec0de79ef268dde821bc900141f4d5a` |
| `20260911135858` | `add_prescriptions_updated_at` | 199 | `7ef79eb4301246c5d8ccd11e0c98f36c` |
| `20260911140337` | `add_cashbox_reversal_columns` | 352 | `7ee3c7aa0e90cdef42c673ddb1400c79` |
| `20260911140514` | `allow_cashbox_reversal_transaction_type` | 458 | `8902149a901a8b8d98d17d7c81025995` |
| `20260911141036` | `harden_cashbox_reversal_type` | 2019 | `43ebb562e681f2573d5da1b18cc88eeb` |
| `20260911141142` | `fix_payment_ledger_transaction_type` | 463 | `bfa156ad16dc182f9c0f6d12db669d0e` |
| `20260911141502` | `fix_medicines_generic_name_compatibility` | 1205 | `7cd494cb4719e2aea283093afa056648` |
| `20261011074344` | `harden_patient_invoice_number_rpc_permissions` | 1369 | `fa85bc51d4fe743b5a5762718e46e736` |
| `20261011074437` | `harden_insurance_coverage_rpc_permissions` | 3835 | `8504c98d1e4d3cee48826e41e5d69408` |
| `20261011075101` | `harden_pharmacy_batch_branch_isolation` | 2639 | `2e632526be6a5021352adcb533d20b09` |
| `20261011080253` | `harden_supplier_bill_rpc_branch_and_search_path` | 2418 | `5d6254563c77eba7445c7cd441761598` |
| `20261011080319` | `harden_finance_pharmacy_rpc_search_paths` | 971 | `c03361836985e996c05206b78f0b5127` |
| `20261011080434` | `enforce_branch_isolation_on_clinical_child_tables` | 6804 | `78010a0852d06cdae5d19c7743387478` |
| `20261011080524` | `preserve_super_admin_supplier_bill_compatibility` | 2439 | `f057895df5f103ba2dd6740e5dbc8152` |
| `20261014164131` | `roshan_cashbox_reversal_concurrency` | 2217 | `ae4f73ae273554f14fc0f5cf8052f9ef` |
| `20261016161923` | `roshan_phase18_dedupe_finance_audit_triggers_20261016` | 492 | `e98df7f7d58a48ca7e0b02d1b1539ef7` |
| `20261016162410` | `roshan_phase21_patient_registration_atomicity_20261016` | 2723 | `18635b1e9bd434a14eb12fe10b2332af` |
| `20261016170816` | `roshan_security_privileged_role_guard_20261016` | 9015 | `387ec6e2f1e7e3611f39ec23c8d85aba` |
| `20261016172209` | `roshan_phase7_atomic_prescription_20261016` | 6126 | `77f316403d348341afc746352460f044` |
| `20261016183123` | `roshan_phase8_atomic_invoice` | 5877 | `649c7e2823b07eda341b54f48a1305b3` |
| `20261016183130` | `roshan_phase13_consolidated_visit_invoice` | 16831 | `d8b64bfde09ec8a62edc83e70e7fd641` |
| `20261016183136` | `roshan_phase14_dispense_invoice_atomic_compat` | 10613 | `ff0da5cccabdd3b1029e02bdfea39e3e` |
| `20261016183145` | `roshan_phase15_manual_invoice_consolidation` | 4137 | `12c8bc97d2491185fe66fde0992b6716` |
| `20261016183152` | `roshan_phase16_billing_idempotency` | 5005 | `3846e3e7cd2692b0c65aca5fd5d2c7b1` |
| `20261016204859` | `roshan_phase21_patient_registration_privileges_20261016` | 246 | `f8b6284f3e72e8b231e755ab5817776a` |
| `20261016211342` | `roshan_phase22_clinic_local_queue_date_20261016` | 1534 | `4674f5bca39b8a3c81e1c869df905d3f` |
| `20261016215806` | `roshan_phase23_legacy_queue_allocator_20261016` | 1024 | `c500691c6c6dec3ea92f90c785d79854` |
| `20261016221553` | `roshan_phase24_visit_form_options_20261016` | 1588 | `c866539de52f70644cfd9226e42f23da` |
| `20261016222009` | `roshan_phase25_current_app_profile_20261016` | 2016 | `8f321030af405a2e54627a0bc0511396` |
| `20261017125924` | `roshan_security_candidate_bundle_20261017` | 29978 | `60269c5efa4d8be85581f14849f1667d` |
| `20261017125934` | `roshan_insurance_claim_amount_integrity_20261017` | 7361 | `4473480eafeaf155dde074db1782ec71` |
| `20261017125936` | `roshan_insurance_coverage_validity_20261017` | 7338 | `563596abd9ac7cab76e7e5cd8523558f` |
| `20261017133157` | `roshan_revoke_legacy_invoice_number_20261017` | 260 | `5d7259780affcb29ec995858a6d3c520` |
| `20261017225523` | `roshan_insurance_prior_authorization_branch_isolation` | 1894 | `39bc12e5dc47ddf445211f4777b20430` |
| `20261017225540` | `roshan_post_expense_finite_amount` | 1482 | `9736250e430c712c687d46b0840812b5` |
| `20261017230623` | `roshan_post_expense_money_precision` | 1570 | `bed511038aad5ece9d06bf743b79108a` |
| `20261017230645` | `roshan_insurance_claim_money_precision` | 5293 | `9799a03e105c1465fda2805e10594df9` |
| `20261017231612` | `roshan_invoice_payment_money_precision` | 3652 | `5955bd258f9c9f4e0ba8eaf3f534033f` |
| `20261017231629` | `roshan_pharmacy_batch_money_precision` | 3078 | `d799b199850edb28c4a4c064746046ed` |
| `20261018061746` | `roshan_pharmacy_batch_receipt_idempotency` | 5701 | `34f4a16b5fbab81a0c4f892bb7f95ba1` |
| `20261018062939` | `roshan_pharmacy_batch_receipt_guards` | 8353 | `683571b0350a9ea2e17f376f16d26c7e` |
| `20261018063549` | `roshan_phase19_invoice_rpc_only_writes` | 2164 | `086f07c62117660dd5012dca353b41fa` |
| `20261018064139` | `roshan_phase20_clinical_child_branch_isolation` | 13474 | `4b0c2e855ce08879c9cf9bc074c39897` |
| `20261018064638` | `roshan_clinical_child_write_rpcs` | 3613 | `690778a46c97d3886cbb203599b6584d` |
| `20261018065708` | `roshan_clinical_child_rpc_only_writes` | 520 | `737b78e71cb5d5f0fd6cb7323f5d9f9b` |
| `20261018201642` | `roshan_phase31_clinical_financial_security_hardening` | 18493 | `b49393f160d5c097973bbbe3ea3499ed` |
| `20261018201758` | `roshan_phase31_contract_security_cutover` | 1197 | `9ed77769bf921a7c7c397e16b8372ba7` |
| `20261019061315` | `roshan_phase32_medical_certificate_visit_index` | 107 | `8ffa48d50ddc55eedd19e9ebce224090` |
| `20261020090350` | `roshan_phase34_storage_guard_lab_verify_realtime` | 20212 | `704c7a6127d9a2f7056f42d8ba35ae85` |
| `20261020111126` | `roshan_phase36_audit_coverage_and_visit_lifecycle_guards` | 4116 | `709b9cde24364271cab45c801cf256da` |
| `20261020232033` | `roshan_phase39_permissions_lab_catalog_and_audit_closure` | 3211 | `1739b0eb57bfd70d978955bebd603378` |
| `20261031071119` | `roshan_phase46_uat_schema_compatibility` | 5239 | `c762c78af47bc2521fa21af0f07fe739` |
| `20261031071122` | `roshan_phase47_queue_branch_attribution` | 6568 | `dc616222eae5d6e5d2c6b9de5aa47ffc` |
| `20261031103927` | `roshan_phase48_storage_entity_branch_binding` | 5663 | `f5ee865d0429bf532977924ef60978fa` |
| `20261102122437` | `superseded_placeholder_phase49_atomic_pharmacy_dispense` | 138 | `99219a63dc008c857c674f0a198fac42` |
| `20261102133658` | `superseded_placeholder_phase50_clinical_visit_bill_completion` | 138 | `99219a63dc008c857c674f0a198fac42` |
| `20261102133734` | `superseded_placeholder_phase51_public_setup_required_anon` | 138 | `99219a63dc008c857c674f0a198fac42` |
| `20261102140000` | `superseded_placeholder_phase52_reporting_analytics` | 138 | `99219a63dc008c857c674f0a198fac42` |
| `20261102232813` | `roshan_remediation_archive_container` | 443 | `a39956f8bbc2fe44fb6c4bc10fcab39a` |
| `20261102232819` | `roshan_phase49_isolate_malformed_idempotency_table` | 227 | `34856827a2ac18a01d5065e5fa896a00` |
| `20261102232823` | `roshan_phase49_atomic_pharmacy_dispense_repaired` | 19149 | `5e9082b7f8efa2733eac3463080552bc` |
| `20261102232849` | `roshan_phase50_clinical_visit_bill_completion_reconciled` | 4478 | `381936b092c5c5a85983b198cb2524c1` |
| `20261102232852` | `roshan_phase51_public_setup_required_anon_reconciled` | 792 | `ce740f50fdf5f0d3d6f279c427e65fca` |
| `20261102232855` | `roshan_phase52_reporting_analytics_reconciled` | 14310 | `f3e301313a7541d087264f50083e99bb` |
| `20261102232941` | `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | 3289 | `eedfc4ec43dc90edf1765a23790516b0` |

## Complete QA ledger — 22 rows

| Version | Migration name | JSON bytes | MD5 |
| `20261023182629` | `qa_schema_baseline_v112_platform_preserving` | 430993 | `f3a1dede1deddcfe74b8cba3e9566932` |
| `20261023182742` | `roshan_phase34_consolidated_storage_realtime_lab_verify` | 20610 | `1c77a2ce8d9134d9ed43a24b5ee4af7e` |
| `20261023182746` | `roshan_phase36_audit_coverage_and_visit_lifecycle_guards` | 4069 | `dc53f0787d2d1883c4fff492fc8b9b1e` |
| `20261023182750` | `roshan_phase39_permissions_lab_catalog_and_audit_closure` | 2524 | `42d8f6df5f1cb9625569a9056a2cfd22` |
| `20261023182756` | `roshan_phase45_atomic_visit_queue_completion_retry` | 2926 | `960988cf6d716604a65d6b1ef5a7363a` |
| `20261023182855` | `qa_phase31_contract_security_cutover` | 1213 | `d9bf16614626e5bce2715caa6182eb2a` |
| `20261023183515` | `qa_acl_reconciliation_from_production_catalog` | 15171 | `d9a60abdff07ae8f6ed84b15ebe31b9b` |
| `20261023183623` | `qa_authenticator_acl_and_default_privileges_reconciliation` | 16190 | `227ec9804038d39c92988a32d571f699` |
| `20261031065937` | `roshan_phase46_uat_schema_compatibility` | 5239 | `c762c78af47bc2521fa21af0f07fe739` |
| `20261031070544` | `roshan_phase47_queue_branch_attribution` | 6568 | `dc616222eae5d6e5d2c6b9de5aa47ffc` |
| `20261031071243` | `qa_restore_security_invoker_on_exposed_views` | 2410 | `c81b917f1665ec105ff4ba1166472ff2` |
| `20261031103912` | `roshan_phase48_storage_entity_branch_binding` | 5663 | `f5ee865d0429bf532977924ef60978fa` |
| `20261102122437` | `roshan_phase51_public_setup_required_anon` | 556 | `f5ee887188ec948f083aba0f0e87b02a` |
| `20261102133658` | `roshan_phase49_atomic_pharmacy_dispense` | 19159 | `12ddaceff592d8e7559056a47ce178b7` |
| `20261102133734` | `roshan_phase50_clinical_visit_bill_completion` | 4488 | `5db588886b2741e4759479dc9e9a0b1f` |
| `20261102232858` | `superseded_duplicate_roshan_phase50_clinical_visit_bill_completion` | 4478 | `381936b092c5c5a85983b198cb2524c1` |
| `20261102232905` | `roshan_phase52_reporting_analytics_reconciled` | 14310 | `f3e301313a7541d087264f50083e99bb` |
| `20261103114242` | `roshan_phase54_source_aware_financial_reversal` | 7817 | `8329dbfe9a51b588a3c0244e21736726` |
| `20261103114612` | `roshan_phase54b_payment_updated_at_compat` | 4983 | `8fef1495c28875c149ace54c133b61b2` |
| `20261103115649` | `roshan_phase54c_branchless_receipt_integrity` | 10409 | `78baf5a4d3f03d1af45ebdcaf3a858cc` |
| `20261103155227` | `roshan_phase55_clinical_parent_guard_acl_reconciliation` | 2308 | `6b8e017911641a60ec1599362d4351bd` |
| `20261104065852` | `roshan_phase57_pharmacy_quantity_required_guard` | 10958 | `7bffc0d979d925cc3633a21e7292625d` |
