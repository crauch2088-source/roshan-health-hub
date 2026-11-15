# Roshan Health Hub — Live Project State

Snapshot: 2026-11-15 06:55 UTC. This is a cache, not authority over live GitHub, Supabase or Vercel. Refresh the underlying service before every write.

## GitHub and CI

- Repository: crauch2088-source/roshan-health-hub
- Main: f8c8b2d1767643561599764405b4cdbfd4db2c79
- Open PRs: 5. Priority PRs: #250 Phase 61C security boundary (Draft), #210 Phase 60 catalogue identity/pack attestation (Draft), #181 receipt compatibility (Draft).
- Open issues: #199 backup/recovery and acceptance; #217 pharmacist-to-prescriber correction workflow; #218 Phase 55 private-helper ACL divergence.
- Main current-head runs: Finance-only RPC isolation 43644032032 PASS; CodeQL push run 43644032038 PASS. Latest full CI 43527161767 passed on previous application SHA a9040601702972bdf144fc96b9658eebd5a6d31a. The current main commit is documentation-only; do not claim full CI on f8c8b2d.

### Critical Phase 61C — PR #250

- Branch: fix/phase61c-atomic-dispense-role-boundary-20261114
- Code/test head: f3a81b0ef8b110127433b828e75c2d92909e9e73; Draft, mergeable.
- Exact-head CI 43686671277: 18 successful jobs, one intentional skip for canonical PG17 baseline/authenticated clinical acceptance, zero failures.
- Dedicated Phase 61 PG17 workflow 43686671156 passed; all 10 exact-head workflow runs concluded success.
- Latest test commit adds a synthetic legacy_pharmacist denial case for the nested invoice-linked RPC in addition to the atomic RPC. No hosted migration was applied.
- Independent reviews: 0. Inline review threads: 0. Keep Draft and do not apply to QA or Production.

### Separate Phase 60 — PR #210

- Branch: feat/medicine-catalogue-identity-rebased-20261109
- Head: f041ac9fa0e3cb4114346984e3d1393ad972e18f; Draft.
- Exact-head CI 43646371012: 19 successful jobs, one intentional clinical-acceptance skip, zero failures; includes the disposable PostgreSQL 17 Phase 60 integration job.
- PR #210 is catalogue identity editing and append-only pack attestation, not Phase 61C. It is not applied to QA or Production; independent review and pharmacist physical-pack acceptance remain open.

## Supabase live snapshot

| Measure | Production jewzonxplxhogqrnhosl | QA hopfohcnrtbiqjkgeukz |
|---|---:|---:|
| PostgreSQL | 17.6 | 17.11 |
| Migration rows / latest | 129 / 20261102232941 | 27 / 20261113232719 |
| Public tables / columns | 56 / 842 | 58 / 873 |
| Private tables / columns | 4 / 24 | 2 / 13 |
| Public constraints / indexes | 215 / 249 | 242 / 255 |
| Private constraints / indexes | 7 / 5 | 3 / 3 |
| Public functions / triggers | 96 / 69 | 101 / 81 |
| Private functions / triggers | 47 / 0 | 56 / 0 |
| Public policies | 210 | 212 |
| Public RLS enabled / forced | 56 / 44 | 58 / 46 |

Ledger comparison: 3 shared version IDs, all with different names and statement fingerprints; 126 Production-only and 24 QA-only. The three collisions are detailed in docs/DB_MIGRATION_RECONCILIATION.md. Do not edit ledger rows.

### Pharmacy and role boundary

- QA Phase 57 migration 20261104065852 and Phase 57B migration 20261111215510 are applied. QA private invoice-linked implementation rejects NULL quantity and free-text/external items.
- Production has neither Phase 57 nor 57B. Its invoice-linked function still contains three COALESCE(pi.quantity,1) fallbacks and lacks the NULL/free-text/external guards.
- QA Phase 61B is applied as 20261113232719. Phase 61C is candidate-only in PR #250; absent from both hosted projects.
- Canonical pharmacist: one active user in each project. legacy_pharmacist: zero active users in each project; exact permissions in both are pharmacy.edit, pharmacy.view, reports.view. Do not grant pharmacy.update or billing.create to the legacy role.
- PR #250's Phase 61C wrapper requires canonical pharmacist plus pharmacy.update and billing.create. Disposable PG17 tests deny legacy_pharmacist at both atomic and nested invoice-linked RPC boundaries.
- Phase 55: QA private.app_has_claim_branch(uuid) and private.sync_user_role_text() are owner-only; Production proacl is NULL and anon/authenticated/service_role/authenticator have effective EXECUTE. No ACL changes were made.

## Supabase advisors

| Advisor | Production | QA |
|---|---:|---:|
| Security findings | 31 | 34 |
| Performance findings | 95 | 147 |
| Health findings | 0 | 0 |

Security findings include pg_trgm in public, the intentional anon SECURITY DEFINER setup_required() bootstrap signal, and authenticated SECURITY DEFINER RPCs requiring per-function review. Performance INFO includes 2/7 unindexed foreign keys and 93/140 unused-index observations. No blanket revokes or index drops were performed.

## Vercel

- Canonical alias roshan-health-hub.vercel.app maps to READY deployment dpl_G9jScsLW3jDXFePVZLQgedwMMKRH, source SHA a9040601702972bdf144fc96b9658eebd5a6d31a; aliasError=null.
- Newer Production attempt dpl_5YyUYp838yV3ws7uCVurH9bJQvxA for docs-only main SHA f8c8b2d was CANCELED. No new application deployment occurred.

## Backup and recovery

- Backup-runner main: f171732b61fe0460c61a36aa63b861065f9ea9d1. Latest runner-main CI 43190851147 passed validation only.
- Latest full manual encrypted backup/restore: 43183851731 on runner SHA eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8. Both validate and backup jobs passed; local PostgreSQL 17 restore, encryption and encrypted-only upload passed.
- Drive archive roshan-production-backup-43183851731.zip remains present in folder 2026-11-12, 305284 bytes, MD5 22271054f6c10b1baf1d23ac4bdac24e. GitHub artifact is expired/not listed. Owner-side decryption of this latest Drive copy remains unverified.
- Backup scope is PostgreSQL only; Storage object bytes, Vault secrets, platform settings and credentials are excluded.

## Release decision and next task

- Production: NO-GO. No Production or QA DDL/DML/ACL/RLS/Auth/Storage changes, no new clinical/financial records, no backup write, no merge and no deployment promotion were performed in this snapshot.
- Next highest-value task: obtain independent second-person SQL/security review of PR #250. Only after review, execute the documented QA-only Phase 61C release gate and read back effective grants/functions. Keep Production read-only.
- Clinical E2E remains deferred until a free isolated test environment and suitable synthetic doctor/pharmacist identities are available. Reception, clinician, pharmacy, finance, Android RTL/LTR, keyboard and physical-print acceptance remain separate human gates.
- Last evidence-weighted baseline: 62% Engineering RC / 15% Operational Acceptance. No percentage increase is claimed for this audit/documentation pass. Conditional Engineering RC estimate: 20–35 focused hours; no calendar launch ETA is defensible.