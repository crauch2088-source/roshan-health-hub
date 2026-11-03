# Live Phase 49–52 and migration-provenance reconciliation

**Read-only verification date:** 2026-11-03  
**Repository main at application verification:** `a00f8111f9d6f38e02cf850be398a1c16fee8265`  
**Projects:** production `jewzonxplxhogqrnhosl`; isolated QA `hopfohcnrtbiqjkgeukz`.

## Scope and method

This is a read-only migration-ledger and PostgreSQL catalog inspection using migration-list operations and catalog-only `SELECT` statements. It did not read patient, visit, prescription, invoice, payment, expense or stock-movement rows; create test identities or records; or perform DDL, DML, grants, Auth, Storage or deployment mutations.

The `statement_md5` values are MD5 fingerprints of each stored statement array concatenated with a newline separator. They are forensic comparison aids, not cryptographic signatures or proof of repository-file identity. Function fingerprints are MD5 of `pg_get_functiondef(oid)`. Full source-to-ledger SHA-256 parity and full-schema parity were not performed.

## Environment and ledger state

| Environment | Status | PostgreSQL | Ledger rows | Latest ledger row |
|---|---|---:|---:|---|
| Production | `ACTIVE_HEALTHY` | 17.6.1.155 | 129 | `20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal` |
| QA | `ACTIVE_HEALTHY` | 17.11.0.003 | 17 | `20261102232905 roshan_phase52_reporting_analytics_reconciled` |

### Production Phase 49–52 ledger rows

| Version | Name | Statement bytes | MD5 |
|---|---|---:|---|
| `20261102122437` | `superseded_placeholder_phase49_atomic_pharmacy_dispense` | 134 | `86c9fe3553b0537bce754baecb76bcd8` |
| `20261102133658` | `superseded_placeholder_phase50_clinical_visit_bill_completion` | 134 | `86c9fe3553b0537bce754baecb76bcd8` |
| `20261102133734` | `superseded_placeholder_phase51_public_setup_required_anon` | 134 | `86c9fe3553b0537bce754baecb76bcd8` |
| `20261102140000` | `superseded_placeholder_phase52_reporting_analytics` | 134 | `86c9fe3553b0537bce754baecb76bcd8` |
| `20261102232819` | `roshan_phase49_isolate_malformed_idempotency_table` | 223 | `665db1b98a38b4af54a3b6d03e9175e5` |
| `20261102232823` | `roshan_phase49_atomic_pharmacy_dispense_repaired` | 19,145 | `0e0ea85d6d1bea3ac575892fe9b7583e` |
| `20261102232849` | `roshan_phase50_clinical_visit_bill_completion_reconciled` | 4,474 | `9cc937636c342d3b257e84eff0fe26af` |
| `20261102232852` | `roshan_phase51_public_setup_required_anon_reconciled` | 788 | `fc31b869c119988a8d96492840c33b6a` |
| `20261102232855` | `roshan_phase52_reporting_analytics_reconciled` | 14,306 | `6743bc9f79fbf747275393109d769625` |

The four 134-byte production rows share one fingerprint and are named as superseded placeholders; they are not evidence that the full migrations ran. The latest production cleanup/reversal row `20261102232941` was identified by name/version, but its SQL body and source mapping were not inspected in this pass.

### QA Phase 49–52 ledger rows

| Version | Name | Statement bytes | MD5 |
|---|---|---:|---|
| `20261102122437` | `roshan_phase51_public_setup_required_anon` | 552 | `4b848d12b776028dd67cc0e6ffebc452` |
| `20261102133658` | `roshan_phase49_atomic_pharmacy_dispense` | 19,155 | `55f65a3816d431ff42a5272c9e338658` |
| `20261102133734` | `roshan_phase50_clinical_visit_bill_completion` | 4,484 | `cf5948d78786d6038fa93a74ecf22256` |
| `20261102232858` | `superseded_duplicate_roshan_phase50_clinical_visit_bill_completion` | 4,474 | `9cc937636c342d3b257e84eff0fe26af` |
| `20261102232905` | `roshan_phase52_reporting_analytics_reconciled` | 14,306 | `6743bc9f79fbf747275393109d769625` |

The QA ledger contains Phase 51, 49, 50 and 52, but its history differs from production and includes a superseded duplicate Phase 50 row. The duplicate Phase 50 and production reconciled Phase 50 statement fingerprints match; Phase 52 fingerprints match across projects. Phase 49 and Phase 51 stored statements differ between projects. These differences still need source reconciliation.

## Final function catalog comparison

All six function-definition fingerprints below matched between production and QA.

| Function | Definition MD5 | Bytes | Security / volatility | EXECUTE: anon / authenticated / service_role |
|---|---|---:|---|---|
| `public.atomic_pharmacy_dispense(uuid,boolean,uuid)` | `c32ecc508535ca62d47bb30b87e7fcd1` | 3,719 | SECURITY DEFINER / VOLATILE | no / yes / no |
| `public.fn_dispense_prescription_with_invoice(uuid,boolean)` | `162794975fc4f6a9cc39d7314252e37f` | 10,166 | SECURITY DEFINER / VOLATILE | no / yes / no |
| `public.complete_clinical_visit_and_bill(uuid)` | `ac8ad218d24858054eebbe4eeff58c3d` | 3,533 | SECURITY DEFINER / VOLATILE | no / yes / no |
| `public.get_reporting_analytics(date,date,uuid)` | `4eab58dae9d5d1d251e9a9ddce46973a` | 12,080 | SECURITY INVOKER / STABLE | no / yes / no |
| `public.setup_required()` | `45e8bd588cad2458620c2d9fd1c91e01` | 189 | SECURITY DEFINER / STABLE | yes / yes / no |
| `private.setup_required()` | `a7da915c13fa4a993e7ad9caf497fb7d` | 205 | SECURITY DEFINER / STABLE | no / yes / no |

All six have an empty fixed `search_path`. The public setup wrapper's anonymous EXECUTE grant is intentional for a boolean bootstrap status; anon cannot execute the private helper or use schema `private`. The two environments' catalog metadata agree. Production RPC behavior was not exercised under an application session.

## Pharmacy RLS and privileges

- `private.pharmacy_dispense_idempotency` exists in both projects with seven expected columns, `request_id` primary key and a check requiring `result_payload` to be NULL or a JSON array. RLS is enabled; anon/authenticated have no direct table privileges.
- `public.stock_movements` has RLS enabled. Authenticated has SELECT only (no INSERT/UPDATE/DELETE); anon has no SELECT. Its only listed policy is authenticated SELECT gated by `pharmacy.read` and `private.app_has_branch_access(branch_id)`.
- `public.pharmacy_inventory`, `public.prescriptions` and `public.prescription_items` have RLS enabled and forced. Authenticated has SELECT only; direct writes are denied by table privileges.
- `public.medicines` has RLS enabled and forced. Authenticated CRUD grants exist, with the inspected policies gated by `pharmacy.*` permissions. The stock-aggregate trigger contract was not executed in this pass.

## Phase 52 indexes

All nine reporting indexes exist in both projects, with `indisvalid=true` and `indisready=true`: `payments_reporting_date_idx`, `expenses_reporting_date_idx`, `lab_orders_reporting_created_idx`, `insurance_claims_reporting_submitted_idx`, `insurance_claims_reporting_decided_idx`, `insurance_claims_reporting_paid_idx`, `prescriptions_reporting_created_idx`, `prescriptions_reporting_dispensed_idx`, and `stock_movements_reporting_created_idx`.

## What this proves — and what it does not

Verified: target RPC presence; matching fingerprints for the six listed function definitions; matching audited function flags/EXECUTE ACLs; pharmacy idempotency table shape; branch-scoped SELECT-only stock-movement access; and all nine reporting indexes valid/ready.

Not verified: full production/QA schema parity, exact repository-file-to-ledger SQL parity, complete migration-source mapping, the SQL body of production migration `20261102232941`, authenticated runtime behavior, report totals against synthetic fixtures, dispense/visit-completion E2E, or staff acceptance. No patient or financial rows were queried.

## Release boundary and next task

- No production DDL, DML, grants, Auth, Storage or deployment changes were made by this run.
- An encrypted off-site logical backup and successful isolated restore rehearsal were not evidenced here. Keep this gate **unverified**, not passed.
- Authenticated clinical E2E and staff UAT remain explicitly deferred until the isolated free QA login path and suitable synthetic clinician identity exist. The skipped CI acceptance job is not a pass.
- Next P0: recover and review exact stored SQL for production remediation rows `20261102232819`–`20261102232855` and cleanup/reversal row `20261102232941`; map each to quarantined, non-replayable source artifacts and the canonical manifest; compare source/ledger with SHA-256; then replay only in disposable PostgreSQL 17. Do not manually alter ledger rows, re-run live migrations or apply further production DDL during reconciliation.
- Complete the encrypted off-site backup and isolated restore drill before any further production database change or live-data launch.

## SHA-256 source mapping and remediation review — 2026-11-03

This addendum supersedes only the earlier statement that exact repository-to-ledger SHA-256 parity had not yet been checked for the Phase 49–52 rows. It does not establish full schema parity or full-chain replay.

| Production version | Stored name | Ledger bytes | Ledger SHA-256 | Source file | Result |
|---|---|---:|---|---|---|
| `20261102232823` | `roshan_phase49_atomic_pharmacy_dispense_repaired` | 19145 | `ba292230bafe17c6f8b6c6286f64073d83aaf19a7e468c9806bd6c45e7f78950` | `db/roshan_phase49_atomic_pharmacy_dispense.sql` | Exact byte match after removing only the terminal `COMMIT;` wrapper and trailing whitespace |
| `20261102232849` | `roshan_phase50_clinical_visit_bill_completion_reconciled` | 4474 | `3f663771a1739f3d67d71b0eeee74f959628e059081740ba83171f247436d180` | `db/roshan_phase50_clinical_visit_bill_completion.sql` | Exact byte match after removing only the terminal `COMMIT;` wrapper and trailing whitespace |
| `20261102232852` | `roshan_phase51_public_setup_required_anon_reconciled` | 788 | `1d38e5f1b45acd38bb1f96e58f17a24acd9cde2f89e5079971e709f730743dae` | `db/roshan_phase51_public_setup_required_anon.sql` | Exact byte match after removing only the terminal `COMMIT;` wrapper and trailing whitespace |
| `20261102232855` | `roshan_phase52_reporting_analytics_reconciled` | 14296 | `9be8cc5fd48631febf10e7e19c3bd46e8c65932ebafb3eec44269a2ee09972da` | `db/roshan_phase52_reporting_analytics.sql` | Exact byte match after removing only the terminal `COMMIT;` wrapper and trailing whitespace |

The checked-in source file SHA-256 values (including the terminal wrapper) and Git blob SHAs are preserved in `docs/recovered-migrations/phase49-52-provenance.json`.

### Unmapped remediation rows

- `20261102232819` (`roshan_phase49_isolate_malformed_idempotency_table`) is a 223-byte, one-statement table/index rename. Its ledger SHA-256 is `d34bcd4b12417cf0df7be976a80aea678ba352c72629f82267bb7b9933fcb3e8`. No matching canonical source file exists; the exact statement is preserved under `docs/recovered-migrations/sql/` as quarantine evidence.
- `20261102232941` (`roshan_synthetic_patient_cleanup_and_stock_ledger_reversal`) is a 3,285-byte, one-statement `DO` block with SHA-256 `e826d4947a497e61fcdde5b87ae4e1a8789523fa2979db048f6960b119e04c75`. It is not in the private remediation archive and no canonical source file was found. The public recovered copy redacts nine UUID occurrences across four distinct literals.
- Static review shows a guarded 49-to-50 medicine aggregate stock reversal plus a +1 stock-movement adjustment, followed by dynamic soft-deletion of related rows across qualifying public tables. It does not permanently delete those rows.
- Important limitation: the migration has no explicit synthetic-record marker check. It validates one target patient's existence and non-null branch, but does not explicitly assert that the second patient shares that branch. Because no patient/business rows were queried, this review cannot attest that the hard-coded targets were synthetic or that the data-level postconditions are correct. Do not rerun or reverse this migration based on inference.

### Superseded placeholders and private archive

- Production versions `20261102122437`, `20261102133658`, `20261102133734`, and `20261102140000` each contain the same 134-byte placeholder statement with SHA-256 `e95dd067bc31011d7c04ed1a0e1302f241472bf932b0a97203b1b1b4024d8c93`; they are not the actual migration SQL.
- `private.roshan_remediation_archive_20261103` exists with five rows: one malformed pharmacy-idempotency table row and four superseded placeholder migration rows. Its stored migration statement arrays are 11 bytes each, not the full SQL bodies. The table is owned by `postgres`, RLS is disabled, and direct SELECT/INSERT/UPDATE/DELETE grants are absent for anon, authenticated, service_role and authenticator; authenticated has schema USAGE but no table privilege.

### QA comparison

- QA Phase 49 (`20261102133658`) and Phase 50 (`20261102133734`) stored statements exactly match the checked-in source files.
- QA Phase 51 (`20261102122437`) differs from the current source only by omission of three leading explanatory comments and the following blank line; the SQL body and ACL statements match.
- QA Phase 52 (`20261102232905`) has the same stored SQL as production Phase 52 (`20261102232855`) and matches the source after terminal `COMMIT;` wrapper removal.
- QA's superseded duplicate Phase 50 row (`20261102232858`) matches production Phase 50's reconciled statement.

### Release boundary

- These were read-only migration-ledger/catalog queries. No production or QA DDL, DML, privilege, Auth, Storage or deployment changes occurred; no patient/clinical/financial rows were read.
- The encrypted off-site backup and isolated restore rehearsal remain unverified. Authenticated clinical E2E and staff UAT remain deferred by the owner; no acceptance is claimed.
- Next: build a disposable PostgreSQL 17 fixture for the 32819 rename and a parameterized synthetic equivalent of the 32941 stock-reversal/soft-delete contract. Do not execute either artifact against production or QA.
