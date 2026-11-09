# Device-side encrypted backup recovery verification — 2026-11-09

## Outcome

**Passed:** the owner verified the encrypted Production database backup on an Android device using Termux. The encrypted payload's checksum matched, age decryption succeeded with the locally held private identity, the gzip/tar archive was readable, and the temporary plaintext archive was removed.

This closes the end-user device-decryptability gate. It is distinct from, and complements, the backup runner's earlier PostgreSQL 17 isolated restore rehearsal and critical row-count comparison. The Android test validated decryption and archive readability; it did not import the database into a PostgreSQL server on the phone.

## Evidence

- Source bundle: `Roshan-Production-Backup-2026-11-08.zip`.
- Inner encrypted payload: `roshan-production-20261108T233641Z.tar.gz.age`.
- On-device SHA-256:
  `64a346c48d5db96fc4c28bd99bb60c38802f223de4938d43c2d8137fee0ffef1`.
- The checksum matched the expected manifest value.
- The archive was extracted successfully from the device's `~/downloads` directory to `~/roshan-backup/restore-check`.
- The Termux package-install attempt for `unzip` encountered a mirror package-index size/hash mismatch. It was non-blocking because `unzip` was already available.
- `termux-setup-storage` did not expose `~/storage/downloads` in that session. The existing `~/downloads` path was used instead.
- The user ran `age -d` with the locally stored identity at `~/roshan-backup/identity.txt`. The resulting `restore-test.tar.gz` existed and was 298 KB.
- `tar -tzf restore-test.tar.gz >/dev/null` completed and printed `DECRYPTION_AND_ARCHIVE_OK`.
- The user removed the temporary plaintext archive with `rm -f restore-test.tar.gz`; the follow-up check printed `PLAINTEXT_REMOVED`.

## Security handling

- The private age identity remained on the user's device and was not shared in chat or uploaded.
- No decrypted SQL, database rows, patient data, database password, or private key was transmitted.
- The encrypted backup and private identity were retained; only the temporary decrypted archive was removed.

## Backup scope and limitations

- The backup is a PostgreSQL database backup, encrypted with age.
- At backup time, Storage object count and Vault secret count were both zero; three Storage buckets existed and were empty.
- The archive does not contain Storage object bytes or Vault secret material.
- The backup workflow is manual; no recurring schedule is configured.
- Device-side tar readability is not itself a second live PostgreSQL restore. The separate runner-side PostgreSQL 17 isolated restore rehearsal and critical row-count comparison passed earlier.

## Release impact

This verification closes the device-decryptability sub-gate. It does **not** authorize Production Phase 57, application deployment, or clinical launch. Remaining independent gates include authenticated QA pharmacist acceptance, staff UAT across reception → GP → lab → pharmacy → billing, physical A4/mobile/RTL/LTR printing checks, and live Production/QA migration-ledger reconciliation.

Never store the private age identity, database password, access token, plaintext dump, or decrypted SQL in this repository.
