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
