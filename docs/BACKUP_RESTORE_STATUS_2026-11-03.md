# Backup and restore readiness — 2026-11-03

## Verified state

- The private Google Drive destination folder **Roshan Health Hub Backups** exists, is owned by the connected account, is not trashed, and is not shared.
- The folder contains no verified backup artifact.
- GitHub Actions repository-secret inventory returned **zero secrets** for this repository.
- Vercel production environment metadata includes sensitive database connection variables (including `POSTGRES_URL_NON_POOLING` and `POSTGRES_PASSWORD`). Their values were not retrieved, copied, logged, or exposed.
- The available Vercel environment connector exposes metadata in the safe listing path; it is not an approved bridge for injecting those values into an independent backup runner.
- A Google Drive resumable-upload action is available for large staged files. It requires an already staged file reference; it does not itself create a database dump or provide database credentials.
- No encrypted database dump, Storage-object archive, or restore rehearsal has been completed.

## Safety and change record

- No DDL or DML was executed against Production or QA.
- No project password or API key was rotated.
- No secret value, database URL, patient data, or plaintext dump was written to GitHub, chat, or Drive.
- The GitHub Actions secret inventory and Vercel environment listing were metadata-only checks.

## Current blocker

There is not yet a controlled runner with least-privilege access to the production database, an independently held encryption recipient/private-key custody arrangement, and a secure Drive upload identity. The repository currently has no GitHub Actions secrets. Therefore an automated backup workflow cannot run safely yet.

## Required next steps

1. Provision a controlled runner/secret store and inject the database connection value there without passing it through chat or source control.
2. Establish an encryption keypair outside the repository; store only the public recipient in the runner and keep the private key under separate custody.
3. Implement a backup job that exports the database using an authorized Supabase CLI/pg_dump environment, separately captures required Storage object bytes and recovery metadata, encrypts the artifacts before upload, and records checksums and timestamps.
4. Upload the encrypted artifacts to the private Drive folder using the resumable upload path.
5. Restore into a disposable isolated target (not the existing QA project and never Production), then verify schema, roles/grants/RLS, critical RPC behavior, Storage references, and representative synthetic records.
6. Update `docs/MASTER_PLAN.md` and close this gate only after the restore rehearsal passes.

**Release gate: OPEN.** A destination folder and upload capability are not a backup. No backup or restore is claimed complete.
