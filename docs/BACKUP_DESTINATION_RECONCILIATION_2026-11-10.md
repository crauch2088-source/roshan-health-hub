# Backup destination reconciliation — 2026-11-10

## Purpose and safety

A read-only Google Drive and GitHub Actions recheck was performed on 2026-11-10. No Drive files or folders were created, moved, renamed, downloaded, shared, or deleted. No backup workflow was dispatched. No credentials, private age identity, database content, patient rows, clinical notes, or financial rows were accessed.

## Verified Drive hierarchy

The connected Drive account owns the following non-trashed objects:

1. Root folder **Roshan Health Hub - Encrypted Backups**, ID 1m-1JA2yT_NZxo0Drb4qGjyd24UW_Mta5.
2. Dated child folder **2026-11-09**, ID 14q8YQbDddwzJ1tEyM0t8bK9f5ExRezF7, parent is the canonical root above.
3. File **Roshan-Production-Backup-2026-11-08.zip**, ID 1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv, parent is the dated child folder, size 305,317 bytes, MD5 875a85ac23e8b7a671c371cca41f7732, trashed=false.

The file's web link is https://drive.google.com/file/d/1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv/view?usp=drivesdk.

A separate folder named **Roshan Health Hub Backups**, ID 1ak6tu379LSxfmjioeQsxUN5eJ_FWitd6, was also found. Its direct child listing returned zero items. It is not the parent of the existing encrypted snapshot and is not the canonical destination.

## Backup and restore evidence

- Backup runner main: ed41574bb278325e7bc06fd034e767db1544c55a.
- Latest workflow overall: 42537677251, branch fix/portable-backup-checksum-20261109, head bca6eeed81b5b76f6cac0312fd370651cdfde20c. Validation succeeded; the backup job was skipped; no GitHub artifact was created. Do not describe this run as a backup.
- Latest full backup run: 42535939237, branch feat/backup-db-password-fallback, head 713ee4edf47429df9e02c475e5909e4c4f62a744. Both validate and backup jobs succeeded, including PostgreSQL 17 dump, isolated local restore, critical row-count comparison, age encryption, and ciphertext-only artifact upload. Its GitHub Actions artifact has expired; the Drive copy above remains.
- The encrypted archive SHA-256 recorded for that backup was 3b3df1aa9056c70a0d6c9fc40f98a5ba6f23e4889040c24ec8f3302f270df355.
- Owner-device verification on 2026-11-09 confirmed the inner encrypted archive SHA-256 64a346c48d5db96fc4c28bd99bb60c38802f223de4938d43c2d8137fee0ffef1, successful age decryption using the private identity held locally, gzip/tar readability, and removal of temporary plaintext.
- The backup is database-only. At snapshot time Storage objects and Vault secrets were zero; Storage object bytes and Vault secret material are not included. No recurring backup schedule exists.
- The portable checksum-manifest helper is now on runner main, and its validation/unit tests passed in the latest validation job. A new full backup using the current main helper remains unverified.

## Documentation correction

The backup-runner README previously named the separate empty folder “Roshan Health Hub Backups”. Draft PR #4 replaces that stale destination text with a direct link to the verified **Roshan Health Hub - Encrypted Backups** folder:

- PR: https://github.com/crauch2088-source/roshan-health-hub-backup-runner/pull/4
- Commit: 56b458f4c1f2a4cc7380eaa70df11d36c0190f67

The change is README-only. It does not move the existing backup, change workflow behavior, or create an external write.

## Next action

When the owner explicitly authorizes a new manual Production backup, run the current main workflow and verify that the portable checksum manifest is included in the full encrypted backup, the isolated PostgreSQL 17 restore passes, the encrypted artifact is transferred to the canonical Drive root, and the owner-device decryption/archive-readability check succeeds. Do not dispatch automatically.
