# Roshan Health Hub Audit & Hardening Plan

> Execution: native implementation in this session, using focused tasks, tests-first, and independent review where available. This document is a working plan; it does not authorize production data changes, secret rotation, merges, or deployments.

**Goal:** Establish a verifiable release baseline and reduce security, clinical-workflow, and reliability risks in Roshan Health Hub without destabilizing the current production database.

**Architecture:** Audit the current repository and hosted services read-only first. Implement fixes on isolated branches with regression tests, preserve the existing Supabase schema, and require CI plus review before merging. Production changes require separate explicit approval and a rollback plan.

**Tech Stack:** React, TypeScript, TanStack Start, Supabase/Postgres/RLS, GitHub Actions, Vercel, optional PostHog.

## Global Constraints

- Never print or commit secrets, service-role keys, JWTs, credentials, or real patient data.
- Do not delete or rewrite production data during audit.
- Do not merge PRs or deploy production as part of this audit.
- Do not change the existing schema unless a specific defect is proven and a reviewed migration is prepared.
- Keep Node/runtime versions aligned across package.json, CI, and Vercel; verify before changing.
- Preserve Arabic/English and RTL behavior, phone-first workflows, and role-based access.
- Treat security-advisor warnings as investigation leads, not proof of exploitable vulnerabilities.
- Do not drop indexes solely because usage counters say “unused”; assess workload and database age first.

## Review Focus

- Cross-role and cross-branch access to patient, clinical, laboratory, pharmacy, and finance records.
- SECURITY DEFINER RPCs: verify each callable function's ACL, permission checks, branch scoping, input validation, and safe search_path.
- SSR errors and logs: diagnostics must not expose identifiers, credentials, or clinical content.
- Queue numbering, dispensing, billing/payment, and stock movements must be atomic and resistant to duplicate/replayed actions.
- Mobile Arabic/English layouts, keyboard/focus behavior, and recoverable network failures.

## Task 1 — Freeze baseline and map changes

- [ ] Record main SHA, active branches, open PRs, CI results, Vercel project/deployment IDs and runtime configuration.
- [ ] Read each open PR's diff, changed-file list, checks, review threads, and latest head SHA; do not rely only on its description.
- [ ] Confirm the deployment serving the intended production domain and distinguish it from preview/duplicate Vercel projects.
- [ ] Deliverable: audit notes with verified facts, unknowns, and candidate fixes.

## Task 2 — Database security review (read-only first)

- [ ] Enumerate all public tables, RLS status, policies, grants, and branch-scope helpers.
- [ ] Review every SECURITY DEFINER function executable by authenticated users. Confirm authorization is performed inside the function and cannot be bypassed via parameters or cross-branch IDs.
- [ ] Investigate Supabase advisor findings, including authenticated execution of SECURITY DEFINER functions and the public-schema pg_trgm extension.
- [ ] Check whether similarly named tables (e.g. medicines and medicines_2) are legacy, active, or accidental; do not rename/drop them during audit.
- [ ] Add pgTAP/RLS tests in a development branch for representative least-privilege, cross-branch, and denied-write cases.
- [ ] Deliverable: prioritized findings with evidence and proposed SQL migrations; no production DDL until reviewed and explicitly approved.

## Task 3 — Secret and dependency hygiene

- [ ] Enable/configure GitHub secret scanning, code scanning, and dependency alerts where supported by repository permissions.
- [ ] Review repository history and current files for committed secrets; report only file/path and secret type, never value.
- [ ] If a real secret is confirmed exposed, prepare rotation/revocation before any history rewrite; history rewriting is a separate approved action.
- [ ] Run dependency audit and inspect direct/transitive high-severity advisories.
- [ ] Deliverable: repeatable security checks in CI and documented remediation status.

## Task 4 — Runtime, CI, and deployment consistency

- [ ] Compare package.json Node engine, GitHub Actions runtime, Vercel runtime, lockfile, and build preset.
- [ ] Inspect the open SSR error-logging PR and validate redaction tests against synthetic inputs.
- [ ] Confirm production/preview runtime logs and route health without accessing patient records.
- [ ] Deliverable: consistent build/runtime configuration and tests for SSR error redaction.

## Task 5 — Clinical and operational workflow tests

- [ ] Trace existing code and policies for patient registration → visit → queue → invoice → payment.
- [ ] Trace consultation → diagnosis → prescription → lab order → result entry/verification.
- [ ] Trace prescription → FEFO batch selection → dispensing → stock movement → audit log.
- [ ] Add tests for duplicate submissions, concurrency, invalid state transitions, zero/negative quantities, expired stock, and branch boundaries.
- [ ] Deliverable: explicit workflow test matrix and regression coverage for confirmed defects.

## Task 6 — Frontend/mobile quality

- [ ] Review PR #8's final head and CI status; validate route/navigation changes and permission-aware mobile navigation.
- [ ] Test 320–430px mobile widths, RTL/LTR, nested routes, empty/loading/error states, and keyboard focus.
- [ ] Review client-side search/pagination for large tables and avoid loading all records.
- [ ] Deliverable: documented device/viewport matrix and only targeted, test-backed fixes.

## Task 7 — Observability and PostHog

- [ ] Confirm whether PostHog is connected and identify the correct organization/project before querying.
- [ ] If configured, inspect only aggregate error/usage information; do not send patient identifiers or clinical details to analytics.
- [ ] If not configured, record it as unavailable and propose privacy-safe events rather than pretending telemetry exists.
- [ ] Deliverable: monitoring recommendations and privacy-safe event schema.

## Task 8 — Release gate

- [ ] Run tests, typecheck, lint, production build, and relevant RLS tests on the final candidate commit.
- [ ] Review the full diff for accidental scope changes, generated files, secrets, and unsafe SQL.
- [ ] Confirm deployment target, rollback procedure, and backup/recovery readiness.
- [ ] Produce a release report listing passed/failed/not-run checks, known limitations, and approvals still needed.
- [ ] Merge/deploy only after review and separate explicit approval.

## Initial verified findings (2026-10-14)

- Supabase project ref: `jewzonxplxhogqrnhosl`, status `ACTIVE_HEALTHY`; public schema inventory reports 56 tables, all with RLS enabled.
- The table inventory includes similarly named `medicines` and `medicines_2`; investigate usage before changing either.
- Supabase security advisor reports one `pg_trgm` extension in `public` and 15 SECURITY DEFINER functions executable by `authenticated`. This is not automatically a vulnerability; review each function's internal authorization and ACL.
- The performance advisor reports 136 unused indexes. Do not remove them based on this signal alone; project age and query workload must be considered.
- GitHub PR #8 (`feat/shell-redesign`) is open and not merged. Its description documents mock-backend browser tests and explicit limitations; re-check current head and checks before any merge.
- GitHub PR #5 (SSR error logging/redaction) is open and not merged; current metadata reports it is not mergeable. Diagnose the blocking condition before acting.
- Vercel project `roshan-health-hub` reports a READY latest deployment and Node 24.x, while package.json declares Node 22.x. Reconcile actual build configuration and CI before changing runtime settings.
- GitHub's native integration could not create a branch (403 integration permission); the connected Composio GitHub connection successfully created this isolated branch. No production changes have been made.
