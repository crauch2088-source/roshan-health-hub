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
