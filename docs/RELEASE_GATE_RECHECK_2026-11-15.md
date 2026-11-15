# Roshan Health Hub — Live Release-Gate Recheck

**Snapshot:** 2026-11-15, 06:55 UTC. All hosted database queries in this report were read-only. No Production/QA writes, migration applications, privilege changes, backup dispatches, merges or deployment promotions were performed.

## Executive decision

**Production remains NO-GO.** The current Phase 61C candidate has fresh exact-head tests, including the legacy-role denial path, but has no independent second-person review and is not applied to hosted QA. Production still lacks the QA pharmacy quantity/free-text/external guards and Phase 55 helper ACL correction. Migration histories remain non-parallel.

## Repository and workflows

- Main SHA: f8c8b2d1767643561599764405b4cdbfd4db2c79. Latest main commit changes only docs/TIT_CLINIC_COMPARISON_UX_AUDIT_2026-11-14.md.
- Main current-head Finance-only RPC isolation: [43644032032](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43644032032) PASS.
- Main current-head CodeQL: [43644032038](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43644032038) PASS. Latest full CI [43527161767](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43527161767) passed on prior application SHA a9040601702972bdf144fc96b9658eebd5a6d31a; no full CI run is claimed on the docs-only f8c8b2d head.
- Open PRs: 5. Open issues: #199, #217, #218.

### PR #250 — Phase 61C atomic dispense role boundary

- Current code/test head: f3a81b0ef8b110127433b828e75c2d92909e9e73; base main f8c8b2d; Draft, mergeable.
- Exact-head [CI 43686671277](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43686671277): 18 jobs passed, one skipped job (canonical PG17 baseline replay/authenticated clinical acceptance), zero failures.
- Dedicated [Phase 61 PG17 workflow 43686671156](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43686671156) passed. The run applied Phase 61/61B/61C in disposable PostgreSQL 17, reapplied Phase 61C for idempotence, and passed role/RLS/audit/no-side-effects and concurrency assertions. All 10 exact-head workflow runs concluded success; the intentional skip is not a pass.
- The Phase 61C SQL moves the implementation to private.atomic_pharmacy_dispense_unchecked, revokes API-role execution on the unchecked function, and exposes a public SECURITY DEFINER wrapper with empty search_path that requires canonical pharmacist role plus pharmacy.update and billing.create.
- Latest test commit f3a81b0 adds a synthetic legacy_pharmacist denial assertion against the nested Phase 61B invoice-linked RPC as well as the atomic RPC. Review count remains 0; inline review threads remain 0. Keep Draft.
- Phase 61C is not applied to QA or Production. QA latest migration remains 20261113232719 (Phase 61B); Production has no Phase 61/61B/61C migration.

### PR #210 — Phase 60 catalogue identity/pack attestation

- Current head: f041ac9fa0e3cb4114346984e3d1393ad972e18f; Draft.
- Exact-head [CI 43646371012](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43646371012): 19 jobs passed, one intentional clinical-acceptance skip, zero failures; includes the disposable PostgreSQL 17 Phase 60 integration job.
- This is a separate Phase 60 catalogue identity/append-only human pack-attestation candidate. It is not Phase 61C. It is not applied to QA/Production and is not a physical label, barcode, lot, expiry or dispensing hard-stop verification.
- Review count and inline threads remain 0. Keep Draft pending independent review and pharmacist acceptance.

## Supabase migration ledgers

| Field | Production jewzonxplxhogqrnhosl | QA hopfohcnrtbiqjkgeukz |
|---|---:|---:|
| PostgreSQL | 17.6 | 17.11 |
| Migration rows | 129 | 27 |
| Latest version | 20261102232941 | 20261113232719 |

- Shared version IDs: 3; all three have different names and statement payloads.
- Production-only IDs: 126. QA-only IDs: 24.
- Exact colliding versions, names and statement fingerprints are in docs/DB_MIGRATION_RECONCILIATION.md. Fingerprints use md5(array_to_string(statements, newline)); they are not Git blob hashes.
- Do not edit migration ledger rows, rename old versions, or replay either environment's mismatched history into the other.

## Live schema catalog

| Measure | Production public/private | QA public/private |
|---|---:|---:|
| Tables | 56 / 4 | 58 / 2 |
| Columns | 842 / 24 | 873 / 13 |
| Constraints | 215 / 7 | 242 / 3 |
| Indexes | 249 / 5 | 255 / 3 |
| Functions | 96 / 47 | 101 / 56 |
| Triggers | 69 / 0 | 81 / 0 |
| Policies | 210 / 0 | 212 / 0 |
| RLS enabled | 56 / 2 | 58 / 1 |
| RLS forced | 44 / 0 | 46 / 0 |

Counts are schema snapshots, not semantic parity proof.

## Pharmacy, role and ACL verification

- QA Phase 57 migration 20261104065852 and Phase 57B 20261111215510 are applied. The private invoice-linked implementation rejects NULL quantity, free-text medicine rows and external prescriptions.
- Production lacks Phase 57/57B. Its public invoice-linked function still has three COALESCE(pi.quantity,1) fallbacks and no missing-quantity, free-text or external-prescription guard.
- QA Phase 61B migration 20261113232719 is applied; Production lacks it. Phase 61C remains PR-only.
- Canonical pharmacist has one active user in each project. legacy_pharmacist has zero active users in each project and exactly pharmacy.edit, pharmacy.view, reports.view in both. No permission was granted or altered.
- The UI still recognizes legacy_pharmacist as a compatibility label, but canDispense also requires pharmacy.update; the live legacy role does not have it. Phase 61C's database wrapper is stricter and allows only canonical pharmacist plus both required permission bits. Keep the general compatibility-role retirement/support decision separate and reviewed.
- Phase 55 private.app_has_claim_branch(uuid) and private.sync_user_role_text() are owner-only in QA. In Production proacl is NULL and anon/authenticated/service_role/authenticator have effective EXECUTE. No ACL changes were made.

## Supabase advisors

| Advisor | Production | QA |
|---|---:|---:|
| Security | 31 | 34 |
| Performance | 95 | 147 |
| Health | 0 | 0 |

Security details: pg_trgm remains in public; setup_required() is the intentional boolean-only anon SECURITY DEFINER bootstrap signal; authenticated SECURITY DEFINER RPCs require per-function source/call-site review. Private idempotency tables with RLS and no policies are intentional private isolation. Performance INFO: 2/7 unindexed foreign keys and 93/140 unused-index observations. Do not blanket-revoke SECURITY DEFINER or drop indexes without call-site/workload evidence.

## Vercel

- Canonical alias roshan-health-hub.vercel.app currently maps to [READY deployment dpl_G9jScsLW3jDXFePVZLQgedwMMKRH](https://vercel.com/roshan45/roshan-health-hub/G9jScsLW3jDXFePVZLQgedwMMKRH), application SHA a9040601702972bdf144fc96b9658eebd5a6d31a; aliasError=null.
- Newer Production attempt [dpl_5YyUYp838yV3ws7uCVurH9bJQvxA](https://vercel.com/roshan45/roshan-health-hub/5YyUYp838yV3ws7uCVurH9bJQvxA) for docs-only main SHA f8c8b2d is CANCELED. The canonical alias remains on the older READY application deployment. No deployment promotion was performed.

## Backup and restore

- Backup-runner main: f171732b61fe0460c61a36aa63b861065f9ea9d1.
- Latest runner-main CI [43190851147](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43190851147) passed the validate job only; it is not a backup.
- Last complete manual backup [43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) ran on older runner SHA eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8. Both validate and backup jobs passed; the backup job created an encrypted archive, restored it locally on PostgreSQL 17, checked critical counts, and uploaded ciphertext only.
- GitHub artifact for run 43183851731 is expired/not listed. The off-site Drive copy remains present: [roshan-production-backup-43183851731.zip](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view?usp=drivesdk), folder 2026-11-12, 305284 bytes, MD5 22271054f6c10b1baf1d23ac4bdac24e.
- The runner's later main commit f171732 changed README and Android verification script/tests only; no backup workflow file changed. This supports, but does not replace, the historical successful restore evidence.
- Owner-side decryption of the latest Drive copy remains unverified. Backup scope is PostgreSQL only; Storage object bytes and Vault secrets are excluded.

## Release gates

| Gate | State |
|---|---|
| Main current-head Finance/CodeQL | PASS |
| PR #250 exact-head CI | PASS with one intentional SKIP |
| PR #250 Phase 61 PG17 | PASS |
| Independent PR #250 SQL/security review | BLOCKED — 0 reviews / 0 threads |
| Production/QA migration parity | BLOCKED — 3 semantic version collisions, 126/24 unique IDs |
| QA Phase 57/57B | PASS — applied and guarded |
| Production Phase 57/57B | FAIL — legacy fallback and missing guards |
| QA Phase 61B | PASS — migration 20261113232719 |
| Phase 61C hosted application | NOT APPLIED — candidate only |
| Phase 55 Production helper ACL | FAIL — PUBLIC-effective |
| Supabase Health advisors | PASS — zero findings |
| Security/performance advisor triage | OPEN — per-object review required |
| Vercel canonical alias | PASS — READY older deployment |
| Encrypted off-site PostgreSQL archive | PASS — Drive copy present |
| Isolated PostgreSQL 17 restore rehearsal | PASS — run 43183851731 |
| Owner-side decryption of latest archive | UNVERIFIED |
| Clinical/pharmacy/staff acceptance | DEFERRED / NOT ACCEPTED |

## Next task and safety boundary

Next highest-value task is an independent second-person SQL/security review of PR #250, focused on SECURITY DEFINER ownership/search_path, unchecked-function ACLs, canonical role and permission checks, Phase 61B nested RPC behavior, branch isolation, idempotency, inventory/invoice atomicity and audit effects. Do not apply Phase 61C to QA until review and the documented QA release gate pass.

Clinical end-to-end acceptance remains deferred until a free isolated test environment and suitable synthetic doctor/pharmacist identities exist. No Production or QA DDL/DML/ACL/RLS/Auth/Storage writes, no real clinical/financial records, no backup dispatch, no merge and no deployment promotion occurred in this recheck.

Last evidence-weighted baseline: 62% Engineering RC / 15% Operational Acceptance; unchanged by this audit. Conditional Engineering RC estimate: 20–35 focused hours. No guaranteed calendar release ETA.
## Documentation-contract validation

- The initial evidence commit fd46c6e8d95931d519de77df55a15b99b317e80b triggered Spec Kit validation [43688576295](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43688576295). The workflow failed at the repository agent-skills contract because the refreshed PROJECT_STATE.md omitted the required Refresh protocol and STALE markers; the remaining repository/Spec Kit baseline checks passed.
- The follow-up documentation commit restores the explicit refresh contract and keeps the project-state cache warning. This was a documentation-contract failure, not a SQL, application or clinical test failure. The corrected exact-head workflow result is tracked on PR #250.