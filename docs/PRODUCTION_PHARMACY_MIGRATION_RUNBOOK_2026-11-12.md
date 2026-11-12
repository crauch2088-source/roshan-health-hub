# Production pharmacy safety migration runbook — 2026-11-12

**Status: PREPARED / NOT EXECUTED. Production remains blocked.**

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

- [ ] Fresh encrypted Production database backup created from the current backup-runner head, not merely reuse the 2026-11-09 archive.
- [ ] Backup manifest, ciphertext integrity, expected checksum, retention, and successful owner-side decryption verified.
- [ ] Restore completed in an isolated PostgreSQL 17 environment; verify core table counts and the pharmacy/finance schema needed by this function.
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
- The current backup/restore gate is not yet verified with a fresh archive and current checksum helper.
- No Production or QA schema/data changes were performed during preparation of this runbook.

**Decision: NO-GO until every mandatory gate is evidenced and separately approved.**

## Backup runner attempt result — 2026-11-12

- Run [#21](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43164547237) completed with validation success and backup failure because both database credential secrets were absent. It created no archive and made no Production connection.
- Fail-fast guard PR [#5](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/pull/5) was squash-merged as `e7c8c6718d5d7acc7f46a17a2c99c0b222caafcf`. Branch-only run [#22](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43164851066) tested the identical workflow blob: the preflight stopped before CLI setup/Production connection and skipped the backup job; no secret values were printed.
- Therefore the fresh encrypted backup and isolated restore gates remain **open**. The owner must add exactly one repository Actions secret, `SUPABASE_DB_PASSWORD` or `SUPABASE_DB_ACCESS_TOKEN`, without disclosing it in chat, then rerun the manual workflow.
