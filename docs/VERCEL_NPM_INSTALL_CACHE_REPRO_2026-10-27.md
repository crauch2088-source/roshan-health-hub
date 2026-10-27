# Vercel npm install cache-transition reproduction — 2026-10-27

## Decision

The blocked Dependabot dependency batch is not malformed in a clean npm install. A controlled transition from the current production dependency tree to the candidate lockfile reproduces the same npm Arborist failure seen in Vercel. Configure Vercel to use `npm ci`, and ensure changes to `vercel.json` are not swallowed by the build-ignore rule. Treat this as a verified reproduction of the failure pattern, not proof that the isolated directory is byte-for-byte identical to Vercel's internal build cache.

## Starting state

- Repository: `crauch2088-source/roshan-health-hub`
- Verified `main`: `4a1352ef4d70f40842b0856f52de91ecb9afad73`
- Main CI: run [40461822012](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40461822012) succeeded.
- Finance-only RPC isolation: run [40461821974](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40461821974) succeeded.
- Push-on-main / CodeQL: run [40461822062](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40461822062) succeeded.
- Dependabot PR [#118](https://github.com/crauch2088-source/roshan-health-hub/pull/118), candidate SHA `72efefa2185a9a0c56bf1b655e2ee64239264bf3`, contains 36 production patch/minor updates. Its Vercel preview `dpl_CH8PhqNxyy7R1AXQYUKffaYJ6jGA` failed during `npm install` with `ERR_INVALID_ARG_TYPE: The "from" argument must be of type string. Received undefined`.
- Vercel build events explicitly report restoring the cache from production deployment `9NgLmr4sGFvcVbcWHawKAFFo8ZHN` before the failing install.

## Controlled reproduction

Temporary diagnostic PR [#120](https://github.com/crauch2088-source/roshan-health-hub/pull/120) was based on `main` and did not alter app code or dependency files.

1. Run [40462698808](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40462698808) passed a clean `npm install` against only the candidate's exact `package.json` and `package-lock.json` in an isolated temporary directory using Node `v22.23.3` and npm `10.9.9`.
2. Run [40463225740](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/40463225740) repeated the clean candidate install successfully, installed the production dependency tree from source SHA `224e0f7bc4aa02292571b6cee5a2716502e70acf`, then copied the exact candidate manifest and lockfile over that warmed `node_modules` tree.
3. The warm-tree transition failed with the same `ERR_INVALID_ARG_TYPE`. The full stack points to npm's `@npmcli/arborist` `rollbackMoveBackRetiredUnchanged` path in `reify.js:1298`. The candidate's clean install succeeded immediately before that failure.
4. The standard CI run triggered by the diagnostic PR, `40463225666`, was cancelled before the deferred clinical E2E job ran. The isolated install-reproduction workflow completed independently.

This is strong evidence for a stale/warm `node_modules` reification failure rather than a lockfile that fails on a clean install. The exact Vercel internal cache cannot be inspected directly through the available build-log interface.

## Fix candidate

- `vercel.json` sets `installCommand: "npm ci"`. npm ci discards the existing `node_modules` tree and installs from the committed lockfile instead of trying to reconcile the stale tree in place.
- The Vercel `ignoreCommand` now includes `vercel.json`. Without this, a config-only change could be ignored because the old path list did not include the config file, preventing the preview from testing the new install command.
- `tests/vercel-install-command.test.ts` guards both configuration contracts and the explicit deferral gate for clinical E2E.
- The CI workflow's clinical E2E SQL job now requires a manual workflow-dispatch boolean and repository variable `CLINICAL_E2E_QA_READY=true`. The default is false; leave the variable unset until the isolated free QA environment and suitable synthetic clinician identity are confirmed.
- No production database, Auth settings, clinical/financial records, or production deployment were changed by the reproduction.

## Release gate / next step

Do not merge PR #118 while its exact-head preview is in error. Verify this configuration change through its exact-head GitHub checks and a READY Vercel preview first. Then re-evaluate the dependency batch on its current base and require a READY preview on the exact updated SHA. Keep Issue #95 open and do not claim browser or clinical acceptance.
