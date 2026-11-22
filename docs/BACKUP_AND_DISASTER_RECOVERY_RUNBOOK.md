# Roshan Health Hub — Backup & Disaster Recovery Runbook (2026-11-22)

## 1. Scope & Safety Boundaries

- **Backup scope (current):** Logical PostgreSQL 17 database-only archive (`pg_dump --format=custom --no-owner`, all database schemas including `auth` and `storage` metadata, plus filtered custom roles).
- **Explicitly excluded from database archive:** Supabase Storage object bytes (the backup workflow fails closed if `storage.objects > 0`), Supabase Vault encryption root key (fails closed if `vault.secrets > 0`), Supabase control-plane settings, API/JWT keys, Edge Function secrets, and custom domains.
- **Secret-handling rules:**
  - Never paste private `age` identities (`AGE-SECRET-KEY-1...`), database passwords, `SUPABASE_DB_ACCESS_TOKEN`, `SUPABASE_ACCESS_TOKEN`, or decrypted Production dumps into chat, GitHub issues, PR comments, or unapproved cloud environments.
  - Never restore a Production backup over a shared QA or Production Supabase project. Always restore into an isolated disposable PostgreSQL 17 instance.

## 2. Root Cause of Backup Runner Run `#43764265014` (2026-11-15)

- **Repository:** `crauch2088-source/roshan-health-hub-backup-runner` (`main` `f171732b61fe0460c61a36aa63b861065f9ea9d1`).
- **Failed Job / Step:** `validate` (`#132965725378`) → Step 4 (`Preflight Production backup credentials`, `scripts/validate_backup_credentials.sh`).
- **Root Cause:** Both `SUPABASE_DB_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` were absent from repository Actions secrets (only `SUPABASE_ACCESS_TOKEN` was present).
- **Owner Remediation Required:** Before dispatching a manual Production backup, configure **exactly one** read-only/least-privilege database credential (`SUPABASE_DB_ACCESS_TOKEN` or `SUPABASE_DB_PASSWORD`) in `roshan-health-hub-backup-runner` repository secrets, run `Manual encrypted Production backup`, verify download to encrypted off-GitHub storage, and rotate/remove temporary credentials per owner security policy.

## 3. Owner-Only Offline Decryption & Isolated PostgreSQL 17 Restore Procedure

For the surviving encrypted Production archive on Google Drive (`roshan-production-backup-43183851731.zip`, `305,284 bytes`, expected SHA-256 `54b799545d1cb6eaccd16cf3964a3b6a5421c292c457504b967f5bcf5b488dd9`):

1. **Verify archive integrity locally (on owner device):**
   ```bash
   sha256sum roshan-production-backup-43183851731.zip
   # Must match: 54b799545d1cb6eaccd16cf3964a3b6a5421c292c457504b967f5bcf5b488dd9
   ```
2. **Unzip and verify inner ciphertext checksum:**
   ```bash
   unzip roshan-production-backup-43183851731.zip -d ./verify-43183851731
   cd ./verify-43183851731
   sha256sum -c SHA256SUMS
   ```
3. **Decrypt offline using the owner's local private age key (never share this key):**
   ```bash
   age -d -i ~/.config/age/roshan.key -o bundle.tar.gz roshan-production-*.tar.gz.age
   tar -xzf bundle.tar.gz
   ```
4. **Restore into an isolated local PostgreSQL 17 container (never Production or shared QA):**
   ```bash
   docker run -d --name roshan-pg17-restore -e POSTGRES_PASSWORD=local_temp_only postgres:17.6
   docker exec -i roshan-pg17-restore psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE roshan_restore_test TEMPLATE template0;"
   docker exec -i roshan-pg17-restore pg_restore -U postgres --dbname=roshan_restore_test --no-owner --exit-on-error --single-transaction < full.dump
   ```
5. **Validate row counts against `source-counts.json`, record elapsed restore time (Production RTO), and destroy the temporary container + plaintext files:**
   ```bash
   docker rm -f roshan-pg17-restore
   rm -rf ./verify-43183851731
   ```

## 4. Proposed RPO / RTO Objectives (Pending Owner Approval)

The repository does not yet have formally signed-off Production RPO/RTO targets. Proposed targets for owner review before Production go-live:

- **Proposed Production RPO:** `<= 24 hours` (requires converting the manual-only workflow to a monitored daily scheduled encrypted backup with failure alerting).
- **Proposed Production RTO:** `<= 60 minutes` (from verified archive retrieval to isolated PostgreSQL 17 restore + smoke validation).
