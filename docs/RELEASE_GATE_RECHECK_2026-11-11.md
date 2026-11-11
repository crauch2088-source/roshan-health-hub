# Release-gate recheck — 2026-11-11

This record distinguishes source code, hosted migrations, deployed application code, backup artifacts and operational acceptance. It does not authorize Production changes.

## Repository and CI

- Main SHA: `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`.
- PR #228 merged at `1eb6b273f01e190f8862d54a23734983512784d9`; PR #230 at `bed4ef10ba282d052e7ecb8d90c05d14d8443dcb`; PR #231 at `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`.
- Main CI [42974906291](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42974906291): 18 successful jobs, 0 failed, 1 intentional clinical-acceptance skip. Finance integration [42974906293](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42974906293): 2/2 successful PostgreSQL 17 jobs.
- 11 open PRs and 3 open Issues. #229 is Draft/non-mergeable; #211 Draft/non-mergeable; #216 open/mergeable but Vercel preview is quota-blocked. Issues #199, #217, #218 remain open.

## Production and QA Supabase

| Gate | Production | QA |
|---|---|---|
| PostgreSQL | 17.6 | 17.11 |
| Migration rows | 129 | 22 |
| Latest migration | `20261102232941` | `20261104065852` |
| Phase 57 ledger | absent | applied |
| `prescription_items.quantity` | nullable | nullable |
| Dispense NULL rejection | absent | present |
| NULL-to-one fallback | present | absent |

Phase 57's byte-identical source is now on main at blob `9db6768999352c32081f69b5e665c3cc95452616`. The app UI is fail-closed in the deployed build, but the Production RPC still has the fallback. Phase 57B is candidate-only.

The current source map documents 129/129 Production and 22/22 QA row dispositions; this is not semantic parity. Three version IDs are shared but differ in name/fingerprint; 126 rows are Production-only and 19 QA-only. The effective-catalog comparison found public table/view structure, columns, constraints, indexes, RLS, policies, triggers and table grants aligned, with known private-table, function-body and two helper-ACL differences. Issue #218 tracks the Production Phase 55 helper ACL gap.

## Supabase advisors

| Project | Security | Performance | Health |
|---|---|---|---|
| Production | 5 groups / 31 findings | 2 groups / 96 findings (2 unindexed FKs on legacy private table; 94 unused indexes) | 0 |
| QA | 5 groups / 32 findings | 1 group / 142 unused indexes | 0 |

Security findings include private RLS-enabled tables without policies, `pg_trgm` in public, the intentional boolean `setup_required()` SECURITY DEFINER exposure, authenticated SECURITY DEFINER RPCs and disabled leaked-password protection. No grants, Auth settings, extensions, indexes, RLS policies or objects were changed.

## Vercel

Production deployment `dpl_ALmRL8NKie3WdCamcBagVacDSsEE` is READY on app commit `1eb6b273f01e190f8862d54a23734983512784d9`; canonical alias `roshan-health-hub.vercel.app` is present and `aliasError=null`. Main's later commits are documentation-only; no new deployment was required or triggered.

## Backup and restore

- Backup-runner main: `7a3409ad84b4394014aeff36431a95a69813b90d`.
- Latest main run [42791754738](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42791754738): validation succeeded, backup job skipped, no artifact. This is not a backup.
- Prior full run [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237), on feature branch SHA `713ee4edf47429df9e02c475e5909e4c4f62a744), passed PostgreSQL 17 isolated restore, critical count comparison, age encryption and ciphertext upload. Its Actions artifact is no longer available.
- The encrypted Drive copy remains present in **Roshan Health Hub - Encrypted Backups / 2026-11-09**: `Roshan-Production-Backup-2026-11-08.zip`, 305,317 bytes, MD5 `875a85ac23e8b7a671c371cca41f7732`, not trashed. Device-side checksum/decryption/archive-readability passed 2026-11-09. The archive is database-only; Storage object bytes and Vault secrets were not included (both counts were zero at backup time).
- No full backup has exercised current runner main. No external backup write was triggered. Workflow remains manual.

## Release gate disposition

- **Verified:** current-main CI/finance integration; Phase 57 source on main; QA Phase 57; READY Vercel alias; encrypted off-site database archive still present; prior isolated PostgreSQL 17 restore and device decryption evidence.
- **Incomplete/blocked:** Production Phase 57 and Phase 55 ACL changes; full semantic migration/effective-catalog reconciliation; full backup on current runner main; Phase 61 branch reconciliation and independent review; authenticated pharmacist/prescriber, staff, print and device acceptance.
- **Explicitly deferred:** authenticated clinical E2E until a free isolated test environment and synthetic doctor/pharmacist identities are available.
- **Next:** reconcile Draft PR #229 with main using a normal merge commit, preserve its dedicated prescription-authoring permission and no-side-effect tests, then run exact-head CI/PG17. Keep Draft pending independent review and mobile pharmacist/prescriber acceptance. Obtain explicit owner authorization before any full backup dispatch on current runner main.

No hosted DDL/DML, migration, privilege/Auth/Storage change, business-data write, backup dispatch, PR merge or deployment promotion occurred.
