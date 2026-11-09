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


## Live Supabase catalog and security recheck — 2026-11-09 08:53 Africa/Khartoum

Read-only catalog and advisor queries were run directly against both connected PostgreSQL 17 projects. No application rows were selected or modified.

### Live migration and schema parity

| Measure | Production | QA |
|---|---:|---:|
| Applied migrations | 129 | 22 |
| Latest migration | `20261102232941` | `20261104065852` |
| Public base tables | 56 | 56 |
| Public columns | 842 | 842 |
| Public tables with RLS enabled | 56 | 56 |
| Public RLS tables without any policy | 0 | 0 |
| Public SECURITY DEFINER functions | 53 | 55 |
| SECURITY DEFINER callable by anon | 1 | 1 |
| SECURITY DEFINER callable by authenticated | 26 | 28 |

The two QA-only authenticated SECURITY DEFINER RPCs observed in the catalog are `get_invoice_payment_receipt_status(uuid[])` and `reverse_invoice_payment(uuid,text)`, consistent with QA's Phase 54C migration and Production's older migration head. This does not mean the environments are schema-identical: live migration ledgers remain different and require source-level reconciliation before rollout.

### Security advisor interpretation

- Both environments report one anonymous SECURITY DEFINER function: `public.setup_required()`. Its implementation delegates to `private.setup_required()`, which returns only whether `public.users` is empty. This is the intentionally public first-run setup signal; retain it only while that onboarding contract remains required and continue testing that it reveals no user or clinic data.
- Supabase flags authenticated-executable SECURITY DEFINER RPCs (26 Production, 28 QA). This is an exposure warning, not proof that each function is exploitable: these are intended API RPCs and require per-function review of actor identity, permission checks, branch constraints, fixed search_path, and object qualification. The sampled `atomic_pharmacy_dispense`, `get_invoice_payment_receipt_status`, and `reverse_invoice_payment` definitions use an empty search_path and explicit application permission/branch checks. Do not blanket-revoke authenticated EXECUTE or switch these RPCs to SECURITY INVOKER without dependency and authorization testing.
- The internal `private.pharmacy_dispense_idempotency` table has RLS enabled and no policies in both environments; direct table privileges for anon/authenticated/service_role were absent in the read-only check. The Production legacy idempotency table is also ungranted. This is consistent with access only through the owning SECURITY DEFINER RPC; preserve the private schema boundary and verify it in future grants tests.
- Both environments report `pg_trgm` installed in `public` (advisor warning), and leaked-password protection disabled (Auth warning). Moving the extension requires dependency/rebuild analysis; enabling leaked-password protection is an Auth configuration decision. Neither was changed.
- Performance advisors report unused-index informational findings (95 Production, 143 QA) and two unindexed foreign keys on the legacy Production idempotency table. These counts are not a license to drop indexes on an idle/new clinic; require workload evidence and query plans first.

### Release consequence

The live catalog confirms RLS is enabled on all 56 public base tables in both environments and no public RLS-enabled table lacks a policy. It does not establish that every policy is semantically correct or every SECURITY DEFINER function has safe authorization. Keep the function-by-function audit and live migration reconciliation open. No migration, grant, Auth setting, extension, index, or business-data change was performed.


### Receipt-currency schema confirmation — 2026-11-09

A direct read-only QA schema query confirmed that `public.payments`, `public.invoices`, and `public.cashbox_transactions` currently have no currency-code column. The receipt's current-currency source is therefore not backed by transaction-level currency provenance. This confirms the PR #181 historical-relabeling risk is a schema/read-model gap, not just a display formatting concern. No row values were read. Keep the owner policy decision and historical regression test open; do not add a guessed default currency or relabel existing amounts.
