# Roshan Health Hub — Production backup and release-gate evidence

**Evidence date:** 2026-11-12  
**Production project:** `jewzonxplxhogqrnhosl`  
**QA project:** `hopfohcnrtbiqjkgeukz`  
**Application main:** `5159d469b34b794bb68b2fbe245552cd509188a6`  
**Backup runner main:** `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`

## 1. Fresh encrypted Production backup — successful

- Backup-runner PR [#8](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/pull/8) was reviewed in a fresh session and squash-merged. A review comment records that it was a self-review, not a separate human/subagent approval; no independent second-person approval is claimed.
- Backup-runner CI on the merged head: [run #43183801681](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183801681) — success.
- Manual Production backup: [run #43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731), workflow-dispatch event, branch `main`, exact runner SHA `eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8`, overall success.
- The hardened credential preflight actually ran and passed. The separate `validate` and `backup` jobs both completed successfully. In the backup job, `Create and locally restore encrypted backup`, `Upload encrypted artifact only`, and `Record safe run summary` all passed.
- The backup script completed a local PostgreSQL 17 restore rehearsal and its critical table-count comparisons. This is a pre-encryption local restore, not owner-side decryption of the final ciphertext.
- The artifact was produced at 2026-11-12 08:35:59 UTC and expires from GitHub Actions on 2026-11-13 08:35:58 UTC. Its off-site Drive copy is the retained copy.

### Artifact integrity

| Field | Verified value |
|---|---|
| GitHub artifact ID | `13927247998` |
| Artifact name | `roshan-production-backup-43183851731` |
| ZIP file name | `roshan-production-backup-43183851731.zip` |
| Size | `305284` bytes |
| GitHub SHA-256 | `54b799545d1cb6eaccd16cf3964a3b6a5421c292c457504b967f5bcf5b488dd9` |
| Independently downloaded ZIP SHA-256 | Exact match to GitHub digest |
| ZIP contents | `SHA256SUMS` (112 bytes) and `roshan-production-20261112T083337Z.tar.gz.age` (304775 bytes) |
| Ciphertext SHA-256 from manifest | `5c9f5e4ab9628cd9e7bdb11aea0edce96fac11d2c2b2176661add49aa79a3ddd` |
| Independently streamed ciphertext SHA-256 | Exact match to manifest |
| ZIP MD5 | `22271054f6c10b1baf1d23ac4bdac24e` |

The ZIP contains an encrypted `.age` archive and its checksum manifest only; no plaintext database dump was present in the downloaded ZIP listing.

### Canonical Google Drive copy

- Canonical private folder: [Roshan Health Hub - Encrypted Backups](https://drive.google.com/drive/folders/1m-1JA2yT_NZxo0Drb4qGjyd24UW_Mta5) — folder ID `1m-1JA2yT_NZxo0Drb4qGjyd24UW_Mta5`.
- Dated child folder: [2026-11-12](https://drive.google.com/drive/folders/1fUr9TW1zCcedDZqskWW3eWXNF2m6EVmK) — folder ID `1fUr9TW1zCcedDZqskWW3eWXNF2m6EVmK`.
- Uploaded file: [roshan-production-backup-43183851731.zip](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view) — file ID `1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o`.
- Drive read-back confirms MIME type `application/zip`, size `305284`, parent folder ID exactly matches the dated child folder, and `trashed=false`.
- Drive MD5 `22271054f6c10b1baf1d23ac4bdac24e` exactly matches the independently downloaded ZIP.

### Credential cleanup and scope

- The one-time GitHub Actions secret `SUPABASE_DB_PASSWORD` was deleted after successful backup and verified absent. The secret values were never read or exposed. The only remaining repository Actions secret observed was `SUPABASE_ACCESS_TOKEN`; the public age recipient remains a repository variable.
- A future manual backup will require re-adding exactly one supported DB credential secret. Do not paste credentials into ChatGPT or source control.
- At the checkpoint read, Production and QA each had 3 Storage buckets, 0 Storage objects, and 0 Vault secrets. Zero Storage objects means there were no object bytes to export at that moment; bucket metadata is distinct from object content.
- This database archive does not include Storage object bytes, Supabase project/control-plane settings, API/JWT keys, Edge Function secrets, custom-domain configuration, or a private age identity. Vault secret count was zero at the checkpoint, but that does not make platform settings recoverable from this dump.
- **Owner-side decryption remains unverified.** The private age identity was not accessed, uploaded, or exposed. A local restore performed before encryption cannot prove that the owner can decrypt the retained ciphertext. Keep the full disaster-recovery gate open until a safe owner-side decryption test is completed.

## 2. Live Production/QA pharmacy and security evidence

Direct read-only checks after the backup run:

| Measure | Production | QA |
|---|---:|---:|
| PostgreSQL | 17.6 | 17.11 |
| Migration rows | 129 | 26 |
| Latest migration | `20261102232941` | `20261112061251` |
| Storage buckets | 3 | 3 |
| Storage objects | 0 | 0 |
| Vault secrets | 0 | 0 |
| Active pending NULL-quantity prescription items | 0 | 0 |

### Effective dispensing function

- Production `public.fn_dispense_prescription_with_invoice(uuid,boolean)`: still contains `COALESCE(pi.quantity,1)`; explicit NULL-quantity, free-text, and external-prescription guards are absent.
- QA function: no quantity-to-one fallback; NULL-quantity, free-text, and external-prescription guards are present.
- The zero active pending NULL-quantity count does not remove the latent Production defect.

### Exact QA source payload comparison

The exact current source payloads were sent as read-only SQL literals to PostgreSQL and hashed in the QA database; their length and MD5 match the applied QA statement payloads:

| Phase | Source blob | Compared payload | QA stored statement | Result |
|---|---|---|---|---|
| 55 | `081d5e97169786e23cd1990cf9f6dbb1c49e4a1f` | 2,304 bytes; MD5 `b1271f444b6b8254b9b50ca49c7b02d3` (source file without final newline) | 2,304 bytes; same MD5 | Exact |
| 57 | `9db6768999352c32081f69b5e665c3cc95452616` | 10,954 bytes; MD5 `921970d4d86b32dccd430a0ea0ef8745` (full source file) | 10,954 bytes; same MD5 | Exact |
| 57B | `57516e08de8e314f687c21f2f292199d3adff178` | 11,525 bytes; MD5 `bfd2df24224752a1488f2f05494f4211` (function DDL payload, excluding migration comments/transaction wrapper) | 11,525 bytes; same MD5 | Exact |

A Git blob SHA is not the MD5 of a database migration statement. The payload boundaries above are explicit; do not compare the entire Phase 57B wrapper file to its stored function-DDL payload.

### PostgreSQL 17 regression evidence

- Main CI [run #43183563642](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43183563642) completed successfully on application main `5159d469b34b794bb68b2fbe245552cd509188a6`.
- Its `Atomic pharmacy dispense and invoice integration` job passed. The workflow replays Phase 57 and Phase 57B in order and executes `db/tests/pharmacy_dispense_invoice_integration.sql` plus legacy dispense revocation integration. The integration assertions cover NULL quantity, mixed catalogue/free-text rejection, external prescription rejection, and no unintended stock/invoice/status side effects.
- Dedicated Phase 55 CI [run #43184305893](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43184305893) completed successfully on the same main SHA. It applies the Phase 36 fixture, simulates the live drift, applies Phase 55, and verifies clinical parent-link immutability, direct helper EXECUTE denial for application roles, and continued trigger/SECURITY DEFINER caller behavior.

### Production Phase 55 ACL gap and bootstrap exception

- In Production, `private.app_has_claim_branch(uuid)` and `private.sync_user_role_text()` still have default/PUBLIC-effective EXECUTE (including anon/authenticated). QA has owner-only ACLs for both. No ACL changes were applied in this session.
- `private.phase36_guard_clinical_visit_links()` is already owner-only in Production.
- `public.setup_required()` is a separate intentional bootstrap status endpoint. It is SECURITY DEFINER with an empty search_path and returns only the boolean `NOT EXISTS (SELECT 1 FROM public.users)`. Its anon/authenticated execution is not equivalent to exposing patient or clinic data; do not blanket-revoke it without changing the onboarding contract.

## 3. Release decision

**Production remains NO-GO.** The backup, local restore rehearsal, checksum verification, Drive copy, exact Phase 55/57/57B source payload comparisons, and disposable PostgreSQL 17 tests now have current evidence. Still open:

1. Safe owner-side decryption of the retained ciphertext using the owner's offline private age identity.
2. Independent second-person review/sign-off of the Phase 55 and Phase 57/57B Production payloads; the PR #8 credential-preflight review was a self-review only.
3. Explicit Production change-window/release approval and final exact-head preflight immediately before any DDL/ACL action.
4. A reviewed forward-only migration mechanism that preserves migration provenance without copying or fabricating QA ledger rows.
5. Read-only post-apply checks and forward-recovery readiness.

No Production/QA DDL, DML, ACL/RLS, Auth, Storage, or business-data changes were made in this execution round. The only credential mutation was deletion of the one-time GitHub Actions repository secret `SUPABASE_DB_PASSWORD`. The backup itself was a read-only Production export.

