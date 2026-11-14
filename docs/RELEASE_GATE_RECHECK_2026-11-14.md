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
- PR #250: [fix/security: gate atomic pharmacy dispense by pharmacist role](https://github.com/crauch2088-source/roshan-health-hub/pull/250), Draft, mergeable, 10 commits ahead / 0 behind main. Tested code head **99b8b0689c6413b6d227fc035930136ad98516fc**; documentation-only follow-up commit **71df5bdff456a94e5c696e15f3a3a0c2349b4673** is layered after it.

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

## Follow-up — Phase 61C positive-path regression (2026-11-14)

- Independent source review of PR #250 at pre-change head `18fdd82ed8896926c097c7450b7c7f8e6cf3c374` found a coverage gap, not a confirmed runtime defect: the suite proved non-pharmacist rejection and pharmacist access to invalid-input validation, but did not execute a successful dispense through the new outer wrapper. The existing Phase 49/50 positive path runs before Phase 61C and uses a non-canonical synthetic role code.
- Added a post-Phase-61C synthetic canonical-pharmacist success case with a valid linked prescription and unexpired batch. It asserts successful wrapper delegation, exact idempotent replay, a single stock movement, a single pharmacy invoice line, one persisted idempotency result, and remaining batch quantity.
- The test/fixture/source-contract update is on PR #250 only. Commits `ee254b02d0869d65ceccd97e9e3496adadbbec81` and `2fac5c1aed5a30469832829fd510c51da3f12faa` carry the regression; exact-head focused PostgreSQL 17 run [43568850218](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43568850218) passed. The first run [43568728075](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43568728075) failed on a strict numeric-string test assertion, corrected in `2fac5c1`.
- No hosted QA/Production migration, DDL/DML, ACL change, external backup write, merge, or deployment promotion occurred. Independent second-person SQL/security review is still required before a QA-only application.



### Exact-head test result — 2026-11-14 06:58 UTC

- PR #250 head: `2fac5c1aed5a30469832829fd510c51da3f12faa` (15 ahead / 0 behind main), Draft, mergeable, zero submitted reviews and zero inline review threads.
- Focused Phase 61 PostgreSQL 17 workflow [43568850218](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43568850218) passed. It applied Phase 61/61B/61C in disposable PostgreSQL 17, reapplied Phase 61C, passed the new canonical-pharmacist success/idempotent-replay assertions, the role/RLS/audit/no-side-effects suite, concurrent correction serialization, and 24/24 Node source-contract/UI tests.
- Initial run [43568728075](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43568728075) failed on a strict text comparison of a JSON numeric value; commit `2fac5c1` changed the assertion to a numeric comparison and the rerun passed. This was a test assertion correction, not a production SQL change.
- The PR Vercel context is success for its preview; Production remains on deployment `dpl_G9jScsLW3jDXFePVZLQgedwMMKRH`, READY on main SHA `a9040601702972bdf144fc96b9658eebd5a6d31a`, with canonical alias present and `aliasError=null`.
- No hosted QA/Production DDL/DML, ACL changes, real records, backup writes, merge or deployment promotion occurred. Independent second-person SQL/security review remains required before QA-only application.



## Follow-up — permission-negative Phase 61C regression and 07:22 UTC recheck

### Repository and tests

- Main SHA: `a9040601702972bdf144fc96b9658eebd5a6d31a`; PR #249 merged. Main CI [43527161767](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43527161767): 18 success, one intentional clinical-acceptance skip, zero failures.
- PR #250 is Draft/mergeable with zero submitted reviews and zero inline review threads; code/test commit is `d7a72886797c197dc06d8161cd06070f82691a3e`. Documentation-only follow-ups `ada12fdfd68772402cdcd83229667faed667c065`, `bc1afed7913d390f3cb80b3fb24e128b4998ef65` and `b47b4baac6a5004df46947e33a9dad162a7301f6` update release evidence without changing application code or tests.
- New regression commit `d7a72886797c197dc06d8161cd06070f82691a3e` adds two disposable-PG17 denial cases: a pharmacist missing `billing.create`, and a pharmacist missing `pharmacy.update`. Each call must fail with SQLSTATE `42501` before invalid-payload validation; the test restores the permission and verifies neither rejected request creates an idempotency row.
- Exact-head CI [43570730013](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43570730013): 18 success, one intentional clinical-acceptance skip, zero failures. Phase 61 PG17 [43570729978](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43570729978) passed, including migration reapply/idempotence, role/ACL/no-side-effect assertions, concurrent correction serialization and 25/25 Node source-contract/UI tests. Insurance UI #43570729933, insurance integrity #43570729917, prescription atomicity #43570730047, privileged-role guard #43570730571 and PR Vercel preview status succeeded.
- No application migration code changed in this test-only commit. Phase 61C remains unapplied to hosted QA/Production; PR remains Draft.

### Current hosted gates

| Gate | Current verified state |
|---|---|
| Production migration ledger | 129 rows; latest `20261102232941` |
| QA migration ledger | 27 rows; latest `20261113232719` (Phase 61B) |
| Ledger version parity | 3 shared IDs, all with different names/statement MD5s; 126 Production-only and 24 QA-only |
| Phase 57/57B | QA applied; Production absent; quantity remains nullable in both |
| Phase 57 behavior | Production invoice-linked RPC retains 3 NULL-to-one fallbacks; QA private unchecked implementation has 0 |
| Phase 55 ACL | Production private helpers PUBLIC-effective; QA owner-only |
| Phase 61B | QA applied as `20261113232719`; Production absent |
| Phase 61C | PR #250 candidate only; not hosted-applied |
| Supabase advisors | Production 31 security / 95 performance / 0 health; QA 34 / 147 / 0 |
| Vercel Production | `dpl_G9jScsLW3jDXFePVZLQgedwMMKRH` READY on main SHA; canonical alias present |
| Backup-runner main | `f171732b61fe0460c61a36aa63b861065f9ea9d1`; latest CI validator-only |
| Latest manual backup attempt | #43190680531; preflight and backup skipped, no artifact |
| Last complete backup/restore | #43183851731 on earlier runner SHA; isolated PostgreSQL 17 restore and encrypted upload passed |
| Off-site encrypted artifact | Drive copy present, 305,284 bytes, MD5 `22271054f6c10b1baf1d23ac4bdac24e`; owner-side decryption unverified |

Current public/private catalog counts differ: Production 56/4 tables, 842/24 columns, 222 constraints, 254 indexes, 210 policies, 69 triggers, 143 functions, 58/44 RLS/forced-RLS tables; QA 58/2 tables, 873/13 columns, 245 constraints, 258 indexes, 212 policies, 81 triggers, 157 functions, 59/46 RLS/forced-RLS tables. All observed indexes are valid/ready. These counts do not establish semantic parity.

**Production remains NO-GO.** The encrypted backup and runner-side restore gate has prior positive evidence, but no new full backup was produced on current runner main and owner-side decryption remains unverified. Full migration/catalog parity, Production security/pharmacy guards, independent SQL review, and clinical/pharmacy operational acceptance remain open. Clinical E2E stays deferred until a free isolated environment and suitable synthetic doctor/pharmacist identities are available.

Next: independent second-person SQL/security review of PR #250; then, only after the documented QA gate, consider QA-only Phase 61C application/read-back. If review is unavailable, continue object-level source-to-ledger/catalog reconciliation with read-only tools.
