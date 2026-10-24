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
