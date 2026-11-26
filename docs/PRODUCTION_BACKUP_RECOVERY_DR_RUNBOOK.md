# Roshan Health Hub — Production Backup Recovery & Disaster Recovery Runbook

**Status:** Owner-approved low-cost policy recorded; database recovery evidence PASS; overall operational DR gate OPEN pending timed control-plane recovery rehearsal, Storage/Vault boundary controls, and independent review.

**Production project:** `jewzonxplxhogqrnhosl`  
**Region / engine:** `eu-west-1` / PostgreSQL 17.6.1.155  
**Supabase plan:** Free  
**Backup runner:** [roshan-health-hub-backup-runner](https://github.com/crauch2088-source/roshan-health-hub-backup-runner)  
**Canonical private archive:** [Roshan Health Hub - Encrypted Backups](https://drive.google.com/drive/folders/1m-1JA2yT_NZxo0Drb4qGjyd24UW_Mta5)

## 1. Recovery design and safety boundaries

- Production backup is a manually dispatched, read-only logical PostgreSQL dump. The runner performs an isolated PostgreSQL 17 restore rehearsal, compares critical counts, encrypts with age, and uploads ciphertext only to a one-day GitHub Actions artifact.
- The owner must transfer the artifact to the canonical private Drive archive, in a dated child folder, and verify a complete read-back by SHA-256. The GitHub artifact is temporary staging, not retention.
- Keep the age private identity offline or in the owner's password manager. Store only the public age recipient in the runner repository variable. Never upload the private identity, decrypted dump, plaintext manifest bundle, database password, PAT, API secrets, or connection string to GitHub/Drive/ChatGPT.
- Do not run restore commands against Production or QA. Restore only into a newly provisioned isolated recovery project/container.
- Never delete or overwrite an existing recovery database to repeat a drill without explicit owner approval.
- Never add a scheduled GitHub workflow that only creates a one-day artifact and does not complete durable off-site transfer.
- PR #296 is unrelated QA remediation and must not be merged as part of this DR gate. PR #297 is the documentation/evidence PR.

## 2. Current verified backup

- Workflow run: [#45080086071](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/45080086071)
- Artifact: `roshan-production-backup-45080086071.zip`
- Artifact ZIP SHA-256: `ef99f0875ee0aed41e24bc738803839cd9d4c326f5a3b5ac7375b0014379a480`
- Encrypted member SHA-256: `5b80dff16006fd9b384177e00e4c28c980865494b5353fbe7f9b4a003b3b3477`
- Private Drive file: [roshan-production-backup-45080086071.zip](https://drive.google.com/file/d/1N-YpbrJ8gJs8-Z9oMSEBJgod4UD_IuML/view)
- Dated folder: [2026-11-22](https://drive.google.com/drive/folders/16sQvIVQdU1R-RhbzxrTuPVoyGuVqSX9E)
- Drive read-back returned 304,943 bytes and the exact same SHA-256 as the GitHub artifact; ZIP integrity and inner checksum passed.
- Owner-side decryption passed. The new artifact was independently restored into isolated PostgreSQL 17 database `roshan_dr_20261122_independent` using the existing `supabase_admin` bootstrap superuser. The restore used `--exit-on-error --single-transaction --no-owner --no-privileges`.
- Critical restored counts matched the backup manifest: Auth users 6; patients 3; visits 9; invoices 0; payments 0; cashbox transactions 0; Storage buckets 3; Storage objects 0.

## 3. Restore verification baseline

The same namespace-filtered read-only catalog query was run against live Production and the independent restore. Both sides returned exactly:

| Metric | Production | Restore |
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

The one unvalidated constraint on both sides is `realtime.messages_payload_exclusive` on `realtime.messages`, defined as `CHECK ((payload IS NULL) OR (binary_payload IS NULL)) NOT VALID`. Do not validate or modify it as part of a restore drill.

## 4. Backup execution checklist

1. Confirm the owner-controlled GitHub Actions secrets/variables exist in the private runner repository; do not expose their values:
   - `SUPABASE_ACCESS_TOKEN` (CLI authentication).
   - Exactly one of `SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`.
   - `AGE_RECIPIENT` public recipient variable.
2. Open Actions → Manual encrypted Production backup; use `main`; explicitly confirm the Production backup.
3. Require both validation and backup jobs to pass. Confirm the local PostgreSQL 17 restore rehearsal and critical count comparison pass.
4. Download the ciphertext-only artifact before its one-day expiry.
5. Transfer it to a dated child folder under the canonical private Drive archive.
6. Read the object back from Drive and verify byte count, SHA-256, ZIP integrity, and the inner encrypted member checksum.
7. Record run ID, timestamp, artifact ID, sizes, checksums, Drive file ID, and verification outcome in the DR session record.
8. If any step fails, mark that cycle FAILED; do not treat an Actions artifact alone as a successful retained backup.

## 5. Owner-side restore checklist

1. Use a trusted, isolated environment with adequate free disk space and PostgreSQL 17 tooling. Confirm the recovery target is not Production or QA.
2. Download the ciphertext ZIP from the private Drive archive and verify its SHA-256 against the recorded artifact digest before extraction.
3. Inspect ZIP contents; expect only the checksum manifest and age-encrypted archive.
4. Verify the inner encrypted member checksum.
5. Enter the age private identity only through a secure local prompt/file workflow. Never paste it into chat, a command literal, shell history, logs, or a repository.
6. Decrypt locally and inspect the manifest/archive listing. Do not upload or share decrypted files.
7. Restore into a fresh isolated PostgreSQL 17/Supabase-compatible target using the local bootstrap superuser where required. Use fail-fast, single-transaction restore semantics; never weaken source privileges or alter Production roles to make a restore pass.
8. Compare critical row counts and namespace-filtered structural counts with the source snapshot.
9. Verify the restored application with synthetic test identities only. Never use real patient data for synthetic smoke tests.
10. Record start/end timestamps to calculate actual RTO. The current drill did not time a complete platform/service recovery.

## 6. Supabase control-plane re-provisioning checklist

The logical database archive does not reproduce the entire Supabase project. During a real disaster, create/restore a separate project only after reviewing cost, region, and owner authorization, then reconfigure and verify:

- Project region, compute/disk settings, SSL enforcement, network restrictions, database connection settings, and database password.
- Database extensions and settings not fully represented by the dump; custom role passwords must be reset/re-provisioned securely.
- Auth: site URL, redirect allow-list, enabled providers, SMTP/email templates, phone/SMS provider, CAPTCHA, MFA and other enabled security controls.
- API: project URL, publishable/anon and service-role key lifecycle. Rotate/recreate keys as appropriate and update Vercel environment variables without recording secret values in this repository.
- Edge Functions: inventory and redeploy required functions, then re-provision their secrets. Current Production inventory returned no deployed Edge Functions.
- Realtime: publications, enabled tables, replication settings and any required configuration.
- Storage: recreate the three private buckets listed below and reapply/verify policies before allowing uploads.
- Vercel: verify production project environment variables, deployment settings, domains and aliases; redeploy only after the replacement backend is validated.
- External integrations, provider credentials, DNS/custom domains, webhooks, scheduled jobs, and third-party callbacks.
- Rotate credentials that may have been exposed during the incident and verify the new values in their authorized secret stores.

Do not store passwords, PATs, API keys, service-role keys, private age identities, or raw environment files in this checklist.

## 7. Storage and Vault boundary

Current Production has three private buckets and zero objects:

- `roshan-clinical-attachments` — private
- `roshan-lab-reports` — private
- `roshan-medical-certificates` — private

Current `storage.objects` count is zero and `vault.secrets` count is zero. The database backup contains Storage metadata, not Storage object bytes. The runner fails closed if Storage objects become non-zero or Vault secrets exist.

**Before the first real file is uploaded**, implement and test an independent S3-compatible object export and restore procedure, including object bytes, metadata, content type, bucket mapping, access policies, and integrity checks. Until that is proven, do not treat database metadata as a file backup and do not mark Storage recovery as covered.

If Vault secrets are introduced, stop and establish a separately protected Vault encryption-root-key recovery procedure before relying on database dumps.

## 8. Owner-approved low-cost operational policy — APPROVED 2026-11-26

The Supabase organization is on the Free plan. Supabase's current documentation says daily managed database backups are available on Pro, Team, and Enterprise plans, and recommends regular CLI exports plus off-site backups for Free projects: https://supabase.com/docs/guides/platform/backups

Owner-approved minimum-cost policy. It preserves the 24-hour recovery-point objective without purchasing a Supabase plan upgrade, paid backup service, VM, or always-on recovery infrastructure:

- Cadence: one successful encrypted Production backup with verified private Drive read-back every 24 hours, and immediately before every Production migration/release. A run counts only after Drive read-back and SHA-256 verification.
- RPO: maximum 24 hours, conditional on the cadence actually being met and the off-site copy verified. If a cycle is missed, record the actual exposure; do not claim the RPO was met.
- RTO: target no more than 4 hours from incident declaration to restored database plus essential platform reconfiguration. This is an owner-approved target, not yet measured end-to-end; record actual elapsed time during the next full drill.
- Retention: keep the latest 7 daily verified backups, plus 1 verified backup per week for the preceding 4 weeks (maximum 11 retained copies). The weekly copies are selected from existing daily runs; they do not require extra backup runs. Delete older copies only after verifying that the newer retention set is complete and readable. The one-day GitHub artifact does not count toward retention.
- Drill: independent restore rehearsal at least quarterly and after material backup/platform changes. Reuse a disposable isolated target; do not provision paid always-on infrastructure.
- Monitoring/ownership: the owner checks each cycle. A failed or missing backup triggers immediate remediation, and the DR gate returns to OPEN until a verified off-site backup exists.
- Cost boundary: remain on the current Supabase Free plan and existing private Drive storage while within its available quota. Do not add a paid plan, cloud VM, managed backup product, or new always-on service without separate explicit approval. If Drive quota or another free-tier limit is reached, stop retention pruning only after preserving the newest verified backup; obtain owner approval before any paid expansion.

No schedule or reminder is currently enabled. The runner remains manual-only until a durable Drive transfer workflow is automated. Until then, the owner-operated daily checklist is the accepted process; a one-day Actions artifact alone never satisfies the policy.

## 9. Gate decision

**Database backup and restore evidence: PASS.**  
**Live-to-restore structural parity: PASS.**  
**Off-site private copy and byte-for-byte retrieval: PASS.**  
**Overall Production Backup Recovery & Disaster Recovery gate: OPEN.**

Formal closure still requires:
1. A timed end-to-end recovery rehearsal including the control-plane re-provisioning checklist, with actual RTO recorded.
2. A tested Storage object-byte recovery mechanism before the first real object is stored; until then, enforce the zero-object precondition and keep the buckets empty.
3. A separately protected Vault encryption-root-key recovery procedure before introducing any Vault secrets; until then, keep Vault secret count at zero.
4. Independent reviewer acceptance of this runbook and evidence.

No Production/QA writes, migrations, deployments, key rotations, or Supabase project settings changes are authorized by this runbook.


## 10. Verified Production backup — 2026-11-26

A fresh owner-approved manual backup cycle completed successfully on 2026-11-26.

- Runner repository: `crauch2088-source/roshan-health-hub-backup-runner`
- Workflow run: [#31 — encrypted Production backup](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/45764308295)
- Run ID: `45764308295`; completed successfully at `2026-11-26T05:55:14Z`.
- Validation/preflight job: PASS.
- Production database dump and isolated local PostgreSQL 17 restore rehearsal: PASS.
- Encrypted artifact upload: PASS; only ciphertext was uploaded.
- Artifact: `roshan-production-backup-45764308295.zip`, 308,191 bytes.
- GitHub artifact SHA-256: `04e4e6c5b9865c4c20fc104abc04641b216ea1c86ee88bc75b2d32e81aded49b`.
- Off-site copy: [private Drive archive — 2026-11-26](https://drive.google.com/drive/folders/1evGsWSmhysqH1lAs0909xxRpQ0ogr_Q7).
- Drive file ID: `1Njr31badfS8RCwbF8QLKXVUDxZV1-Nll`; 308,191 bytes; private, owner-only.
- Drive read-back SHA-256: `04e4e6c5b9865c4c20fc104abc04641b216ea1c86ee88bc75b2d32e81aded49b`; MD5 `022113d28c7fe9840b950ec4e73b261b`. Both hashes and byte length match the original artifact exactly.

The prior verified Drive copy was created at `2026-11-22T23:00:14Z`; the new copy was verified at `2026-11-26T05:55:49Z`. The gap was approximately **78 hours 55 minutes**, so the owner-approved 24-hour RPO was breached during that interval. The new copy establishes a current recovery point; it does not retroactively erase the missed cadence. Resume daily owner checks immediately.

This run performed no Production writes, migrations, deployments, key rotations, or project-setting changes. The runbook remains manual-only; no schedule or reminder was enabled.
