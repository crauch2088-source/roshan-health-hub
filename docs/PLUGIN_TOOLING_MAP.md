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
| TinyFish (browser automation) | High for release validation | Use for authenticated read-only smoke tests and carefully scoped synthetic-data workflows, including login, role gates, patient search, queue, invoice/payment and SSR routes. | Connected and successfully used for authenticated read-only production smoke test; browser profile created. Note: profile registry did not list signed_in_sites even though the run loaded the session, so verify profile persistence before relying on repeat runs. |
| Firecrawl (web/docs research) | Medium-high | Use for multi-page official documentation and guideline research when a task requires a broad, sourced evidence review; not needed for ordinary web searches. | Connected and callable (verified 2026-10-16). |
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

## Firecrawl enabled (verified 2026-10-16)
- Firecrawl is now connected and callable. Use `firecrawl_search` for broad sourced research; `firecrawl_scrape` for specific official docs/pages; `firecrawl_map` to inventory a documentation site; `firecrawl_crawl` for bounded multi-page collection; `firecrawl_parse` for PDFs/DOCX/XLSX; `firecrawl_research_*` for biomedical literature when relevant; and `firecrawl_agent` only when fields span many unknown URLs (then check status until terminal). Firecrawl docs: https://docs.firecrawl.dev/introduction.
- For Roshan, best use cases: compare official Supabase/TanStack/Vite docs before version-sensitive code changes; research authoritative clinical guideline sources for clinical templates; review security docs and migration guidance; gather documented UX/accessibility patterns. Keep source URL, date/version, and evidence with each conclusion.
- Firecrawl `interact` is browser control, but do not assume it replaces a full authenticated UI testing setup. Keep TinyFish as an optional next connection for saved browser profiles and repeatable signed-in smoke tests. Never enter or scrape real patient data. For protected pages, use synthetic account/data and explicitly bounded tasks.


## Authenticated browser QA now available (2026-10-16)
- TinyFish was used for a read-only smoke test on `https://roshan-health-hub.vercel.app`; run: https://agent.tinyfish.ai/runs/d7d5a041-d267-45ed-b147-373086c66da0.
- The browser agent reported successful authenticated access as General Manager and all 23 listed routes rendering without visible errors. No Add/Edit/Delete/Save/Submit action was activated and no data was mutated.
- Use this profile to progress from route-level smoke tests to bounded synthetic-data workflow tests with explicit cleanup and postconditions. Keep legacy pharmacy RPC revocation blocked until the new UI and retry/idempotency behavior pass.
- Limitation: visual smoke testing is not instrumented browser-console evidence, independent authorization testing, or full end-to-end workflow coverage. Also reconcile profile-registry metadata: the run used the session even though `signed_in_sites` was empty.


## TinyFish smoke-test evidence and next-stage routing — 2026-10-16
- Successful authenticated patient-registration test (run https://agent.tinyfish.ai/runs/7f496a5f-f247-4dd9-af7f-81a2a565460d) created exactly one synthetic patient through the real UI; the “Saved” toast and MRN `RMC000001` were observed. The record and only its patient audit rows were removed through guarded exact-identity SQL after confirming there were no dependent clinical/financial rows. Independent postconditions returned patients=0, visits=0, invoices=0, audit_logs=0.
- Read-only route audit (https://agent.tinyfish.ai/runs/abe5ee2f-49bc-4617-b31a-d58e5c84a0cc) passed for `/visits`, `/queue`, `/lab`, `/billing`, `/pharmacy`, and `/patients`; all displayed correct empty states and navigation worked. Registration modal validation: full name required and Save disabled until entered. No mutation actions were activated in this second run.
- Do not treat these as full workflow/E2E or authorization coverage. Next test plan: create a tagged synthetic patient; run one visit and queue transition, then lab order/result and prescription/invoice/pharmacy flows in controlled batches; after each batch verify transactional invariants and remove only rows linked to the exact synthetic IDs, including related audit rows. Never run a broad purge against live tables.
- Observed UX gap: patient list has no visible edit/delete/archive action. Review role permissions and existing soft-delete columns; any new control should be permission-gated, audited, and soft-delete/archive only, with safeguards around clinical/financial dependents. Avoid hard delete as a general product action.
- TinyFish profile metadata still omits `roshan-health-hub.vercel.app` from `signed_in_sites` even though the browser runs were authenticated. Verify session persistence before relying on future unattended runs.


## Follow-up run outcome and issue triage — 2026-10-16
- A second synthetic registration succeeded, but the TinyFish run failed while opening the New Visit form (https://agent.tinyfish.ai/runs/0a5100a7-e292-45b6-85f6-7081a9d0de21). No visit/queue/financial/clinical child rows were created. The exact synthetic patient and its audit rows were removed after verifying all dependent child tables were empty; final DB counts are all zero for patients, visits, queue, appointments, lab, prescriptions, invoices/items, payments, and audit logs.
- Issues #17 (atomic prescription writes) and #20 (atomic invoice writes + amount validation) were closed after confirming their fixes are on main with DB/integration/CI evidence. Obsolete Composio test issue #1 was also closed.
- Keep issue #18 open until tests explicitly cover >1,000 invoices and query failure, despite the current exact-pagination, amount fallback, and unavailable-state implementation.
- Continue visit/queue validation in a new, bounded attempt only after diagnosing the prior TinyFish run failure; never assume a failed browser run did not mutate data—inspect and clean only exact synthetic IDs first.


## Final issue triage correction — 2026-10-16
- Issue #18 is now closed after verifying exact paginated invoice retrieval, completeness gating, fallback amount handling, explicit query-error states, and regression tests for >1,000 rows, failures, inexact counts, and invalid amounts.
- CI run #38964357807 passed the tooling-map documentation update. Documentation CI is not evidence of a new production deployment.
- Reception→visit→queue browser flow remains incomplete after a TinyFish failure during New Visit navigation; exact synthetic patient/audit cleanup completed and all relevant table counts returned to zero. Diagnose the automation failure before a new bounded attempt.


## Phase 21B production hardening completed — 2026-10-16
- Applied the tracked migration `db/roshan_phase21_patient_registration_privileges.sql` through Supabase `apply_migration` under name `roshan_phase21_patient_registration_privileges_20261016`.
- Verified effective grants after migration: authenticated direct INSERT on `public.patients` denied; authenticated and anon EXECUTE on `public.next_mrn()` denied; service_role retains next_mrn; authenticated EXECUTE on `public.create_patient_atomic` remains allowed; anon cannot execute the new RPC.
- Post-migration TinyFish registration smoke succeeded (run https://agent.tinyfish.ai/runs/643f8bd1-d227-4fc8-b96b-fa6098819ebf). The unique synthetic patient and its exact audit rows were then removed after confirming no dependent rows; final patients/visits/queue/invoice/payment/audit counts are zero.
- Continue broader role/branch negative authorization tests; this phase only hardens the patient-registration write path.


## Supabase security catalog check — 2026-10-16
- After Phase 21B, read-only inventory found 42 public SECURITY DEFINER functions; 20 are executable by `authenticated`, zero public ones by `anon`; all 20 authenticated-callable definitions have empty `search_path` and static authorization/scope markers.
- Five private-schema functions have anon EXECUTE ACLs, but anon lacks USAGE on `private`; treat as defense-in-depth cleanup candidate, not evidence of an exposed endpoint. Do not revoke grants broadly without checking callers and default privileges.
- Full adversarial authorization/branch tests remain pending. Supabase Auth leaked-password protection and `pg_trgm` extension placement are still open review items.
- Vercel runtime-error cluster API returned 403 for the connected account; did not retry unchanged. Use only an explicitly authorized alternative if runtime-error evidence becomes necessary.

## Verified date-boundary bug and workflow rule — 2026-10-16
- Production smoke testing proved that clinic-local midnight (Africa/Khartoum) is 22:00 UTC on the previous calendar date. A visit persisted with the previous UTC date was therefore excluded by the visits screen's queue_date = todayISO() filter.
- Fix under review in Phase 22: the UI explicitly persists the intended queue_date, and both database trigger fallbacks use AT TIME ZONE 'Africa/Khartoum'. PostgreSQL 17 regression coverage asserts the visit date, exactly-one ticket, and explicit-date path.
- For browser QA that creates records, wait for the current TinyFish run to reach a terminal state before starting another. A retry loop previously created seven visits; all seven are soft-deleted and their queue tickets were removed. Never use unbounded repeated submits to diagnose a visually empty list.

## Phase 22 execution status — 2026-10-16
- PR #45 merged into main at `3f55f1ec6acaa33bab51a58c64f0c5bf518f25c8`; main CI run [#38967952735](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38967952735) passed, including the new PostgreSQL 17 clinic-local queue-date regression.
- Supabase production migration `roshan_phase22_clinic_local_queue_date_20261016` is applied and both live trigger definitions were verified with `search_path = ''` and the `Africa/Khartoum` timezone fallback.
- Production Vercel deployment is blocked by a 402 `api-deployments-free-per-day` limit; retry after 24 hours or resolve the billing/plan limit. No CLI fallback session was available, so no alternate deployment path was attempted.

## Tooling and privacy updates — 2026-10-16

- GitHub repository protections enabled and re-verified: secret scanning and push protection are both enabled. The open secret-alert query returned zero results after activation; historical exposure is still not proven absent.
- GitHub CodeQL default setup is configured for JavaScript/TypeScript with the default query suite and hosted runner. Initial setup workflow: https://github.com/crauch2088-source/roshan-health-hub/actions/runs/38969319514. At the last check it was still running; do not claim a completed scan until the workflow and first results are verified.
- Dependabot vulnerability alerts/security updates remain disabled according to the repository API. The current connected GitHub tool surface did not expose a supported toggle; enable them in repository settings when available, then verify alert access.
- PostHog project 657231 had ingested no events, and `package.json` has no PostHog SDK dependency, so application instrumentation is not wired. Privacy settings updated before any telemetry rollout: IP anonymization enabled, console-log capture disabled, session recordings remain disabled, and reporting timezone set to `Africa/Khartoum`. Performance capture remains enabled; do not introduce analytics or replay on clinical screens until the SDK/config and event payloads are reviewed for patient/financial data.
- Browser Use Cloud tools are discoverable through Composio and the instant account is active for start-run/status/get-run operations, but accepted runs are metered and have a required positive USD cost cap. Prefer the already-connected TinyFish workflow for routine smoke tests unless Browser Use offers a specific missing capability and its cost is acceptable.
- Main branch currently has no active branch protection rules. Do not add required-check rules until they are aligned with the user's direct-main workflow; CI should continue to be checked explicitly.
