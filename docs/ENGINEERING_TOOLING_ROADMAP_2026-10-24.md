# Roshan Health Hub — Engineering Tooling Roadmap

**Decision date:** 2026-10-24  
**Status:** Approved by the project owner; phased implementation underway  
**Scope:** Existing `crauch2088-source/roshan-health-hub` repository only. This is not authorization to create a parallel app, buy paid services, change production clinical data, or apply unapproved database migrations.

## Objectives

Improve dependency security, CI/workflow safety, database regression confidence, phone-first UI acceptance, accessibility, and privacy-aware operational visibility while preserving the free-tier budget and current clinical/financial safeguards.

## Baseline and guardrails

- Existing capabilities include GitHub Actions CI, CodeQL, secret scanning/push protection, npm audit and lockfile checks, application guard tests, PostgreSQL 17 synthetic integration tests, and Better Stack uptime monitoring.
- Graphify was integrated as an optional code-navigation aid; it is not a runtime dependency and does not replace source review or tests.
- Preserve the current Node 22 runtime and PostgreSQL 17 CI baseline.
- One atomic commit per logical task; group code, tests, and docs together. Squash-merge PRs and check exact-head CI before merge.
- Documentation/config-only work must avoid frontend builds where the existing workflow conditions support that safely. Do not add a duplicate workflow solely to run another linter.
- No paid tiers, Vercel quota bypasses, production test data, or production database writes for tool evaluation.
- Do not merge broad dependency updates solely because automation proposes them. Review diffs and rely on the full existing CI gates.

## Approved workstreams and acceptance criteria

### 1. Dependency maintenance — start now

**Tool:** GitHub Dependabot (not Renovate in parallel).

- Configure weekly updates for root npm dependencies and GitHub Actions.
- Group compatible minor/patch updates and keep major updates separately reviewable; cap open version-update PRs to limit CI churn.
- Verify repository-level dependency graph, Dependabot alerts, and Dependabot security updates settings. A YAML file configures version-update PRs but does not by itself switch on all security settings.
- Acceptance: configuration is valid; security settings are verified from live repository settings; update PRs pass the normal tests before merge.
- Avoid routine dependency churn that duplicates the recently completed security remediation. Do not auto-merge dependency PRs.

Official docs: https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-version-updates and https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-security-updates

### 2. GitHub Actions static security and syntax review

**Tools:** `actionlint` and `zizmor`.

- Audit existing workflow files first; reuse an existing suitable CI workflow rather than adding another workflow/job unless a real coverage gap requires it.
- Start report-only; classify findings, pin or harden actions only where justified, and preserve required-check behavior.
- Do not introduce workflow path filters that can leave required checks permanently pending. Use concurrency cancellation only for superseded runs where cancellation is safe.
- Acceptance: all existing workflows parse; findings are triaged; no secrets or permissions are broadened; CI run count does not materially increase.

References: https://github.com/rhysd/actionlint and https://github.com/woodruffw/zizmor

### 3. PostgreSQL/RLS integration coverage

**Tools:** Supabase CLI + pgTAP, building on the existing disposable PostgreSQL 17 tests.

- Inventory existing coverage first to avoid duplicate tests.
- Add pgTAP only for uncovered database contracts: RLS/role boundaries, grants, constraints, critical RPC contracts, and migration assertions.
- Run against disposable PostgreSQL 17 with synthetic identities/data. Never use production as the test database; never apply candidate migrations to production without a separate explicit release gate.
- Acceptance: a focused regression fails on a deliberately broken local/test fixture and passes after correction; existing finance and clinical concurrency/security suites remain intact.

References: https://supabase.com/docs/guides/database/testing and https://supabase.com/docs/guides/database/extensions/pgtap

### 4. Phone-first browser acceptance and accessibility

**Tools:** Playwright + axe-core.

- Add a small number of stable browser journeys, not a large brittle screenshot suite: sign-in/role gating where a supported QA identity exists, reception/patient search, visit navigation, lab workflow, invoice/prescription visibility, and forbidden-role boundaries.
- Cover Arabic RTL and English LTR, narrow mobile viewport, keyboard/focus, labels/errors, and dialogs.
- Use isolated preview/test configuration and synthetic data only. Do not manufacture production staff identities or clinical records. Authenticated staff E2E stays gated until an authorized QA identity and supported login path are available.
- axe-core findings are triaged by severity; automated checks complement, not replace, manual review.
- Acceptance: critical unauthenticated/role-boundary checks run without production credentials; supported test journeys are deterministic; no real patient data is captured in traces/screenshots.

References: https://github.com/microsoft/playwright and https://github.com/dequelabs/axe-core

### 5. SQL style and supply-chain posture

**Tools:** SQLFluff (report-only first) and OpenSSF Scorecard.

- Run SQLFluff against a carefully selected subset first; assess parser limitations with PL/pgSQL, dynamic SQL, and project conventions before making it merge-blocking.
- Run Scorecard as a periodic/report-only posture check; prioritize actionable permission, token, and workflow risks over chasing a perfect score.
- Semgrep, Gitleaks, Trivy, Renovate, and OWASP ZAP are optional alternatives/follow-ups only if a demonstrated gap remains. Avoid duplicating CodeQL and GitHub secret scanning. ZAP scans must be passive/baseline against an isolated synthetic-data staging target, never random active scans against production.
- Acceptance: no redundant scanners or new paid dependencies; findings are reviewed against actual repository risks.

References: https://github.com/sqlfluff/sqlfluff and https://github.com/ossf/scorecard

### 6. Monitoring, analytics, performance, and PWA

- Verify Better Stack uptime status and target; uptime alone is not proof that login, clinical workflows, or database operations work.
- Inspect PostHog SDK/config before enabling analytics. Never send patient identifiers, clinical text, financial details, tokens, request bodies, sensitive URLs/query strings, or replay of clinical screens. Keep PostHog off until privacy-safe capture is demonstrated.
- Use Lighthouse for targeted mobile performance/accessibility diagnostics.
- Evaluate Workbox/offline behavior only after auditing the current PWA. Do not cache clinical records offline without a reviewed security model, expiry, and logout-clearing behavior.
- Acceptance: no sensitive telemetry, no duplicate uptime monitors, no paid services, and no production test transactions.

## Execution sequence

| Stage | Work | Gate |
|---|---|---|
| 1 | Add Dependabot weekly configuration and this roadmap | Review configuration; exact-head CI |
| 2 | Verify live Dependabot/security settings; audit existing Actions workflows with actionlint/zizmor | Report-only results, no duplicate workflows |
| 3 | Map uncovered SQL contracts; add focused pgTAP/PG17 tests and SQLFluff report-only checks | Disposable database tests pass |
| 4 | Add minimal Playwright + axe-core acceptance coverage | Synthetic-data preview only; authorized QA identity required for authenticated paths |
| 5 | Review Better Stack, PostHog privacy, Lighthouse/PWA findings, Scorecard | Document evidence and remaining blockers |

## Current limitations / explicit non-claims

- Repository configuration cannot prove repository-level Dependabot security toggles are enabled; those settings must be read from GitHub.
- A green CI run is not a substitute for authorized staff acceptance of real clinical workflows.
- Static scanners, Graphify, synthetic PostgreSQL tests, and uptime checks do not establish clinical readiness.
- No production database migration, Auth identity creation, clinical/financial write, or deployment is part of Stage 1.
