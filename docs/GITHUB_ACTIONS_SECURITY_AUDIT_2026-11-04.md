# GitHub Actions security audit — 2026-11-04

## Scope and baseline

- Audited all 24 tracked workflows under `.github/workflows/` at application `main` `4237e09b6350e36b89d3dd80dde049823260998d`.
- One-time static audit only. No permanent audit workflow, CI job, application dependency, database change, or production setting was added.
- Baseline `zizmor 1.32.0` (offline mode) reported 116 findings: 53 unpinned action references, 44 checkout credential-persistence findings, 18 excessive/default-permission findings, and one low-severity ad-hoc package-install finding.

## Changes

- Pinned all 53 action references to the full commit SHA of the exact upstream major-version tag observed during this audit:
  - `actions/checkout@v7` → `3d3c42e5aac5ba805825da76410c181273ba90b1`
  - `actions/checkout@v4` → `11d5960a326750d5838078e36cf38b85af677262`
  - `actions/setup-node@v7` → `949feb2413d6458794dcd2491c4babbbce0c15c1`
  - `actions/upload-artifact@v7` → `cf430e030ddbb5b0abf93d22962f4752f3646cd9`
  - `astral-sh/setup-uv@v6` → `d0cc045d04ccac9d8b7881df0226f9e82c39688e`
- Set `persist-credentials: false` on all 44 checkout steps. Workflow inspection found no `git push` or other workflow step that requires checkout to persist an authenticated remote credential.
- Added workflow-level `permissions: contents: read` to the 14 workflows that previously inherited repository-default token permissions. Existing narrower or purpose-specific permission blocks were left unchanged.

## Validation

- `actionlint 1.7.12` — passed across all 24 workflow YAML files.
- `zizmor 1.32.0` — reduced from 116 findings to one low-severity `adhoc-packages` finding in `browser-e2e.yml`.
- The remaining finding is intentionally retained: browser-test packages are installed only in the ephemeral E2E job at exact direct versions (`@playwright/test@1.64.1` and `@axe-core/playwright@4.14.0`) so Playwright and axe do not become application dependencies. A dedicated lockfile could remove the audit finding later, but would add separate test-package plumbing; it is not a release blocker.
- Zizmor ran in offline mode; online-only audits were not available in this pass. The audit is not a substitute for GitHub-hosted secret scanning or human review of future workflow changes.
- All 24 workflow files parsed successfully as YAML, and `git diff --check` passed.

## Safety boundary

Only GitHub Actions YAML and this audit record are changed. No application runtime code, Supabase schema/data/ACL, secrets, Vercel configuration, patient data, or financial records are changed. No deployment or production backup was triggered by this audit.
