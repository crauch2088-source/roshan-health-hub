# Release-gate recheck — 2026-11-09

Audit update: 2026-11-09 (Africa/Khartoum). This document records the evidence that arrived after the 2026-11-08 read-only audit. The 2026-11-08 report remains a historical snapshot; its backup statements were accurate at that earlier time and are superseded below.

## 1. Encrypted Production backup — completed

- Private runner PR [#2](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/pull/2) is merged at `07ca69125da7cc702f9306da55cccf4916146b2f`.
- Manual workflow [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237) completed with conclusion `success`. Both `validate` and `backup` jobs succeeded. The backup job's steps succeeded: dump and local restore, encrypted artifact upload, and safe summary.
- GitHub artifact [13639676572](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237): `roshan-production-backup-42535939237`, 305,317 bytes, SHA-256 `3b3df1aa9056c70a0d6c9fc40f98a5ba6f23e4889040c24ec8f3302f270df355`. GitHub artifact expiry is 2026-11-09 23:40:05 UTC; the Drive copy is the durable off-site copy.
- Google Drive file: [Roshan-Production-Backup-2026-11-08.zip](https://drive.google.com/file/d/1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv/view?usp=drivesdk), ID `1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv`, parent folder [2026-11-09](https://drive.google.com/drive/folders/14q8YQbDddwzJ1tEyM0t8bK9f5ExRezF7). Drive metadata: 305,317 bytes, MD5 `875a85ac23e8b7a671c371cca41f7732`, not trashed.
- The encrypted bundle was transferred and its Drive metadata verified. Local PostgreSQL 17 restore rehearsal and critical row-count comparison passed. User-device decryption using the offline private age identity is still outstanding; do not claim complete end-user recovery until that test passes.
- Backup preflight found zero Storage objects and zero Vault secrets; three buckets were empty. The archive covers the database only, not Storage object bytes or Vault secret values.
- The one-time `SUPABASE_DB_PASSWORD` Actions secret was removed after the run and Drive verification. The workflow is manual, not recurring.
- No Production migration, DDL/DML, business-row mutation, permission change or application deployment was performed.

## 2. Current application and database release boundary

- Main application repository baseline remains `17eb097052019ec32a4ec18395a73c023ac4cc18` before this documentation PR.
- Production Supabase project `jewzonxplxhogqrnhosl`: latest migration `20261102232941`; PostgreSQL 17.6. QA `hopfohcnrtbiqjkgeukz`: latest migration `20261104065852`, including Phase 57; PostgreSQL 17.11.
- Production and QA migration ledgers intentionally differ in shape and count; source parity CI is not proof of live-ledger parity.
- Phase 57 remains QA-only. Production's dispensing function still has three NULL-to-one fallbacks. No Production migration was applied as part of this backup work.
- Canonical Vercel Production alias remains READY on app commit `6daf1f15be23aa391bd40bc38f671c00c842b446`; the current main docs-only commit is not deployed as application code.

## 3. Open PRs and acceptance limits

- [PR #189](https://github.com/crauch2088-source/roshan-health-hub/pull/189) remains Draft. It gates medicine identity edits through existing `pharmacy.update`; live role mapping includes admin, legacy_admin, legacy_super_admin, pharmacist and super_admin. The medicine catalogue is shared across branches (no `branch_id`); the physical-pack acknowledgement is not persisted as a dedicated audit attestation. Do not label products verified from that checkbox alone.
- [PR #191](https://github.com/crauch2088-source/roshan-health-hub/pull/191) remains Draft. Phase 57 is in QA; disposable PostgreSQL integration tests pass, but authenticated pharmacist acceptance in persistent QA has not been evidenced.
- Issue [#199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) remains the release-gate tracker. Remaining work: device-side decryptability test; QA authenticated pharmacist acceptance; physical A4/mobile/RTL/LTR checks; staff UAT across reception → GP → lab → pharmacy → billing; live-ledger reconciliation; and controlled Production Phase 57 release planning.

## 4. Explicit safety boundaries

- Do not upload or disclose the private age identity, database password, access token, plaintext dump, or decrypted SQL.
- Do not apply Phase 57 or other pending migrations to Production until the remaining acceptance gates and independent review pass.
- Do not treat a successful backup restore rehearsal as clinical UAT or production release authorization.
- No automatic recurring backup schedule is configured.
