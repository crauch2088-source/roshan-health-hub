# Roshan Health Hub — Plugin & Integration Operating Map

Last reviewed: 2026-10-16. Purpose: turn available integrations into repeatable project progress, not a list of logos. Consult before each major workstream and revise when connection state/capabilities change.

## Project guardrails
- Single source of truth is this repository and `docs/MASTER_PLAN.md`; never start a parallel app or let a prototype replace the production codebase.
- Phone-first workflow: prefer direct connected tools and complete patches over desktop-only instructions.
- Main is the working baseline per the user's latest instruction. Make changes directly where authorized, but verify with tests/CI and use migrations for DDL. Do not perform broad destructive operations merely because current data is synthetic.
- Current deployment target is Vercel project `roshan-health-hub`, canonical domain `roshan-health-hub.vercel.app`; current Supabase target is `jewzonxplxhogqrnhosl`. Always re-verify live target identifiers before writes because connected accounts can change.
- Do not place credentials, service keys, real patient details, clinical notes, or financial records in prompts, commits, telemetry, screenshots, issue descriptions, or logs.

## Connected / already available capabilities and when to invoke them

| Integration / tool family | Best project use | Trigger it when | Guardrails / limitations |
|---|---|---|---|
| GitHub native connector | Read repo, inspect commits/branches, issues/PRs, CI, file diffs | Every new phase; before code changes; when verifying CI or merge readiness | Native file writes previously returned 403. If that recurs, use active Composio GitHub tools; do not repeatedly retry the failing path. |
| Composio | Cross-app tool discovery, parallel independent batches, GitHub writes when native connector fails, reusable workflows | Multi-system task, need to inspect multiple services, or native connector lacks write capability | Always search tools first, follow returned plan, load full schemas, confirm ACTIVE connection and correct account, use exact returned slugs. Never batch dependent calls or guess inputs. |
| Supabase | Read schema and migration history; RLS/policy/grant audit; security/performance advisors; Edge Functions, auth, logs; controlled SQL/migrations | Any database, auth, branch/tenant, financial atomicity, clinical workflow, or security task | Current project has 56 public tables with RLS enabled and 88 migration-ledger entries as of 2026-10-16; migration replay parity is unresolved. Advisor findings are leads, not automatic permission to delete indexes. Validate writes and use tracked migrations. |
| Vercel | Canonical project/domain verification, deployment status/logs, env-key names/targets, runtime settings | After each main change; production incident; deployment or environment audit | Canonical project is `roshan-health-hub`; duplicate `roshan-health-hub-hjfy` was retired. Never expose env values; audit keys/targets with decryption off unless a specific permitted diagnostic requires otherwise. |
| PostHog | Error tracking, product funnels, safe aggregate UX telemetry, feature flags | UX friction, failed workflows, performance/error investigation after privacy review | Connected default project was previously empty. Before activation, inspect SDK/config and disable/mask all sensitive capture; exclude patient names/IDs, clinical text, financial data, URLs/query strings, headers/bodies, and tokens. No replay on clinical screens unless proven safe and explicitly approved. |
| Context7 | Current docs and examples for React, TanStack Start/Router, Supabase JS, Vite, Tailwind, etc. | Before using unfamiliar APIs, upgrading dependencies, debugging version-sensitive behavior | Prefer docs matching exact package version; pair with tests rather than treating examples as proof. |
| Figma | Inspect design context, variables, components, and handoff to code | A specific screen redesign or design-system task where access is available | Previously view-only Starter with MCP calls exhausted. Do not block implementation; document design findings and implement/test in code. Load the mandatory Figma skill before every relevant Figma action. |
| Product Design | Structured brief, UX flow audit, screen-by-screen critique, prototype when helpful | Navigation overhaul, screen audit, reducing clicks, task-flow redesign | Do not let the brief gate block urgent bug/security work. Prototype is supplementary; source of truth remains this repo. |
| Superpowers / engineering skills | TDD, debugging, review, implementation workflow | Any behavior change, bug fix, complex feature, or regression-risk change | Read the matching skill first. Write regression tests and verify typecheck/lint/build/guard tests. |
| Lovable | Inspect/compare an existing build or make a disposable visual experiment | Need a quick alternative UI concept or compare a narrow flow | Do not create a second product or modify a separate source of truth. Export useful concepts back into this repo deliberately. |
| Replit | Reproduce an isolated bug or prototype a contained experiment | Reproduction needs a runnable environment not available through current connectors | Keep synthetic data only; don't migrate ownership/source of truth. |
| ChatGPT Work / Cloud Browser (if available in the product) | Multi-step browser workflows, UI smoke tests, interacting with web consoles | Authenticated UI testing, production smoke tests, browser-only configuration | Use Work mode for Cloud Browser; no credentials in chat. Confirm availability through current product help rather than assuming. |
| Gmail / Slack via Composio | Notifications, operational coordination, follow-up on a concrete project dependency | User requests communication, or a project workflow has a specific recipient/channel and purpose | Do not send messages without clear intended recipient/content and authorization; don't transmit sensitive health data. |

## Recommended repeatable tool routing

1. **Start / orient:** read `docs/MASTER_PLAN.md`, verify GitHub main SHA/CI and current open issues/PRs.
2. **Database task:** identify the correct Supabase account/project, inspect schema + migration history + policies, run read-only checks, prepare a reversible migration, apply only when required, then verify schema/data and advisors.
3. **Code task:** inspect relevant source and tests, consult Context7 for version-sensitive APIs, load TDD skill, implement minimal complete patch, run `test:guard`, `typecheck`, `lint`, `build`, inspect CI and deploy status.
4. **Deploy task:** verify Vercel canonical project + branch + environment scope; deploy via Git-linked workflow; confirm READY and canonical domain; run authenticated UI smoke tests when browser access is available.
5. **UX task:** audit one complete role-based workflow at a time (entry → completion → failure/recovery → permissions → mobile/RTL/keyboard), use Product Design/Figma if available, then implement in source and add tests. Measure clicks/time-to-complete, not just appearance.
6. **Analytics task:** first audit PostHog SDK/config and privacy settings. Use synthetic accounts and event names/aggregate counts only; don't collect patient or financial content.
7. **Research task:** official docs + Context7 for APIs; authoritative clinical guidelines for medical decision support; primary sources for security/platform facts; distinguish recommendations from verified project findings.

## High-value next integrations to connect only when the task requires them

| Integration | Priority | Use case / trigger | Status at review |
|---|---|---|---|
| TinyFish (browser automation) | High for release validation | Connect when ready to perform authenticated smoke tests of login, role gates, patient search, queue, invoice/payment and SSR routes. This addresses a documented current blocker. | Listed as available, not installed/connected in plugin inventory. |
| Firecrawl (web/docs research) | Medium-high | Connect for multi-page official documentation and guideline research when a task requires a broad, sourced evidence review; not needed for ordinary web searches. | Listed as available, not installed/connected. |
| GitHub MCP connector | Low / optional | Consider only if it offers a missing repository/action surface not covered by the active GitHub connector + Composio. | Composio search reported no active connection; existing GitHub connector already works for reads. |
| Notion | Low / optional | Connect only if user chooses Notion as a separate knowledge base; otherwise keep project plan in GitHub to avoid duplicate sources of truth. | Available but not connected. |
| Google Drive / Calendar | Low / conditional | Connect only for a specific workflow such as shared SOPs, staff scheduling, or documents stored there. | Not verified as connected; no immediate project blocker depends on them. |
| Additional project trackers / CRM | Low | Only if the clinic later needs external operational coordination; avoid adding process overhead before launch. | Not required for current MVP. |

## Clinical product-specific tool opportunities
- Use authoritative and current clinical sources for medication templates and clinical decision support; record source, guideline/version/date, patient population, contraindications, and review owner. Never present generated dosing as a substitute for clinician verification.
- For medication catalogue improvements, build structured formulation/strength/route/frequency/duration constraints and age/weight cues with hard stops for missing weight, allergy conflicts, and out-of-range doses where clinically appropriate. All calculations require unit tests and clinician review.
- Treat EMR privacy, role/branch isolation, audit logs, and financial atomicity as release gates, not later polish.
- Build synthetic end-to-end scenarios for reception → visit → queue → invoice → payment; doctor → vitals/notes/diagnosis/prescription; lab order → sample/result/verification/print; pharmacy dispense → stock decrement → invoice; reversals/refunds and concurrent actions.
- For UX redesign, inspect every screen, modal, form, empty/error/loading state, keyboard flow, mobile viewport, Arabic RTL and English LTR, and permission boundary. Prioritize speed and fewer clicks for high-frequency reception and GP workflows.

## Change log
- 2026-10-16: Initial map created from the current master plan, connected integration inventory, available direct tools, and current official Supabase/PostHog privacy guidance. Confirm connection status before assuming any integration remains active.


## Fresh live advisor snapshot (2026-10-16)
- Supabase security advisor: 21 authenticated-callable `SECURITY DEFINER` function warnings, one disabled leaked-password protection warning, and one `pg_trgm`-in-public-schema warning.
- Supabase performance advisor: 100 unused-index informational findings.
- Interpretation: these are triage signals, not an instruction to revoke all RPC grants or drop indexes. Some RPCs are deliberately callable by signed-in roles and may contain authorization checks. Review each function's implementation, grants, fixed `search_path`, role/branch enforcement, and negative tests first.
- Vercel's connected account currently reports a single linked project `roshan-health-hub` under team `roshan45`, connected to the expected GitHub repository.
- Next high-value release gate remains authenticated browser smoke testing; TinyFish is suggested as an optional connection for this. Firecrawl is suggested for research tasks requiring broad multi-page source review.


## Repository work discovered during the same review
- Draft PR #34 ([branch-scope prescription/lab child rows](https://github.com/crauch2088-source/roshan-health-hub/pull/34)) reports green PostgreSQL 17 integration and repository checks, but remains unapplied to production. Keep migration-history reconciliation and business review as release gates.
- Open issues requiring prelaunch re-triage include #25 (secret scanning and historical environment-file exposure), #20 (invoice validation/atomicity), #18 (complete patient outstanding-balance calculation), and #16 (server-side insurance-claim invariants).
- Recheck live issue/PR states before acting; this list is a snapshot, not a claim that each item is unchanged.
