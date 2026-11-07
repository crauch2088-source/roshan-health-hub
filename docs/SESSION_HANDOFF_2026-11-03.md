# Roshan Health Hub — session handoff (2026-11-03)

This document records the verified stopping point for the 2026-11-03 engineering session. It is a handoff snapshot, not a declaration that the clinic system is production-ready.

## Repository and merge state

- Repository: `crauch2088-source/roshan-health-hub`
- Main HEAD at handoff: `d2cb1e068e4bcf78e20968c77f255b160f77d9f2`
- Phase 55 PR: [#172 — reconcile clinical parent guard and private helper ACLs](https://github.com/crauch2088-source/roshan-health-hub/pull/172)
- PR #172 is merged. Merge commit: `a7592e8fc63f498e55e0962718f4ad84557f1b56`.
- Current main includes subsequent Phase 53/specification reconciliation commit `d2cb1e068e4bcf78e20968c77f255b160f77d9f2`.
- No production deployment was manually triggered as part of this handoff.

## Phase 55 — clinical parent-link and helper ACL reconciliation

### Implemented and merged

- Forward-only migration: `db/roshan_phase55_clinical_parent_guard_acl_reconciliation.sql`.
- Migration version: `20261103155227`.
- Corrected the Phase 36 clinical parent guard so `lab_order_items.order_id` is immutable while preserving cancelled-visit protection.
- Tightened direct EXECUTE permissions for the three private routines in QA.
- Corrected the synthetic PostgreSQL 17 fixture to match the actual live schema in both environments: `lab_order_items` has no `visit_id` column and `order_id` is required.
- The fixture now checks the expected shape rather than silently testing a synthetic-only column.

### Verification

- QA migration ledger contains Phase 55 version `20261103155227`; QA ledger count at the check: 21.
- Production ledger does not contain Phase 55; Production ledger count at the check: 129.
- Read-only QA post-apply checks confirmed:
  - SECURITY DEFINER and empty `search_path` for the protected routines.
  - `order_id` immutability and retained cancelled-visit guard behavior.
  - Direct EXECUTE denied to PUBLIC, anon, authenticated, service_role and authenticator for all three private routines.
- Exact-head PostgreSQL 17 Phase 55 replay passed: run [41675151991](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41675151991).
- Exact-head standard CI passed: run [41675151995](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41675151995), 18 successful jobs, zero failures, one intentional skip.
- Post-merge main CI passed: run [41675514753](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41675514753), 18 successful jobs, zero failures, one intentional skip.
- Post-merge CodeQL passed for JavaScript/TypeScript and Python: run [41675514590](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41675514590).
- The intentional skip is **Canonical PG17 baseline replay and authenticated clinical acceptance**. It is not evidence that authenticated clinical acceptance passed.
- Latest main CI after the subsequent Phase 53/spec reconciliation also passed: [41711731645](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41711731645). Related main workflow runs [41711731582](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41711731582), [41711730876](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41711730876) and [41711731633](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41711731633) passed.

## Environment state and remaining security drift

### QA

- QA project: `hopfohcnrtbiqjkgeukz`.
- Phases 54, 54B, 54C and 55 are recorded as applied in QA.
- Phase 55 read-only verification was successful as described above.

### Production

- Production project: `jewzonxplxhogqrnhosl`.
- No Phase 54, 54B, 54C or 55 migration was applied during this work.
- Production still has the older Phase 36 guard without the tracked `lab_order_items.order_id` immutability check.
- A post-merge read-only ACL check found that Production still has default PUBLIC EXECUTE on:
  - `private.app_has_claim_branch(uuid)`
  - `private.sync_user_role_text()`
- Authenticated has USAGE on schema `private`, so these PUBLIC grants are effective. Do not describe Production ACLs as reconciled.
- Do not apply Phase 54/54B/54C/55 to Production until the encrypted backup and isolated restore gate is completed and the production change is separately reviewed.

## Backup and restore gate

- A private backup runner repository exists: [roshan-health-hub-backup-runner](https://github.com/crauch2088-source/roshan-health-hub-backup-runner).
- Its workflow is manual-only, requires explicit confirmation, and is designed to create an encrypted PostgreSQL 17 backup, perform an isolated local restore/count check, and upload only encrypted artifacts.
- Validation-only runs passed: `41631926251` and `41632621501`. The actual Production backup job was intentionally skipped because confirmation was false.
- The private Google Drive folder **Roshan Health Hub Backups** exists and is not shared.
- **No Production backup artifact exists yet. No restore rehearsal has passed.**
- No secrets were configured in the runner, no Production connection was attempted, no database password/PAT/private age identity was retrieved or exposed, and no plaintext dump was created.
- Required owner setup and exact instructions are in:
  - `docs/BACKUP_RESTORE_STATUS_2026-11-03.md`
  - `docs/BACKUP_RUNNER_SETUP_2026-11-03.md`
  - private runner repository README
- Required setup includes enabling temporary token-based database access, enforcing SSL, configuring a short-lived PAT as a private Actions secret, and configuring only the public age recipient as an Actions variable. Keep the private age identity offline/in a password manager; never send secrets through ChatGPT.
- The backup workflow aborts if Storage object rows or Vault secret rows are found, because their bytes/root key require separate recovery handling. Re-check these preconditions before running it.

## Other release gates still open

1. Full migration-chain provenance/reconciliation remains incomplete. The redacted production migration `20261102232941` is not a replayable source and must never be rerun.
2. Encrypted Production backup, checksum verification and isolated restore rehearsal remain incomplete.
3. Canonical PG17 baseline replay and authenticated clinical E2E/acceptance remain unverified; the corresponding standard CI job was intentionally skipped.
4. Practical staff UAT on the clinic's phones and clinical/operational sign-off remain open.
5. Do not infer production readiness from CI success, a merged PR, or a Vercel READY state alone.
6. Inventory aggregate RPC work was not started in this session; keep it behind the backup/restore and migration-provenance gates unless the owner explicitly reprioritizes it.

## Safe resume sequence

1. Start from the live main HEAD, not an old branch snapshot. Re-check current PRs, Actions and Supabase migration ledgers before doing work.
2. Complete the owner-only setup in the private backup runner repository without sharing secrets in chat.
3. Run the manual encrypted backup with explicit confirmation; verify the encrypted Drive artifact and checksum, then complete and record the isolated restore rehearsal.
4. Reconcile the migration source/history and the known Production ACL/Phase 36 drift. Review exact SQL and dependencies before any Production change; obtain a fresh, explicit production-change authorization at that time.
5. Apply any approved Production migrations in a controlled order only after the backup gate is demonstrably closed; re-run read-only schema/function/ACL fingerprints afterward.
6. Complete canonical PG17 baseline replay, authenticated clinical E2E, then staff UAT and clinical/operational acceptance.
7. Only then resume deferred inventory performance work and final launch-readiness assessment.

## Change safety record

During the Phase 55 work and this handoff, no Production DDL/DML, patient-row changes, password rotations, or manual deployments were performed. QA Phase 55 application was the only database migration applied for this phase. This handoff does not authorize future Production writes.
