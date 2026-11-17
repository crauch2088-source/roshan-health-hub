# Roshan Health Hub — release-gate recheck

**Evidence time:** 2026-11-17 08:55 Africa/Khartoum  
**Repository main:** 79d81f08f6567f5145f7143e3bf5afdd6e93bf59  
**Decision:** **Production NO-GO**. This report is based on current GitHub, Supabase, Vercel and Drive records. No hosted database writes, merges, deployment promotions, or backup dispatches were performed.

## Repository and CI

- Main is still 79d81f08f6567f5145f7143e3bf5afdd6e93bf59. The exact-SHA Actions query returned five runs: three Dependabot runs succeeded, the dynamic “Push on main” run succeeded, and Finance-only RPC write isolation run 43767368557 succeeded. No full general CI run was returned for this exact main SHA; do not describe the limited checks as a full main CI pass.
- The combined commit status reports Vercel success. The latest READY Production deployment is dpl_G9jScsLW3jDXFePVZLQgedwMMKRH on application SHA a9040601702972bdf144fc96b9658eebd5a6d31a. Its aliases include roshan-health-hub.vercel.app; the project-domain record is verified. Main is seven commits ahead of that deployment, and the exact compare shows those seven commits change only documentation/specification files, not application source. The currently served application source therefore has no identified post-deployment source delta.
- There are 33 open PRs and four open issues (#199, #217, #218, #253). Material candidates include #250 Phase 61C (Draft, head c43c0258eb80760191b1b523128ddcb2c7537344, base f8c8b2d1767643561599764405b4cdbfd4db2c79), #258 prescription/document safety (Draft, head d4fb4eb68a9fade040a5f28457d93b265fb32169), #269 Phase 61 no-side-effect coverage (Draft, head 3d5be08a131f9f0c2aefda3227f1c11d1156deaa), #280 payment idempotency (Draft, head 1c7aff22417897660c0ddc69914ca827d9ddebb6), and this run's Phase 61D FK-index candidate #287 (Draft). #250 has two COMMENTED review submissions, both authored by the repository owner, and zero inline review threads: independent second-person SQL/security review is still absent. Keep it Draft and do not apply Phase 61C to either hosted project.
- PR #258 exact-head workflow 43866121549 succeeded, including the Phase 63 PostgreSQL 17 job. Its canonical baseline/authenticated clinical acceptance check is intentionally skipped, not passed. Independent clinical/security review, authenticated QA role/branch acceptance and print/staff acceptance remain open.
- Issue #253 remains open. The rulesets endpoint returned an empty list, but the branch-protection endpoint returned 403 Resource not accessible by integration. The 2026-11-15 owner-side issue evidence says protection was disabled; this run cannot freshly confirm the branch-protection API state. Treat main protection as unverified and unresolved.

## Supabase — live migration and schema parity

Both projects are ACTIVE_HEALTHY, PostgreSQL 17:

| Evidence | QA | Production |
|---|---:|---:|
| Project ref | hopfohcnrtbiqjkgeukz | jewzonxplxhogqrnhosl |
| PostgreSQL | 17.11.0.003 | 17.6.1.155 |
| Migration rows | 27 | 129 |
| Latest migration | 20261113232719 / Phase 61B | 20261102232941 / synthetic cleanup and stock-ledger reversal |
| Public tables | 58 | 56 |
| Public columns | 873 | 842 |
| Public/private functions | 157 | 143 |
| Non-internal triggers | 81 | 69 |
| Public tables with RLS | 58/58 | 56/56 |

The ledgers share only three version IDs, and all three have different names. QA has 24 QA-only IDs; Production has 126 Production-only IDs. This is not migration or source parity. Never repair it by editing migration ledgers, reusing timestamps, or mechanically replaying either environment's history.

QA records Phase 55 (20261103155227), Phase 57 (20261104065852), Phase 57B (20261111215510), Phase 61 (20261111223309), Phase 58 (20261112061219), Phase 59 (20261112061251) and Phase 61B (20261113232719). Production records none of those phases. Phase 61C is not applied to QA or Production.

### Pharmacy quantity and role boundaries

- QA's effective private unchecked dispensing function contains the explicit NULL-quantity rejection, free-text-item rejection and external-prescription rejection; the public wrapper delegates to it. The QA public wrapper remains callable only through its authenticated role/permission gate.
- Production's public dispensing implementation still uses COALESCE(pi.quantity, 1) in both line selection and stock aggregation. It has no explicit NULL-quantity rejection and no external-prescription guard. Production therefore remains unsafe for missing quantities; a zero count of active NULL-quantity rows does not remove this latent defect.
- The Phase 55 helpers private.app_has_claim_branch(uuid) and private.sync_user_role_text() deny anon/authenticated EXECUTE in QA, but both remain executable by anon/authenticated in Production. No ACL changes were made.
- The legacy_pharmacist role exists in both projects with pharmacy.edit, pharmacy.view and reports.view, and zero active users in each. Do not grant permissions. Preserve fail-closed behavior until the role is explicitly retired or supported through review.

## Supabase advisors

Read at 2026-11-17 06:55 UTC (QA Performance snapshot 06:55:09 UTC):

- **Health:** zero findings in both projects.
- **Security QA:** 34 findings across five groups: one RLS-enabled/no-policy INFO finding on private.pharmacy_dispense_idempotency; pg_trgm in public; the expected setup_required() anon SECURITY DEFINER warning; 30 authenticated SECURITY DEFINER warnings; and one Auth leaked-password-protection warning.
- **Security Production:** 31 findings across five groups: two RLS-enabled/no-policy INFO findings on private idempotency tables; pg_trgm in public; setup_required() anon warning; 26 authenticated SECURITY DEFINER warnings; and one Auth leaked-password-protection warning.
- **Performance QA:** 147 findings across two INFO groups: seven unindexed foreign keys on Phase 61 correction-workflow tables and 140 unused-index suggestions.
- **Performance Production:** 95 findings across two INFO groups: two unindexed foreign keys on the legacy private pharmacy idempotency table and 93 unused-index suggestions.

Do not blanket-revoke SECURITY DEFINER functions, move pg_trgm, or delete unused indexes. The leaked-password-protection warnings are an Auth configuration item for owner review, not a reason to alter SQL grants. The Phase 61 advisor's seven missing FK indexes were individually mapped to actor_id, replacement_prescription_id, corrected_item_id, patient_id, requested_by, resolved_by and visit_id. This run prepares a narrow repository-only Phase 61D candidate for those seven indexes and a PostgreSQL 17 assertion; it does not apply the migration to QA or Production. The two Production legacy-table FK suggestions remain separate pending dependency/use review.

## Vercel and recovery

- Canonical Production project: roshan-health-hub, Hobby plan. READY deployment dpl_G9jScsLW3jDXFePVZLQgedwMMKRH (application SHA a9040601702972bdf144fc96b9658eebd5a6d31a); canonical alias roshan-health-hub.vercel.app is verified and aliasError is null.
- Backup runner repository main is f171732b61fe0460c61a36aa63b861065f9ea9d1; no open PRs. Its latest manual Production backup run, 43764265014 on 2026-11-15, failed at credential preflight. The log explicitly says exactly one of SUPABASE_DB_ACCESS_TOKEN or SUPABASE_DB_PASSWORD must be configured; neither was present. The backup job was skipped and the run has zero artifacts. Latest runner CI 43190851147 succeeded, but it is validation, not a backup.
- Last successful full backup is runner run 43183851731 (2026-11-12), on runner SHA eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8. Both validate and backup jobs passed, including the local PostgreSQL 17 restore step and encrypted-artifact upload.
- The existing off-site Drive artifact remains present: roshan-production-backup-43183851731.zip, file ID 1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o, 305284 bytes, MD5 22271054f6c10b1baf1d23ac4bdac24e, not trashed, in the 2026-11-12 dated folder. The evidence record says its ZIP contains the age-encrypted database archive and checksum manifest.
- The runner's PostgreSQL 17 restore was performed locally before encryption. The latest retained 2026-11-12 ciphertext has not been proven decryptable/restorable by an owner-side offline identity. Issue #199 records a successful owner-side decryption of an earlier 2026-11-09 artifact; that older success does not validate the newer 2026-11-12 ciphertext. No fresh backup or off-site artifact was created in this run.

## Release gates

| Gate | State | Evidence / reason |
|---|---|---|
| Main source and exact-head CI | Partial | Main SHA known; limited checks pass, no full CI run on this exact SHA |
| Production/QA migration parity | Blocked | 129 vs 27 rows; only three mismatched shared version IDs |
| Phase 57/57B pharmacy guard | Blocked | QA protected; Production retains NULL-to-one fallback and lacks external guard |
| Phase 55 helper ACL | Blocked | Production retains PUBLIC-effective anon/authenticated EXECUTE |
| Phase 61C pharmacist-only atomic dispense | Blocked | PR #250 Draft; no independent reviewer; not applied |
| Supabase health advisors | Pass | Zero findings both |
| Security/performance advisors | Open | Specific findings remain; Phase 61D indexes are candidate-only |
| Vercel Production deployment/alias | Pass with source-age note | READY, alias verified; seven later commits are docs/spec only |
| Encrypted off-site backup | Partial | 2026-11-12 artifact exists; latest backup attempt failed; no fresh artifact |
| Isolated restore | Partial | Pre-encryption local PG17 restore passed; latest ciphertext owner-decrypt/restore unverified |
| Branch protection | Unverified / likely open | Prior disabled evidence; current API 403; no rulesets returned |
| Clinical/pharmacy and reception-to-billing UAT | Blocked | Authenticated clinical acceptance deferred; staff UAT, mobile RTL/LTR and physical print acceptance outstanding |

**Readiness remains unchanged:** Engineering Release Candidate **62%**; Operational Acceptance **15%**. This read-only audit and candidate-only FK index work do not raise either score.

**Conditional ETA:** the historical 17–30 engineering-hour estimate remains a planning range, not a promise. A calendar ETA is not defensible until the owner-controlled backup credential/decryption step, independent SQL/security reviews and staff acceptance windows are available.

## Highest-value next actions

1. Owner configures exactly one supported backup credential directly in the private runner repository, reruns the manual backup with explicit confirmation, and verifies owner-side decryption/restoration of the new off-site ciphertext. Never share credentials or the private age identity.
2. Obtain independent second-person SQL/security review for PR #250, then complete the documented QA-only Phase 61C gate and role-switch assertions. No Production application until separate release approval.
3. Review and validate the Phase 61D FK-index candidate on disposable PostgreSQL 17 CI; do not apply it to hosted QA/Production as part of this PR.
4. Reconcile forward-only Production migration/source plans, then schedule pharmacist/prescriber, reception-to-billing, Android RTL/LTR and physical print acceptance.

No hosted DDL/DML, Auth/Storage writes, business-record writes, Production privilege changes, PR merges, backup dispatches or deployment promotions occurred during this recheck.
