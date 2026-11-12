# Production pharmacy safety migration runbook — 2026-11-12

**Status: BACKUP + LOCAL PG17 RESTORE REHEARSAL PASSED / OWNER-SIDE DECRYPTION AND INDEPENDENT REVIEW OPEN / PRODUCTION NO-GO.**

## Objective and scope

Remove the unsafe NULL-to-one dispensing fallback in Production and align the dispensing boundary with the already QA-verified guards. The package contains exactly two forward migrations, in this order:

1. Phase 57 — require explicit positive whole-unit quantities.
2. Phase 57B — reject free-text and externally sourced prescriptions from internal-stock dispensing.

Do not include Phase 61 in this hotfix. Its correction-request UI, role-scoped workflow, and staff acceptance are a separate coordinated release.

## Source and QA provenance

| Order | Version | Name | Source | QA stored statement |
|---|---|---|---|---|
| 1 | `20261104065852` | `roshan_phase57_pharmacy_quantity_required_guard` | `db/roshan_phase57_pharmacy_quantity_required_guard.sql` — Git blob `9db6768999352c32081f69b5e665c3cc95452616` | 10,954 bytes; MD5 `921970d4d86b32dccd430a0ea0ef8745` |
| 2 | `20261111215510` | `roshan_phase57b_free_text_external_prescription_guard` | `db/roshan_phase57b_free_text_external_prescription_guard.sql` — Git blob `57516e08de8e314f687c21f2f292199d3adff178` | 11,525 bytes; MD5 `bfd2df24224752a1488f2f05494f4211` |

The values above are read from the QA migration ledger on 2026-11-12. A Git blob SHA is not an MD5 of the stored migration statement. Do not infer equivalence from similar file names or byte counts. Preserve the exact source payloads and compare the deployment payload against the QA provenance before any execution.

## Mandatory gates — all must pass

- [x] Fresh encrypted Production database backup created from the current backup-runner head; see `docs/BACKUP_EVIDENCE_2026-11-12.md`.
- [ ] Backup manifest, ciphertext integrity, expected checksum, retention, and successful owner-side decryption verified.
- [x] Backup runner completed its isolated PostgreSQL 17 local restore rehearsal and critical table-count comparisons. Owner-side ciphertext decryption remains a separate open gate.
- [ ] Explicitly document recovery coverage for Supabase Storage objects and Vault/configuration secrets. The database archive alone does not cover these. Either verify separate recoverable exports or record an explicit owner-approved residual risk.
- [ ] Confirm Production ledger still has neither version `20261104065852` nor `20261111215510`; stop if either exists under a different name or if the live state changed.
- [ ] Re-read the Production function signature, owner, SECURITY DEFINER flag, fixed empty search_path, and exact EXECUTE grants for authenticated/anon/service_role. Capture the pre-change definition and ACL in the change record.
- [ ] Independent reviewer signs off the two migration payloads and the expected semantic delta from Production's current function.
- [ ] Explicit release approval is recorded for the Production window and operator.

A failed or incomplete gate means **STOP**. Do not use `db push` to replay the historical ledger, do not edit migration history, and do not combine this work with unrelated finance or Phase 61 migrations.

## Expected behavior after both migrations

- A catalogue-linked active prescription item with NULL quantity is rejected before invoice construction or stock mutation.
- Non-finite, zero, negative, fractional, and over-limit quantities remain rejected.
- A prescription containing any active free-text item (`medicine_id IS NULL`) is rejected as a whole; no partial dispensing, invoice line, stock movement, item dispense flag, or parent status change is allowed.
- An external prescription is rejected from internal dispensing before invoice/stock mutation.
- Existing branch isolation, active-catalogue validation, FEFO batch selection, expiry checks, aggregate stock checks, invoice atomicity, idempotency wrapper behavior, and function ACL boundaries must remain intact.
- No quantity is inferred or backfilled. Existing invalid prescriptions remain pending for clinician correction.

## Execution sequence (only after gates and approval)

1. Apply Phase 57 using the exact reviewed payload and migration version `20261104065852`.
2. Read back the ledger row and effective function definition. Verify explicit NULL rejection and absence of `COALESCE(pi.quantity,1)`.
3. Apply Phase 57B using the exact reviewed payload and migration version `20261111215510`.
4. Read back the ledger row and effective function definition. Verify free-text and external guards are present, and the Phase 57 quantity/whole-unit checks remain present.
5. Recheck SECURITY DEFINER, empty search_path, owner, and grants; compare ACLs to the captured pre-change contract.
6. Run the isolated PostgreSQL 17 pharmacy dispense/invoice integration suite, including no-side-effect assertions for NULL quantity, mixed catalogue/free-text, external prescriptions, cross-branch attempts, insufficient/expired stock, and invoice rollback.
7. Run read-only Production postchecks: migration rows, function definition markers, table/column/index/policy/trigger counts, and a before/after catalog fingerprint.
8. Only then consider enabling any application path that depends on the deployed behavior. Do not activate unrelated Phase 58/59 receipt UI or Phase 61 correction UI as part of this migration.

## Failure and rollback policy

Each migration is transactional. If a migration fails before commit, stop and confirm that its ledger row and function definition did not change before retrying. After a successful commit, do **not** restore the older unsafe function as a rollback. Correct forward with a reviewed migration. If postchecks fail, suspend pharmacy dispensing through the approved operational control and escalate; never bypass the guard or mutate stock/invoice rows manually.

## Current no-go facts (2026-11-12)

- QA ledger: 24 rows; Phase 57, 57B, and 61 are present.
- Production ledger: 129 rows; none of those three versions is present.
- Production `fn_dispense_prescription_with_invoice(uuid,boolean)` still contains `COALESCE(pi.quantity,1)`.
- Fresh encrypted backup, local PostgreSQL 17 restore rehearsal, artifact SHA-256, ciphertext SHA-256 manifest, Drive size/MD5 read-back all passed. Owner-side decryption remains unverified; the full disaster-recovery gate is therefore still open.
- No Production or QA schema/data changes were performed during preparation of this runbook.

**Decision: NO-GO until owner-side decryption, independent migration review, explicit release-window approval and provenance-preserving application mechanics are evidenced.**

## Backup runner attempt result — 2026-11-12

- Run [#21](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43164547237) completed with validation success and backup failure because both database credential secrets were absent. It created no archive and made no Production connection.
- Fail-fast guard PR [#5](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/pull/5) was squash-merged as `e7c8c6718d5d7acc7f46a17a2c99c0b222caafcf`. Branch-only run [#22](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43164851066) tested the identical workflow blob: the preflight stopped before CLI setup/Production connection and skipped the backup job; no secret values were printed.
- Therefore the fresh encrypted backup and isolated restore gates remain **open**. The owner must add exactly one repository Actions secret, `SUPABASE_DB_PASSWORD` or `SUPABASE_DB_ACCESS_TOKEN`, without disclosing it in chat, then rerun the manual workflow.


## Fresh backup and disposable PG17 execution evidence — 2026-11-12

This section supersedes the earlier note that the owner still needed to add a database credential. The manual backup was completed after the hardened PR #8 merged. See the complete evidence table, checksums, Drive IDs, scope limitations and residual gates in [`docs/BACKUP_EVIDENCE_2026-11-12.md`](BACKUP_EVIDENCE_2026-11-12.md).

- Successful backup workflow: [#43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731), runner head `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`. The credential preflight ran; both jobs and all backup steps passed.
- Encrypted artifact ID `13927247998`, size 305,284 bytes; GitHub SHA-256 and independently downloaded SHA-256 match. The encrypted archive's internal SHA-256 manifest also matches.
- Canonical Drive copy: [dated folder](https://drive.google.com/drive/folders/1fUr9TW1zCcedDZqskWW3eWXNF2m6EVmK), [encrypted ZIP](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view). Drive metadata read-back confirms size, exact parent ID and MD5.
- `SUPABASE_DB_PASSWORD` was removed from repository Actions secrets after this one-time backup and verified absent. Future manual backup requires a fresh approved DB credential to be configured.
- Storage: 3 buckets / 0 objects; Vault: 0 secrets at the checkpoint. Database backup does not cover object bytes or Supabase control-plane settings.
- Owner-side decryption has not been tested. Do not equate pre-encryption local restore with ciphertext decryption.

### Source and PG17 tests

- Phase 57 exact source payload matches QA stored statement: 10,954 bytes, MD5 `921970d4d86b32dccd430a0ea0ef8745`.
- Phase 57B function DDL payload matches QA stored statement: 11,525 bytes, MD5 `bfd2df24224752a1488f2f05494f4211`.
- Phase 55 source (without its final newline) matches QA stored statement: 2,304 bytes, MD5 `b1271f444b6b8254b9b50ca49c7b02d3`.
- Main CI [#43183563642](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43183563642) passed the PostgreSQL 17 pharmacy integration job that replays Phase 57 then Phase 57B and asserts no-side-effect behavior for invalid prescriptions.
- Dedicated Phase 55 CI [#43184305893](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43184305893) passed the private-helper ACL and clinical parent-trigger assertions.

### Remaining no-go conditions

- Production function still contains `COALESCE(pi.quantity,1)`; no Production migration has been applied.
- Production `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` still have PUBLIC-effective EXECUTE. Phase 55 is QA-verified, not Production-applied.
- Owner-side decryption, independent second-person review, explicit release-window approval, and a forward-only migration mechanism that preserves provenance remain mandatory.
- No Production or QA DDL/DML/ACL/RLS/Auth/Storage changes were made in this execution round.
