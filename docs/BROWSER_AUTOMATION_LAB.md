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

The manual Browser E2E — public routes workflow accepts one exact Roshan deployment URL. It checks out the trusted test harness from main, not the candidate PR branch, so candidate code is executed only inside the browser.

The connected Vercel API does not currently expose the oidcProviders / Trusted Sources setting in its update-project schema. Therefore the manual workflow does not store or transmit a bypass credential. For a protected preview, the operator temporarily disables Vercel Authentication for the preview environment, runs the workflow, and immediately restores the original all_except_custom_domains protection setting. The test target is restricted to Roshan-owned Vercel deployment hostnames.

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
