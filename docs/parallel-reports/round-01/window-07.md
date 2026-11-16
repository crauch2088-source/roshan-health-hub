# Window 07 — Round 01 Report

## 1. Identity and scope

- Window: **07 — Dependency Upgrade Compatibility Review**
- Original task / Issue / PR: Review the five npm-major-updates in [PR #157](https://github.com/crauch2088-source/roshan-health-hub/pull/157).
- Round: 01
- Requested baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Current main SHA checked: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` (verified from main tree and PR base metadata at review time).
- Current task branch / PR: `dependabot/npm_and_yarn/npm-major-updates-069058e270` / PR #157.
- PR head SHA: `6dce05fdd2f47a5ad68e588d288dd50276d2b86f`
- Scope: Peer dependencies, React 19/Vite 8/TanStack Start compatibility, resolver and Lucide major changes, Node declarations, plugin-react/globals, lockfile and transitive dependency integrity, existing CI evidence, and merge recommendation.
- Explicit exclusions: No package manifest or lockfile edits; no PR approval/merge; no new CI runs; no production/QA changes.

## 2. Executive verdict

- Status: **HOLD**
- What is actually complete: Read-only compatibility review of all five direct upgrades and their resolved peer metadata; comparison of base/head lockfiles; inspection of Vite/ESLint configuration and representative Lucide imports; re-check of exact PR head and existing CI workflow results.
- What remains incomplete: Node typings alignment, visual/accessibility verification for Lucide v1, confirmation of the actual Vercel Node runtime/minor version, and focused validation of application resolver call sites.
- Work type: **Review-only**. No application implementation was performed or warranted within this review task.
- Recommendation: Do not approve PR #157 as-is. Four upgrades are eligible for acceptance with the verification notes below. Defer `@types/node@26.6.6` until declarations and the declared Node 22 runtime are intentionally aligned.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main tree](https://api.github.com/repos/crauch2088-source/roshan-health-hub/git/trees/main?recursive=1) | Verified |
| PR #157 | Open, not merged; base main | [PR #157](https://github.com/crauch2088-source/roshan-health-hub/pull/157) | Verified |
| PR head | `6dce05fdd2f47a5ad68e588d288dd50276d2b86f` | [head commit](https://github.com/crauch2088-source/roshan-health-hub/commit/6dce05fdd2f47a5ad68e588d288dd50276d2b86f) | Verified |
| Changed files | `package.json`, `package-lock.json` | PR metadata; 2 files | Verified |
| Exact-head CI | CI run 43818610433 / run #2219: success | [CI run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818610433) | Verified |
| Finance integration | Run 43818610437 / #687: success | [workflow run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818610437) | Verified |
| Clinical child RPC integration | Run 43818610444 / #476: success | [workflow run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818610444) | Verified |
| Review threads | None returned by review-thread query | PR review-thread endpoint | Verified |
| Vercel runtime target | `vercel.json` specifies `npm ci`, but no explicit Node runtime pin; no `.nvmrc` or `.node-version` found | [vercel.json](https://github.com/crauch2088-source/roshan-health-hub/blob/6dce05fdd2f47a5ad68e588d288dd50276d2b86f/vercel.json) | Repository config verified; hosted runtime not rechecked |

The current PR metadata still reports the requested baseline as its base SHA. No newer mainline commit was observed in the repository tree at this check.

## 4. Work actually performed

1. Re-read the repository's parallel continuation protocol and report template from the active protocol branch associated with [PR #261](https://github.com/crauch2088-source/roshan-health-hub/pull/261). The two protocol files are not present on the currently observed main baseline, but their contents were available on `docs/parallel-engineering-continuation-20261116`.
2. Re-fetched PR #157 metadata and confirmed it remains open, unmerged, and based on the requested SHA.
3. Re-checked exact-head workflow results; all three listed runs completed successfully. No new workflow was triggered.
4. Compared `package.json` and `package-lock.json` at base and PR head. Lockfile version remains 3; changed direct packages and resolved transitive changes were enumerated.
5. Inspected resolved peer metadata for `@hookform/resolvers`, `react-hook-form`, `zod`, `@tanstack/react-start`, `@vitejs/plugin-react`, `lucide-react`, `globals`, `@types/node`, and `@rolldown/pluginutils`.
6. Inspected `vite.config.ts`, `eslint.config.js`, `vercel.json`, and representative Lucide imports in navigation, shared UI, and setup components.
7. Created this isolated report file only. No source code, package manifest, lockfile, workflow, or other window report was changed.

## 5. Findings

### F-01 — Node 26 declarations exceed the declared Node 22 runtime line

- Severity: **Medium**
- Status: **Verified configuration skew; runtime impact not reproduced**
- Affected file/function/SQL object: `package.json`; resolved `@types/node` and `undici-types` entries in `package-lock.json`.
- Evidence and exact source/commit:
  - Base package declares `engines.node: 22.x`.
  - PR changes `@types/node` from 22.20.5 to 26.6.6 and `undici-types` from 6.21.0 to 8.9.0.
  - TanStack Start 1.169.4 declares Node `>=22.12.0`; Vite plugin-react 6.3.0 declares Node `^20.19.0 || >=22.12.0`.
- Reproduction or test: No runtime failure reproduced. The PR's exact-head CI passed. Type declarations do not change the deployed Node runtime; the risk is that compilation may permit use of Node 26-only APIs while deployment remains on Node 22.
- Impact: Potential compile/runtime contract drift and less reliable future Node API typing. This is not evidence that the current production build is broken.
- Recommended correction: Keep `@types/node` on the compatible 22.x line unless the project deliberately upgrades and pins its runtime. Also consider tightening the declared Node engine to the framework's minimum `>=22.12.0 <23` after checking hosting support.
- Required regression test: `npm ci`, `npm run typecheck`, runtime-engine guard, and exact Vercel Node version confirmation.
- Dependency / owner: Window 07 review finding; dependency/package owner to correct in a follow-up dependency PR.

### F-02 — Lucide 0.x to 1.x needs UI and accessibility acceptance

- Severity: **Medium**
- Status: **Verified major-version transition; no compile failure observed in exact-head CI**
- Affected file/function/SQL object: Lucide imports across `src/components`, `src/routes`, and `src/lib/nav-icons.tsx`.
- Evidence and exact source/commit:
  - Upgrade: `lucide-react 0.575.0 → 1.72.0`.
  - Release notes include 1.71 icon renames for circle-arrow/square-arrow families and 1.72 route-icon orientation change.
  - Representative existing imports inspected include `AlertTriangle`, `Grid2x2`, `PanelLeft`, `CalendarDays`, `Loader2`, and navigation icon mappings.
- Reproduction or test: Exact-head CI passed. A full rendered-screen, keyboard, and screen-reader pass was not performed.
- Impact: Some icon identifiers/visual orientation or accessibility defaults may change even when TypeScript and production bundling pass.
- Recommended correction: Keep the upgrade eligible, but complete focused UI/accessibility verification before operational acceptance.
- Required regression test: Build plus visual/keyboard/accessibility spot-check of dashboard, mobile navigation, pharmacy, laboratory, dialogs, and icon-only controls.
- Dependency / owner: UI owner; no code edit made in this review.

### F-03 — Resolver v7 peer compatibility is satisfactory; application behavior still needs focused coverage

- Severity: **Low**
- Status: **Peer compatibility verified; call-site behavior not exhaustively verified**
- Affected file/function/SQL object: `@hookform/resolvers`, React Hook Form and Zod form call sites.
- Evidence and exact source/commit:
  - `@hookform/resolvers@7.0.6` peer range accepts `react-hook-form ^7.55.0` and Zod `^3.25.0 || ^4.0.0`.
  - PR retains React Hook Form 7.91.0 and Zod 4.6.7.
  - Resolver v7 TypeBox migration changes to TypeBox 1.x; this is relevant only if the application uses that resolver.
- Reproduction or test: Exact-head CI passed; dedicated nested-field and Arabic validation interaction tests were not run separately.
- Impact: No peer conflict identified. Remaining risk is behavior/type inference at application form call sites.
- Recommended correction: Accept the version; add/retain focused Zod resolver regression coverage and do not migrate TypeBox unless it is actually used.
- Required regression test: Valid/invalid Zod forms, nested errors, inferred output types, and Arabic validation messages.
- Dependency / owner: Forms/UI owner.

### F-04 — Vite plugin React 6 is peer-compatible with the installed Vite 8 / React 19 stack

- Severity: **Low**
- Status: **Peer compatibility verified**
- Affected file/function/SQL object: `@vitejs/plugin-react`, `@lovable.dev/vite-tanstack-config`, `vite.config.ts`.
- Evidence and exact source/commit:
  - Plugin React 6.3.0 peer range requires Vite `^8.0.0`; project resolves Vite 8.3.5.
  - TanStack Start 1.169.4 declares Vite >=8 and React/React DOM >=18.
  - `vite.config.ts` delegates plugin registration to `@lovable.dev/vite-tanstack-config` 2.27.0 and does not itself configure Babel.
- Reproduction or test: Exact-head CI run #2219 passed. No additional local build was run.
- Impact: No peer mismatch found. The plugin's changed Babel integration warrants checking the wrapper package's effective configuration, but no project-owned Babel option was observed in the inspected config.
- Recommended correction: Accept, conditional on retaining exact-head production build and SSR evidence.
- Required regression test: `npm run build`, SSR route smoke test, and dev HMR/React refresh smoke test.
- Dependency / owner: Build tooling owner.

### F-05 — globals 17 is compatible with the project's lint usage

- Severity: **Low**
- Status: **Configuration compatibility verified; dedicated lint run not separately initiated**
- Affected file/function/SQL object: `eslint.config.js`.
- Evidence and exact source/commit:
  - ESLint imports `globals` and uses `globals.browser`.
  - `globals@17.14.0` requires Node >=18, compatible with the declared Node 22 line.
- Reproduction or test: Exact-head CI passed.
- Impact: Development-only lint global definitions; no application runtime impact identified.
- Recommended correction: Accept.
- Required regression test: `npm run lint` on the final exact head.
- Dependency / owner: Build tooling owner.

### F-06 — Lockfile changes are bounded and structurally consistent

- Severity: **Informational**
- Status: **Verified structurally**
- Affected file/function/SQL object: `package-lock.json`.
- Evidence and exact source/commit:
  - Lockfile format remains v3.
  - Root dependency declarations correspond to the PR manifest.
  - Changed direct/transitive resolutions include `@rolldown/pluginutils`, `undici-types`, and removal of Babel-related packages / `react-refresh` associated with the plugin-react upgrade.
  - Resolved package entries inspected contain integrity metadata.
- Reproduction or test: Exact-head CI passed; no separate manual `npm ci` was run.
- Impact: No broad unrelated transitive refresh was identified. The observed changes are explainable by the five direct dependency updates.
- Recommended correction: Retain lockfile as generated by npm; avoid hand-editing. Re-run npm ci through the existing CI after any Node typings correction.
- Required regression test: `npm ci` and production build on the corrected exact head.
- Dependency / owner: Dependency PR owner.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result | Notes |
|---|---|---|---|
| Mainline/PR state check | GitHub PR metadata + main tree | PASS | Current head and base rechecked |
| CI | Run 43818610433 / #2219 | PASS | Exact PR head `6dce05f` |
| Finance-only RPC integration | Run 43818610437 / #687 | PASS | Exact PR head |
| Clinical child RPC integration | Run 43818610444 / #476 | PASS | PostgreSQL 17 workflow; exact PR head |
| Lockfile structural comparison | Base/head package-lock JSON comparison | PASS | v3, root consistency, integrity entries |
| Peer dependency inspection | Resolved lockfile peer metadata | PASS | Direct peer contracts examined |
| Dedicated local `npm ci` | Not run | NOT RUN | Avoided duplicate install/CI cost |
| Dedicated local `npm run build` | Not run | NOT RUN | Existing exact-head CI build evidence used |
| Dedicated local `npm run typecheck` | Not run | NOT RUN | Existing exact-head CI evidence used |
| Visual/accessibility verification | Not run | NOT RUN | Human/browser verification still needed |
| Hosted Vercel Node runtime confirmation | Not run | NOT RUN | Repository config does not pin an exact runtime |

SKIP / NOT RUN are not counted as PASS.

## 7. Changed files and delivery

| Path | Change | Commit SHA |
|---|---|---|
| `docs/parallel-reports/round-01/window-07.md` | New isolated review report | To be filled after commit creation |

- Branch: `docs/window-07-dependency-review-round-01-20261116`
- Commit(s): Created specifically for this report.
- PR: Separate docs-only PR; review-only task, so PR #157 is not modified.
- Report file path: `docs/parallel-reports/round-01/window-07.md`
- Report commit SHA: To be filled after commit creation.
- Was the report committed with the implementation or through a separate docs-only PR? **Separate docs-only PR.**

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production or QA deployment: **No**
- Real patient, clinical, or financial data access/use: **No**
- Secret or credential changes: **No**
- PR merge / issue closure / release approval: **No**
- `package.json` or `package-lock.json` edits: **No**
- New CI runs: **No**

## 9. Risks, dependencies, and owner decisions

1. **Node typings decision:** retain Node 22 declarations or intentionally upgrade and pin the runtime. Current recommendation is to defer @types/node 26.
2. **Vercel runtime:** confirm actual Node minor version is >=22.12.0, required by the current TanStack Start and plugin-react package engines. The repo's `22.x` range and `vercel.json` alone do not prove the hosted runtime.
3. **Lucide UI acceptance:** complete rendered UI and accessibility spot-checks after the major upgrade.
4. **Resolver forms:** add focused Zod/RHF coverage if existing suite does not cover the actual call sites.

## 10. Next action

Dependency PR owner: prepare a minimal follow-up that returns `@types/node` to the Node 22 declaration line without unrelated dependency churn; then run one exact-head CI pass and confirm the Vercel Node runtime is >=22.12.0. Keep PR #157 unapproved until this is resolved and Lucide UI acceptance is recorded.

## 11. Session closeout

- Work completed in this session: continuation protocol/template adopted; current PR #157 state and exact-head CI rechecked; review evidence recorded in this isolated report.
- Work not completed: no dependency change, local build, local typecheck, visual accessibility pass, or hosted runtime check.
- Exact current state at close: PR #157 remains open and unmerged at `6dce05f`; the three queried exact-head workflow runs are green; no source/manifest/lockfile changes made.
- Recommended continuation when the owner says **"أكمل"**: re-check PR #157 and current main, confirm the Node runtime target, then proceed with the smallest Node 22 typings correction and one focused exact-head validation only if authorized.
