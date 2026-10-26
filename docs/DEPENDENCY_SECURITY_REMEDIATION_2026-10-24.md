# Dependency security remediation — 2026-10-24

## Triggering evidence

- Repository: `crauch2088-source/roshan-health-hub`
- Verified `main` SHA: `c091a3355019f741e10a64a2ef08b57a0d15d806`
- Failing CI: [run 40066574017](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40066574017), job `Install, audit, typecheck, lint, build`, step `Security audit`.
- `npm audit` reported `fast-uri@3.1.8` affected by [GHSA-w74x-v6f9-j3xg](https://github.com/advisories/GHSA-w74x-v6f9-j3xg), [GHSA-xhq7-xmqj-769h](https://github.com/advisories/GHSA-xhq7-xmqj-769h), [GHSA-wjr9-j795-jxcr](https://github.com/advisories/GHSA-wjr9-j795-jxcr), and [GHSA-333x-w4r6-6crp](https://github.com/advisories/GHSA-333x-w4r6-6crp); `zod@3.25.76` and transitive `zod@4.6.5` were affected by [GHSA-mrhx-c7xc-m3w5](https://github.com/advisories/GHSA-mrhx-c7xc-m3w5).

## Candidate remediation

- Lock `fast-uri` at `3.1.9` and all Zod entries at `4.6.7`, both patched versions identified by the advisories.
- Update the direct Zod dependency to `^4.6.7` but use `zod/v3` imports in the two existing server-validator modules. This deliberately preserves their existing Zod 3 API/semantics; it is not a broad Zod 4 schema migration.
- Add `tests/dependency-security.test.ts` to the existing guard suite. It checks the lockfile minima and validates the Zod v3 compatibility entry point, including Standard Schema support expected by TanStack server validators.

## Release gate and status

- Candidate only until exact-head CI reports green for `npm ci`, `npm audit`, guard tests, typecheck, lint, and build. Do not merge based on a source-only assertion.
- Do not apply production database migrations, change Supabase/Auth configuration, create clinical/financial test records, or deploy manually for this dependency-only task.
- Authenticated QA login and staff workflow acceptance remain **NOT RUN**; a READY isolated Preview does not prove those flows. Issue #95 remains open.
- Next: inspect the exact candidate commit's workflow results; fix only demonstrated failures, then record the resulting PR/check evidence before squash merge.


## First exact-head CI result — 2026-10-24

- PR: [#104](https://github.com/crauch2088-source/roshan-health-hub/pull/104), candidate head `8a0cce45328a8c29a0557d96a73d99a2ba6645e3`.
- CI run [40074050483](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40074050483): `npm audit` reported **0 vulnerabilities** and the guard suite passed **213/213**. The `Lint` step failed on `tests/dependency-security.test.ts` because of explicit `any` types and Prettier violations (job `120813505369`).
- This follow-up removes explicit `any` by typing the lockfile package records and formats the affected assertions. Recheck the exact new head before considering merge.


## Second exact-head CI result — 2026-10-24

- PR #104 head `74163ce5dfee29e89109b4d9b8b088db05c77026`, run [40074308442](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40074308442): `npm audit` still reported **0 vulnerabilities** and `test:guard` passed **213/213**. Lint had one remaining Prettier-only line-break complaint in `getLockedVersions`; the expression formatting is corrected in the next candidate commit.


## Merge and exact-head verification — 2026-10-24

- PR [#104](https://github.com/crauch2088-source/roshan-health-hub/pull/104) was squash-merged. The verified candidate head was `926065b92c9670eb36ff879360511621de28c851`; the resulting `main` commit is `6e66793b425ec871b91152e285f2dc85cfb4c775` ([commit](https://github.com/crauch2088-source/roshan-health-hub/commit/6e66793b425ec871b91152e285f2dc85cfb4c775)).
- Candidate checks: **29/29 successful** on the exact head. CI [run 40074517658](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40074517658) completed successfully, including install from lockfile, patched-version enforcement, security audit, guard tests, typecheck, lint, and build. The job log confirms `npm audit` found **0 vulnerabilities** and `test:guard` passed **213 tests**. PostgreSQL 17 integration [run 40074517840](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40074517840) passed.
- Vercel reported the PR preview deployment as **Ignored/Skipped**; no manual deployment or quota workaround was attempted. No production DB/Auth configuration or clinical/financial records were changed.
- Post-merge main checks were still queued/in progress at evidence capture: [CI run 40075092505](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40075092505), [finance-only RPC write isolation run 40075092448](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40075092448), and [clinical-child RPC-only run 40075092590](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40075092590). Recheck these exact-SHA runs before claiming merged main is fully green.
- **Next:** confirm post-merge CI conclusions, then resume the non-authenticated portion of Issue #95. Authenticated staff login and clinical E2E remain deferred/blocked until an authorized QA identity and supported login path are available.

## Dependabot CI regression triage — 2026-10-26

- Verified base `main`: `82c9a8306e4f611bcd593eeb5b192fd15b693265`. Exact-main CI `40077452190` and finance isolation `40077452172` succeeded on this SHA.
- Dependabot PR #109 (head `c41c3af9e8858e04984ee5db41e312f658092c35`, CI `40077778966`) and PR #110 (head `10df87161c54a9b7bc61eb4cfe2ca73f3ee3cd71`, CI `40077832680`) both failed guard test 46 because the lockfile no longer contains `fast-uri`; the guard incorrectly required the package to remain present. The regression now treats absence as safe while still rejecting any present version below `3.1.9`.
- Dependabot PR #111 (head `11ef1e196b1b32db2f56dd93767f8f9b367b58e9`, CI `40077928497`) failed `npm ci`: it selects TypeScript `7.0.2`, while locked `typescript-eslint@8.71.1` declares peer TypeScript `>=4.8.4 <6.1.0`. Dependabot now ignores TypeScript semver-major updates until the lint toolchain advertises support; minor/patch updates remain enabled. A source regression guard protects this policy.
- This change does not modify application dependencies or clinical/financial behavior. It does not make existing Dependabot PRs safe to merge automatically; PR #111 remains blocked until closed or regenerated without TypeScript 7, and #109/#110 need exact-head checks after rebasing onto the guard fix.
- **Next:** run exact-head CI for this atomic config/test/docs patch. If green, squash-merge it, then ask Dependabot to rebase #109/#110 and inspect all checks before merging either. Keep broad major upgrades out of production until each candidate passes the full suite.

## Post-merge verification and next gate — 2026-10-26

- PR #113 merged at `519884818e871aa79ae6232aa978b79bdb668184` after exact-head `865c237476c348f8aca905963609bc411b26ed78` passed 26/26 checks. Main CI `40281547079`, finance isolation `40281547073`, and push-on-main/CodeQL `40281547181` succeeded.
- PR #110 was rebased onto the guard fix at `d1588e5eb50fc180e3018376f39f22e9b718076a`; its CI `40281734787`, finance isolation `40281734763`, and clinical-child RPC-only `40281734788` all passed. The 23 check runs were 22 successful and one neutral. It was squash-merged at `5adfa01a6a96bd2060014a8529741bf9f7525440`.
- PR #111 closed unmerged by Dependabot after TypeScript semver-major updates were ignored. PR #109 remains open/stale at head `c41c3af9e8858e04984ee5db41e312f658092c35`; a rebase was requested but no new head had appeared at capture. Do not merge it until rebased exact-head CI is green.
- Main post-merge CI `40281870267` and push-on-main `40281870285` were still in progress at capture; finance `40281870288` and clinical-child RPC-only `40281870350` passed. Next verify these checks on the latest main head and then re-evaluate PR #109.

## Production patch/minor update blocked by TanStack Start API change — 2026-10-26

- Rebased PR #109 head `f95bc60bfb7204bd5406d6f50805c0876c6dd9b5`, base `5adfa01a6a96bd2060014a8529741bf9f7525440`, fails CI run `40281962439` at TypeScript typecheck. `src/lib/ai/assistant.functions.ts` uses `inputValidator` at lines 166, 288, 397 and 496; the candidate's `@tanstack/react-start@1.169.4` types no longer expose that method on `ServerFnBuilder`. Subsequent callback parameters become implicit `any`. This is a concrete API incompatibility, separate from the fast-uri guard fix.
- The PR's finance-only RPC integration `40281962460` and clinical-child RPC-only integration `40281962438` passed, but those do not override the failed typecheck. PR #109 remains open and must not be merged until the API change is reviewed and the full check matrix is green.
- Main `3f8403d2f9fae9d479e5477015853d9f2e8787b9` passed 22/22 checks in `40281990606`; finance isolation `40281990671` and push-on-main/CodeQL `40281990948` passed.
- PR #114 contains ten remaining npm major updates without TypeScript 7; it is still open and had no CI run at the latest check. Treat it as unapproved pending exact-head checks and review.
- Next: inspect the supported TanStack Start server-function validator API and either split the TanStack package family out of general production patch/minor updates or implement a narrow tested compatibility migration. Do not merge PR #109 or #114 while their exact-head release gates are incomplete.
