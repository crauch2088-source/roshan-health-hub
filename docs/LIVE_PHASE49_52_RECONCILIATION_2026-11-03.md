# Live Phase 49–52 and migration-provenance reconciliation

**Read-only verification date:** 2026-11-03  
**Repository main at application verification:** `a00f8111f9d6f38e02cf850be398a1c16fee8265`  
**Projects:** production `jewzonxplxhogqrnhosl`; isolated QA `hopfohcnrtbiqjkgeukz`.

## Scope and method

This is a read-only migration-ledger and PostgreSQL catalog inspection using migration-list operations and catalog-only `SELECT` statements. It did not read patient, visit, prescription, invoice, payment, expense or stock-movement rows; create test identities or records; or perform DDL, DML, grants, Auth, Storage or deployment mutations.

The `statement_md5` values are MD5 fingerprints of `array_to_string(schema_migrations.statements, E'\\n')`. They are forensic comparison aids, not cryptographic signatures or proof of repository-file identity. Function fingerprints are MD5 of `pg_get_functiondef(oid)`. Full source-to-ledger SHA-256 parity and full-schema parity were not performed.

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
