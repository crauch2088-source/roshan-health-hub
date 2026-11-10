# Parallel engineering review — 2026-11-10

**Purpose:** record the results of a cross-workstream review and fresh read-only environment checks. This report does not authorize hosted changes.

## 1. Exact-head GitHub evidence

| Workstream | Candidate | Exact head checked | GitHub Actions | Interpretation |
|---|---|---|---|---|
| Pharmacy dispensing | PR #209 | `48fc38e867e6f1387881862e9ab806b93cda6c9c` | 5/5 workflows successful | Quantity and external-prescription guard candidate passes automated CI; free-text/unlinked prescription correction remains open in Issue #217 |
| Medicine catalogue | PR #210 | `7e64287d754f737e9e82a05e27279ccecf90c595` | Current follow-up head; no PR-triggered workflow run is visible through the connected GitHub status endpoint at review time | Previous head `324a2cb479380aab58e81bad1e695e998852e20d` passed 5/5 workflows. A stale pack-confirmation state was found and corrected; do not credit the new fix until exact-head CI passes |
| SDG provenance and receipt integrity | PR #211 | `2b0e35bb2bbff585f4a9942709bc39f842d5855e` | 10/10 workflows successful | Phase 58/59 candidate checks pass, including PostgreSQL 17, finance-only RPC isolation, security bundle, historical-source checks and Spec Kit |
| Receipt UI | PR #181 | `00f09d956c0632d6e193e4864bdb0401b092b09a` | 8/8 workflows successful | UI candidate checks pass; it depends on Phase 58/59's v2 receipt-status RPC and persisted currency provenance; real browser/mobile and physical printer acceptance remain open |
| Sprint evidence ledger | PR #215 | `8f0e3073aa222d25197354c4ab7d780df91986d8` | CI successful; PR merged | H0/48-hour charter evidence is now part of main |

Vercel preview status on PR #210 and #211 reports the free-plan build-rate limit. This is a preview-capacity issue, not a GitHub Actions failure. Avoid nonessential preview-triggering commits.

## 2. New catalogue UX defect found and corrected

Independent review of PR #210 found that the pack-inspection checkbox could remain selected after the pharmacist changed the medicine's identity fields. That allowed stale UI confirmation to survive an identity edit.

- Added a regression assertion to `tests/inventory-receive-rpc.test.ts`.
- Changed `updateIdentityField` in `src/routes/_authenticated/inventory.tsx` to clear `packInspectionConfirmed` on every identity edit.
- Exact follow-up head: `7e64287d754f737e9e82a05e27279ccecf90c595`. The regression assertion was refined to capture the complete block-bodied handler rather than stopping at its first statement.
- PR #210 remains Draft pending exact-head CI and independent review.
- The database verification RPC still captures the saved identity snapshot under row lock; this UI fix does not weaken or replace the server-side attestation.

## 3. Fresh read-only Production/QA verification

A fresh direct SELECT-only check was run against Production project `jewzonxplxhogqrnhosl` and QA project `hopfohcnrtbiqjkgeukz`.

| Check | Production | QA |
|---|---:|---:|
| Migration ledger rows | 129 | 22 |
| Latest migration version | `20261102232941` | `20261104065852` |
| Currency-provenance columns on the seven Phase 58 financial tables | 0 | 0 |
| Dispensing function contains normalized `COALESCE(pi.quantity,1)` fallback | Yes | No |
| Dispensing function contains explicit `pi.quantity IS NULL` rejection | No | Yes |

This confirms the Phase 58/59 currency migrations remain candidate-only in both hosted environments. It also confirms Phase 57's quantity guard is present in QA but not Production. Production still contains the unsafe NULL-to-one dispensing fallback. The first whitespace-sensitive check was inconclusive; a normalized function-definition check then confirmed the results shown above.

**Release consequence:** no Production dispensing rollout, financial receipt release, migration replay, or ledger repair is authorized. Do not infer historic currency from settings and do not backfill legacy NULL values without evidence and a separate approved reconciliation plan.

## 4. Cross-workstream review findings

### Pharmacy
- PR #209 rejects invalid/missing quantities and external prescriptions before stock/invoice mutation.
- Unlinked/free-text items still fail closed. Issue #217 defines the required pharmacist-to-prescriber correction loop; do not fuzzy-link, silently drop, partially dispense or invoice those items.
- QA pharmacist acceptance is not yet evidenced.

### Shared medicine catalogue
- PR #210 separates identity editing from physical-pack attestation.
- Identity edit permission is Admin + Pharmacist + Super Admin; physical-pack attestation is Pharmacist + Super Admin.
- Catalogue is shared across branches; a change affects all branches.
- Medicine creation remains governed separately by `pharmacy.create`.
- The follow-up stale-confirmation regression fix is pending exact-head validation.

### SDG finance and receipts
- PR #211 makes new financial records SDG-only with immutable transaction provenance and preserves historical NULLs rather than guessing.
- Phase 59 redacts mismatched ledger/reversal metadata and requires persisted payment, invoice, cashbox and reversal currency agreement.
- PR #181's UI is not independently releasable ahead of the Phase 58/59 dependency.
- Insurance claim payments remain explicitly deferred until their own persisted-currency source workflow exists.

### Migration and security
- Production and QA migration ledgers remain materially divergent. Counts and latest versions are not proof of source parity.
- Existing source-parity CI verifies a frozen source set and forward delta; it does not prove the live 129/22 ledgers have been reconciled.
- Keep per-function ACL/search_path review; do not mass-revoke intended SECURITY DEFINER RPCs.
- No hosted database writes were made in this review.

### Mobile, bilingual UX and printing
- Automated receipt/print model and UI checks are present in PR #181.
- The test suite does not substitute for actual Android/browser, A4/thermal printer, Arabic RTL/English LTR and staff acceptance.
- No physical printer acceptance is claimed.

### Backup and recovery
- Previously recorded encrypted DB dump/PG17 restore and owner-side decryption evidence remain useful.
- The latest helper run was validation-only; a full backup/restore using the current main checksum helper remains unverified.
- Storage objects and Vault secrets are outside the database archive; end-to-end recovery coverage remains incomplete.
- No backup was dispatched in this review.

## 5. Updated execution order

1. Obtain exact-head CI for PR #210's follow-up fix; keep it Draft until it passes.
2. Complete independent SQL/security review of PR #209, #210 and #211.
3. Finish the live migration source-to-ledger and effective-catalog mapping; preserve both hosted environments unchanged.
4. Verify PR #181 against the Phase 58/59 contract in isolated QA; retain legacy NULL/mismatch fail-closed behavior.
5. Complete the actionable Issue #217 prescriber correction workflow and its PostgreSQL 17 negative/positive cases.
6. Run authenticated doctor/pharmacist/finance acceptance, Android/browser journeys and physical print tests.
7. Re-run the current backup helper end-to-end, including explicit Storage/Vault scope, then document recovery and rollback evidence.

## 6. Progress accounting

- **Engineering RC:** 49% (weighted, evidence-based). The new PR #210 fix is not credited until exact-head validation; the workstream score is therefore unchanged.
- **Operational acceptance:** 11% (separate denominator). No new staff, authenticated clinical/finance, device or physical printer sign-off was obtained.
- **Estimated Engineering RC time remaining:** 24–40 hours, conditional on migration-source reconciliation and independent reviews.
- **Operational acceptance:** likely 1–3 weeks after Engineering RC, depending on real staff/device availability.

These percentages measure the accelerated sprint's launch-critical Engineering RC scope, not the percentage of all product features and not clinical launch readiness.

## Safety record

All fresh Supabase operations in this review were SELECT/catalog-definition reads. No Production or QA DDL/DML, migration application, business-data write, Auth/Storage mutation, permission change, deployment promotion or backup dispatch occurred. All candidate PRs remain Draft unless separately noted (#215 merged).


## 7. Backup-runner hardening and destination correction

A read-only review of the private backup-runner repository found that its README still directed the encrypted artifact to the legacy empty Drive folder `Roshan Health Hub Backups`, despite the canonical destination being `Roshan Health Hub - Encrypted Backups`. The README was corrected and now explicitly warns against the legacy folder.

The same review found the shell runner unconditionally exported `PGOPTIONS=-c jit=true` for both temporary-token and database-password connections, while the URL builder and README specify that the JIT connection option belongs only to temporary-token mode. The shell-level override was removed so the credential-specific URL builder remains the single source of connection-option behavior. Added `tests/test_backup_connection_options.py` covering token JIT option, password fallback without JIT, ambiguous-credential rejection and absence of a shell-level override.

Backup-runner commits: README destination correction `342e6fe7b2b5ea83f300324699d01e344eb176ef`; regression test `8cefd20a6876ac56ae6c56feea9f549ba2480408`; shell fix `7a3409ad84b4394014aeff36431a95a69813b90d`. Static source inspection confirms the shell no longer sets PGOPTIONS and the URL builder still adds JIT only when the temporary token is supplied. **The new Python tests have not yet been executed in a fresh workflow run**, and no backup was dispatched. The Production backup remains database-only; Storage object bytes and Vault secrets remain separate recovery scope.
