# Free repository automation routing — 2026-11-09

## Decision

Use the already-connected GitHub connector and Composio GitHub API actions as the primary no-cost automation path for repository operations. Do not add a hosted browser-agent dependency or paid browser service for tasks that have a first-party GitHub API.

Use the repository-owned Playwright/Chromium/axe-core harness for browser tests. It is already present in the project and avoids TinyFish run credits for repeatable E2E and public-route acceptance.

Keep TinyFish as an optional fallback for genuinely browser-only workflows, authenticated visual inspection, and UI tasks that cannot be expressed reliably through APIs. Do not use it for routine branch updates, PR metadata, CI inspection, or repository reads.

## Task routing

| Task | Primary path | Fallback | Evidence required |
|---|---|---|---|
| Read repository files, branches, PRs, diffs | GitHub native connector | Composio GitHub read actions | Exact ref/SHA and returned file/diff |
| Update a PR branch from its base | Composio GitHub `GITHUB_UPDATE_A_PULL_REQUEST_BRANCH` | GitHub CLI `gh pr update-branch <number> --repo owner/repo` | API result, refreshed head SHA, compare against base |
| Inspect PR checks | GitHub connector status/workflow tools | `gh pr checks <number> --repo owner/repo` | Exact-head checks; distinguish pending, skipped, and passed |
| Repeatable app browser tests | Repository Playwright tests and GitHub Actions | Local Playwright run | Exact commit, test summary, artifacts |
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
