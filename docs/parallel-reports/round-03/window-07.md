# Window 07 — Round 03 Report

## 1. Identity and scope

- Window: **07 — Dependency compatibility**
- Original task / PR: [PR #157](https://github.com/crauch2088-source/roshan-health-hub/pull/157)
- Round: **03**
- Main baseline SHA: `79d81f08f6567f5145f7143e3bf5afdd6e93bf59`
- Candidate head SHA: `6dce05fdd2f47a5ad68e588d288dd50276d2b86f`
- Scope: Deepen the previous review using exact Vercel build events, GitHub CI job details/logs, and a like-for-like dependency-audit baseline check.
- Exclusions: No dependency/source edits, no PR approval/merge, no new CI run, no production/QA writes or deployments, no human visual acceptance claim.

## 2. Executive verdict

- Status: **CONDITIONAL ACCEPTANCE FOR BUILD/TYPE COMPATIBILITY; UI ACCEPTANCE STILL OPEN**
- What is complete: Candidate's exact PR-head GitHub CI is green; its dedicated Node setup job used Node 22.23.4 and passed install, security audit gates, typecheck, lint, and build; Vercel built and deployed the exact candidate commit with the `nodejs22.x` runtime; a pre-candidate mainline deployment produced the same 7-moderate npm audit count, and the intervening mainline commits changed documentation/specification files only.
- What remains incomplete: Lucide 1.72 visual/keyboard/accessibility acceptance has not been run. Vercel build logs expose runtime major `nodejs22.x`, not the exact Vercel Node minor. This does not block the observed build, but the minor remains unverified.
- This round is review-only; no application implementation was changed.

## 3. Repository state verified

| Item | Exact value | Evidence / link | Status |
|---|---|---|---|
| Main SHA | `79d81f08f6567f5145f7143e3bf5afdd6e93bf59` | [main](https://github.com/crauch2088-source/roshan-health-hub/tree/main) | Verified |
| PR #157 | Open, unmerged; head `6dce05fdd2f47a5ad68e588d288dd50276d2b86f`; base main SHA | [PR #157](https://github.com/crauch2088-source/roshan-health-hub/pull/157) | Verified |
| Candidate changed files | `package.json`, `package-lock.json` only | GitHub PR file list + diff | Verified |
| GitHub CI | Run 43818610433, all 19 jobs successful | [CI run](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/43818610433) | Verified |
| Node used by CI | `v22.23.4` | CI job 133136243260 log | Verified |
| Vercel preview | READY, deployment `dpl_3sJUxaxKjxA1KRjk37AfRFaoma1h`, commit `6dce05f...` | [Preview](https://roshan-health-hub-git-dependabot-npmandyarnnpm-979373-roshan45.vercel.app) | Verified |
| Vercel runtime | `nodejs22.x` | Exact candidate deployment build log | Verified (major only) |
| Earlier mainline audit comparator | READY deployment `dpl_G9jScsLW3jDXFePVZLQgedwMMKRH`, commit `a904060...` | Vercel build events | Verified |
| Changes between comparator and exact main baseline | Seven commits; changed files are docs/specs only, no package manifest or lockfile | GitHub compare API `a904060...79d81f0` | Verified |
| Round-01 report PR #268 | Open, unmerged | [PR #268](https://github.com/crauch2088-source/roshan-health-hub/pull/268) | Verified |
| Round-02 report PR #270 | Open, unmerged | [PR #270](https://github.com/crauch2088-source/roshan-health-hub/pull/270) | Verified |

## 4. Work actually performed

1. Rechecked main, PR #157, PR #270, and the round-02 report; no candidate head or base movement was found.
2. Re-fetched the full PR diff and confirmed the dependency change remains limited to `package.json` and `package-lock.json`.
3. Retrieved the exact candidate Vercel build events. The log confirms:
   - Vercel cloned PR head `6dce05f`.
   - `npm ci` added 417 packages and completed.
   - Vercel/Nitro selected `nodejs22.x`.
   - Vite 8.3.5 transformed 2,522 modules.
   - Build completed and deployment completed.
4. Inspected the exact-head CI jobs. All 19 jobs succeeded. The dedicated install/audit/typecheck/lint/build job explicitly set up Node 22 and passed all steps.
5. Retrieved that job's raw logs and confirmed the exact CI Node version was `v22.23.4`.
6. Compared the npm audit warning against an earlier mainline Vercel deployment. Both builds reported exactly 7 moderate vulnerabilities. GitHub compare confirms that the seven commits between the earlier deployed SHA and the exact current main baseline changed docs/specs only; no dependency manifest or lockfile changed. Therefore, the observed count of seven moderate vulnerabilities is pre-existing, not introduced by PR #157.
7. Created this isolated round-03 report. No source, package, lockfile, workflow, or environment setting was modified.

## 5. Findings

### F-01 — Candidate passes the Node 22 build/typecheck path

- Severity: **Informational / compatibility evidence**
- Status: **Verified PASS**
- Affected components: Node 22 toolchain, Vite 8.3.5, `@vitejs/plugin-react@6.3.0`, `@types/node@26.6.6`.
- Evidence:
  - CI job 133136243260: `Set up Node.js 22`, install, production and full-tree security audit gates, Typecheck, Lint, Build all succeeded.
  - Raw job log: `Found in cache @ /opt/hostedtoolcache/node/22.23.4/x64`; `node: v22.23.4`.
  - Exact candidate Vercel deployment log: `[nitro:vercel] Using nodejs22.x runtime`; Vite 8.3.5 transformed 2,522 modules; build and deployment completed.
- Impact: The prior concern that the candidate could not build on Node 22 is not supported by the observed evidence. This is a real successful Node 22 build/typecheck, not merely a peer-dependency inference.
- Residual caveat: The declaration package is Node 26 while the actual runtime is Node 22. No runtime failure has been reproduced. The CI typecheck passing shows current source compiles, but it cannot by itself prove no future code could call a Node 26-only API.
- Recommendation: Do not treat this mismatch as a demonstrated blocker. Prefer aligning `@types/node` with Node 22 in a future coordinated dependency update for declaration/runtime accuracy, or explicitly document why the newer types are safe. No unilateral package edit is made in this review window.
- Required follow-up: If keeping Node 26 declarations, audit server/runtime imports for use of APIs newer than Node 22 before merge.

### F-02 — Seven moderate npm audit findings are pre-existing

- Severity: **Low / informational for this PR**
- Status: **Verified pre-existing baseline**
- Affected component: Complete npm dependency tree.
- Evidence:
  - Candidate PR #157 Vercel build: `7 moderate severity vulnerabilities`.
  - Earlier mainline Vercel build at `a9040601702972bdf144fc96b9658eebd5a6d31a`: also `7 moderate severity vulnerabilities`.
  - The GitHub comparison from `a904060...` to exact main baseline `79d81f0...` is seven commits and contains only documentation/specification files; neither `package.json` nor `package-lock.json` changed in that interval.
  - Candidate CI's production dependency audit (blocking) and complete dependency audit (high/critical blocking) both passed.
- Impact: The count of seven moderate findings is not a new regression introduced by this upgrade. It remains a repository-wide security-maintenance item.
- Recommendation: Track the moderate advisories separately with package/advisory-level triage. Do not block this dependency PR solely on the unchanged count. Do not run `npm audit fix` indiscriminately.
- Required regression test: Keep the existing blocking production and high/critical audit gates.

### F-03 — Lucide 1.72 visual/accessibility acceptance remains outstanding

- Severity: **Medium**
- Status: **Not tested**
- Affected components: Icon glyphs, navigation, icon-only buttons, dialogs, and RTL/LTR views.
- Evidence: PR #157 upgrades `lucide-react 0.575.0 → 1.72.0`; exact-head CI and Vercel build pass, but neither validates rendered icon orientation, accessible names, focus behavior, or visual regressions.
- Impact: Build compatibility is established; UX/accessibility compatibility is not.
- Recommendation: Keep a separate human/browser acceptance gate for dashboard, mobile navigation, pharmacy, laboratory, dialogs, and icon-only controls, in RTL and LTR.
- Required test: Keyboard navigation, accessible names, and screenshots at phone and desktop breakpoints.

## 6. Tests and validation

| Test / workflow | Exact command or run ID | Result | Notes |
|---|---|---|---|
| GitHub CI | Run 43818610433 | PASS | 19/19 jobs |
| Node setup | Job 133136243260 | PASS | Exact Node v22.23.4 |
| Install from lockfile | Job 133136243260 | PASS | Exact candidate lockfile |
| Production dependency security audit | Job 133136243260 | PASS | Blocking gate |
| Full dependency audit (high/critical) | Job 133136243260 | PASS | Blocking gate |
| Typecheck | Job 133136243260 | PASS | Exact candidate head |
| Lint | Job 133136243260 | PASS | Exact candidate head |
| CI build | Job 133136243260 | PASS | Exact candidate head |
| Vercel `npm ci` | Deployment `dpl_3sJUxaxKjxA1KRjk37AfRFaoma1h` | PASS | 417 packages installed |
| Vercel build/deploy | Same deployment | PASS | Node 22.x, Vite 8.3.5, 2,522 modules transformed |
| Audit baseline comparison | Deployment `dpl_G9jScsLW3jDXFePVZLQgedwMMKRH` + GitHub compare | PASS | Same 7 moderate; no dependency files changed between baseline and main |
| Visual/accessibility acceptance | Not run | NOT RUN | Requires browser/human review |
| Runtime API audit for Node 26-only calls | Not run | NOT RUN | Residual declaration/runtime hygiene |

NOT RUN is not counted as PASS.

## 7. Changed files and delivery

| Path | Change | Commit |
|---|---|---|
| `docs/parallel-reports/round-03/window-07.md` | New isolated round-03 review report | `b2fa1fcb83fc34124cdd72d48045764dba156501` (creation commit) |

- Branch: `docs/window-07-dependency-review-round-03-20261116`
- Delivery: Separate documentation-only PR because this task is review-only; PR number and final head SHA are supplied with the delivery confirmation.
- No application, package, lockfile, or workflow files changed.

## 8. Safety and actions not performed

- Production or QA database writes: **No**
- Hosted migrations / ACL / RLS changes: **No**
- Production deployment initiated: **No**
- New Vercel deployment initiated: **No** (only inspected existing candidate preview logs)
- New CI run initiated: **No**
- Package manifest / lockfile edits: **No**
- PR #157 approval or merge: **No**
- Secret or credential changes: **No**
- Patient/clinical/financial data accessed: **No**

## 9. Risks, dependencies, and owner decisions

1. **Lucide UI acceptance — Medium:** outstanding; this is the only remaining concrete acceptance gate identified for the icon major upgrade.
2. **Node declarations — Low:** Node 26 typings are used while runtime is Node 22. Candidate CI on Node 22.23.4 and Vercel's Node 22.x build pass. Align types with Node 22 or audit for Node 26-only API use; no present runtime failure is demonstrated.
3. **Moderate audit findings — Existing maintenance item:** 7 moderate findings are already present in the earlier mainline dependency tree; not a new PR regression. High/critical blocking gates pass.
4. **Shared dependency files:** any package/lockfile change must be coordinated by the repository owner, not performed independently by this review window.

## 10. Next action

Complete a focused visual and accessibility acceptance pass for Lucide 1.72 (RTL/LTR, mobile/desktop, icon-only controls, keyboard/focus/accessibility names). In parallel, have the dependency owner decide whether to align `@types/node` to Node 22 or record the Node 26 declaration exception after checking runtime imports. Do not block on the unchanged 7 moderate audit count alone. Re-run CI only if dependency files are actually changed.

## 11. Session closeout

- Work completed: verified exact candidate CI job details and Node 22.23.4; inspected exact Vercel build/deploy events; confirmed successful candidate build on `nodejs22.x`; compared npm audit warning to an earlier mainline deployment and proved the same 7 moderate findings existed before PR #157; created this round-03 report.
- Work not completed: no visual/accessibility acceptance, no Node 26-only API audit, no package changes, no approval/merge.
- Exact state at close: main remains `79d81f08...`; PR #157 remains open at `6dce05f...`; candidate CI and Vercel preview build are successful; 7 moderate audit findings are pre-existing; Lucide visual/accessibility acceptance remains outstanding.
- Recommended next continuation: recheck PR #157 and report PRs; complete the Lucide UI acceptance gate; record final dependency compatibility recommendation without repeating already-completed CI/build checks.
