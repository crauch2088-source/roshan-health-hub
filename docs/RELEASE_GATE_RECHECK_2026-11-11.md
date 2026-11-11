# Release-gate recheck — 2026-11-11

This record distinguishes source code, hosted migrations, deployed application code, backup artifacts and operational acceptance. It does not authorize Production changes.

## Repository and CI

- Main SHA: `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`.
- PR #228 merged at `1eb6b273f01e190f8862d54a23734983512784d9`; PR #230 at `bed4ef10ba282d052e7ecb8d90c05d14d8443dcb`; PR #231 at `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`.
- Main CI [42974906291](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42974906291): 18 successful jobs, 0 failed, 1 intentional clinical-acceptance skip. Finance integration [42974906293](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42974906293): 2/2 successful PostgreSQL 17 jobs.
- 11 pre-existing open PRs and 3 open Issues; the new documentation recheck PR #232 brings the current total to 12. #229 is Draft/non-mergeable; #211 Draft/non-mergeable; #216 open/mergeable but Vercel preview is quota-blocked. Issues #199, #217, #218 remain open.

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
- Prior full run [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237), on feature branch SHA `713ee4edf47429df9e02c475e5909e4c4f62a744`, passed PostgreSQL 17 isolated restore, critical count comparison, age encryption and ciphertext upload. Its Actions artifact is no longer available.
- The encrypted Drive copy remains present in **Roshan Health Hub - Encrypted Backups / 2026-11-09**: `Roshan-Production-Backup-2026-11-08.zip`, 305,317 bytes, MD5 `875a85ac23e8b7a671c371cca41f7732`, not trashed. Device-side checksum/decryption/archive-readability passed 2026-11-09. The archive is database-only; Storage object bytes and Vault secrets were not included (both counts were zero at backup time).
- No full backup has exercised current runner main. No external backup write was triggered. Workflow remains manual.

## Release gate disposition

- **Verified:** current-main CI/finance integration; Phase 57 source on main; QA Phase 57; READY Vercel alias; encrypted off-site database archive still present; prior isolated PostgreSQL 17 restore and device decryption evidence.
- **Incomplete/blocked:** Production Phase 57 and Phase 55 ACL changes; full semantic migration/effective-catalog reconciliation; full backup on current runner main; Phase 61 branch reconciliation and independent review; authenticated pharmacist/prescriber, staff, print and device acceptance.
- **Explicitly deferred:** authenticated clinical E2E until a free isolated test environment and synthetic doctor/pharmacist identities are available.
- **Next:** reconcile Draft PR #229 with main using a normal merge commit, preserve its dedicated prescription-authoring permission and no-side-effect tests, then run exact-head CI/PG17. Keep Draft pending independent review and mobile pharmacist/prescriber acceptance. Obtain explicit owner authorization before any full backup dispatch on current runner main.

No hosted DDL/DML, migration, privilege/Auth/Storage change, business-data write, backup dispatch, PR merge or deployment promotion occurred.


## Exact-head verification after initial publication

- PR #232 initial head `be142c6372be06c3d9d906f19675eced3911633d` completed CI [42975739280](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42975739280): 18 successful jobs, 0 failures, 1 intentional authenticated clinical-acceptance skip.
- CodeQL [42975736393](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42975736393) passed both Python and JavaScript/TypeScript analyses. Vercel Ignore Build Step skipped a docs-only preview; no deployment was created.
- PR #216 was reconciled with current main by normal two-parent merge commit `d24bf9feddd50384281ade242f6562ac250fb550` (parents: previous PR head `22a43bfaa93a83d2349516bc5c8fb250f4979d3d` and main `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb`). The PR remains open; this was a branch update, not a PR merge. Exact-head CI [42976273030](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42976273030) completed with 18 successful jobs, zero failures and one intentional clinical-acceptance skip; the Phase 49 PostgreSQL 17 quarantine contract passed. Integrations [42976272854](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42976272854), [42976272962](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42976272962) and [42976272795](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42976272795) all passed. Vercel status is green.


## Phase 61 branch reconciliation blocker — 2026-11-11

- Draft PR #229 head `21dea75c5b509045e00cd29b37dbcabafec1bfc1` remains non-mergeable: 27 commits ahead / 6 behind current main, merge base `d42baae4f5bdbb6319cd389630f0b4ad349150ab`.
- The current PR checkpoint lists three conflicts: `docs/48H_EXECUTION_LOG_2026-11-10.md`, `docs/MASTER_PLAN.md`, and `src/routes/_authenticated/pharmacy.tsx`. The workflow and quantity-helper changes are not listed as current conflicts; preserve the mainline Phase 57/57B implementation and resolve only the actual overlapping files. Main also carries the restored Phase 57/57B SQL and fail-closed pharmacy UI; do not overlay the PR tree wholesale.
- Last exact-head PR #229 CI [42906793861], Phase 61 PostgreSQL 17 [42906793698], prescription [42906794175], insurance [42906794125], privileged-role [42906793823], Spec Kit [42906795609] and insurance UI [42906793828] checks passed on the pre-reconciliation head. Its Vercel status failed due the free build-rate limit; no retry, quota bypass or paid upgrade was attempted. These old checks do not validate a reconciled tree.
- Next: create a normal two-parent merge commit preserving both histories, resolve the three overlaps explicitly, preserve `prescriptions.create` authorization and no-side-effect contracts, then run exact-head CI/PG17 once. Keep Draft until independent review and pharmacist/prescriber mobile acceptance.


## Follow-up verification — 2026-11-11 07:15 UTC

- Before this documentation correction, PR #232 head `fe3c353d80906c581438743f5be2c8f9e813500d` passed exact-head CI [42977180293](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42977180293) (18 successful jobs, zero failures, one intentional authenticated clinical-acceptance skip) and CodeQL [42977173084](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42977173084) (success). The Vercel check on that head was successful. The new documentation commit requires its own exact-head checks.
- A fresh comparison of current main `ecdc7d6a1704bb07ca8e799e0afe50a8bc9197bb` against Draft PR #229 head `21dea75c5b509045e00cd29b37dbcabafec1bfc1` confirms 27 commits ahead / 6 behind, merge base `d42baae4f5bdbb6319cd389630f0b4ad349150ab`; GitHub still reports `mergeable=false`. The three conflicts recorded in the current PR checkpoint are the execution log, Master Plan, and authenticated pharmacy route.
- Supabase advisors were re-read at 07:15 UTC: Production Security 5 groups / 31 findings, Performance 2 / 96, Health 0; QA Security 5 / 32, Performance 1 / 142, Health 0. No ACL, Auth, RLS, extension, index, or object changes were made.
- The canonical Drive folder and dated child were re-listed read-only. The encrypted 305,317-byte archive remains present and not trashed. The latest backup-runner main workflow [42791754738](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42791754738) still has a successful validation job and a skipped backup job; no new backup or restore claim is made.
