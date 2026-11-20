# Roshan Health Hub — live release-gate recheck

**Observed:** 2026-11-16, approximately 06:40–06:46 UTC  
**Decision:** **Production NO-GO**  
**Scope:** read-only hosted Supabase/Vercel/backup checks plus source-only Draft PR work. No hosted DDL/DML/ACL/RLS/Auth/Storage changes, no real clinical/financial records, no backup dispatch, no merge, and no Production promotion.

## Repository and exact-head checks

- Current main: **79d81f08f6567f5145f7143e3bf5afdd6e93bf59** (docs-only commit).
- Open PRs: #258, #257, #256, #254, #250, #210, #181, #179, #157. Open Issues: #253, #218, #217, #199.
- Main check-runs on the current SHA: 6/6 success (Dependabot x2, CodeQL Python/JavaScript, PostgreSQL 17 invoice-payment idempotency concurrency, PostgreSQL 17 finance RPC-only writes). Main push/finance runs #43767368160 and #43767368557 succeeded. Dependabot run #43818318594 was still in progress at observation time.
- PR #258 is Draft and based on current main. Behavior/test commit: **a25680c01ef42f147704cde71daeabb1d226d58b**. Exact-head CI [#43818933478](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818933478) completed successfully: 20 jobs, 19 success, one intentional skip, zero failures. Phase 63 PostgreSQL 17 job **133137266910** passed; CodeQL [#43818926213](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818926213) passed; Vercel Preview Comments passed. The skipped canonical baseline/authenticated clinical acceptance is deferred, not a pass.
- PR #250 Phase 61C remains Draft at **c43c0258eb80760191b1b523128ddcb2c7537344** (base **f8c8b2d1767643561599764405b4cdbfd4db2c79**, behind current main). Its exact-head checks are 33 success plus one intentional clinical/baseline skip. Two COMMENTED review submissions are from the PR author; there are zero inline review threads and no independent second-person review. Do not apply Phase 61C to QA or Production.
- Main branch protection is disabled (protected=false; required status-check enforcement off). The repository connection has admin permission, but .github/workflows/ci.yml intentionally ignores docs/spec paths and Spec Kit validation covers only selected files. A global required CI context would leave some docs-only PRs without a run. Next governance task: add an always-running path-aware aggregate PR gate, then configure required CI, independent approval/last-push approval, stale-review dismissal, conversation resolution, and force-push/deletion protection. Do not weaken the clinical skip.

## Supabase migration ledger and live catalog

| Environment | PostgreSQL | Ledger rows | Latest migration |
|---|---:|---:|---|
| Production | 17.6 | 129 | 20261102232941_roshan_synthetic_patient_cleanup_and_stock_ledger_reversal |
| QA | 17.11 | 27 | 20261113232719_roshan_phase61b_clinical_role_boundary |

Only three version IDs overlap, and all three have different names/fingerprints:
- 20261102122437: QA Phase 51 setup-required vs Production superseded Phase 49 placeholder.
- 20261102133658: QA Phase 49 pharmacy vs Production superseded Phase 50 placeholder.
- 20261102133734: QA Phase 50 visit billing vs Production superseded Phase 51 placeholder.

QA-only versions: 24. Production-only versions: 126. Do not edit migration ledgers or replay mismatched history.

| Catalog metric | QA | Production |
|---|---:|---:|
| Public/private tables | 58 / 2 | 56 / 4 |
| Public/private columns | 873 / 13 | 842 / 24 |
| Public views | 5 | 5 |
| Public/private constraints | 242 / 3 | 215 / 7 |
| Public/private indexes | 255 / 3 | 249 / 5 |
| Public policies | 212 | 210 |
| Public triggers | 81 | 69 |
| Public/private functions | 101 / 56 | 96 / 47 |
| Public RLS / forced RLS tables | 58 / 46 | 56 / 44 |

## Pharmacy and role gates

- QA has Phase 57 20261104065852, Phase 57B 20261111215510, Phase 61 correction workflow 20261111223309, Phase 58 20261112061219, Phase 59 20261112061251, and Phase 61B 20261113232719.
- Production has none of those QA-only phase versions.
- Both prescription_items.quantity columns remain nullable. QA's private fn_dispense_prescription_with_invoice_unchecked has the explicit quantity-required guard, zero NULL-to-one fallbacks, and free-text/external-prescription checks. Production's public invoice-linked dispense function still has three COALESCE(pi.quantity, 1) fallbacks and no corresponding guards.
- QA's public atomic_pharmacy_dispense remains EXECUTE-accessible to authenticated/authenticator and its body has no role-helper marker; Production has the same exposed RPC boundary. Phase 61C is still only a Draft source candidate. QA's public invoice-linked wrapper uses the Phase 61B role helper, but that does not close the separate atomic-dispatch boundary.
- Active role aggregates: QA has one pharmacist and no active legacy_pharmacist; Production has one pharmacist and no active legacy_pharmacist. No compatibility permissions were granted.
- Phase 55 private helper ACL correction and Phase 58/59 currency provenance remain QA/Production gaps.

## Supabase advisors

| Advisor | QA | Production |
|---|---:|---:|
| Security findings | 34 | 31 |
| Performance findings | 147 (7 unindexed FKs, 140 unused indexes) | 95 (2 unindexed FKs, 93 unused indexes) |
| Health findings | 0 | 0 |

Security findings include exposed SECURITY DEFINER RPC warnings, setup_required(), public pg_trgm, private idempotency tables with RLS/no policy, and leaked-password protection disabled. These are triage leads; do not blanket-revoke functions or delete indexes.

## Vercel

- Latest Production attempt for current main SHA: **dpl_AzLPKkaMZU7NgR2Gz8Z5ZYGU6NAA** — CANCELED.
- Latest READY Production deployment: **dpl_G9jScsLW3jDXFePVZLQgedwMMKRH**, application SHA **a9040601702972bdf144fc96b9658eebd5a6d31a**. Canonical alias **roshan-health-hub.vercel.app** is present; aliasError=null.
- Preview **dpl_8yvjoCSL1BdJW7y2stCHQ5iMraWx** is READY on PR #258 predecessor SHA **b97a6f8dc609973e3a02b715bb2eceb4962de05e**, target null. It is not Production and does not represent the new code commit a25680c.

## Backup and recovery

- Backup-runner main: **f171732b61fe0460c61a36aa63b861065f9ea9d1**.
- Latest manual backup run [#43764265014](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43764265014) failed at Production credential preflight because SUPABASE_DB_ACCESS_TOKEN and SUPABASE_DB_PASSWORD were unavailable; backup job was skipped and no artifact was produced.
- Latest full successful backup/restore run [#43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) ran on runner SHA **eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8**; PostgreSQL 17 dump, isolated restore, integrity comparison, age encryption and ciphertext-only upload all passed. Its GitHub artifact is no longer listed.
- The retained off-site Drive archive is present and not trashed: [roshan-production-backup-43183851731.zip](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view?usp=drivesdk), 305,284 bytes, MD5 **22271054f6c10b1baf1d23ac4bdac24e**, in folder 2026-11-12. Runner-side isolated restore passed; owner-side decryption of this latest artifact remains unverified. Archive scope is PostgreSQL only, not Storage object bytes or Vault secrets.

## Release decision and next work

**Production NO-GO.** Blocking gates: migration/source reconciliation; Production Phase 55/57/57B/58/59 and reviewed 61B/61C sequence; owner-supplied backup credentials plus fresh backup and owner-side decryption/restore verification; independent SQL/security review; required merge-gate enforcement; and clinical/pharmacy, reception-to-billing, mobile RTL/LTR and physical A4 acceptance. Clinical E2E remains explicitly deferred until an isolated free test environment and suitable synthetic doctor/pharmacist identities exist.

Next highest-value task: obtain independent review of PR #250 and PR #258; in parallel, implement the always-running path-aware merge-gate workflow needed before enabling main branch protection. Do not merge, apply Production migrations, or promote deployments.

Evidence-weighted readiness remains **62% Engineering Release Candidate / 15% Operational Acceptance**. No percentage increase is claimed. Prior ETA of 2–3 focused engineering days plus 1–2 weeks of staged acceptance is conditional only; the missing backup credential and independent reviewers prevent a reliable calendar commitment.
