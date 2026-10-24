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
