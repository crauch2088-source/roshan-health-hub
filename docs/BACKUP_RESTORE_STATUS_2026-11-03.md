# Backup and restore readiness — 2026-11-03

## Verified state

- The private Google Drive destination folder **Roshan Health Hub Backups** exists, is owned by the connected account, is not trashed, and is not shared. It contains no verified backup artifact yet.
- A separate private GitHub repository now exists: `crauch2088-source/roshan-health-hub-backup-runner`. It contains only the manual backup workflow, script, and setup documentation; no secrets or backup artifacts have been added.
- The runner workflow is manual-only, requires an explicit `confirm_production_backup=true` input, and uploads only encrypted artifacts with one-day retention.
- Validation-only workflow run `41631926251` passed: Bash syntax, ShellCheck, Supabase CLI `2.122.0` availability, and the required `db dump --db-url` / `--role-only` flags. The Production backup job was intentionally skipped because confirmation was false.
- Supabase documents temporary token-based database access for PostgreSQL 17+. Both Roshan projects run PostgreSQL 17.6. This provides a path that avoids using the Production database password in the runner.
- The runner uses the existing private Drive folder via the connected Google Drive resumable-upload integration after the encrypted GitHub artifact is downloaded. No Google service-account credential is required.
- The workflow is designed to abort if `storage.objects` is non-empty or `vault.secrets` contains rows, because object bytes and the Vault encryption root key require separate recovery paths.

## Required one-time owner setup

1. Enable Supabase **Temporary token-based database access** in organization Feature Previews and add a short-lived Production access rule for the owner's account and database role `postgres`.
2. Create a short-lived Supabase Personal Access Token and add it as the private runner repository Actions secret `SUPABASE_DB_ACCESS_TOKEN`. Do not send it through ChatGPT. Revoke it and remove the temporary access rule after the backup.
3. Generate an age keypair on a trusted device. Keep the private identity offline/in a password manager; add only the public `age1...` recipient as the private repository Actions variable `AGE_RECIPIENT`.
4. Once those values exist, trigger **Actions → Manual encrypted Production backup** with the confirmation input set to true. The runner will dump the full PostgreSQL database, perform an ephemeral local PostgreSQL 17 restore and compare critical table counts, then encrypt the archive. The agent can transfer the encrypted artifact to Drive and verify the upload.

Detailed setup steps and commands are in the private runner repository README.

## Safety and change record

- No Production DDL or DML has been executed for backup setup.
- No Production database password or PAT value was retrieved, copied, logged, or exposed.
- No plaintext database dump has been written to GitHub, chat, or Drive.
- The new runner has not yet connected to Production; no encrypted backup artifact exists.
- No Production password or API key was rotated.

## Current gate

**Encrypted Production backup: NOT DONE. Restore rehearsal: NOT DONE. Release gate: OPEN.**

A private runner and a validated workflow are preparation, not a backup. The gate stays open until the first encrypted artifact is uploaded to Drive, its checksum is verified, and the local restore rehearsal passes. Full migration-chain reconciliation, authenticated clinical E2E, and staff UAT remain separate release gates.
