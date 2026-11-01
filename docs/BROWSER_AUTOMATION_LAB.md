# Roshan Browser Automation Lab

## Purpose

Run repeatable browser acceptance checks against a specific Roshan Vercel deployment without using TinyFish credits. The harness uses Playwright, Chromium, and axe-core.

## Current coverage

The public-route suite checks:

- 320px, 360px, 390px, and 430px viewports.
- Root recovery to /auth or /setup.
- Arabic RTL and English LTR sign-in rendering.
- Email/password autocomplete semantics.
- Horizontal overflow.
- Public error-message disclosure.
- WCAG 2.1 A/AA automated accessibility rules on /auth and /setup.
- Unauthenticated access to /dashboard redirects to a public recovery route.

The suite intentionally does not submit credentials or mutate patient, visit, prescription, laboratory, inventory, or financial records. Authenticated role workflows are a separate QA phase.

## Local use

Install Chromium once:

```bash
npx playwright install --with-deps chromium
```

Run against a local app:

```bash
BASE_URL=http://127.0.0.1:5173 npm run test:e2e:public
```

Run against a Vercel deployment:

```bash
BASE_URL=https://your-roshan-preview.vercel.app npm run test:e2e:public
```

## GitHub Actions use

The manual Browser E2E — public routes workflow is dispatchable from `main` only and always checks out `main` with persisted credentials disabled. A candidate preview URL is supplied as data; the runner never checks out or installs the candidate branch. `scripts/validate-browser-e2e-target.mjs` accepts only the canonical production host, the verified stable project alias, the `roshan-health-hub-git-<branch-slug>-roshan45.vercel.app` branch-preview pattern, or the observed `roshan-health-<9-character-deployment-id>-roshan45.vercel.app` deployment pattern. It rejects other projects on the same Vercel team, non-HTTPS URLs, credentials, ports, paths, queries, and fragments. Positive and negative cases run in `npm run test:guard`.

The connected Vercel API does not currently expose the oidcProviders / Trusted Sources setting in its update-project schema. Therefore the manual workflow does not store or transmit a bypass credential. For a protected preview, the operator temporarily disables Vercel Authentication for the preview environment, runs the workflow, and immediately restores the original all_except_custom_domains protection setting. The test target is restricted by exact hostnames and project-specific patterns; a generic `*-roshan45.vercel.app` suffix is not accepted.

The persistent Vercel Sandbox browser lab is the primary agent-operated browser. It uses Playwright directly and can be used for detailed diagnostics and screenshots. The GitHub workflow provides a repeatable, artifact-producing run when needed. When the Vercel integration exposes Trusted Sources, prefer a GitHub OIDC rule scoped to this repository, the workflow file, and preview deployments; do not replace this with a long-lived secret in source control.

## Reports

Playwright writes:

- playwright-report/ — human-readable HTML report.
- test-results/ — traces, screenshots, video, and JSON results.

GitHub Actions uploads these as a short-retention artifact after each manual run.

## Security and operating rules

- Keep Vercel preview SSO enabled.
- Do not put bypass credentials in source files, workflow YAML, issue comments, or logs.
- Use the GitHub Actions secret store.
- The Playwright route handler attaches the bypass header only to the exact target deployment origin.
- Use a preview deployment for candidate changes. Production is read-only and must not receive synthetic data.
- Do not interpret public-route tests as authenticated clinical acceptance.
- Human staff acceptance remains a separate final gate; Issue #95 must remain open until it is completed.


## Project-specific workflow target validation

The validator rejects generic team hostnames such as `other-project-roshan45.vercel.app`, deceptive suffixes, non-HTTPS URLs, credentials, non-default ports, paths, queries, and fragments. Its regression cases run with `npm run test:guard`. Dispatch the workflow from `main` only; the runner checks out `main` regardless of the supplied preview target.
