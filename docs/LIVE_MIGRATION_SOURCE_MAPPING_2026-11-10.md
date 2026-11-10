# Live migration source and ledger mapping — 2026-11-10

## Scope and method

This is a read-only reconciliation supplement to the 2026-11-09 ledger report and the 48-hour H0 evidence ledger. The companion [fingerprint snapshot](LIVE_MIGRATION_LEDGER_FINGERPRINTS_2026-11-10.json) contains only each live row's version, migration name, byte length and MD5 of `statements::text`. No migration SQL body was read or exported. No DDL/DML, ledger repair, replay, permission change or business-row query was performed.

Main at capture: `bed6ff4c87d582107bf62ee353be4eb35958481b`.

## Current live ledger result

| Measure | Production | QA |
|---|---:|---:|
| PostgreSQL | 17.6 | 17.11 |
| Migration rows | 129 | 22 |
| Latest version | `20261102232941` | `20261104065852` |
| Latest name | `roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` | `roshan_phase57_pharmacy_quantity_required_guard` |

The environments share only three version IDs. All three collide with different names and statement fingerprints:

| Version | Production | QA |
|---|---|---|
| `20261102122437` | `superseded_placeholder_phase49_atomic_pharmacy_dispense` (138 bytes; MD5 `99219a63dc008c857c674f0a198fac42`) | `roshan_phase51_public_setup_required_anon` (556 bytes; MD5 `f5ee887188ec948f083aba0f0e87b02a`) |
| `20261102133658` | `superseded_placeholder_phase50_clinical_visit_bill_completion` (138 bytes; same placeholder MD5) | `roshan_phase49_atomic_pharmacy_dispense` (19,159 bytes; MD5 `12ddaceff592d8e7559056a47ce178b7`) |
| `20261102133734` | `superseded_placeholder_phase51_public_setup_required_anon` (138 bytes; same placeholder MD5) | `roshan_phase50_clinical_visit_bill_completion` (4,488 bytes; MD5 `5db588886b2741e4759479dc9e9a0b1f`) |

This means 126 rows are Production-only and 19 are QA-only by version ID. Never repair this by replaying one environment's history, inserting ledger rows manually, or reusing a colliding timestamp.

### Identical stored statement fingerprints under different version IDs

The live metadata query found **five** cross-environment pairs with identical byte lengths and MD5 fingerprints, not only the two Phase 50/52 pairs listed in the earlier 2026-11-09 report:

| Logical migration | Production version | QA version | Bytes | MD5 |
|---|---|---|---:|---|
| Phase 46 UAT schema compatibility | `20261031071119` | `20261031065937` | 5,239 | `c762c78af47bc2521fa21af0f07fe739` |
| Phase 47 queue branch attribution | `20261031071122` | `20261031070544` | 6,568 | `dc616222eae5d6e5d2c6b9de5aa47ffc` |
| Phase 48 storage/entity binding | `20261031103927` | `20261031103912` | 5,663 | `f5ee865d0429bf532977924ef60978fa` |
| Phase 50 clinical visit completion | `20261102232849` | `20261102232858` | 4,478 | `381936b092c5c5a85983b198cb2524c1` |
| Phase 52 reporting analytics | `20261102232855` | `20261102232905` | 14,310 | `f3e301313a7541d087264f50083e99bb` |

Equal byte length plus MD5 is strong evidence of equal stored serialization for these pairs. It is not a semantic SQL review, a source-file hash, or proof that the full schema/function/ACL catalogs are equal. Phase 49 and Phase 51 do not appear among the equal-fingerprint pairs.

## Source coverage: what is and is not proved

The repository currently has several differently scoped, historical source artifacts. They must not be described as one current 129-row parity result:

- `docs/recovered-migrations/manifest.json` is a **79-row** recovery snapshot from 2026-10-15.
- `docs/recovered-migrations/source-parity-report.json` is a **93-entry** normalized-source snapshot from 2026-10-17 (92 normalized matches and one intentionally redacted environment-specific identity mapping).
- `docs/LIVE_MIGRATION_DELTA_2026-10-18.md` and its JSON extend that frozen historical set with forward-source mappings through the then-current 109-row ledger. Its own limitation says the source hashes are repository hashes, not independent hashes of stored live SQL.
- `docs/APPLIED_MIGRATION_INVENTORY.md` contains 94 rows and ends at `20261017133157`; it is not a current full Production inventory.
- `docs/recovered-migrations/phase49-52-provenance.json` provides a scoped normalized-source mapping for four Production Phase 49–52 rows, identifies the four superseded 134-byte placeholders, and records two non-replayable quarantine artifacts. It was captured before the current 22-row QA ledger.
- `.github/workflows/ci-migration-source-parity.yml` explicitly runs `scripts/verify-migration-source-parity.py` against the historical 93-entry hashes and forward-source delta. It does not connect to Supabase or compare the current live 129/22 ledgers. A green run is source-repository consistency evidence, not live-ledger parity.

The 14 Production rows after the previously documented 115-row checkpoint have the following disposition:

- Phase 46, 47 and 48 have exact cross-environment stored fingerprints under different version IDs and corresponding tracked source files.
- Four Phase 49–52 rows (`20261102232823`, `20261102232849`, `20261102232852`, `20261102232855`) have scoped normalized source mappings in `phase49-52-provenance.json`; that comparison removes only the terminal `COMMIT;` wrapper and trailing whitespace.
- Four earlier version IDs are 134-byte superseded placeholders, not the Phase 49–52 migration bodies.
- `20261102232813` is a remediation archive-container entry; it is not a forward schema migration source.
- `20261102232819` is an exact recovered table/index rename artifact kept in quarantine; it is not approved for replay.
- `20261102232941` is a redacted cleanup/stock-reversal artifact. Its original SQL is not committed publicly, and the redacted copy is non-replayable. Static review found a broad soft-delete sweep and did not prove that fixed target identifiers are synthetic. Do not infer that fact from migration names or prior narrative.

QA additionally has the Phase 54, 54B, 54C, 55 and 57 forward migrations. The corresponding Phase 54/54B/54C/55 source files are tracked on main; the Phase 57 source is currently in Draft PR #209 and is not yet on main. QA's baseline and ACL/restore-specific reconciliation rows remain environment-specific evidence and are not interchangeable with Production migration files.

## Phase 57 pharmacy quantity guard

Read-only function-definition checks confirm:

- Production: explicit NULL guard absent; legacy `COALESCE(pi.quantity, 1)` fallback remains.
- QA: explicit NULL guard present; NULL-to-one fallback absent; applied version `20261104065852`.
- `prescription_items.quantity` remains nullable in both environments.
- Current active, non-deleted NULL-quantity item count is zero in both environments.

The zero count is a snapshot, not protection against future bad writes. Production dispensing remains a P0 stop-ship until a reviewed forward-only migration is separately approved after source/recovery gates.

## Required next reconciliation work

1. Extend the current source map from the historical 115-row checkpoint to every current Production and QA ledger row, recording exact source path, repository blob/source hash, evidence type and whether the stored live statement itself was independently hashed.
2. Reconcile effective catalogs separately: tables/columns, constraints, indexes, functions/procedures, triggers, RLS policies, routine ACLs/default privileges and Storage policies. Matching table/column counts are insufficient.
3. The disposable PostgreSQL 17 fixture already exists on main and its exact rename/parameterized cleanup job passed in main CI run [42772781756](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42772781756). Draft PR [#216](https://github.com/crauch2088-source/roshan-health-hub/pull/216), commit `1b2a81e807b0c867bef3742794f2c15e4f1af536`, adds missing/duplicate target and wrong-branch/duplicate-ledger/inconsistent-stock negative cases; exact-head CI [42774855081](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42774855081) passed 18 jobs with one intentional clinical-acceptance skip, including the Phase 49 PG17 job. No further fixture build is needed. The original cleanup SQL remains unavailable, so these tests do not certify the original statement.
4. Keep Phase 57 in QA only until the source is on main, exact-head tests/review pass, and a synthetic pharmacist identity exists. Keep authenticated clinical E2E deferred until the isolated free environment and suitable synthetic doctor/pharmacist identities exist.

## Verification boundary

This report is evidence about migration history and source mapping only. It does not prove a full migration-chain replay, full effective-catalog parity, authenticated clinical/pharmacy acceptance, or authorization for any hosted change. Production remains read-only and gated.


## Current-row source/disposition matrix — 2026-11-10 addendum

The following matrix records every row in the current 14-row Production tail and all 22 current QA rows. “Repo blob” is the Git object ID of the tracked candidate/source file, not a hash of the stored live SQL. Except where the Phase 49–52 provenance artifact explicitly says otherwise, these rows are path/disposition mapped only; no live SQL bodies were read or exported.

### Production tail — all 14 rows after the 115-row checkpoint

| Version | Live migration name | Tracked source/artifact | Repo blob | Evidence/disposition |
|---|---|---|---|---|
| 20261031071119 | roshan_phase46_uat_schema_compatibility | db/roshan_phase46_uat_schema_compatibility.sql | 75b35475ea1aa048110ea74208b7fc59b2301b9d | Path mapped; exact stored fingerprint also matches QA version 20261031065937; no live-body export |
| 20261031071122 | roshan_phase47_queue_branch_attribution | db/roshan_phase47_queue_branch_attribution.sql | ba6daf5ec90266399e0db96aaf2ccb576d894e2b | Path mapped; exact stored fingerprint also matches QA version 20261031070544; no live-body export |
| 20261031103927 | roshan_phase48_storage_entity_branch_binding | db/roshan_phase48_storage_entity_branch_binding.sql | da16042eee5ef5a2261070e526fc3d4d416b69d7 | Path mapped; exact stored fingerprint also matches QA version 20261031103912; no live-body export |
| 20261102122437 | superseded_placeholder_phase49_atomic_pharmacy_dispense | No SQL source | — | 138-byte placeholder only; not the Phase 49 migration |
| 20261102133658 | superseded_placeholder_phase50_clinical_visit_bill_completion | No SQL source | — | 138-byte placeholder only; not the Phase 50 migration |
| 20261102133734 | superseded_placeholder_phase51_public_setup_required_anon | No SQL source | — | 138-byte placeholder only; not the Phase 51 migration |
| 20261102140000 | superseded_placeholder_phase52_reporting_analytics | No SQL source | — | 138-byte placeholder only; not the Phase 52 migration |
| 20261102232813 | roshan_remediation_archive_container | No tracked forward source | — | Archive-container ledger entry; not a replayable forward schema migration |
| 20261102232819 | roshan_phase49_isolate_malformed_idempotency_table | docs/recovered-migrations/sql/20261102232819_roshan_phase49_isolate_malformed_idempotency_table.sql | d443a3610832492b4e6e1953bd2656a4c7d3a432 | Exact recovered quarantine artifact; rename-only disposition; replay blocked |
| 20261102232823 | roshan_phase49_atomic_pharmacy_dispense_repaired | db/roshan_phase49_atomic_pharmacy_dispense.sql | cf3f67291601d7513d758570b8d46c35d6bc56f1 | Scoped normalized-source equality documented in phase49-52-provenance.json; terminal COMMIT wrapper/trailing whitespace removed |
| 20261102232849 | roshan_phase50_clinical_visit_bill_completion_reconciled | db/roshan_phase50_clinical_visit_bill_completion.sql | 031cca46782d5821f05d936ff7d35d9c19fef28c | Scoped normalized-source equality documented in phase49-52-provenance.json; terminal COMMIT wrapper/trailing whitespace removed |
| 20261102232852 | roshan_phase51_public_setup_required_anon_reconciled | db/roshan_phase51_public_setup_required_anon.sql | fc124e36b1435c9e135ed2ec282581f585f93a26 | Scoped normalized-source equality documented in phase49-52-provenance.json; terminal COMMIT wrapper/trailing whitespace removed |
| 20261102232855 | roshan_phase52_reporting_analytics_reconciled | db/roshan_phase52_reporting_analytics.sql | b86ccade80bc88e4a09d2e027389a1bd3782ad17 | Scoped normalized-source equality documented in phase49-52-provenance.json; terminal COMMIT wrapper/trailing whitespace removed |
| 20261102232941 | roshan_synthetic_patient_cleanup_and_stock_ledger_reversal | docs/recovered-migrations/sql/20261102232941_roshan_synthetic_patient_cleanup_and_stock_ledger_reversal.sql | 6466457b05e76580d5e4389597efa45107682e5b | Redacted quarantine artifact only; original SQL unavailable; replay blocked pending owner review and disposable-PG17 equivalence tests |

### QA ledger — all 22 rows

| Version | Live migration name | Tracked source/artifact | Repo blob | Evidence/disposition |
|---|---|---|---|---|
| 20261023182629 | qa_schema_baseline_v112_platform_preserving | db/baseline/0000_roshan_pg17_baseline_v112.sql (related baseline only) | cfde594e3710e79529439b637b2703cc1ed6e727 | No exact source/body equality claimed; QA-specific platform-preserving baseline |
| 20261023182742 | roshan_phase34_consolidated_storage_realtime_lab_verify | db/roshan_phase34_consolidated_storage_realtime_and_lab_verify.sql | 03432ada7c7a11cf2530ba9aadab35ab6bd0a1a6 | Historical source-path mapping; no independent stored-body hash |
| 20261023182746 | roshan_phase36_audit_coverage_and_visit_lifecycle_guards | db/roshan_phase36_audit_coverage_and_visit_lifecycle_guards.sql | c52c65cdd50767a71298de47682294ad45ffed89 | Source path present; no independent stored-body hash |
| 20261023182750 | roshan_phase39_permissions_lab_catalog_and_audit_closure | db/roshan_phase39_permissions_lab_catalog_and_audit_closure.sql | 72875833745f580ad7e3cb063aa1d6d04d7d8daa | Source path present; no independent stored-body hash |
| 20261023182756 | roshan_phase45_atomic_visit_queue_completion_retry | db/roshan_phase45_atomic_visit_queue_completion_retry.sql | 89c8cbdb4a77ca1852834cf477e5d36c612272e3 | Source path present; no independent stored-body hash |
| 20261023182855 | qa_phase31_contract_security_cutover | db/roshan_phase31_contract_security_cutover.sql | 27e4cbb44e8127e956188414a5673c5907a6d87b | Related source path; QA-specific variant not independently body-matched |
| 20261023183515 | qa_acl_reconciliation_from_production_catalog | No tracked source file found | — | Environment-specific QA ACL reconciliation; retain as a non-replayable historical event |
| 20261023183623 | qa_authenticator_acl_and_default_privileges_reconciliation | No tracked source file found | — | Environment-specific QA authenticator/default-privilege reconciliation; retain as a non-replayable historical event |
| 20261031065937 | roshan_phase46_uat_schema_compatibility | db/roshan_phase46_uat_schema_compatibility.sql | 75b35475ea1aa048110ea74208b7fc59b2301b9d | Stored fingerprint exactly matches Production Phase 46 under a different version |
| 20261031070544 | roshan_phase47_queue_branch_attribution | db/roshan_phase47_queue_branch_attribution.sql | ba6daf5ec90266399e0db96aaf2ccb576d894e2b | Stored fingerprint exactly matches Production Phase 47 under a different version |
| 20261031071243 | qa_restore_security_invoker_on_exposed_views | db/qa/20261030_restore_security_invoker_on_qa_views.sql | 31ce968972b0e55942a48c5f364029e4ec940bd7 | QA-only view-option reconciliation; not a Production migration |
| 20261031103912 | roshan_phase48_storage_entity_branch_binding | db/roshan_phase48_storage_entity_branch_binding.sql | da16042eee5ef5a2261070e526fc3d4d416b69d7 | Stored fingerprint exactly matches Production Phase 48 under a different version |
| 20261102122437 | roshan_phase51_public_setup_required_anon | db/roshan_phase51_public_setup_required_anon.sql | fc124e36b1435c9e135ed2ec282581f585f93a26 | SQL body/ACL statements match the source; QA copy omits three leading comments and one blank line |
| 20261102133658 | roshan_phase49_atomic_pharmacy_dispense | db/roshan_phase49_atomic_pharmacy_dispense.sql | cf3f67291601d7513d758570b8d46c35d6bc56f1 | Exact current source-file match documented in phase49-52-provenance.json |
| 20261102133734 | roshan_phase50_clinical_visit_bill_completion | db/roshan_phase50_clinical_visit_bill_completion.sql | 031cca46782d5821f05d936ff7d35d9c19fef28c | Current source path mapped; separate QA fingerprint recorded; no new independent hash claim beyond the scoped provenance artifact |
| 20261102232858 | superseded_duplicate_roshan_phase50_clinical_visit_bill_completion | db/roshan_phase50_clinical_visit_bill_completion.sql | 031cca46782d5821f05d936ff7d35d9c19fef28c | Same stored statement fingerprint as Production Phase 50 version 20261102232849 |
| 20261102232905 | roshan_phase52_reporting_analytics_reconciled | db/roshan_phase52_reporting_analytics.sql | b86ccade80bc88e4a09d2e027389a1bd3782ad17 | Scoped normalized-source equality documented in phase49-52-provenance.json |
| 20261103114242 | roshan_phase54_source_aware_financial_reversal | db/roshan_phase54_source_aware_financial_reversal.sql | 8c33e99f7b9d3772eb5136d4c957d5b9c1970659 | Source path present on main; no independent stored-body hash |
| 20261103114612 | roshan_phase54b_payment_updated_at_compat | db/roshan_phase54b_payment_updated_at_compat.sql | 3f68b6a4e4c74b265388fb822ea96c77d336fea2 | Source path present on main; no independent stored-body hash |
| 20261103115649 | roshan_phase54c_branchless_receipt_integrity | db/roshan_phase54c_branchless_receipt_integrity.sql | 1a061929f9a564ce1ddc917ad8c29b8252609593 | Source path present on main; no independent stored-body hash |
| 20261103155227 | roshan_phase55_clinical_parent_guard_acl_reconciliation | db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql | 081d5e97169786e23cd1990cf9f6dbb1c49e4a1f | Source path present on main; no independent stored-body hash |
| 20261104065852 | roshan_phase57_pharmacy_quantity_required_guard | db/roshan_phase57_pharmacy_quantity_required_guard.sql (immutable original) | 9db6768999352c32081f69b5e665c3cc95452616 | Exact byte-for-byte match to QA stored SQL body: 10,954 bytes; MD5 921970d4d86b32dccd430a0ea0ef8745. Production has no Phase 57 row. |

### What this matrix closes — and what it does not

- The previously unmapped current ledger tail now has a row-level path or explicit non-replayable/environment-specific disposition: 14/14 Production tail rows and 22/22 QA rows.
- This does **not** turn path mapping into proof that the live stored SQL equals the repository file. Exact stored/source normalization is claimed only where the scoped Phase 49–52 provenance artifact records it.
- The four untracked QA-specific baseline/ACL rows, Production archive-container entry, four Production placeholders, and two quarantine artifacts remain non-replayable or review-only. They must not be recreated by manually inserting ledger records.
- The older 115-row Production checkpoint and historical QA source set still require a single consolidated per-row matrix if a future reviewer needs one artifact spanning every historical row. Their evidence remains in the 79-row, 93-entry and 2026-10-18 source-mapping artifacts cited above.



### Direct stored-SQL body comparison — read-only, 2026-11-10

Selected stored statements were retrieved from `supabase_migrations.schema_migrations` and compared with exact repository source files. This is stronger than path mapping, but remains a selected subset rather than a complete 129/22-row source replay.

| Phase | Environment / version | Source bytes | Stored bytes | Result |
|---|---|---:|---:|---|
| 46 | Production `20261031071119`; QA `20261031065937` | 5,254 | 5,235 | Executable SQL equal after stripping line comments and normalizing whitespace; header comments differ |
| 47 | Production `20261031071122`; QA `20261031070544` | 6,650 | 6,564 | Executable SQL equal after stripping line comments and normalizing whitespace |
| 48 | Production `20261031103927`; QA `20261031103912` | — | — | Byte-for-byte exact |
| 49 | Production `20261102232823`; QA `20261102133658` | 19,155 | 19,145 / 19,155 | Production differs only by terminal wrapper/whitespace; QA byte-for-byte exact |
| 50 | Production `20261102232849`; QA `20261102133734` | 4,484 | 4,474 / 4,484 | Production differs only by terminal wrapper/whitespace; QA byte-for-byte exact |
| 51 | Production `20261102232852`; QA `20261102122437` | 798 | 788 / 552 | Both normalized executable SQL bodies equal; QA omits comments and transaction wrapper |
| 52 | Production `20261102232855`; QA `20261102232905` | 14,315 | 14,296 | Normalized executable SQL equal after comments/wrapper/whitespace normalization |
| 54 | QA `20261103114242` | 7,809 | 7,809 | Byte-for-byte exact |
| 54B | QA `20261103114612` | 4,977 | 4,977 | Byte-for-byte exact |
| 54C | QA `20261103115649` | 10,405 | 10,405 | Byte-for-byte exact |
| 55 | QA `20261103155227` | 2,305 | 2,304 | Normalized executable SQL equal; one trailing newline differs |
| 57 | QA `20261104065852` | 10,954 | 10,954 | Byte-for-byte exact; source blob `9db6768999352c32081f69b5e665c3cc95452616` |

Normalization removes line comments, outer BEGIN/COMMIT wrappers, and whitespace differences; it is not a SQL parser or semantic proof. No Production ledger rows exist for Phases 54, 54B, 54C, 55, or 57. Phase 57B is a candidate-only forward migration, not an applied ledger row.

The original Phase 57 migration source is now immutable and exact to QA. The subsequent free-text and external-prescription guards are tracked separately as `db/roshan_phase57b_free_text_external_prescription_guard.sql`; this candidate is not applied to QA or Production.
