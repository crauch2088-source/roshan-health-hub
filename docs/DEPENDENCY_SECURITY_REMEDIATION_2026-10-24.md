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


## TanStack Start server-function validator compatibility — 2026-10-27 (candidate)

- Start-of-run baseline verified from GitHub: `main` at `9cd8d0da48974c18dad8d5cbccc49ef8fde68b9b`; CI run `40369335545`, finance-only RPC isolation `40369335403`, and push-on-main/CodeQL `40369335604` all completed successfully on that exact SHA.
- Rechecked Dependabot PR #109 at head `f95bc60bfb7204bd5406d6f50805c0876c6dd9b5`. Its CI `40281962439` fails the Typecheck job: four calls in `src/lib/ai/assistant.functions.ts` use `.inputValidator()`, removed in `@tanstack/react-start@1.169.0`; finance and clinical-child RPC-only integrations passed but do not waive TypeScript failure.
- Official TanStack Start release notes identify the breaking change: `.inputValidator()` was removed from server functions and middleware; `.validator()` accepts the same validator. See https://github.com/TanStack/router/releases/tag/%40tanstack%2Freact-start%401.169.0 and https://tanstack.com/start/latest/docs/framework/react/guide/server-functions.
- Candidate changes only the four AI read-only server-function builders from `.inputValidator()` to `.validator()`, preserving the existing Zod v3 schemas, validation constraints, authentication checks, read-only query behavior, and handler bodies. A regression test asserts all four builders use the supported method and none retain the removed method.
- This is a source/test/doc candidate on a dedicated branch. No dependency lockfile change, production database/Auth change, patient/financial record, or deployment action is included. PR #109 remains unmerged until the exact updated dependency candidate passes its full check matrix.
- **Status at candidate creation:** PR/check evidence pending. Keep the release blocked until exact-head typecheck, lint, build, and integration checks pass.
- **Next:** run the focused guard suite and exact-head GitHub Actions; then rebase/retest PR #109 only after this compatibility fix is merged.


## TanStack validator migration — exact candidate verification (2026-10-27)

- PR [#117](https://github.com/crauch2088-source/roshan-health-hub/pull/117) source/test commit `16ea4c90f4e81cc808121a8e02d0452420fc8013` passed its exact-head CI matrix. Main CI run `40459881437`, insurance-claim integrity `40459881399`, prescription atomicity `40459881523`, privileged-role guard `40459881375`, insurance-claim UI validation `40459881536`, and dynamic PR workflow `40459879974` all completed with conclusion `success`. Vercel preview status for this candidate is `success`.
- The install/audit/typecheck/lint/build job succeeded, including the new regression assertion that the four AI server functions use `.validator()` and none use `.inputValidator()`. PostgreSQL integration workflows also succeeded; they are regression checks, not clinical acceptance.
- The exact tested source commit changes only the validator method name, preserves the same Zod v3 schemas and handler bodies, and adds the source-contract test. No lockfile, database, Auth, production data, or deployment configuration changed.
- **Merge gate:** the passing evidence above belongs to source/test commit `16ea4c90...`. This follow-up updates evidence documentation only; the final PR head must still complete its own checks before merge.
- **Next:** verify exact-head checks after this documentation follow-up, then merge PR #117 only if all required checks remain green. Rebase and re-evaluate PR #109 afterward; do not merge its 35-package batch without its own full passing checks.


## TanStack validator API fix — merge and production verification (2026-10-27)

- PR [#117](https://github.com/crauch2088-source/roshan-health-hub/pull/117) merged by squash as `224e0f7bc4aa02292571b6cee5a2716502e70acf`. Exact final PR head `0837a94c799d7802a029eb1f81dc545b453a5ba0` passed: CI `40460084141`, insurance-claim integrity `40460084177`, privileged-role guard `40460084169`, prescription atomicity `40460084122`, insurance-claim UI validation `40460084187`, and PR workflow `40460081078`; all completed successfully. The combined Vercel preview status was success.
- Post-merge exact-main CI `40460217556`, finance-only RPC write isolation `40460217370`, and push-on-main `40460217140` all completed successfully on merge SHA `224e0f7bc4aa02292571b6cee5a2716502e70acf`.
- Vercel production deployment `dpl_9NgLmr4sGFvcVbcWHawKAFFo8ZHN` is `READY`, target `production`, source SHA exactly `224e0f7bc4aa02292571b6cee5a2716502e70acf`, canonical alias `roshan-health-hub.vercel.app`, and `aliasError: null`.
- The production dependency blocker is resolved at source level: the four read-only AI server functions use `.validator()`, the same Zod v3 schemas are retained, and the regression guard rejects a return to `.inputValidator()`. No lockfile or database changes were included. No production database migrations, Auth changes, patient records, or financial records were created.
- PR #109 remains open and unchanged at head `f95bc60bfb7204bd5406d6f50805c0876c6dd9b5` / base `5adfa01a6a96bd2060014a8529741bf9f7525440`, despite issuing both `/rebase` and `@dependabot rebase` comments (comment IDs `6435214209` and `6435222003`). Do not assume a rebase occurred or merge #109; verify a new head and exact-head CI first. PR #114 still has no CI run on its current head and remains unapproved.
- Issue #95 remains open. Authenticated clinical E2E/staff acceptance remains explicitly deferred until the isolated free QA environment and suitable synthetic clinician identity are available.
- **Next task:** resolve Dependabot PR #109's stale-base/rebase blocker through a supported repository workflow and rerun its exact-head CI. If the bot cannot rebase, do not hand-edit or merge the 35-package branch blindly; safely regenerate/close the grouped update only after reviewing the Dependabot policy and preserving auditability. In parallel, continue the non-authenticated source-level UX audit; do not close Issue #95 without browser evidence.


## Dependency PR #109 closure and preview-build blocker — 2026-10-27

- After merging the validator API fix, PR #109 was synced to main as head `b6d827a2d5dbb91f0ea91a7f1cd817ea99b8cf1e` on base `5c92e2fa921d7de86e2f9b1e45ba8bf92fb301c0`. Its GitHub CI `40460576126`, clinical-child RPC-only `40460576135`, finance-only RPC isolation `40460576132`, and PR workflow `40460574769` all succeeded.
- The PR was then **closed unmerged** by Dependabot at 2026-10-27T06:21:04Z, with bot comment “Looks like these dependencies are updatable in another way, so this is no longer needed.” It was not merged; main `package.json` and lockfile still pin `@tanstack/react-start@1.168.61`, `@tanstack/react-router@1.170.42`, and the pre-update dependency versions.
- The Vercel preview for the closed head failed at deployment `dpl_DVAXprPabMFRmMmHFnPKujiEXmav`: `npm install` exited with `ERR_INVALID_ARG_TYPE`, “The \"from\" argument must be of type string. Received undefined.” This failure is distinct from GitHub CI's successful `npm ci`; it is a release-reliability blocker, not proof that the update is safe to ship.
- Do not reopen or recreate the 35-package batch blindly. First reproduce/diagnose the Vercel `npm install` failure against the exact lockfile and determine why Vercel's install path differs from `npm ci`. Keep the dependency updates unapplied until both CI and Vercel preview pass on the exact head.
- This dependency failure does not roll back the separately merged `.validator()` source fix. Production code deployment for main's source commit `224e0f7bc4aa02292571b6cee5a2716502e70acf` is READY; the later main commit `5c92e2fa...` changes docs only and its deployment was canceled by the configured build-ignore rule.


## Dependabot replacement PR #118 — repeated Vercel install failure (2026-10-27)

- Dependabot opened replacement PR [#118](https://github.com/crauch2088-source/roshan-health-hub/pull/118), head `72efefa2185a9a0c56bf1b655e2ee64239264bf3`, with 36 production patch/minor updates. Exact-head GitHub CI `40460693105`, finance isolation `40460693071`, and clinical-child RPC-only `40460693076` all passed.
- Vercel preview deployment `dpl_CH8PhqNxyy7R1AXQYUKffaYJ6jGA` is `ERROR` on the same SHA. Build events show `npm install` exits with `ERR_INVALID_ARG_TYPE: The "from" argument must be of type string. Received undefined`. The same error occurred on closed, unmerged PR #109 (`dpl_DVAXprPabMFRmMmHFnPKujiEXmav`). A blocker comment was added to PR #118 (comment `6435338565`).
- Read-only lockfile comparison found six nested optional WASM package entries without `resolved`/integrity fields in both current main and the candidate; this is **not candidate-specific evidence** and does not explain the Vercel failure. No root cause has been proven.
- PR #118 remains open and **must not be merged** until the Vercel install path is diagnosed and a READY preview exists for the exact head. GitHub `npm ci` passing is insufficient because Vercel uses `npm install` during its build.
- **Next:** reproduce the Vercel install failure in a controlled, no-cost Node/npm environment using the exact candidate lockfile and capture the full npm error stack. Do not mutate production dependencies or retry deployment blindly.


## Verified closure of production patch/minor dependency batch — 2026-10-27 07:10 UTC

- PR #118 merged at `2026-10-27T07:01:41Z` into `main` commit `123bc8b92ddbc64ef236d50c6c822d030b38d390`; it is not an open blocker. The commit updated 34 direct production dependencies and the lockfile after PR #121 changed Vercel installation to `npm ci`.
- Exact-main GitHub Actions runs passed: CI `40464623894`, finance isolation `40464623888`, clinical-child RPC-only `40464623978`, push-on-main/CodeQL `40464663442`, Dependabot dynamic workflow `40464733500`. Vercel production deployment `dpl_HSXd9Ss53pMX5uvnKKBEnHLBwq2f` is READY on that exact SHA, canonical alias `roshan-health-hub.vercel.app`, alias error null.
- PR #109 remains closed unmerged. The previous `ERR_INVALID_ARG_TYPE` Vercel install failure is resolved for the merged PR #118 path; do not generalize that result to other dependency batches.
- PR #114 remains open at `9e783981e13993ee03669efc459a563c1c3c216b` and fails exact-head Typecheck in run `40465003880`: `react-day-picker` major update removes `ClassNames.table`; Recharts major update changes tooltip prop typings in `src/components/ui/chart.tsx`. Guard tests (220) and PostgreSQL integration jobs pass, but lint/build are skipped after typecheck failure. Do not merge until these API breaks are addressed or the incompatible majors are excluded and regenerated, with green exact-head checks.
- Next: prioritize Issue #95 source-level UX audit; keep the major-update PR isolated and unmerged. No production DB/Auth change or clinical/financial record was created.

## Known-incompatible UI major updates deferred — candidate (2026-10-28)

- Main baseline: `e6ecc9cf171900791862a56be415c29bc5ceba7e`. Dependabot PR [#114](https://github.com/crauch2088-source/roshan-health-hub/pull/114) is open at `9e783981e13993ee03669efc459a563c1c3c216b` on older base `123bc8b92ddbc64ef236d50c6c822d030b38d390`.
- CI [run 40465003880](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40465003880) proves the grouped npm-major batch is not mergeable: `react-day-picker` changes `ClassNames` and removes `table`; Recharts changes Tooltip typings and breaks `src/components/ui/chart.tsx`. Typecheck fails before lint/build can complete.
- Candidate Dependabot policy defers semver-major updates for those two packages until dedicated API migrations are tested; the existing TypeScript major deferral is preserved. Minor/patch updates remain enabled. The source regression guard now requires all three package-level deferrals.
- This does not alter package.json/package-lock.json and does not make the current PR #114 safe. Implementation commit [`4bd9b5b2fb73b748804d91738db50ebe911921a9`](https://github.com/crauch2088-source/roshan-health-hub/commit/4bd9b5b2fb73b748804d91738db50ebe911921a9) passed exact-head CI [40647743371](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40647743371): 25 check runs succeeded and the canonical clinical acceptance job was skipped by its explicit gate. Supporting workflows [40647738961](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40647738961), [40647743267](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40647743267), [40647756440](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40647756440), [40647743272](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40647743272), and [40647743509](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40647743509) all succeeded. Vercel skipped the non-runtime preview under the configured ignore rule; no production deployment or data/privilege changes occurred.
- Next: verify the final documentation-only head's CI, merge the policy-only PR, then close/regenerate PR #114 and review the new batch independently.



## React Hooks ESLint major update deferred — candidate (2026-10-28)

- Verified base `main` SHA: `f954fc7ac8ab1fdf8eb91e69ba01eac6ca640e76`. The latest main CI `40648290444`, finance-only RPC isolation `40648290314`, and push-on-main/CodeQL `40648290207` all completed successfully on that SHA.
- Dependabot PR [#128](https://github.com/crauch2088-source/roshan-health-hub/pull/128), head `4478f880b8a9d689fa1edb54177439a781506fe4`, failed the `Install, audit, typecheck, lint, build` job in run [40648694255](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40648694255), job `122683443594`. `npm audit` reported zero vulnerabilities and TypeScript typecheck completed, but lint failed after `eslint-plugin-react-hooks` moved from 5.x to 7.1.1. The log shows newly activated rules including `react-hooks/set-state-in-effect`, `react-hooks/use-memo`, and `react-hooks/purity` failing across existing UI and clinical components. The grouped major-upgrade PR must not merge on the strength of passing unrelated checks.
- Candidate policy adds a Dependabot ignore rule for only `eslint-plugin-react-hooks` semver-major updates. Patch/minor updates remain enabled. `tests/dependency-security.test.ts` now asserts this deferral alongside the existing TypeScript, `react-day-picker`, and Recharts major guards.
- Candidate touches only `.github/dependabot.yml`, the source regression guard, and evidence docs. It does not change `package.json`, `package-lock.json`, application runtime, database/Auth, production data, or deployment settings.
- **Status:** PR #129 candidate; exact-head CI evidence is recorded below after the formatting correction. Keep PR #128 unmerged; after this policy change is merged, close/regenerate the grouped update and inspect the remaining major upgrades on their own exact head.


## Exact-head CI formatting follow-up — 2026-10-28

- The first PR #129 CI attempt, run [40649362381](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40649362381), failed the insurance-claim UI validation workflow's shared lint step only because Prettier wanted the new four-package assertion array split across lines in `tests/dependency-security.test.ts:95`. This was a formatting failure, not an application, database, or insurance-claim assertion failure.
- Follow-up commit [`40d622786cf9a3246ad71dbfcde4ac29a521e6e1`](https://github.com/crauch2088-source/roshan-health-hub/commit/40d622786cf9a3246ad71dbfcde4ac29a521e6e1) reformatted the array without changing policy or behavior. On this exact head, CI run [40649590052](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40649590052) completed successfully: all 18 jobs completed, with 17 successful and the canonical PostgreSQL 17/authenticated clinical acceptance job intentionally skipped. The core install/audit/typecheck/lint/build job `122686287921` passed; `npm audit` and the full guard suite passed. The dynamic PR workflow [40649586575](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40649586575), CodeQL check `122686516269`, and Vercel Preview Comments check `122686293485` succeeded. Supporting exact-head workflows for privileged-role guard [40649590300](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40649590300), insurance-claim integrity [40649590025](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40649590025), and prescription atomicity [40649590113](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40649590113) also succeeded. The canonical clinical acceptance job remains skipped by its explicit gate; this is not clinical acceptance. The final refreshed check-run list contained 26 completed checks: 25 success and one intentional skip.


## Seroval serialization advisory — candidate remediation (2026-10-29)

- Verified `main` baseline: `a04022a87f29c1cb5be030252872e97034ca81c4`. Main CI run [40830639464](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40830639464) failed in the `Install, audit, typecheck, lint, build` job at `npm audit`; all 16 other jobs in that run passed or were intentionally skipped. The audit identified `seroval@1.6.9` with two moderate serialization/code-injection advisories, fixed from `1.6.11`: [GHSA-f86p-h4j2-7qgj](https://github.com/advisories/GHSA-f86p-h4j2-7qgj) and [GHSA-9wx9-5pv9-3349](https://github.com/advisories/GHSA-9wx9-5pv9-3349).
- Candidate updates only the existing transitive `node_modules/seroval` lock entry from `1.6.9` to the minimum patched `1.6.11`, using the npm registry's exact tarball URL and SHA-512 integrity. `package.json` and the dependency graph's declared ranges are unchanged; unrelated optional-package lock metadata is preserved.
- Added a regression assertion in `tests/dependency-security.test.ts` that every locked Seroval package must be at least `1.6.11`.
- Isolated Node 22.23.4 verification: `npm audit --package-lock-only` reports 0 vulnerabilities, the focused dependency-security suite passes 6/6, and the lockfile diff changes only the Seroval version/resolved/integrity fields. The sandbox's full `npm ci` was killed by its resource limit; full install/audit/typecheck/lint/build must be confirmed by exact-head GitHub Actions before merge.
- No production database/Auth/data changes were performed; the automatic post-merge production deployment is recorded below.
- **Merged:** PR [#132](https://github.com/crauch2088-source/roshan-health-hub/pull/132), exact tested head `233709c472639419a662428f797d2201a47c4be9`, squash-merged on 2026-10-29 as main SHA [`5e87e7fec219dcf82cae2748773033e2d1bcb064`](https://github.com/crauch2088-source/roshan-health-hub/commit/5e87e7fec219dcf82cae2748773033e2d1bcb064).
- Exact PR-head checks: CI [40831494295](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831494295), PR dynamic workflow [40831492745](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831492745), prescription atomicity [40831494350](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831494350), privileged-role guard [40831494245](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831494245), insurance claim UI [40831494270](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831494270), and insurance claim integrity [40831494367](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831494367) all succeeded. Final PR-head check list: 25 successful checks, one intentionally skipped canonical PG17 baseline/authenticated clinical acceptance check, zero failures. CodeQL check `123306758663` and Vercel Preview Comments check `123306693363` succeeded.
- Post-merge main checks on `5e87e7fec219dcf82cae2748773033e2d1bcb064`: CI [40831720166](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831720166), finance-only RPC isolation [40831720278](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831720278), and push-on-main/CodeQL [40831720065](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40831720065) all succeeded. The main CI job confirms install, `npm audit`, typecheck, lint, and build succeeded; the canonical clinical acceptance job remained skipped by its explicit gate.
- Vercel automatically deployed the merged lockfile patch: production deployment [`dpl_ErJoAbBCLcbXk5BtQaonpLQyaofv`](https://vercel.com/roshan45/roshan-health-hub/ErJoAbBCLcbXk5BtQaonpLQyaofv) is `READY` on the exact merge SHA, target `production`, canonical alias `roshan-health-hub.vercel.app`, `aliasError: null`. No manual deployment, database/Auth mutation, or clinical/financial record creation occurred.
- Isolated Node 22.23.4 checks before merge: `npm audit --package-lock-only` reported zero vulnerabilities, the focused dependency-security suite passed 6/6, and the lockfile diff changed only the Seroval entry. The full local `npm ci` was terminated by the temporary sandbox resource limit; exact-head GitHub Actions supplied the successful full install/audit/typecheck/lint/build evidence.
- **PR #125 branch refresh completed:** the prescription custom-fields branch now includes current main via merge commit [`76ec8c9d6ee4c9db6a8347f91b1ab3e14574f173`](https://github.com/crauch2088-source/roshan-health-hub/commit/76ec8c9d6ee4c9db6a8347f91b1ab3e14574f173). Exact-head CI [40832478523](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832478523), PR workflow [40832474200](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40832474200), and the insurance, privileged-role, and prescription-atomicity integration workflows all succeeded (26 successful checks, one explicitly skipped clinical acceptance gate, zero failures). Its Vercel preview is READY; details are recorded in `docs/PRESCRIPTION_CUSTOM_FIELDS_REVIEW_2026-10-29.md`.
- **Next:** preserve PR #125's staff-acceptance gate and Issue #95; continue only non-authenticated source-level UX review until authorized acceptance is possible. Clinical E2E remains deferred. Keep npm-major PR #131 and GitHub Actions-major PR #108 unmerged until their exact-head compatibility checks pass.
