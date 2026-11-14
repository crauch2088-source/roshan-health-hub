# Roshan Health Hub — Live Release Gate Recheck
**2026-11-14 · 06:30 UTC**

## Executive decision

**Production NO-GO.**

Main is healthy and the Phase 61C candidate now passes its exact-head CI and PostgreSQL 17 integration suite. This is not a hosted QA application, Production migration, deployment promotion, or clinical/pharmacy acceptance.

## Source and checks

- Main SHA: **a9040601702972bdf144fc96b9658eebd5a6d31a**.
- Main CI [43527161767](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43527161767): 18 success, 1 intentional clinical-acceptance skip, 0 failures.
- Main Push [43527160629](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43527160629), Spec Kit [43527161693](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43527161693), Finance isolation [43527161727](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43527161727): success.
- Open PRs: 9. Open issues: #199, #217, #218.
- PR #250: [fix/security: gate atomic pharmacy dispense by pharmacist role](https://github.com/crauch2088-source/roshan-health-hub/pull/250), Draft, mergeable, 10 commits ahead / 0 behind main. Current head **99b8b0689c6413b6d227fc035930136ad98516fc**.

### PR #250 exact-head checks

| Check | Run | Result |
|---|---:|---|
| CI | [43566379340](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43566379340) | 18 success, 1 intentional skip |
| Phase 61 PostgreSQL 17 | [43566379352](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43566379352) | Success |
| Insurance UI | [43566379632](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43566379632) | Success |
| Insurance integrity | [43566379299](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43566379299) | Success |
| Prescription atomicity | [43566379303](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43566379303) | Success |
| Privileged role guard | [43566379297](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43566379297) | Success |
| CodeQL | [43566239898](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43566239898) | Success |
| Vercel status | PR head | Success |

Phase 61 PG17 replay applied Phase 61/61B/61C in disposable PostgreSQL, reapplied Phase 61C to prove idempotence, then passed role/ACL/no-side-effect, concurrency and source-contract tests. Assertions cover anon/authenticated/service_role/authenticator denial on the private unchecked RPC, authenticated-only wrapper access, Admin/Super Admin rejection before payload validation, pharmacist reaching SQLSTATE 22023, and no idempotency rows after rejected calls.

The Phase 61C migration is **not applied** to hosted QA or Production. PR #250 remains Draft and unmerged.

## Supabase live records — read-only

| | Production | QA |
|---|---:|---:|
| Project status | ACTIVE_HEALTHY | ACTIVE_HEALTHY |
| PostgreSQL | 17.6.1.155 | 17.11.0.003 |
| Migration rows | 129 | 27 |
| Latest version | 20261102232941 | 20261113232719 |

Only 3 version IDs are shared; all 3 have different names and statement MD5s. Production has 126 unique versions; QA has 24 unique versions. Collisions: 20261102122437, 20261102133658, 20261102133734.

QA Phase 61B is actually recorded as 20261113232719, 8,844 bytes, MD5 9f5095e70fa9cc6ed7e7fe83f7766312. The prior manifest timestamp 20261114120000 was incorrect and is corrected in PR #250.

- Phase 55: Production private helper ACLs remain NULL; anon/authenticated/service_role have effective EXECUTE. QA grants are owner-only.
- Phase 57/57B: Production quantity remains nullable, has zero current NULL rows, but the active dispense function still has 3 COALESCE(pi.quantity,1) fallbacks and lacks guards. QA has zero fallbacks and enforces missing-quantity, unlinked/free-text and external-prescription rejection. QA Phase 57/57B applied; Production neither applied.
- Phase 61C: both hosted environments still have the active authenticated SECURITY DEFINER atomic_pharmacy_dispense entry point without the explicit pharmacist-role boundary. Candidate fix is PR #250 only.

### Supabase Advisors — 2026-11-14 06:13 UTC

| Advisor | Production | QA |
|---|---:|---:|
| Security | 31 findings | 34 findings |
| Performance | 2 unindexed FKs + 93 unused-index notices | 7 unindexed FKs + 140 unused-index notices |
| Health | 0 | 0 |

Security warnings include authenticated-callable SECURITY DEFINER functions, the intentional anon setup_required() wrapper, pg_trgm in public, private RLS/no-policy notices and leaked-password protection disabled. No blanket revocation or index deletion was made.

## Deployment

Vercel Production deployment dpl_G9jScsLW3jDXFePVZLQgedwMMKRH is READY on main SHA a9040601702972bdf144fc96b9658eebd5a6d31a. Canonical alias roshan-health-hub.vercel.app is present; aliasError=null. No new deployment was triggered.

## Backup and restore

- Backup-runner main: f171732b61fe0460c61a36aa63b861065f9ea9d1.
- Latest runner-main CI [43190851147](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43190851147) passed validation only.
- Latest full encrypted backup/restore [43183851731](https://github.com/crauch2088-source/roshan-health-hub-backup-runner/actions/runs/43183851731) ran on parent SHA eb7d8ae8e22be1a4147d35cabe0acb0e77f0ecd8; validate, backup, PostgreSQL 17 local restore, age encryption and encrypted-only upload passed.
- Drive archive [roshan-production-backup-43183851731.zip](https://drive.google.com/file/d/1HQxRWPIkYLeFQ0DNR-8wSEULLYCWMM4o/view?usp=drivesdk) is present, not trashed, 305,284 bytes, MD5 22271054f6c10b1baf1d23ac4bdac24e, in folder 2026-11-12. GitHub artifact 13927247998 expired; Drive copy remains.
- Runner-side isolated restore passed. Owner-side decryption of the latest Drive copy remains unverified. No new backup write was triggered.

## Release gates and next task

**Completed:** main CI; PR #250 exact-head PG17/CI/security checks; Vercel READY; encrypted off-site PostgreSQL archive exists; runner-side isolated restore passed.

**Open/blocked:** full migration-ledger/source parity; Production Phase 55/57/57B/58/59 rollout; Phase 61C hosted QA application; owner-side decrypt verification; independent SQL/security review; staff clinical/pharmacy acceptance; physical printing/mobile acceptance. Clinical E2E remains deferred until a free isolated environment and synthetic doctor/pharmacist identities exist.

**Next:** independent SQL/security review of PR #250; only then consider an approved QA-only Phase 61C application and read-back. Keep Draft, do not merge, do not touch Production. Afterwards reconcile diverged PR #229 (40 ahead / 18 behind, not mergeable) using a normal two-parent merge and preserve its bilingual workflow.

Last evidence-weighted progress baseline: **62% Engineering RC / 15% Operational Acceptance**; no increase claimed. No defensible launch ETA while these gates remain open.
