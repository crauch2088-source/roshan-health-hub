# Free repository automation routing — 2026-11-09

## Decision

Use the already-connected GitHub connector and Composio GitHub API actions as the primary no-cost automation path for repository operations. Do not add a hosted browser-agent dependency or paid browser service for tasks that have a first-party GitHub API.

Use the repository's Playwright configuration and npm scripts as the intended browser-test path, but first verify the test runner dependency. On 2026-11-09, `playwright.config.ts` and `test:e2e` / `test:e2e:public` scripts exist, while `@playwright/test` is absent from `package.json`, `package-lock.json`, and `bun.lock`. Therefore the E2E harness is currently scaffolded but not proven runnable; do not claim browser tests pass or use it as a ready replacement until the dependency and lockfile are added in a separately tested PR.

Keep TinyFish as an optional fallback for genuinely browser-only workflows, authenticated visual inspection, and UI tasks that cannot be expressed reliably through APIs. Do not use it for routine branch updates, PR metadata, CI inspection, or repository reads.

## Task routing

| Task | Primary path | Fallback | Evidence required |
|---|---|---|---|
| Read repository files, branches, PRs, diffs | GitHub native connector | Composio GitHub read actions | Exact ref/SHA and returned file/diff |
| Update a PR branch from its base | Composio GitHub `GITHUB_UPDATE_A_PULL_REQUEST_BRANCH` | GitHub CLI `gh pr update-branch <number> --repo owner/repo` | API result, refreshed head SHA, compare against base |
| Inspect PR checks | GitHub connector status/workflow tools | `gh pr checks <number> --repo owner/repo` | Exact-head checks; distinguish pending, skipped, and passed |
| Repeatable app browser tests | Existing Playwright config/scripts after dependency repair | TinyFish only for a narrowly scoped visual check | Exact commit, test summary, artifacts; currently blocked by missing `@playwright/test` dependency |
| Authenticated browser-only console workflow | TinyFish, narrowly scoped | Manual owner action | Explicit target, bounded action list, before/after state |
| Web research / official docs | Official documentation and Context7 | Firecrawl for broad multi-page research | Source URL, version/date, evidence |

## Safe branch-update procedure

1. Read the current PR metadata and record its exact `head.sha`, base branch, and base SHA.
2. Compare the exact head with the current base. Do not rely on stale PR metadata.
3. Call GitHub's update-branch operation with `expected_head_sha` set to the observed head SHA.
4. If GitHub reports conflicts, stop. Do not force-push, rewrite published history, or bypass the conflict by retargeting the PR.
5. Refresh PR metadata after an accepted asynchronous update.
6. Verify that the refreshed head contains the current base (compare status `ahead`, `behind=0`) and inspect exact-head CI.
7. Keep the PR Draft unless separately reviewed and explicitly authorized for merge.

## Cost and security boundaries

- No new runtime dependency, external browser service, paid subscription, API key, or Vercel build is required for this routing decision.
- Prefer GitHub API operations over visual automation when both can perform the task.
- Never expose tokens, cookies, environment values, patient data, clinical notes, or financial records in logs or prompts.
- Never run production database writes, apply migrations, change grants/RLS/Auth/Storage, or promote production deployments as part of routine automation.
- Do not force-push or auto-merge. Keep one coherent change bundle and preserve the repository's quota-safe CI policy.
- A successful API request to update a branch is asynchronous; verify the resulting commit and compare before reporting completion.

## Repository capabilities already present

- `npm run test:guard` is the fast source/contract guard suite.
- `npm run typecheck`, `npm run lint`, and `npm run build` are the repository checks.
- `npm run test:e2e` runs Playwright E2E.
- `npm run test:e2e:public` runs the public-route Playwright suite.
- The browser E2E target validator and manual main-only workflow constrain target selection and avoid running untrusted candidate manifests.

## Official references

- GitHub CLI PR branch update: https://cli.github.com/manual/gh_pr_update-branch
- GitHub REST update-branch endpoint: https://docs.github.com/en/rest/pulls/pulls#update-a-pull-request-branch
- Playwright: https://playwright.dev/


## Verified gap found during rollout

- The repository has `playwright.config.ts` and npm scripts `test:e2e` / `test:e2e:public`, but `@playwright/test` is not declared in `package.json`, `package-lock.json`, or `bun.lock` as of 2026-11-09. The scripts are not a verified runnable browser-test harness yet. Add the dependency and regenerate the canonical lockfile in a dedicated, tested change before routing release acceptance through Playwright.
