# Release-gate recheck — 2026-11-09

Audit update: 2026-11-09 (Africa/Khartoum). This document records the evidence that arrived after the 2026-11-08 read-only audit. The 2026-11-08 report remains a historical snapshot; its backup statements were accurate at that earlier time and are superseded below.


## Superseding verification — 2026-11-09 08:44 Africa/Khartoum

This update supersedes the earlier statements below that device-side decryptability remained outstanding. Those statements are retained as historical snapshots and are no longer the current status.

### Backup and recovery: passed

- Private backup-runner PR #2 is merged. Workflow [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237) passed PostgreSQL 17 dump, isolated restore rehearsal, critical row-count comparison, age encryption, and ciphertext-only artifact upload.
- The encrypted bundle is stored in the private Drive copy [Roshan-Production-Backup-2026-11-08.zip](https://drive.google.com/file/d/1_r9tfQc-ZufN_7Ys0f9LIpOA3CoaYDlv/view?usp=drivesdk). The owner independently verified the payload checksum on Android/Termux, decrypted it using the offline identity, confirmed gzip/tar readability, and deleted the temporary plaintext archive.
- This closes both the runner-side isolated restore rehearsal and the owner-device decryption/archive-readability sub-gate. It is not a second PostgreSQL import on Android.
- The archive contains the database only. At backup time there were zero Storage objects, zero Vault secrets, and three empty buckets. Backups remain manual; no recurring schedule is configured.
- The private age identity, database credentials, plaintext dump, and decrypted SQL were not committed or shared.

### Current code and acceptance state

- PR #201 (device-side recovery evidence) and PR #202 (engineering acceleration review) are merged.
- PR #191 remains Draft at code head `44cf17f09e528390a074debff464aa4fb894bc95`. Its exact-head CI is recorded as 18 successful jobs, zero failures, and one intentional skip for authenticated clinical acceptance. Phase 57 is applied to QA only; persistent-QA pharmacist acceptance and independent review remain open.
- PR #189 remains Draft at code head `3df3d3af7e20def9b509402996169ad668c5c9c3`. Its exact-head CI is recorded as 18 successful jobs, zero failures, and one intentional authenticated clinical-acceptance skip. Permission scope, global catalogue semantics, and durable pack-verification evidence remain unresolved.
- PR #179 (saved-prescription printing) and PR #181 (persisted-payment receipts) remain Draft. Automated tests do not substitute for browser/Android print preview, role/branch E2E, physical printer checks, or staff acceptance.
- Production Supabase remains on migration `20261102232941`; QA remains on `20261104065852` with Phase 57 applied in QA only. The live ledgers are not yet reconciled. No Production migration or application data write was performed by the backup/recovery work.
- Issue [#199](https://github.com/crauch2088-source/roshan-health-hub/issues/199) remains the canonical release-gate tracker.

### Remaining gates

1. Obtain an authorized synthetic QA pharmacist sign-in path and complete the Phase 57 pharmacist acceptance scenario in persistent QA.
2. Complete independent review of PR #191 and resolve the PR #189 role-scope/catalogue/audit decisions.
3. Complete authenticated role/branch E2E and staff UAT for reception → GP → lab → pharmacy → billing.
4. Complete Arabic RTL / English LTR browser print-preview and Android/mobile checks; verify A4 on actual hardware and defer thermal claims until the target printer/browser is tested.
5. Reconcile Production and QA migration ledgers to canonical source before planning any Production rollout.

**Release boundary:** successful backup and recovery do not authorize Production Phase 57, Phase 54C promotion, production DDL/DML, permission changes, deployment promotion, or clinical launch. No production business data is to be used for acceptance testing.


## Live operational release-gate recheck — 2026-11-09 08:46 Africa/Khartoum

This is the latest read-only snapshot and supersedes earlier current-state summaries in this file. Historical sections below are retained for audit chronology.

### Repository and CI
- Main `cc2d59912144e1ebaa7497ce05c0dcf7b1f8422c`; CI [42541355920](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42541355920) passed 18 jobs with one intentional authenticated clinical-acceptance skip; finance-only integration [42541355913](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42541355913) passed 2/2.
- PR #203 pre-refresh head `55d5513497c2c1f5269cccce859c2af4adeed6ef`: CI [42575154783](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42575154783) passed 18 jobs with one intentional clinical skip; Spec Kit validation [42575154876](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42575154876) passed; CodeQL [42575151638](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42575151638) passed both analyses. These checks predate this documentation refresh.
- Eight open PRs: #203, #157, #191, #189, #185, #179, #181, #112. Open release tracker: [Issue #199](https://github.com/crauch2088-source/roshan-health-hub/issues/199). PRs #191 and #189 are each four commits behind main and remain Draft.

### Supabase
- Production: 129 migrations, latest `20261102232941`, PostgreSQL 17.6. QA: 22 migrations, latest `20261104065852`, PostgreSQL 17.11. The live ledgers are not identical; source-parity CI is not live-ledger reconciliation.
- Phase 57 (`20261104065852_roshan_phase57_pharmacy_quantity_required_guard`) is QA-only. QA explicitly rejects NULL prescription quantity and has no NULL-to-one fallback. Production retains three `COALESCE(pi.quantity,1)` fallbacks. Both projects currently have zero active non-deleted NULL-quantity prescription items; the quantity column remains nullable.
- Health advisors: zero findings in both projects. Security findings: Production—2 private RLS-without-policy INFO, 1 `pg_trgm`-in-public WARN, 1 anon-callable SECURITY DEFINER `setup_required()` WARN, 26 authenticated-callable SECURITY DEFINER WARN, 1 leaked-password-protection WARN. QA—1 private RLS-without-policy INFO, the same extension/anon/password warnings, and 28 authenticated-callable SECURITY DEFINER WARN. Performance: Production—95 unused-index INFO and 2 unindexed foreign keys on the legacy private idempotency table; QA—143 unused-index INFO. No broad privilege or index changes are justified by these advisory counts alone.

### Deployment
- READY Production deployment: [`dpl_E5m6Z8CLf3uaFRwt1dAxiRMpADPv`](https://vercel.com/roshan45/roshan-health-hub/E5m6Z8CLf3uaFRwt1dAxiRMpADPv), application SHA `6daf1f15be23aa391bd40bc38f671c00c842b446`, canonical alias `roshan-health-hub.vercel.app`, `aliasError=null`.
- Main is 10 commits ahead and zero behind that deployment; the delta consists of workflow/documentation files, with no application source changes. The latest main documentation deployment `dpl_F1BMSx6ff5BYx2A6kFcSps4htVjG` was CANCELED by the expected ignore-build path.

### Backup and recovery
- Backup-runner main: `ed41574bb278325e7bc06fd034e767db1544c55a`; PR #2 merged at `07ca69125da7cc702f9306da55cccf4916146b2f`.
- Latest workflow [42537677251](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42537677251) ran on `fix/portable-backup-checksum-20261109` at `bca6eeed81b5b76f6cac0312fd370651cdfde20c`: validation passed, backup was skipped, and no artifact was produced. It is not a completed backup.
- Latest full successful backup remains [42535939237](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237): PostgreSQL 17 dump, isolated restore rehearsal, critical row-count comparison, age encryption and ciphertext-only upload all passed. Artifact [13639676572](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/42535939237) was 305,317 bytes, SHA-256 `3b3df1aa9056c70a0d6c9fc40f98a5ba6f23e4889040c24ec8f3302f270df355`; the artifact was not expired at 06:47 UTC and expires at 23:40:05 UTC. The Drive copy was re-verified at 06:47 UTC: 305,317 bytes, MD5 `875a85ac23e8b7a671c371cca41f7732`, not trashed, owned by the connected account.
- The owner-device inner-payload SHA-256 matched the manifest; age decryption and gzip/tar listing succeeded; temporary plaintext was removed. Backup is manual, with no recurring schedule. It covers PostgreSQL only; Storage object bytes and Vault secret values were absent at backup time and are not included.

### Gate result and next task
- Passed: encrypted off-site database backup, runner-side PostgreSQL 17 restore rehearsal and row-count comparison, owner-device decryption/archive check, current main CI, PR #203 pre-refresh CI/CodeQL/Spec Kit checks, canonical Vercel alias, and zero health-advisor findings.
- Blocked/unverified: live Production/QA migration-to-source reconciliation, Production Phase 57, authenticated QA pharmacist acceptance, authenticated doctor/pharmacy clinical E2E, staff UAT, and physical A4/mobile/RTL/LTR printer acceptance. Clinical E2E remains deferred until a suitable isolated free environment and synthetic doctor/pharmacist identities are available.
- Next: perform a read-only, version-by-version comparison of both live ledgers with the canonical migration manifest and source files, classify intentional QA baseline/QA-only entries, and prepare a reviewed Production rollout sequence. Do not apply Production DDL/DML or change privileges in that task.

No Production or QA writes, migrations, privilege changes, backup dispatches, merges or deployments were performed during this recheck.

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
