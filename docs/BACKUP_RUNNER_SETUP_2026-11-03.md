# Backup runner setup — Roshan Health Hub (2026-11-03)

The private runner is at https://github.com/crauch2088-source/roshan-health-hub-backup-runner.

## Design

- Private repository, separate from the public application repo.
- Manual-only GitHub Actions workflow; no push, pull-request, or scheduled execution.
- Explicit confirmation input required before any Production connection.
- Temporary Supabase database access token used as the database password; the Production DB password is not needed.
- PostgreSQL 17.6 full custom-format dump includes database schemas and data, including Auth and Storage metadata.
- The runner aborts if Storage object rows exist (object bytes are outside PostgreSQL) or if Vault secrets exist (Vault encryption root key is not part of a database dump).
- An ephemeral local Supabase/PostgreSQL 17 target receives the dump; critical table counts are compared before encryption.
- The only uploaded artifact is age-encrypted. GitHub artifact retention is one day; the agent transfers it to the existing private Google Drive folder using the connected resumable-upload path.
- The age private identity is not stored in GitHub, Drive beside the backup, or ChatGPT.

## Required repository settings

In the private runner repository:

- Actions secret: `SUPABASE_DB_ACCESS_TOKEN` — short-lived Supabase PAT used by the temporary database access rule.
- Actions variable: `AGE_RECIPIENT` — public `age1...` recipient.
- Optional Actions variable: `SUPABASE_DB_POOLER_PORT` — defaults to `5432`, with the required `options=-c jit=true` connection parameter. Change it only if the Supabase Dashboard provides a different compatible shared-pooler endpoint.

## Validation already performed

- Run `41631718043`: basic syntax and CLI flag validation passed.
- Run `41631926251`: Bash syntax, ShellCheck, Supabase CLI setup, and required CLI flags passed. The backup job was skipped intentionally because `confirm_production_backup=false`.
- Run `41632621501`: the updated shared-pooler port 5432 and JIT connection settings passed the same validation-only workflow; no Production connection was attempted.
- No secrets were configured, no Supabase database connection was attempted, and no backup artifact was created.

## Remaining owner setup

1. Supabase Dashboard → Organization Settings → Feature Previews: enable `supabase-ui-jit-db-access`.
2. Ensure **Enforce SSL on incoming connections** is enabled for the Production project; temporary database access requires SSL enforcement.
3. Production project `jewzonxplxhogqrnhosl` → Database settings: grant the owner's account temporary access to role `postgres`, with the shortest practical expiry.
4. Create a short-lived Supabase PAT and add it as `SUPABASE_DB_ACCESS_TOKEN` in the private runner's Actions secrets.
5. On a trusted device, generate an age identity:
   ```bash
   age-keygen -o roshan-backup-identity.txt
   age-keygen -y roshan-backup-identity.txt
   ```
   Keep the identity file offline/in a password manager; add only the public recipient as `AGE_RECIPIENT`.
6. Trigger the workflow with explicit confirmation. After success, the agent will transfer the encrypted artifact to **Roshan Health Hub Backups**, verify the Drive file and checksum, then the PAT/access rule can be revoked.

## References

- Temporary token-based database access: https://supabase.com/changelog/2026-05-25-temporary-token-based-database-access
- Supabase backup/restore: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- Supabase database backups: https://supabase.com/docs/guides/platform/backups
- age encryption: https://age-encryption.org/
