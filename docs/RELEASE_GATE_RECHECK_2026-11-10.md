# Release-gate recheck — 2026-11-10

Audit time: 2026-11-10 06:42 UTC
Scope: repository main/PRs/checks, Production and QA Supabase ledgers and catalogs, Supabase advisors, Vercel production deployments/aliases, private backup runner, and the existing private Drive backup location.

This was a read-only operational audit. No hosted database writes, DDL/DML, privilege changes, Auth/Storage mutations, backup dispatch, Drive writes, deployment promotion, merge, or clinical/financial record creation occurred. Repository documentation was prepared separately in a Draft PR. No secret values, patient rows, clinical notes, or financial rows were read.

## 1. Repository and checks

- Main SHA: 969074279a4cc7c06db1c320e311b72a5b7003ac — ci: update pinned Spec Kit workflow actions.
- Exact-main check runs: 23 success, 1 skipped, 0 failures.
  - CI 42577899480: 18 success; the authenticated clinical-acceptance job was skipped by its explicit readiness gate.
  - Finance-only PostgreSQL integration 42577899543: 2/2 success.
  - CodeQL 42577899119: JavaScript/TypeScript and Python analyses succeeded.
  - Spec Kit validation 42577899611: success.
- Open PRs: 10 — #211, #210, #209, #208, #207, #185, #181, #179, #157 and #112. Open non-PR issue: #199.
- Current work of highest release relevance:
  - PR #211, Phase 58/59 SDG financial provenance, Draft, head 36c7d404c4c32a79d63de093ddd1bba68a11607d. Exact-head checks: 40 success, 1 intentional clinical-acceptance skip, 0 failures. Phase 58 and Phase 59 PostgreSQL 17 jobs passed in CI run 42631066313; supporting PG17 integration runs include 42631066304 and 42631066395; CodeQL analysis 129207477859 succeeded. This is candidate code only, not hosted QA/Production state.
  - PR #209, rebased Phase 57 pharmacy quantity guard, Draft, head 5c07ad63b4c7b302175bc61b9737c34457678142. No authenticated pharmacist acceptance is claimed.
  - PR #181, receipt printing, Draft, head 00f09d956c0632d6e193e4864bdb0401b092b09a; its read path now depends on Phase 58 columns and get_invoice_payment_receipt_status_v2(uuid[]) from PR #211. Keep #181 behind #211 and revalidate it after the dependency is integrated.
  - PR #210 medicine catalogue identity correction remains Draft. #208 and #207 are documentation candidates. #179 remains a separate saved-prescription printing candidate.
- The GitHub branch-protection endpoint returned HTTP 403 Resource not accessible by integration; branch protection/required-check enforcement is unverified in this run. Do not infer its state from the API denial.

## 2. Live Supabase migration ledgers and parity

Both projects are ACTIVE_HEALTHY.

| Environment | PostgreSQL | Ledger rows | Latest migration |
|---|---:|---:|---|
| Production jewzonxplxhogqrnhosl | 17.6.1.155 | 129 | 20261102232941 roshan_synthetic_patient_cleanup_and_stock_ledger_reversal |
| QA hopfohcnrtbiqjkgeukz | 17.11.0.003 | 22 | 20261104065852 roshan_phase57_pharmacy_quantity_required_guard |

The live ledgers are not equal: 3 version IDs are shared, and all 3 shared IDs have different migration names; Production has 126 Production-only rows and QA has 19 QA-only rows. The shared-ID mismatches are:

- 20261102122437: Production placeholder for Phase 49; QA Phase 51.
- 20261102133658: Production placeholder for Phase 50; QA Phase 49.
- 20261102133734: Production placeholder for Phase 51; QA Phase 50.

Phase 50 and Phase 52 also have matching serialized statement content under different version IDs in the detailed reconciliation report. This is not a safe basis for manually inserting ledger rows or replaying historical migrations. Source/effective-catalog reconciliation remains open; CI migration-source parity is not proof of live-ledger parity. See docs/LIVE_MIGRATION_LEDGER_RECONCILIATION_2026-11-09.md.

### Phase 57 pharmacy quantity guard

A fresh read-only query of the live dispensing function and ledger confirmed:

| Check | Production | QA |
|---|---:|---:|
| Phase 57 migration 20261104065852 | absent | applied |
| Explicit pi.quantity IS NULL rejection | absent | present |
| COALESCE(pi.quantity,1) fallbacks | 3 | 0 |
| prescription_items.quantity nullable | YES | YES |
| Active non-deleted NULL-quantity items | 0 | 0 |

Production still has the future-risk NULL-to-one fallback. Zero current affected items does not remove the defect. Do not apply Phase 57 to Production before source reconciliation and the separately approved release gate.

### Phase 58/59 candidate status

Read-only catalog checks confirmed that all seven proposed Phase 58 currency_code columns are absent in both projects (0/7 present in each), and Phase 59 get_invoice_payment_receipt_status_v2(uuid[]) is absent in both. The Phase 58/59 code and disposable PostgreSQL 17 tests are in Draft PR #211 only. No hosted migration or backfill has occurred. Existing historical currency must not be inferred from mutable settings.

## 3. Supabase advisors

Observed 2026-11-10:

| Advisor | Production | QA |
|---|---:|---:|
| Health findings | 0 | 0 |
| Security finding groups | 5 | 5 |
| Performance findings | 96 | 142 |

Security group details:
- Production: 2 private RLS-enabled tables without policies (INFO; direct access intentionally denied), 1 public-schema pg_trgm extension (WARN), 1 anon-executable SECURITY DEFINER setup_required() (WARN; boolean-only bootstrap contract), 26 authenticated-executable SECURITY DEFINER RPCs (WARN), and leaked-password protection disabled (WARN).
- QA: 1 private RLS-enabled table without policies (INFO), the same extension and anon setup RPC warnings, 28 authenticated-executable SECURITY DEFINER RPCs, and leaked-password protection disabled.
- Performance: Production has 94 unused-index INFO findings and 2 unindexed-FK INFO findings on the quarantined legacy idempotency table; QA has 142 unused-index INFO findings.

These are triage findings, not permission to mass-revoke intended RPCs, change Auth settings, or drop indexes. No advisor remediation was applied.

## 4. Vercel production deployment and alias

- Current-main documentation-only deployment: dpl_GbuBeUsyKShUzAgGKSQq2MxfKkgK, state CANCELED, source SHA 969074279a4cc7c06db1c320e311b72a5b7003ac. The cancellation is consistent with the Ignore Build Step for non-runtime documentation/CI changes.
- Latest READY Production deployment: dpl_E5m6Z8CLf3uaFRwt1dAxiRMpADPv, app SHA 6daf1f15be23aa391bd40bc38f671c00c842b446.
- Canonical alias roshan-health-hub.vercel.app remains attached to that READY deployment; aliasError=null.
- The READY app SHA is older than current main, whose intervening changes are documentation/CI/spec changes. READY and alias attachment do not establish authenticated workflow, printer, or staff acceptance.

## 5. Backup runner and encrypted off-site artifact

- Private runner main: ed41574bb278325e7bc06fd034e767db1544c55a; it includes the portable relative SHA-256 manifest helper.
- Latest workflow overall 42537677251, branch fix/portable-backup-checksum-20261109, head bca6eeed81b5b76f6cac0312fd370651cdfde20c: workflow conclusion success, validate succeeded, but backup was skipped and no GitHub artifact was produced. This is validation only, not a backup.
- Latest completed full backup 42535939237, branch feat/backup-db-password-fallback, head 713ee4edf47429df9e02c475e5909e4c4f62a744: both validate and backup jobs succeeded. The backup job completed PostgreSQL 17 dump, isolated local restore rehearsal, critical table-count comparison, age encryption, and ciphertext-only artifact upload. GitHub artifact 13639676572 expired at 2026-11-09 23:40 UTC; the durable Drive copy remains.
- Existing Drive file Roshan-Production-Backup-2026-11-08.zip is present, not trashed, owned by the connected account, and 305,317 bytes (MD5 875a85ac23e8b7a671c371cca41f7732).
- Verified parent chain: private folder Roshan Health Hub - Encrypted Backups → dated folder 2026-11-09 → encrypted backup file. A separate legacy folder named Roshan Health Hub Backups is empty and is not the actual destination.
- The prior successful backup's encrypted archive SHA-256 was 3b3df1aa9056c70a0d6c9fc40f98a5ba6f23e4889040c24ec8f3302f270df355; the owner also verified the inner encrypted file on Android/Termux, decrypted it with the locally held age identity, confirmed archive readability, and removed temporary plaintext. Inner archive SHA-256: 64a346c48d5db96fc4c28bd99bb60c38802f223de4938d43c2d8137fee0ffef1.
- This backup is database-only. At snapshot time Storage objects and Vault secrets were zero; Storage object bytes and Vault secret material are not included. No recurring backup schedule is configured.
- The current runner checksum helper passed its validation/unit-test job, but the latest workflow skipped the full backup. A fresh full backup on the current main helper is therefore unverified. No backup dispatch or external write was performed in this audit.
- Runner README destination correction is in Draft backup-runner PR #4, commit 56b458f4c1f2a4cc7380eaa70df11d36c0190f67.

## 6. Release-gate matrix

| Gate | State | Evidence / blocker |
|---|---|---|
| Main CI and CodeQL | Complete with explicit skip | 23 success, 1 clinical-acceptance skip, 0 failures |
| Migration-source CI contract | Passed | Main CI migration-source job succeeded |
| Live Production/QA migration source reconciliation | Incomplete | 3 shared version IDs all mismatched; 126/19 environment-only rows |
| Phase 57 in QA | Applied | 20261104065852; explicit NULL guard present |
| Phase 57 in Production | Blocked | Missing migration; three NULL-to-one fallbacks remain |
| Phase 58/59 in hosted QA/Production | Not applied | 0/7 columns and v2 RPC absent in both |
| Supabase Health advisors | Clear | 0 findings in each project |
| Supabase Security/Performance | Open findings | Triage findings above; no blanket remediation |
| Vercel canonical alias | READY | Alias attached to dpl_E5m6Z8CLf3uaFRwt1dAxiRMpADPv, no alias error |
| Existing encrypted off-site backup | Complete for 2026-11-08 snapshot | Private Drive artifact exists and owner-device decryptability verified |
| Isolated PostgreSQL 17 restore rehearsal | Passed for 2026-11-08 snapshot | Run 42535939237 restore and count comparison succeeded |
| Full backup using latest checksum helper | Unverified | Latest run 42537677251 skipped the backup job |
| Authenticated doctor/pharmacist acceptance | Deferred | User requested deferral until free isolated QA and suitable synthetic identities exist |
| Staff UAT / A4 / Android printer | Not accepted | No staff or physical-device acceptance evidence |
| Main branch protection | Unverified | GitHub branch-protection endpoint denied access (403) |

## 7. Next highest-value task

1. Complete the canonical source/effective-catalog reconciliation for all live Production/QA ledger entries, including placeholder, duplicate, quarantined, recovered, and version-remapped migrations. Update the manifest and applied inventory only after each mapping is supported by exact source/fingerprint evidence; do not force the two live ledgers to be identical or manually insert ledger rows.
2. Independently review Phase 58/59 SQL, ACLs, source-ledger links, and receipt fail-closed behavior in PR #211. Keep it Draft until review is complete. Revalidate PR #181 only after its Phase 58/59 dependency is integrated.
3. Keep Phase 57 in QA and PR #209 Draft until the authorized synthetic pharmacist path is available; Production remains untouched.
4. When a new backup is explicitly authorized, run the current main runner with its checksum helper and verify artifact, Drive copy, checksum, isolated restore, and owner-device decryptability. Do not dispatch automatically.
5. Keep clinical E2E deferred until the free isolated environment and suitable synthetic doctor/pharmacist identities are available; staff UAT and physical A4/Android printing remain separate acceptance gates.

No hosted database, permissions, patient/clinical/financial data, Drive files, or Vercel deployments were changed during this audit.
