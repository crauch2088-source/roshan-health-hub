# Roshan Health Hub — Production Backup, Independent Restore & DR Drill Session Record

**Record date:** 2026-11-23 (UTC+02:00 session; Cloud Shell work performed during 2026-11-22/23)  
**Purpose:** Preserve the evidence, commands/outcomes, scope limitations, and remaining actions from the Production Backup Recovery & Disaster Recovery session.  
**Application repository:** `crauch2088-source/roshan-health-hub`  
**Backup runner repository:** `crauch2088-source/roshan-health-hub-backup-runner`  
**Production Supabase ref:** `jewzonxplxhogqrnhosl`  
**QA Supabase ref:** `hopfohcnrtbiqjkgeukz`  
**PR under review:** [#296](https://github.com/crauch2088-source/roshan-health-hub/pull/296)  
**PR head last verified during this record:** `e8e1c961a70af606fc0eff732326e957085e13cd`  
**PR state last verified:** open, draft, not merged; base `main` at `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.

> **Decision: DR GATE NOT CLOSED.** A real independent local PostgreSQL 17 restore from the owner-decrypted retained backup has now succeeded. This closes the database-restore proof gap for this specific backup. It does not prove complete project disaster recovery, Storage object-byte recovery, control-plane reconstruction, ongoing automation, retention adequacy, or measured RPO/RTO.

## 1. Safety boundaries and execution scope

- Production and QA databases were not modified during this drill.
- PR #296 was not merged, closed, or retargeted.
- No application deployment or Production/QA migration was performed.
- The retained encrypted backup was processed by the owner in their own Google Cloud Shell after explicit consent. Ephemeral Mode was enabled.
- The age private identity was entered locally through a hidden prompt; it was not pasted into ChatGPT, GitHub, or the report.
- The encrypted artifact was decrypted and inspected locally. Neither the plaintext dump nor patient-level records were sent to an external service.
- The PostgreSQL restore container was started with `--network none`; the restore was local to the Cloud Shell environment.
- No paid infrastructure, VM, Cloud SQL instance, or new Storage bucket was created.
- This record intentionally excludes credentials, private encryption identities, database connection strings, and patient-level values.

## 2. Backup artifact provenance and integrity

The retained artifact corresponds to the successful manual backup workflow:

- Workflow: [successful run #43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731)
- Artifact ZIP: `roshan-production-backup-43183851731.zip`
- Backup timestamp in manifest: `20261112T083337Z`
- Encrypted archive member: `roshan-production-20261112T083337Z.tar.gz.age`
- Artifact size: `305284` bytes
- ZIP MD5: `22271054f6c10b1baf1d23ac4bdac24e`
- Outer ZIP SHA-256: `54b799545d1cb6eaccd16cf3964a3b6a5421c292c457504b967f5bcf5b488dd9`
- Inner encrypted archive SHA-256: `5c9f5e4ab9628cd9e7bdb11aea0edce96fac11d2c2b2176661add49aa79a3ddd`
- The downloaded artifact's size and hashes were checked against the previously recorded values. ZIP integrity passed.
- The age-encrypted member was decrypted locally using the owner's offline identity.
- The decrypted bundle was extracted under a private temporary directory in Cloud Shell. It contained: `full.dump`, `roles.filtered.sql`, `archive-contents.txt`, `source-counts.json`, `restore-counts.json`, `manifest.json`, and `restore-notes.txt`.

The previous evidence record, `docs/BACKUP_EVIDENCE_2026-11-12.md`, documents the successful runner workflow, private Drive copy and its read-back, artifact metadata, and earlier scope limitations. This session adds owner-side decryption and an independent restore from the retained encrypted artifact.

## 3. Manifest and backup scope findings

The decrypted manifest reported:

- Production project ref: `jewzonxplxhogqrnhosl`
- PostgreSQL source version: `17.6`
- Supabase CLI: `2.122.0`
- All database schemas included; Auth schema included; Storage metadata included.
- Custom-format PostgreSQL dump.
- Runner-recorded restore rehearsal: passed.
- `storage_object_bytes_included=false`
- `storage_objects_at_snapshot=0`
- `vault_secret_count=0`

Manifest source counts and recorded restore counts matched:

| Object | Count |
|---|---:|
| Auth users | 6 |
| Patients | 3 |
| Visits | 9 |
| Invoices | 0 |
| Payments | 0 |
| Cashbox transactions | 0 |
| Storage buckets | 3 |
| Storage objects | 0 |

These are counts only; no patient records or patient identifiers are reproduced here.

### Explicit exclusions

The backup is a database logical backup, not a complete Supabase project image. It does not contain:

- Storage object bytes (file contents).
- Supabase project/control-plane settings.
- API/JWT keys.
- Edge Function secrets.
- Custom-domain configuration.
- Provider/integration configuration outside the database.
- The Vault encryption root key or an offline age private identity.

The Vault secret count was zero at the snapshot. That means no Vault secret rows needed recovery from this particular snapshot; it does not make Vault's encryption root key or project-level settings recoverable from the database dump.

## 4. Independent PostgreSQL 17 restore — PASS

### Environment and image

- Environment: owner's Google Cloud Shell, Ubuntu 24.04.5, x86_64.
- Docker engine: 29.9.x.
- The restore used the exact pinned image digest:
  `supabase/postgres@sha256:3e2a7ab48783077d0122dc72ed5174afb543110c38266c845716c51d130658e4`
- The pinned image reported `pg_restore (PostgreSQL) 17.6`.
- A mutable image tag was deliberately not substituted because it resolved to a different digest.
- The PostgreSQL container was run with `--network none`.
- `pg_isready` returned accepting connections.
- `supabase_admin` was verified as a superuser in the disposable local container.
- The five dump-required extension control files were present; installed extensions included `pg_stat_statements`, `pg_trgm`, `pgcrypto`, `supabase_vault`, and `uuid-ossp` (plus built-in `plpgsql`).

### Restore mechanics

- `pg_restore --list` succeeded and listed 1,772 TOC entries.
- A fresh target database, `roshan_restore_verify`, was created in the isolated local PostgreSQL container.
- The archive was restored using `pg_restore --exit-on-error --single-transaction`.
- The restore command returned exit code `0`.
- A required Supabase Realtime role absent from the container's initial role set was created locally with restrictive, non-login, non-superuser attributes before restore. This was a local disposable-environment prerequisite only; no Production or QA role was changed.
- The archive's `roles.filtered.sql` contained only SET/RESET statements; it did not create application roles.

**Result: the decrypted retained backup was independently restored into a fresh local PostgreSQL 17 database successfully.** This is stronger evidence than the runner's pre-encryption restore rehearsal and the Android manifest verifier: it tests the actual retained ciphertext, owner-side decryption, and an independent PostgreSQL restore.

### Restored row-count comparison

Counts queried from the independently restored database matched the manifest/recorded restore counts:

| Object | Independent restore | Manifest source/restore |
|---|---:|---:|
| Auth users | 6 | 6 / 6 |
| Patients | 3 | 3 / 3 |
| Visits | 9 | 9 / 9 |
| Invoices | 0 | 0 / 0 |
| Payments | 0 | 0 / 0 |
| Cashbox transactions | 0 | 0 / 0 |
| Storage buckets | 3 | 3 / 3 |
| Storage objects | 0 | 0 / 0 |

### Structural and integrity observations

The independently restored database reported:

| Measure | Count/result |
|---|---:|
| Schemas | 12 |
| Indexes | 395 |
| Constraints | 359 |
| Triggers | 78 |
| RLS policies | 226 |
| Functions | 247 |
| Extensions | 6 |
| Invalid indexes | 0 |
| Unvalidated constraints | 1 |
| Tables with RLS enabled | 82 |
| Tables with FORCE RLS | 44 |

The single unvalidated constraint was the Supabase Realtime internal check `realtime.messages.messages_payload_exclusive`, defined as `CHECK ((payload IS NULL) OR (binary_payload IS NULL)) NOT VALID`. A read-only check found zero rows violating it. It was not altered or validated.

The structural counts above describe the restored database. No corresponding source-side structural baseline was captured in this session, so they must not be represented as a proven Production-to-restore structural equality comparison.

## 5. Storage metadata and policy inspection

The restored database contained these three bucket definitions:

| Bucket | Public | Max size | Allowed MIME types | Objects in snapshot |
|---|---|---:|---|---:|
| `roshan-clinical-attachments` | false | 20 MiB | PDF, PNG, JPEG | 0 |
| `roshan-lab-reports` | false | 10 MiB | PDF, PNG, JPEG | 0 |
| `roshan-medical-certificates` | false | 10 MiB | PDF, PNG, JPEG | 0 |

The database contained 16 Storage RLS policies:

- 12 permissive policies: INSERT, SELECT, UPDATE, DELETE for each of the three buckets.
- 4 restrictive boundary policies: one per operation (INSERT, SELECT, UPDATE, DELETE).
- The bucket-specific policies reference permission and branch-path checks, including `app_has_perm` and `private.phase33_branch_access_from_path(name)`.
- The restrictive boundary policies reference `private.phase33_storage_access(bucket_id, name, action)`.

**Important distinction:** this proves that bucket metadata and policy definitions were present in the restored database. It does not prove that authenticated Storage API requests succeed or are correctly denied in every branch/role scenario. No live Storage upload/download/delete test was run, and the snapshot had zero objects, so no file-byte restoration could be tested.

### Fail-closed clinical attachments behavior

The returned definition of `private.phase48_storage_entity_branch_matches` included an explicit case for `roshan-clinical-attachments` that returns `false`, with comments stating that no approved uploader/entity contract exists yet and every operation must remain fail-closed until a real call site is reviewed.

This is a deliberate security boundary, not evidence of a successful clinical-attachment workflow. It means this bucket is not operationally ready for file access until the upload/entity contract and call site are reviewed and tested.

### Function privilege/configuration observations

The diagnostic output showed:

- `public.app_has_perm(_code text)` is owned by `postgres`, is not SECURITY DEFINER, and has an empty `search_path`.
- `anon` does not have EXECUTE on `public.app_has_perm`; `authenticated` and `service_role` do.
- The private Storage helper functions reviewed were owned by `postgres` and used an empty `search_path`.
- Previously observed helper attributes: `phase33_branch_access_from_path` and `phase33_storage_access` are SECURITY DEFINER; `phase34_storage_path_valid` is not; `phase48_storage_entity_branch_matches` is SECURITY DEFINER.
- The pasted diagnostic output began part-way through the expanded function definitions. Therefore, this record does not claim that every line of every helper definition or every role grant was independently reviewed from the complete output.

## 6. Vault, pg_cron, and automation findings

- `vault.secrets` exists in the restored database and returned a count of zero.
- The `supabase_vault` extension was installed (version `0.3.1`).
- `pg_cron` was not installed in the restored database.
- No `cron` schema was present.
- A prior diagnostic attempted to query `cron.job`; that query failed because the relation does not exist. This is not a restore failure. It establishes only that this restored database has no `cron.job` table/schema.
- The backup runner README confirms the external GitHub Actions workflow is manual-only, with no scheduled trigger. It requires explicit dispatch confirmation.
- The successful backup workflow was run on 2026-11-12. A later workflow run, #43764265014, failed at credential preflight because the required Production backup credential was absent; it failed before `pg_dump`/dump creation/encryption.
- The runner README states that the GitHub Actions artifact is ciphertext-only and has one-day retention; the encrypted Drive copy is the retained copy.
- The backup runner instructions require `SUPABASE_ACCESS_TOKEN` plus exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`. The preferred temporary-token route requires the relevant Supabase feature preview and a temporary access rule; the fallback uses the existing Production DB password and should be removed after a one-time run.
- The prior 2026-11-12 evidence record states that the one-time `SUPABASE_DB_PASSWORD` secret was deleted after the successful backup. The subsequent preflight failure is consistent with the absence of a currently configured DB credential, but no secret values were inspected in this session.

No conclusion is made that external GitHub Actions automation is absent merely because `pg_cron` is absent. The confirmed state is: external backup automation exists but is manual-only; no database-level cron schedule was present in the restored snapshot.

## 7. PR #296 status — independently rechecked

At the time of this record, GitHub returned:

- State: open.
- Draft: true.
- Merged: false.
- Base: `main`, base SHA `3bc317b0d6cc3eaa1b7623ce3c78477f848c8b1a`.
- Head branch: `fix/qa-operational-blockers-20261121`.
- Head SHA: `e8e1c961a70af606fc0eff732326e957085e13cd`.
- 12 commits; 29 changed files.
- PR title: `fix(qa): resolve P0 branch RLS visit blocker, P1 expenses/duplicate guards, and P2 pharmacy/i18n leaks`.

The PR description says the changes address QA operational blockers and that Production was untouched. This DR drill did not change the PR or its merge state. Do not merge PR #296 as a side effect of DR documentation.

## 8. RPO, RTO, retention and completeness assessment

| DR dimension | Evidence/state | Status |
|---|---|---|
| Encrypted artifact integrity | ZIP and inner ciphertext checksums verified | PASS |
| Owner-side decryption | Decrypted locally using offline identity | PASS |
| Independent PostgreSQL 17 restore | Fresh local DB restore exited 0 | PASS |
| Critical row counts | Independent restore matches manifest counts | PASS |
| Storage bucket metadata | Three definitions restored | PASS |
| Storage policy definitions | 16 policies restored and inspected | PASS, definition-level only |
| Storage object bytes | Not included; zero objects at snapshot | NOT TESTED / OUT OF SCOPE OF THIS DUMP |
| Storage API behavior | No authenticated API workflow tested | OPEN |
| Vault secrets | Zero rows at snapshot | No secret rows to restore; key/control-plane recovery still open |
| Supabase control plane | Not included in dump | OPEN |
| Backup schedule | Runner is manual-only | OPEN |
| Backup credential availability | Later preflight failed due missing Production credential | OPEN |
| Artifact retention | GitHub staging artifact one day; Drive copy retained | POLICY/RECOVERY TEST OPEN |
| RPO | No scheduled successful backups and no accepted target established | NOT ESTABLISHED |
| RTO | Restore succeeded but elapsed restore duration was not measured against an agreed target | NOT ESTABLISHED |
| Repeatable drill | One independent restore demonstrated | PARTIAL; repeatability not yet demonstrated |
| Runbook/ownership | Runner README and earlier evidence exist; full recovery inventory/ownership needs completion | PARTIAL |

The last known successful Production backup is dated 2026-11-12. The failed later workflow did not produce a newer backup. At the time of the 2026-11-22/23 drill, the successful backup was approximately 10–11 days old. This is an observed backup-age gap, not a measured RPO.

No RTO value should be inferred from the successful restore. The duration was not captured, and no formal recovery target was agreed or tested.

## 9. Remaining work to close the DR gate

The following work remains, in priority order:

1. **Restore backup automation availability**
   - Re-enable the runner's credential preflight safely.
   - Choose the supported credential route.
   - Add required secret values only in the private runner repository's GitHub Actions Secrets settings; never send values to ChatGPT or commit them.
   - Prefer temporary database access where supported; otherwise use the documented fallback with a controlled short window and remove the DB password secret after the run.
   - Run a new manual Production backup only after the owner explicitly confirms the dispatch and the workflow's read-only scope is verified.
2. **Define backup cadence and targets**
   - Owner must approve a realistic cadence and retention policy.
   - Suggested starting policy for evaluation (not yet approved or implemented): daily backups retained 30 days plus monthly copies retained 12 months, provided this can be done securely without unacceptable cost.
   - Define and approve RPO and RTO targets before claiming them.
3. **Prove retention and off-site recovery**
   - Verify the canonical private Drive copy, permissions, dated folder, file metadata, and a second retrieval.
   - Decide whether the current one-day GitHub artifact staging window is sufficient.
   - Test recovery from the retained off-site copy, not only a transient Actions artifact.
4. **Storage file recovery**
   - Decide whether attachments/reports/certificates will remain unused until an approved file backup mechanism exists.
   - If Storage objects become non-empty, the current DB-only backup runner correctly aborts; add a separately reviewed object-byte export/restore process before accepting such data.
   - Review and approve the clinical-attachment uploader/entity contract before changing the fail-closed behavior.
5. **Vault and control-plane recovery**
   - Inventory any Vault secrets, encryption-root-key custody, Edge Function secrets, API/JWT keys, auth/provider settings, domains, and other project settings.
   - Document secure re-provisioning/rotation steps. Do not place secret values in the repository.
6. **Measure RTO**
   - Time a future full restore from retrieval of the off-site artifact through a verified usable restored database.
   - Record exact start/end times, environment, version, steps, errors, and acceptance checks.
7. **Repeat the drill**
   - Repeat the owner-side decryption and independent restore using a newly generated backup after credential/automation recovery.
   - Have a second reviewer independently inspect the evidence and approve the final DR acceptance.
8. **Update canonical project documents**
   - Link this session record from the Master Plan and the canonical DR runbook/evidence index after repository-path and branch review.
   - Keep the overall gate open until every required dimension has explicit acceptance evidence.

## 10. Final session outcome

**Passed:** artifact integrity; owner-side decryption; independent PostgreSQL 17 restoration from the retained encrypted artifact; manifest row-count reconciliation; Storage metadata/policy definition restoration and inspection.

**Not passed / not established:** complete Supabase project recovery; Storage object-byte recovery; Storage API operational tests; clinical-attachment upload contract; Vault/control-plane reconstruction; automatic backup cadence; current credential readiness; approved retention policy; RPO; measured RTO; repeated independent drill.

**Operational decision: PARTIAL PASS — DATABASE RESTORE VERIFIED; FULL DR GATE REMAINS OPEN.**

Production and QA were not changed. PR #296 remains open/draft and unmerged. No Production deployment or database migration was performed.


## 11. Backup Runner source and Actions review — 2026-11-23 continuation

The private runner's current `main` source was inspected read-only. The workflow files and key scripts were fetched directly from GitHub:

- `.github/workflows/manual-encrypted-production-backup.yml` blob `015b49666dde54fd77756dae05c646104c325ad0`.
- `.github/workflows/ci.yml` blob `543cc99ebfed0b990b2ce42a3e10a706e13b5277`.
- `scripts/backup-and-restore.sh` blob `9db082ac305819b7c5d096a6a3f9d56776454e2c`.
- `scripts/validate_backup_credentials.sh` blob `09c2aaf2fc96fd2d2d378f4a126ab5ff984612ba`.
- `tests/test_validate_backup_credentials.sh` blob `f2619149197de9b669c78bed2122ffbeb01857ba`.
- Runner README blob `aa88b27f06014928d1f81fd721673e61c26d1e1b`.

### Workflow design findings

1. The Production backup workflow is triggered only by `workflow_dispatch`. It has no `schedule`, `push`, or `pull_request` trigger. The workflow requires an explicit boolean `confirm_production_backup=true` before the Production backup job runs.
2. Workflow permissions are restricted to `contents: read`; concurrency prevents overlapping Production backup runs.
3. The workflow validates credentials before the backup job. It requires `SUPABASE_ACCESS_TOKEN`, exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`, and `AGE_RECIPIENT`.
4. The backup job uploads only the encrypted artifact and configures `retention-days: 1`. There is no Google Drive upload step in the workflow. The README explicitly assigns transfer to the canonical private Drive folder as a manual owner step.
5. The README states that the encrypted artifact is temporary staging, the Drive copy is the retained copy, and the workflow must abort if Storage objects or Vault secrets are non-empty.
6. CI validates shell syntax, ShellCheck, credential validator regression tests, Python helper tests, and required Supabase CLI flags. The CI workflow does not need Production credentials and does not itself create a Production backup.
7. The backup shell script checks PostgreSQL version, Storage object count and Vault secret count before dumping. It creates a custom-format dump, runs a local PostgreSQL 17 restore rehearsal, compares critical table counts, packages a manifest, encrypts with age, and generates checksums. Plaintext working directories and local restore project are removed by the EXIT cleanup trap; secure forensic erasure is not claimed.
8. The workflow currently uses the mutable Docker image tag `postgres:17.6` for remote dump/restore client operations. This is a reproducibility hardening candidate: pin the image by a verified digest after compatibility testing. It is not the cause of the observed credential preflight failure.

### Latest failed workflow — exact cause confirmed from job log

- Run: [#43764265014](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014)
- Event: `workflow_dispatch`
- Created: `2026-11-15T21:32:41Z`
- Runner head SHA: `f171732b61fe0460c61a36aa63b861065f9ea9d1`
- `validate` job: failed at step **Preflight Production backup credentials**.
- `backup` job: skipped.
- The safe log output showed the CLI token was present and the age recipient variable was present, while both supported database credential inputs were empty.
- The validator emitted: `Configure exactly one of SUPABASE_DB_ACCESS_TOKEN or SUPABASE_DB_PASSWORD.`
- No database dump, encryption, or artifact upload step ran in this workflow attempt. No evidence indicates a Production connection was opened by this failed attempt.

The run history inspected at the time of this source review showed #43764265014 as the latest listed manual backup run, after successful run #43183851731 on 2026-11-12. This was the state before the subsequent owner-authorized run documented in Section 12 below.

### Decision: do not add a schedule yet

A scheduled workflow is intentionally **not** added in this round. With only one-day GitHub artifact retention and no automated durable off-site transfer step, a scheduled run could succeed while its only artifact expires before an owner transfers it. This would not satisfy the backup-retention objective and could create false confidence.

Before enabling a schedule, the owner must approve and implement a reliable, least-privilege off-site delivery path (or a clearly owned, monitored manual transfer process with a frequency that meets the approved RPO), prove retention, and test retrieval. No Drive credential, OAuth scope, service account, or upload integration is currently assumed to exist.

### Owner action required — credential recovery

The next backup at the time of this source review could not run until one of the documented database credential paths was configured privately in the backup runner repository. The owner subsequently configured the existing Production DB password privately and authorized a new run; see Section 12. The credential value was never shared in this conversation. The documented options were:

- Preferred when the Supabase organization exposes the feature: a short-lived temporary database access token in secret `SUPABASE_DB_ACCESS_TOKEN`, with the required temporary access rule and SSL enforcement; revoke it and remove the temporary rule after the backup.
- Fallback where the feature is unavailable: the existing Production DB password in secret `SUPABASE_DB_PASSWORD`; do not reset it solely for this workflow; remove the secret after the one-time backup.
- `SUPABASE_ACCESS_TOKEN` and `AGE_RECIPIENT` were present in the failed run and must not be replaced or disclosed unless a fresh private settings check shows they are missing/invalid.

The owner added the credential directly in GitHub Settings → Secrets and variables → Actions for the **private backup-runner repository**. No credential value was shared in this conversation. A new Production backup was dispatched only after the owner's explicit approval, as recorded in Section 12.

### Review outcome

**PASS WITH FINDINGS — source review complete.** At the end of that source-review stage, the operational backup was blocked by the missing database credential. That blocker was subsequently cleared by the owner, and the authorized Production backup completed successfully as documented below. No runner source files were changed.


## 12. Owner-authorized Production backup run #30 — SUCCESS

After the owner privately configured the existing Production DB password secret and explicitly approved execution, the manual encrypted Production backup workflow was dispatched.

- Workflow run: [#45080086071](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/45080086071)
- Runner repository head SHA: `f171732b61fe0460c61a36aa63b861065f9ea9d1`
- Run conclusion: `success`
- Started: `2026-11-22T22:52:04Z`
- Completed: `2026-11-22T22:55:37Z`
- The actual backup-and-restore step ran from `22:52:48Z` to approximately `22:55:33Z`; the database dump, local PostgreSQL 17 restore rehearsal, encryption, and artifact upload all completed in under three minutes once the required image was available.
- Credential preflight and runner validation jobs both passed.
- The backup script queried Production PostgreSQL version, Storage object count, and Vault secret count. It proceeded through dump and restore; therefore the script's explicit abort conditions for non-zero Storage objects or Vault secrets were not triggered.
- The full database dump was restored into a fresh isolated local Supabase/PostgreSQL 17 target using `pg_restore --exit-on-error --single-transaction`.
- The runner compared its critical source counts with restored counts; the script reached its success marker, so the comparison passed.
- The manifest was generated, the bundle was encrypted with age, and checksum files were generated.
- The workflow uploaded ciphertext only; the artifact upload step completed successfully.
- Safe workflow summary recorded: database dump and local restore rehearsal passed; artifact encrypted only; retention one day; Production writes none.
- No Production or QA database writes, migrations, or application deployments were performed by this workflow.
- No runner source files were changed to obtain this success.

### Artifact identity and independent transfer verification

- Artifact name: `roshan-production-backup-45080086071`
- Artifact ID: `14776383466`
- Artifact URL: [download from GitHub Actions](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/45080086071/artifacts/14776383466)
- Artifact ZIP size: `304943` bytes
- GitHub artifact ZIP SHA-256: `ef99f0875ee0aed41e24bc738803839cd9d4c326f5a3b5ac7375b0014379a480`
- Downloaded artifact was independently fetched and verified in the working environment. Its SHA-256 exactly matched GitHub's digest.
- ZIP integrity test passed with no compressed-data errors.
- ZIP contains exactly two entries: `SHA256SUMS` and `roshan-production-20261122T225248Z.tar.gz.age`.
- Encrypted member size: `304433` bytes.
- The checksum manifest's expected encrypted-member SHA-256 and the independently computed SHA-256 both equal `5b80dff16006fd9b384177e00e4c28c980865494b5353fbe7f9b4a003b3b3477`.
- Artifact retention is configured for one day; GitHub reported expiry at `2026-11-23T22:55:33Z`. This artifact is temporary staging and must not be treated as the durable retained backup.

### What this run proves — and what it does not

**Proved by Run #30:** a new Production database backup could be created using the repaired private credential configuration; the runner's isolated PostgreSQL 17 restore rehearsal passed; source/restored critical row counts matched; age encryption and checksum generation passed; GitHub accepted and stored the ciphertext-only artifact; the downloaded ZIP and inner encrypted member checksums were independently verified.

**Not yet proved by this run:** owner-side age decryption and a separate independent PostgreSQL restore of this *new* artifact; durable off-site Drive storage/read-back; long-term retention; automated schedule; approved RPO/RTO; recovery of Supabase control-plane settings or Storage object bytes. The new artifact has not been uploaded to the canonical private Drive folder as part of this session.

### Updated operational outcome

The missing database credential blocker is cleared for this one authorized run. The backup runner remains manual-only, and its GitHub artifact retention remains one day. Do not add a schedule until durable off-site transfer and retention are automated or a monitored owner-operated process has been explicitly accepted against the approved RPO.

**Updated decision: Production backup + runner restore rehearsal PASS; downloaded ciphertext integrity PASS; full DR gate remains OPEN pending durable off-site retention, owner-side decryption and independent restore of this new backup, control-plane recovery inventory, approved RPO/RTO, and repeatable recovery acceptance.**

PR #296 remains open/draft and unmerged. PR #297 remains a documentation-only draft. Production and QA were not modified.


## 13. Composio-mediated private Google Drive transfer and read-back — PASS

The owner explicitly requested use of the connected Composio integration to place the new encrypted artifact in the established private Google Drive backup archive.

### Destination resolution

- Connected Google Drive account was confirmed ACTIVE for the owner's private account.
- Existing canonical archive folder found: `Roshan Health Hub - Encrypted Backups`.
- The archive already contained dated folders, including `2026-11-12`, which held the prior successful artifact `roshan-production-backup-43183851731.zip`. This confirmed the existing folder structure and destination.
- A new dated child folder `2026-11-22` was created under that canonical archive.
- Folder URL: https://drive.google.com/drive/folders/16sQvIVQdU1R-RhbzxrTuPVoyGuVqSX9E

### Uploaded object

- File: `roshan-production-backup-45080086071.zip`
- Google Drive file ID: `1N-YpbrJ8gJs8-Z9oMSEBJgod4UD_IuML`
- Size: `304943` bytes
- MIME type: `application/zip`
- Parent folder: `2026-11-22` under the canonical private encrypted-backups archive.
- Drive metadata reports `shared=false`, `trashed=false`, and the expected parent folder ID.
- Drive metadata MD5: `7745142df88f2aeaa806a89d336a5b54`
- File URL: https://drive.google.com/file/d/1N-YpbrJ8gJs8-Z9oMSEBJgod4UD_IuML/view

### Read-back verification

The uploaded file was downloaded again from Google Drive through the connected Composio integration and independently checked in the remote verification environment:

- Downloaded byte count: `304943` — exact match.
- Downloaded SHA-256: `ef99f0875ee0aed41e24bc738803839cd9d4c326f5a3b5ac7375b0014379a480` — exact match with the original GitHub Actions artifact digest.
- Downloaded MD5: `7745142df88f2aeaa806a89d336a5b54` — exact match with Drive metadata.
- ZIP integrity test: passed (`testzip()` returned no corrupt member).
- ZIP members: `SHA256SUMS` and `roshan-production-20261122T225248Z.tar.gz.age` only.

This proves the encrypted backup has been transferred to the established private Drive archive and can be retrieved byte-for-byte. The Drive file remains private; no sharing permissions were added.

### Updated DR gate status

**PASS:** current-run encrypted artifact creation; runner-local PostgreSQL 17 restore rehearsal; GitHub artifact integrity; private off-site Drive upload; Drive metadata/privacy verification; complete Drive read-back with byte-for-byte SHA-256 and MD5 equality.

**Still OPEN:** owner-side decryption and independent PostgreSQL 17 restore of the new November 22 artifact; documented and approved backup cadence/retention; RPO/RTO targets and measurement; Supabase control-plane and secret re-provisioning inventory; Storage object-byte strategy before any object is stored; repeatable drill and independent reviewer acceptance.

The Drive transfer closes the off-site-copy and retrieval proof gap for this artifact, but it does not by itself close the full Production Backup Recovery & DR gate.


## 14. Owner-side decryption and independent PostgreSQL 17 restore — PASS

The owner completed the recovery drill in an isolated Google Cloud Shell environment. The decrypted archive was handled locally in the ephemeral session; the age identity/private key and decrypted bundle were not uploaded or shared.

### Decryption and archive validation

- Owner-side age decryption completed successfully (DECRYPTION=PASS).
- The decrypted tar archive contained the expected database dump, filtered role SQL, archive listing, source/restored count snapshots, manifest, and restore notes.
- pg_restore --list successfully parsed the custom-format dump; the archive reports PostgreSQL 17.6.
- The independent restore target was the isolated container roshan-dr-pg17, using the pinned PostgreSQL image digest already recorded for this drill. The target database was roshan_dr_20261122_independent.
- The first restore attempt using the non-superuser postgres role rolled back under --single-transaction when it encountered the privilege restriction on the Realtime function's SET log_min_messages setting. The target was verified empty after rollback.
- Restore was rerun as the existing supabase_admin superuser with --exit-on-error --single-transaction --no-owner --no-privileges. It completed successfully. No role grants or server settings were changed.

### Independent restored data verification

| Object | Restored count |
|---|---:|
| auth.users | 6 |
| public.patients | 3 |
| public.visits | 9 |
| public.invoices | 0 |
| public.payments | 0 |
| public.cashbox_transactions | 0 |
| storage.buckets | 3 |
| storage.objects | 0 |

All eight values exactly match the backup manifest's Production source-count snapshot. The independent restore command emitted INDEPENDENT_RESTORE=PASS.

### Structural inspection

The restored database reported 10 non-system schemas: auth, extensions, graphql, graphql_public, private, public, realtime, storage, supabase_migrations, and vault.

The inspection returned 100 non-system tables, 520 indexes, 471 constraints, 78 non-internal triggers, 226 RLS policies, zero invalid indexes, and one unvalidated constraint. The unvalidated constraint is realtime.messages_payload_exclusive on realtime.messages, defined as CHECK ((payload IS NULL) OR (binary_payload IS NULL)) NOT VALID. This is the known Realtime constraint previously observed in the earlier restore baseline; it is recorded, not silently validated or modified.

The raw function count of 3405 came from pg_proc without a namespace filter and therefore includes PostgreSQL/system and extension routines. It is not an application-only function count and must not be compared with earlier application-level counts. The broad index and constraint catalog counts are drill observations, not asserted parity metrics against a separately queried live source.

### Recovery boundary and safety

- This was an independent restore of the new November 22 encrypted artifact, separate from the runner's own restore rehearsal.
- Production and QA were not modified. No migration, deployment, or Production write was performed.
- The isolated recovery database/container was not connected to Production.
- Storage object bytes were not part of the bundle; the source snapshot contained zero Storage objects. This drill proves Storage metadata restoration only, not object-byte recovery or Storage API upload/download/delete behavior.
- Supabase project control-plane settings, API/JWT keys, Edge Function secrets, custom domains, provider configuration, and Vault root/encryption material remain outside this database restore proof.

### Updated DR gate status

**PASS:** current-run encrypted Production database backup; runner-local PostgreSQL 17 restore rehearsal; ciphertext checksum/integrity; private off-site Drive copy and byte-for-byte read-back; owner-side age decryption; independent PostgreSQL 17 restore of the November 22 artifact; exact match of all eight critical data counts; structural inspection with zero invalid indexes and the known NOT VALID Realtime constraint explicitly identified.

**STILL OPEN:** approved backup cadence and retention policy; formally approved RPO/RTO targets and measured recovery objectives; complete Supabase control-plane and secret re-provisioning inventory and rehearsal; Storage object-byte backup/recovery strategy before any object is stored; repeatable scheduled/owner-operated drill evidence and independent reviewer acceptance.

The independent database recovery proof gap for this artifact is now closed. The overall Production Backup Recovery & Disaster Recovery gate remains OPEN until the remaining operational and control-plane criteria are accepted. PR #296 remains open/draft and unmerged; PR #297 remains documentation-only and draft.


### Corrected application-schema structural counts

A second catalog query was run with explicit namespace joins and filters, excluding system schemas and counting only application/extension schema objects. This corrects the earlier broad pg_proc count, which included system and extension routines.

- Non-system schemas: 10
- Ordinary tables (relkind = r): 99
- Indexes (relkind = i): 394
- Constraints: 359
- Non-internal triggers: 78
- RLS policies: 226
- Functions/procedures: 246

The corrected counts for constraints (359), triggers (78), RLS policies (226), and functions/procedures (246) match the prior recorded structural baseline. The index count is 394 versus the previously recorded 395 and remains an explicit one-index discrepancy pending source-side comparison. The table count of 99 uses ordinary tables only and is not directly comparable to the earlier pg_tables count of 100, which may include partitioned/other table categories.

No catalog objects were modified during this inspection.


## 15. Live Production-to-independent-restore structural parity and control-plane inventory — PASS / PARTIAL

A read-only SQL query was executed against the live Production project and the same namespace-filtered catalog query was compared with the independent restored database. The two sides match exactly:

| Metric | Live Production | Independent restore |
|---|---:|---:|
| Non-system schemas | 10 | 10 |
| Ordinary tables | 99 | 99 |
| Indexes | 394 | 394 |
| Constraints | 359 | 359 |
| Non-internal triggers | 78 | 78 |
| RLS policies | 226 | 226 |
| Functions/procedures | 246 | 246 |
| Invalid indexes | 0 | 0 |
| Unvalidated constraints | 1 | 1 |

The single unvalidated constraint on both sides is realtime.messages_payload_exclusive on realtime.messages, defined as CHECK (((payload IS NULL) OR (binary_payload IS NULL))) NOT VALID. It was not modified. This direct live-source comparison resolves the earlier apparent 394-versus-395 index discrepancy: it was caused by inconsistent counting scopes, not a missing restored index.

A separate read-only Production query confirmed:
- Three Storage buckets exist and all are private: roshan-clinical-attachments, roshan-lab-reports, and roshan-medical-certificates.
- storage.objects contains zero objects.
- vault.secrets contains zero rows.
- There are zero invalid indexes.

The connected Supabase project metadata identifies Production as ACTIVE_HEALTHY, PostgreSQL 17.6.1.155, region eu-west-1, on the Free plan. The project API URL is https://jewzonxplxhogqrnhosl.supabase.co. The publishable-key inventory returned one disabled legacy anon key record and one enabled key record named roshan_vercel_production; actual key material is intentionally not copied into this report. The Edge Functions inventory returned no deployed functions.

### Recovery scope and Free-plan implications

Supabase's current official backup documentation states that automatic daily database backups are provided for Pro, Team, and Enterprise projects, and recommends regular CLI exports plus off-site backups for Free projects. This Production project is on the Free plan; therefore the current manual-only runner is not backed by a Supabase automatic daily-backup entitlement. The one-day GitHub Actions artifact is staging only; the private Drive copy is the durable off-site copy verified for this drill.

Official reference: https://supabase.com/docs/guides/platform/backups

Supabase's restore-to-new-project documentation also states that Storage objects/settings, Edge Functions, Auth settings/API keys, Realtime settings, and certain platform/database settings require manual reconfiguration. Official reference: https://supabase.com/docs/guides/platform/clone-project

### Operational policy proposal — awaiting owner acceptance

The technical evidence now supports the database backup and independent restore path, but an operational RPO/RTO and retention policy must be explicitly accepted by the project owner. The following is a proposed low-cost policy, not yet an approved service commitment:

- Backup cadence: owner-operated encrypted Production backup at least once every 24 hours, plus before any Production migration or release; verify successful workflow, Drive upload, and Drive read-back each time.
- RPO target: no more than 24 hours, conditional on a successful daily backup and verified off-site copy.
- RTO target: no more than 4 hours to restore the database and complete the documented platform reconfiguration. This target is NOT yet measured end-to-end; the completed drill measured successful database recovery but did not time a full project/service restoration.
- Retention: retain at least 30 daily encrypted copies in the canonical private Drive archive; do not rely on the one-day GitHub Actions artifact as retention.
- Drill cadence: perform and record an independent restore rehearsal at least quarterly and after material changes to the backup format or Supabase platform configuration.

No scheduled backup or reminder has been enabled. The runner remains manual-only because its GitHub artifact upload is not automatically transferred to Drive. Do not add a cron trigger that merely creates a one-day GitHub artifact without durable off-site transfer.

### Remaining blockers to formal gate closure

1. Owner acceptance of the proposed cadence, RPO, RTO, retention, and quarterly drill policy (or a replacement policy).
2. An end-to-end timed recovery rehearsal including manual Supabase project recreation/reconfiguration, Auth settings, API key replacement, Realtime settings, database extensions/settings, and any required deployment/secret updates. Current connectors expose project metadata and publishable-key inventory but do not provide a safe complete export/replay of all private project settings and secrets.
3. Storage object recovery remains a future precondition: all three buckets are currently private and empty, and the backup runner fails closed if storage.objects becomes non-empty. Before the first real file is uploaded, implement and test an independent S3-compatible object export/restore process; until then, do not treat database metadata as file backup.
4. Independent reviewer acceptance of the complete runbook and recovery evidence.

The database-specific restore and parity sub-gates are PASS. The overall Production Backup Recovery & Disaster Recovery gate remains OPEN pending the above owner/operational acceptance and full control-plane recovery rehearsal. No Production/QA writes, settings changes, deployments, key rotations, or project creation were performed in this session.


## 16. Vercel recovery inventory — read-only inventory captured

The Vercel project `roshan-health-hub` was inspected without decrypting environment variable values or changing settings.

- Project ID: `prj_DXhmP7InMjEeoZaIBnw3UhEGaUxk`
- Team ID: `team_GxMH4eyATlCfJMG8SJXzDcAg`
- Framework reported: `tanstack-start-lovable`
- Verified production domain returned: `roshan-health-hub.vercel.app`
- Project domains also include `roshan-health-hub-roshan45.vercel.app` and `roshan-health-hub-git-main-roshan45.vercel.app`.
- Environment-variable inventory was listed with decryption disabled. Production entries include Supabase URL and publishable/anon key variables, JWT/service-role/secret-key variables, and Postgres connection variables. Names observed include `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_URL`, `SUPABASE_JWT_SECRET`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `POSTGRES_URL`, `POSTGRES_PRISMA_URL`, `POSTGRES_URL_NON_POOLING`, `POSTGRES_USER`, `POSTGRES_HOST`, `POSTGRES_PASSWORD`, and `POSTGRES_DATABASE`.
- No environment variable values were retrieved, displayed, copied, or changed. This inventory records names only; it is not a secret backup or a verified restoration of those values.

This improves the control-plane inventory but does not satisfy the full re-provisioning rehearsal. The owner must retain actual secret values only in the authorized password manager/secret stores and confirm they can be re-entered after project replacement. A successful recovery test must verify the replacement Vercel environment variables and deployment without exposing their values in logs or this repository.
