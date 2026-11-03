# Roshan Health Hub — Engineering Improvement Execution Plan

**Decision date:** 2026-11-03  
**Status:** Proposed execution baseline; owner requested the plan and documentation.  
**Repository:** `crauch2088-source/roshan-health-hub`  
**Baseline reviewed:** `main` at `e3fa0febb7d27b21bfdf169d75a945b5aad5b71e`  
**Related plan:** `docs/ENGINEERING_TOOLING_ROADMAP_2026-10-24.md`

## 1. Executive decision

Execute the engineering improvements as one controlled programme, in dependency order, without creating a parallel application or introducing paid services. The first objective is to make database changes reproducible and verifiable; the second is to reduce CI cost and improve security; the third is to prove end-to-end clinical workflows in isolated QA; the fourth is operational resilience and measured performance. FHIR compatibility and deeper interoperability are deliberately later, exploratory work.

This document refines the 2026-10-24 tooling roadmap using the repository and integration state reviewed on 2026-11-03. It does not supersede the clinical feature roadmap (Phases 53–56) or authorize production database writes, new paid subscriptions, staff identity creation, or clinical launch.

## 2. Current baseline and evidence

### Repository and delivery

- Main branch at review: `e3fa0febb7d27b21bfdf169d75a945b5aad5b71e`.
- Existing stack: React, TypeScript, Tailwind, Supabase, Vercel; preserve Node 22 and PostgreSQL 17 baselines.
- Existing GitHub Actions inventory reviewed: 20 workflow files; the main `.github/workflows/ci.yml` contains 21 jobs and 15 PostgreSQL service declarations. This is a reason to profile and consolidate carefully, not proof that every database service is redundant.
- Existing workflow already uses Node/npm caching and concurrency cancellation. Do not add duplicate caching or another CI system without evidence.
- Existing coverage includes CodeQL, secret scanning/push protection, npm audit/lockfile checks, application guard tests, PostgreSQL 17 synthetic tests, Playwright/Chromium and axe-core.
- Graphify is already integrated as an optional code-navigation tool; keep it out of runtime and default CI.

### Connected services

- GitHub, Supabase (production and isolated QA), Vercel, Better Stack, PostHog, Linear, Figma/Product Design, Lovable, Replit, Context7 and TinyFish are available in the existing tool ecosystem.
- Better Stack already monitors the canonical production URL `https://roshan-health-hub.vercel.app/` (monitor ID `5086672`, 180-second interval, EU and Asia checks). A previous incident referenced an obsolete Vercel URL and was resolved. Do not create duplicate uptime monitors.
- PostHog must remain disabled for clinical-screen analytics/replay until privacy review proves that no patient identifiers, clinical text, financial information, tokens, request bodies or sensitive URLs can be captured.
- The free Supabase organization tier does not provide the same scheduled backup capability as paid tiers. A verified logical backup and restore drill is a precondition for real patient data. Do not claim a backup exists until an actual export is produced and restore-tested.

### Database integrity context

Recent forensic work found a malformed Phase 49 idempotency table and inaccurate migration-ledger entries. A remediation was attempted on both environments and core function fingerprints were compared. The ledger still contains superseded/placeholder history, so this plan treats migration provenance and full schema parity as an open release gate until a fresh independent audit confirms the state. A handful of matching RPC fingerprints does not prove complete schema parity, RLS correctness, or operational readiness.

### Clinical readiness context

Automated public-route and browser checks do not prove authenticated role workflows. Authenticated staff UAT on phone-sized devices and clinical sign-off remain separate gates before live use. Production must never be used as an automated test target.

## 3. Programme guardrails

1. **No paid services or tier upgrades** without a separate explicit decision.
2. **No production test data or test transactions.** Use disposable local PostgreSQL 17 and the isolated QA Supabase project.
3. **No destructive production database changes** as part of this tooling programme. Production migration work requires a separate change plan, verified backup/restore, exact SQL review and release approval.
4. Preserve Node 22, PostgreSQL 17, existing security boundaries, branch isolation, audit history, money precision and idempotent clinical/financial RPC behavior.
5. Do not weaken required checks, bypass branch protection, auto-merge dependency updates, or add workflow path filters that can leave required checks pending.
6. Do not add overlapping tools (e.g. Dependabot and Renovate together; multiple uptime vendors; duplicate scanners) when existing tools already cover the need.
7. Use one atomic PR per logical work package; bundle code, tests, configuration and documentation. Check CI on the exact PR head before merge.
8. Keep all generated artifacts, traces, screenshots and test data synthetic. Do not upload database dumps, secrets or patient data to GitHub or AI services.
9. Every tool must have a stated job, owner, cost, data access boundary and removal criterion.
10. Tool adoption is evidence-driven: report-only first, blocking only after false positives and coverage are understood.

## 4. Target architecture for the improvement programme

| Concern | Primary mechanism | Supporting mechanism | Explicit non-goal |
|---|---|---|---|
| Source control and review | GitHub PRs and required checks | Dependabot, CodeQL, actionlint, zizmor, Scorecard | A second issue tracker or CI platform |
| Database lifecycle | Supabase CLI and reviewed SQL migrations | PostgreSQL 17, pgTAP, schema diff | Blindly rebuilding production history |
| Browser acceptance | Existing Playwright + axe-core | Lighthouse, TinyFish only for special interactive checks | Capturing real patient screens |
| Observability | Existing Better Stack | Privacy-safe aggregate health endpoint; PostHog only after approval | Session replay of clinical workflows |
| Code understanding | Existing Graphify | Context7 for version-specific docs | Runtime dependency or mandatory per-commit graph rebuild |
| Performance | Lighthouse and k6 against QA | Browser profiling | Load testing production |
| Interoperability | FHIR R4 mapping study | Medplum/OpenMRS reference review | Replacing Supabase or rewriting the EMR now |

## 5. Phased execution plan

Effort estimates below are planning ranges in focused engineering days, not delivery promises. Several tasks can be prepared in parallel, but phase gates must be respected. Work should be performed by the available coding agent/tooling on a branch, with owner review at each release gate.

### Phase A — Establish trustworthy database lifecycle (P0)

**Estimate:** 3–6 focused engineering days  
**Goal:** Every environment can be rebuilt and compared from canonical migration sources.

Tasks:
1. Inventory every SQL migration/source file, manifest entry, Supabase migration-ledger row, live schema object and applied migration identifier for QA and production. Preserve raw evidence in a non-secret report.
2. Identify all historical placeholder, duplicate, missing and out-of-order ledger records. Do not edit the ledger until each record is mapped to an exact canonical source file/version and its physical effects are understood.
3. Establish a clean, disposable local Supabase CLI workspace on a dedicated branch. Do not bulk-move or rename historical migrations. Define a forward-only baseline strategy for legacy history with explicit provenance.
4. Build a reproducible PostgreSQL 17 test database from the proposed canonical chain. Confirm a clean reset/replay succeeds without manual SQL Editor steps.
5. Compare the replayed schema with QA using reviewed schema-diff output. Classify each difference as expected, drift, environment-specific or unresolved. Do not apply generated diff SQL automatically.
6. Run an independent read-only parity audit for tables, columns, constraints, indexes, functions, triggers, RLS policies, grants, extensions and migration history.
7. Document a controlled repair procedure for ledger discrepancies, including how to archive evidence and how to avoid falsely marking a migration as applied.

Tools:
- Supabase CLI (local development, migration list, db reset, db diff/dump).
- PostgreSQL 17 disposable instance.
- pg-delta as an evaluation-only diff engine; compare output with the current supported CLI behavior before adoption.
- Existing manifest and migration reconciliation documents.

Acceptance gates:
- Fresh local reset/replay is deterministic.
- Canonical migration filenames and ledger identifiers are traceable one-to-one, with documented legacy baseline exceptions.
- QA schema diff has no unexplained differences.
- RLS/grants/functions are checked, not just table counts.
- No production writes were needed for this phase.
- A verified logical export and restore drill is separately completed before any real patient data is introduced.

### Phase B — Reduce CI duration and waste safely (P0)

**Estimate:** 2–4 focused engineering days  
**Goal:** Preserve coverage while reducing duplicated PostgreSQL setup and unnecessary builds.

Tasks:
1. Capture a baseline from recent Actions runs: per-workflow frequency, job duration, queue time, failure rate, PostgreSQL service startup time, artifact size and rerun frequency.
2. Build a dependency map of the 21 jobs in main `ci.yml`. Identify jobs with genuinely independent schemas/fixtures versus jobs that can safely share a PostgreSQL 17 service.
3. Prototype grouping in a branch: one PostgreSQL service per compatible test group, isolated databases/schemas per test suite, deterministic cleanup, and no shared mutable fixtures between parallel tests.
4. Keep concurrency, npm cache and Node 22 setup already present. Do not add duplicate cache actions.
5. Use change detection inside workflows to skip only expensive, clearly irrelevant jobs. Keep required checks reporting a successful/skipped conclusion; do not use unsafe event-level path filters that leave checks pending.
6. Separate documentation-only/config-only work from application build/test paths where existing workflow architecture permits, while retaining SQL/config validation when relevant.
7. Measure before/after median and p90 CI duration, total runner minutes and failure/flakiness rates across a representative sample.
8. Preserve isolated tests for concurrency, idempotency, finance precision, branch isolation and security boundaries even if they cost more.

Acceptance gates:
- No reduction in required clinical/financial/security assertions.
- Exact-head PR checks remain deterministic and required checks do not hang pending.
- Demonstrable reduction in PostgreSQL startup/runner time or a documented reason why grouping is unsafe.
- No increase in flaky tests or hidden skipped coverage.

### Phase C — Workflow and dependency supply-chain hardening (P1)

**Estimate:** 1–3 focused engineering days  
**Goal:** Detect GitHub Actions defects and dependency risks without creating CI noise.

Tasks:
1. Run actionlint against all existing workflow YAML in report-only mode.
2. Run zizmor against all existing workflows in report-only mode.
3. Triage every finding by exploitability and actual permissions/token exposure; record accepted false positives with rationale.
4. Correct high-confidence issues in one atomic PR: least-privilege GITHUB_TOKEN permissions, pinned third-party actions where appropriate, safe artifact handling, untrusted PR context handling and secret boundaries.
5. Verify Dependabot configuration for root npm and GitHub Actions. Group compatible minor/patch updates; keep major updates separate; cap open update PRs.
6. Verify live GitHub dependency graph, Dependabot alerts and security-update settings; do not infer those settings from YAML alone.
7. Evaluate OpenSSF Scorecard periodically/report-only. Prioritize actionable branch protection, token, workflow and dependency issues rather than chasing a numerical score.
8. Keep CodeQL and secret scanning; do not add redundant Gitleaks/Semgrep/Trivy scanners unless a specific uncovered risk justifies one.

Acceptance gates:
- All workflow files parse.
- No unresolved high-severity actionable zizmor finding without an explicit exception.
- Dependabot update configuration is valid and does not auto-merge.
- Existing CI count does not materially increase solely to run scanners.
- Security settings are verified from GitHub, not assumed.

### Phase D — Database contract testing with pgTAP (P1)

**Estimate:** 2–4 focused engineering days  
**Goal:** Prove database behavior and authorization, not merely object existence.

Tasks:
1. Map existing SQL/PG17 tests to RLS policies, role grants, constraints, RPC signatures, branch isolation and idempotency behavior.
2. Identify only uncovered contracts; do not duplicate existing SQL/TypeScript tests.
3. Add pgTAP tests for selected high-risk contracts: unauthenticated denial, role-specific access, cross-branch denial, function execute privileges, constraint enforcement, idempotency/retry behavior and migration postconditions.
4. Use disposable synthetic identities and fixtures. Never point tests at production.
5. Add a negative-control demonstration: intentionally break one isolated fixture/policy and prove the relevant test fails, then restore and prove it passes.
6. Integrate pgTAP into the existing database test workflow or a compatible existing job; do not create a parallel CI pipeline by default.
7. SQLFluff remains report-only initially, scoped to conventional SQL files. Assess PL/pgSQL and project-specific syntax false positives before making it blocking.

Acceptance gates:
- Every added test covers a documented gap.
- Positive and negative test cases behave as expected.
- Existing finance, inventory, clinical concurrency and security suites remain green.
- No production identity, record or write is involved.

### Phase E — Authenticated clinical browser journeys (P1)

**Estimate:** 3–6 focused engineering days, dependent on QA identity setup  
**Goal:** Test role-aware workflows from the phone UI through the database.

Tasks:
1. Verify the supported QA authentication mechanism and test-user lifecycle. Use dedicated synthetic accounts only; no real staff identities or reused production credentials.
2. Define role fixtures for Reception, GP, Lab Doctor, Lab Assistant, Pharmacist and Admin, only where the corresponding QA roles and permissions are implemented.
3. Build a small number of deterministic Playwright journeys: registration/search → queue → consultation → lab order/result → prescription → dispense → invoice/payment → audit trail, selecting only supported complete workflows.
4. Add negative paths: unauthorized route access, cross-branch record access, forbidden role action, duplicate submission/retry and expired session.
5. Cover Arabic RTL and English LTR at 320–430px; verify focus, keyboard behavior, accessible names, validation errors and dialog handling with axe-core.
6. Ensure traces, videos, screenshots and test reports contain synthetic records only. Disable or redact sensitive payload capture.
7. Use TinyFish only for a browser workflow that cannot be reliably covered by Playwright; do not duplicate the same test in two systems.
8. Keep human staff UAT as a separate acceptance gate. Automated tests cannot approve clinical workflow safety.

Acceptance gates:
- Deterministic role-based tests run against isolated QA.
- Positive and negative paths pass.
- No production credentials or real patient data are captured.
- Critical axe-core findings are resolved or documented.
- Staff acceptance remains pending until actual clinic personnel complete supervised UAT.

### Phase F — Privacy-safe observability and backup/restore (P0 before live data)

**Estimate:** 2–5 focused engineering days, excluding external storage setup  
**Goal:** Detect operational failures and prove recoverability without leaking sensitive data.

Tasks:
1. Keep the existing Better Stack monitor; verify its canonical target, status, incident routing and alert recipients.
2. Design a minimal `/healthz` or readiness endpoint returning only generic application/dependency availability. It must not disclose database hostnames, schema, credentials, patient counts, exception text or secrets.
3. Distinguish liveness (app process responds) from readiness (critical dependency is available) and define timeouts/failure behavior.
4. Add a small set of synthetic, non-sensitive checks for authentication availability and a harmless read-only health path only if the security review approves them.
5. Keep PostHog disabled for clinical screens until SDK, event properties, URL capture, replay, network payloads and retention are reviewed. If later enabled, use aggregate allowlisted events and never send PHI/PII or financial data.
6. Define backup scope: database schema, data, Storage objects/metadata and required configuration/secrets recovery procedure. Do not store secret values in Git.
7. Produce an encrypted logical backup using an authorized Supabase CLI/pg_dump environment and a secure destination outside the repository. Record date, project, encryption, retention and checksum without exposing secrets.
8. Perform a restore drill into an isolated temporary project/database. Verify row counts, schema objects, RLS/grants, Storage references and critical RPC behavior.
9. Write a concise incident, restore and rollback runbook. A backup is not accepted until restore succeeds.

Acceptance gates:
- Better Stack continues monitoring the canonical site without duplicate monitors.
- Health endpoint reveals no sensitive internals.
- No clinical/financial/user identifiers enter telemetry.
- Backup file is encrypted and stored outside GitHub.
- Restore drill succeeds and is documented before real patient data is entered.

### Phase G — Mobile performance and resilience (P2)

**Estimate:** 2–4 focused engineering days  
**Goal:** Improve perceived speed and behavior under constrained connectivity.

Tasks:
1. Run Lighthouse on representative public and authenticated QA pages at mobile settings; capture baseline LCP, INP, CLS, bundle size and accessibility findings.
2. Profile actual slow routes and large assets before changing code. Avoid arbitrary optimization.
3. Apply targeted improvements: route-level code splitting, lazy loading, image sizing/compression, query waterfalls, unnecessary rerenders and cache headers as supported by the current architecture.
4. Use k6 against QA only for bounded load tests: patient search, queue reads, safe synthetic visit creation and approved RPC workloads. Define low concurrency/rate limits and abort thresholds.
5. Test slow network and connection interruption around saves. Confirm clear pending/success/failure UI and safe retry semantics.
6. Audit PWA service-worker caching. Cache only static app assets by default. Do not cache clinical records or API responses offline without a separately reviewed encryption, expiry, logout-clearing and device-loss model.
7. Re-run mobile checks on the Honor X7c or comparable mid-range Android device when available; automated emulation is not a substitute for a real-device check.

Acceptance gates:
- Performance improvements are measured against a baseline.
- No regression in clinical data integrity or authorization.
- Load tests target QA only and have bounded thresholds.
- No sensitive offline cache is introduced.
- No Vercel quota or free-tier limit is bypassed.

### Phase H — FHIR interoperability discovery (P3; not a launch blocker)

**Estimate:** 2–4 focused engineering days for a scoped feasibility study; implementation separately estimated  
**Goal:** Prepare for future exchange with external health systems without replacing the existing stack.

Tasks:
1. Review FHIR R4 resources relevant to current workflows: Patient, Practitioner, Encounter, AllergyIntolerance, Observation, MedicationRequest, MedicationDispense, DiagnosticReport, ServiceRequest and Invoice/Account-related mappings.
2. Produce a field-level mapping from current Roshan entities to FHIR resources, documenting terminology, units, status mapping, identifiers, references and unsupported fields.
3. Evaluate Medplum as an interoperability/reference platform and OpenMRS O3 as a workflow/UI reference. Evaluate OpenEMR only for practice-management workflow comparison.
4. Check licenses and deployment/data residency implications before copying code or adopting dependencies. Prefer learning from patterns over copying source.
5. Prototype a read-only export/import mapping on synthetic data; validate semantic round trips and unit correctness.
6. Do not add a FHIR server, migrate the database or replace Supabase without a separate architecture decision and cost/security review.

Acceptance gates:
- Mapping document reviewed.
- Synthetic export validates against the selected FHIR R4 profiles.
- No patient data is sent to external services.
- No change to production architecture without a separate owner-approved ADR.

## 6. Critical path and parallelism

Recommended order:

```text
A: Migration provenance + reproducible local DB
        |
        +----> B: CI profiling and safe consolidation
        |             |
        |             +----> C: actionlint/zizmor + Dependabot
        |
        +----> D: pgTAP contract coverage
                      |
                      +----> E: Authenticated Playwright journeys
                      
F: Backup/restore + privacy-safe monitoring
        |
        +----> Required before any real patient data / live operations

G: Lighthouse + bounded k6 + PWA resilience
        |
        +----> After core journeys and QA stability

H: FHIR/Medplum/OpenMRS discovery
        |
        +----> Independent, non-blocking future interoperability work
```

A and initial B profiling can start in parallel. C can begin as report-only while A is underway. D depends on a trustworthy disposable migration chain. E depends on stable QA schema and authorized synthetic test identities. F must be completed before real patient data. G follows stable journeys. H is deliberately last and does not block the current release.

## 7. Delivery batches and estimates

| Batch | Included phases | Estimated focused effort | Exit artifact |
|---|---|---:|---|
| 1. Foundation | A + B baseline/prototype | 5–10 days | Reproducible DB chain, parity report, CI measurement and safe optimization proposal |
| 2. Security | C | 1–3 days | actionlint/zizmor report, triage and Dependabot verification |
| 3. DB confidence | D | 2–4 days | Focused pgTAP suite and coverage map |
| 4. Clinical E2E | E | 3–6 days | Role-based QA journeys and accessibility report |
| 5. Operational readiness | F | 2–5 days | Encrypted backup, successful restore drill, health/incident runbook |
| 6. Performance | G | 2–4 days | Lighthouse baseline, k6 report, mobile/network fixes |
| 7. Interoperability | H | 2–4 days discovery | FHIR mapping and feasibility ADR |

**Total planning range:** approximately 17–36 focused engineering days, with parallel work possible. This is not a calendar promise; actual duration depends on QA auth access, backup destination access, CI measurements and unresolved migration history. Implementation must stop at a phase gate if its evidence is missing.

## 8. Prioritization rules

When time or CI budget is constrained, prioritize in this order:
1. Data integrity, migration provenance and backup/restore.
2. Clinical/financial authorization and database contract tests.
3. CI efficiency without lost coverage.
4. Authenticated role-based clinical browser journeys.
5. Security supply-chain review and dependency maintenance.
6. Privacy-safe monitoring and incident response.
7. Mobile performance and offline resilience.
8. FHIR interoperability exploration.

Do not prioritize dashboards, graph visualizations, new AI agents, new CI vendors or aesthetic tooling ahead of the above.

## 9. Tool adoption register

| Tool | Decision | Use | Cost/data boundary |
|---|---|---|---|
| Supabase CLI | Adopt | Local migration lifecycle, dump, diff, reset | Free/local use; credentials kept outside Git |
| pgTAP | Adopt selectively | Missing database contract tests | Open source; synthetic local/QA data |
| actionlint | Adopt | Workflow syntax/static checks | Open source; reuse existing CI |
| zizmor | Adopt | GitHub Actions security audit | Open source; report-only first |
| Dependabot | Keep/use | Weekly grouped dependency updates | GitHub-native; no auto-merge |
| OpenSSF Scorecard | Evaluate | Periodic supply-chain posture | Report-only; no score chasing |
| SQLFluff | Evaluate selectively | SQL linting | Report-only until parser fit proven |
| Playwright + axe-core | Expand | Authenticated synthetic journeys and accessibility | Existing stack; no real patient data |
| Lighthouse | Adopt for diagnostics | Mobile performance/accessibility baselines | Run selectively |
| k6 | Adopt for bounded QA tests | Load and concurrency measurements | QA only; bounded request rate |
| Better Stack | Keep | Canonical uptime and approved health checks | Existing integration; no duplicate monitors |
| PostHog | Hold | Aggregate allowlisted analytics only after privacy review | Disabled for clinical capture/replay |
| Graphify | Keep | On-demand code relationship exploration | Optional local aid; not runtime/mandatory CI |
| Context7 | Keep | Verify current library/API documentation | No production data |
| TinyFish | Selective | Browser workflows not covered reliably by Playwright | Synthetic QA only |
| Medplum | Research | FHIR mapping/interoperability reference | No current production dependency |
| OpenMRS O3 | Research | Modular clinical workflow/UI patterns | No current production dependency |
| OpenEMR | Reference only | Clinic operations comparison | No code adoption without license review |
| Lost Pixel | Defer | Visual regression after UI stabilizes | Avoid brittle/duplicate screenshot suites |
| Renovate, Datadog, Sentry, second uptime vendor | Do not add now | Overlaps current tools or adds cost/complexity | Reconsider only if a demonstrated gap appears |

## 10. Release and change-control checklist

Before merging any implementation batch:
- [ ] Scope is one logical change with code/tests/docs together.
- [ ] No real patient or financial data in tests, logs, traces or screenshots.
- [ ] No secrets or database dumps in Git.
- [ ] Exact migration source, version and rollback/recovery behavior reviewed if SQL changes.
- [ ] Existing security, branch-isolation, money-precision and concurrency assertions retained.
- [ ] CI ran on the exact PR head; skipped checks are understood and do not weaken required gates.
- [ ] Cost/CI impact compared with baseline.
- [ ] Docs and operational runbooks updated.
- [ ] Owner approval obtained for production-impacting or architectural changes.
- [ ] Clinical staff UAT remains a separate requirement before real clinical use.

## 11. Explicitly out of scope

- Rewriting Roshan on Medplum/OpenMRS/OpenEMR.
- Replacing Supabase, Vercel or GitHub without a proven technical/cost reason.
- Adding paid tiers or subscriptions.
- Running load/security scans against production.
- Enabling PostHog session replay on clinical screens.
- Offline caching of identifiable clinical records.
- Automatic merging of dependency updates.
- Treating passing automated tests as clinical approval.
- Marking the migration-ledger issue resolved solely because selected RPC fingerprints match.

## 12. Immediate next actions

1. Create a read-only migration provenance/parity report from both projects and canonical repository files; resolve discrepancies before further migration writes.
2. Capture GitHub Actions timing and job-dependency evidence for a representative set of recent runs.
3. Run actionlint and zizmor report-only on current workflows and publish a finding inventory.
4. Start a local Supabase CLI/PG17 replay prototype on a dedicated branch; do not touch production.
5. Map current test coverage to candidate pgTAP contracts and select only uncovered gaps.
6. Confirm availability of isolated QA identities and the supported login path before authenticated browser journeys.
7. Define a secure backup destination and authorized export/restore method before introducing real data.

**Current status:** This is a documented execution plan, not a claim that the phases have been implemented. The first implementation batch should be migration provenance/reproducibility and CI measurement, with no production writes.
