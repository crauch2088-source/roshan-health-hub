# Roshan Health Hub — Visual UX Modernization & Workflow Redesign Plan

**Status:** Approved direction; implementation not yet audited against live screens in this phase  
**Owner:** Roshan engineering  
**Last reviewed:** 2026-10-24  
**Scope:** Internal clinic operations product (reception, clinicians, laboratory, pharmacy, finance, administration), not a consumer appointment-booking app.

## 1. Executive intent

Raise Roshan's visual quality and ease of use to the standard of the supplied reference video while preserving Roshan's distinct purpose, clinical workflows, authorization model, and low-cost operating constraints. The reference is inspiration for polish and coherence, not a specification to copy.

Success means staff can complete common work with fewer navigation decisions and less ambiguity, on a phone and on modest devices, without compromising clinical safety, data integrity, accessibility, or auditability.

## 2. Non-negotiable constraints

- No paid services, paid testing platforms, new recurring infrastructure, or new production projects.
- Do not use real patient data for screenshots, fixtures, demonstrations, or automated tests. Use synthetic, clearly identified data in isolated test environments only.
- No direct production schema/data/auth changes as part of visual redesign. Any later database requirement must be justified, separately reviewed, migration-backed, and approved.
- Preserve existing clinical/business behavior unless a specific defect is documented and regression-tested.
- Preserve role-based permissions, audit trails, visit lifecycle guards, RLS, and existing database invariants. Do not weaken security to make a UI easier.
- Keep the work on a feature branch and use one atomic Git tree commit per coherent batch; do not commit directly to main. Avoid repeated pushes/builds and unnecessary CI/Vercel quota consumption.
- Follow `docs/MASTER_PLAN.md`, `AGENTS.md`, `docs/DB_MIGRATION_RECONCILIATION.md`, `docs/PLUGIN_TOOLING_MAP.md`, `docs/SECURITY_PR_REVIEW.md`, and existing UX audit evidence. This plan supplements rather than replaces those sources of truth.
- Existing system is not yet in operational use at the active branch; records in the system are manually entered test workflow data, not actual patient records. Confirm current state before any future claim about production usage.

## 3. Research synthesis and design principles

The research points to a small set of durable principles:

1. **Design around tasks, not decorative dashboards.** NHS service guidance emphasizes making complex healthcare journeys simpler, testing with real/potential users, and consistency across devices.
2. **Accessible by construction.** Target WCAG 2.2 AA as the design/test baseline where applicable: semantic headings and landmarks, keyboard operation, visible focus, sufficient contrast, labelled inputs, associated error messages, and no color-only status cues. Do not bolt on an accessibility overlay as a substitute for accessible implementation.
3. **Clinical data entry needs context and recovery.** Use explicit labels, concise hints, validation close to the relevant field, meaningful error summaries, safe draft/pending states, and prevent accidental loss of work.
4. **Low-connectivity resilience is a product requirement, not a visual effect.** Make loading, empty, stale, offline, retry, and save-confirmation states explicit. Do not claim offline write support unless implemented and tested end-to-end.
5. **One design system, role-aware workspaces.** Shared tokens/components should make reception, clinician, lab, pharmacy, finance and admin feel like one product; each role should see the next useful action without exposing unauthorized functions.
6. **Measure outcomes.** Assess task steps, completion, error/recovery rate, responsive behavior, accessibility findings, performance and regression results rather than declaring success from screenshots alone.

### Research references

- NHS Service Manual — make the service simple to use: https://service-manual.nhs.uk/standards-and-technology/service-standard-points/4-make-the-service-simple-to-use
- NHS Service Manual — accessibility design: https://service-manual.nhs.uk/accessibility/design
- NHS Service Manual — design system: https://service-manual.nhs.uk/design-system/index
- Google Open Health Stack — design guidelines, data capture and offline/sync: https://developers.google.com/open-health-stack/design
- GOV.UK Design System — form structure and user-centered data collection: https://www.gov.uk/service-manual/design/form-structure
- Supabase — database testing and RLS testing: https://supabase.com/docs/guides/database/testing
- Supabase — testing overview: https://supabase.com/docs/guides/local-development/testing/overview
- Playwright — testing best practices: https://playwright.dev/docs/best-practices
- MDN — mobile accessibility checklist: https://developer.mozilla.org/en-US/docs/Web/Accessibility/Guides/Mobile_accessibility_checklist

These are design and engineering references, not proof of legal compliance in Sudan or a substitute for local clinical governance.

## 4. Product experience target

### Visual language
- Calm, modern clinical identity; teal/green may be explored as an accent, not assumed as a final palette before contrast and existing brand review.
- Neutral surfaces, restrained semantic colors, clear typography, consistent spacing/radii/elevation, purposeful icons, and low-noise layouts.
- No decorative medical cross requirement; retain Roshan's independent identity.
- Strong visual hierarchy for patient identity, active visit, critical alerts, workflow state and primary action.
- Light and dark themes only if existing architecture supports them without duplicating styling debt; do not make them a prerequisite for MVP.

### Navigation and responsive behavior
- Phone-first layouts with clear role-appropriate primary navigation and safe access to secondary functions.
- Desktop/tablet can use wider workspaces and denser tables without changing business semantics.
- Keep global identity, branch context, active patient/visit context and save status visible where relevant.
- Avoid excessive nested menus, ambiguous icon-only actions, horizontal overflow, and modals that trap essential workflows on small screens.
- Arabic RTL and English LTR must be tested separately; do not assume mirroring CSS alone resolves bidirectional content, tables, icons, dates, or mixed clinical notation.

### Workflow-specific outcomes
- **Reception:** find/register patient, identify possible duplicates, open visit, assign queue token (Q001 pattern), route to service, see payment/eligibility state without needless navigation.
- **Clinician:** identify active patient and visit, review history, record vitals, document encounter, select ICD-10 diagnosis, prescribe using supported medication/formulation instructions, order tests, save drafts, finalize safely.
- **Laboratory:** see pending orders, track sample/status, enter/validate results, flag abnormal values with text plus visual cue, review and release results with auditability.
- **Pharmacy:** review prescription, check formulation/instructions and availability, dispense/record partial availability where supported, maintain stock/expiry and clear exceptions.
- **Finance/reception:** clear invoice/receipt/payment status, support configured payment methods (including Bankak where already supported), explain failed/partial operations and prevent duplicate submissions.
- **Admin:** manage staff/roles, service catalog, settings and branch context with least privilege.
- **Specialists/dentistry:** preserve the shared encounter model while exposing specialty-specific fields only where supported by the current product and schema.

Do not invent new capabilities during a visual pass. Mark gaps for separate implementation and review.

## 5. Delivery phases and gates

### Phase 0 — Repository and runtime baseline (first)
- Read required project docs and current UX audit, then map routes/layouts, shared components, theme tokens, navigation, forms, dialogs, tables and role gates.
- Inspect current main/PR/CI state before branching. Confirm available free tools and existing test scripts; do not infer from stale summaries.
- Capture baseline screenshots at representative phone and desktop widths using synthetic data only, if the existing preview/test environment permits.
- Deliverable: route/component inventory, prioritized issue list, baseline test and performance evidence.

**Gate:** no code changes until the current structure and relevant security/workflow constraints are understood.

### Phase 1 — UX audit and task maps
- Audit the actual screens against the earlier UX audit; record findings with route, role, viewport, severity, reproducible steps, and proposed fix.
- Map critical tasks from start to finish; identify redundant clicks, hidden status, confusing terminology, validation failures and loss-of-work risks.
- Separate cosmetic defects, interaction defects, workflow gaps and data/security risks.
- Deliverable: prioritized backlog scored by user impact, clinical/business risk, frequency, and effort.

**Gate:** no broad redesign based only on a reference image or assumed component structure.

### Phase 2 — Design system foundation
- Define semantic color tokens (surface/text/border/primary/success/warning/danger/info), typography, spacing, radius, shadows, focus ring, breakpoints, motion and density.
- Audit contrast for normal/large text and interactive controls; validate semantic statuses with text/icons in addition to color.
- Establish reusable page header, navigation, buttons, inputs, select/autocomplete, cards, status badges, empty/loading/error states, tables, confirmation dialogs, toasts and field-level validation.
- Verify RTL/LTR, keyboard, focus, reduced motion, touch target size and zoom/reflow.
- Deliverable: documented tokens and shared components with targeted tests.

**Gate:** do not migrate all screens until shared patterns are validated and no regressions are introduced.

### Phase 3 — App shell and navigation
- Rework app shell, role-aware landing/workspace, mobile navigation, page titles/breadcrumbs where useful, global search if already supported, branch indicator and contextual actions.
- Make permission-driven visibility consistent with backend authorization; UI visibility is never the security boundary.
- Remove redundant navigation only after route and deep-link coverage is confirmed.
- Deliverable: coherent responsive shell and route smoke tests.

### Phase 4 — High-frequency operational workflows
Implement in this order, based on likely daily use and cross-workflow dependency:
1. Reception and patient lookup/registration/queue.
2. Clinician workspace and encounter documentation.
3. Laboratory orders, samples and results.
4. Prescription and pharmacy dispense.
5. Invoices, payment and receipts.
6. Admin/settings and less frequent specialist flows.

For each workflow: document current behavior; improve layout and error states; preserve permissions and transactions; test success, empty, loading, validation, cancellation, retry, permission-denied and narrow viewport states.

**Gate:** no workflow is marked complete until automated tests and a focused manual walkthrough both pass.

### Phase 5 — Reliability, accessibility and performance
- Add or extend Playwright end-to-end coverage for critical tasks and responsive layouts; add axe-core or an equivalent free automated accessibility scan if compatible with existing tooling.
- Use existing unit/component test framework; do not introduce overlapping paid platforms.
- Check console/network failures, duplicate submits, save-state clarity, keyboard-only use, contrast, focus order, RTL/LTR, zoom/reflow and reduced-motion behavior.
- Measure bundle/runtime impact with existing free tooling; avoid unnecessary animation, large images and new dependencies.
- Verify offline/poor-network states. Any offline persistence must be explicitly scoped, threat-modelled and tested; do not cache sensitive clinical data casually.

### Phase 6 — Review, preview and acceptance
- Run the smallest useful targeted checks during iteration, then one consolidated suite per coherent batch to protect CI/build quotas.
- Verify current commit's checks only; inspect deployment preview only if a build is warranted.
- Review for security/clinical regressions and confirm no production schema/data changes.
- Present one consolidated acceptance checklist and one end-to-end staff walkthrough when the code is ready. User requested a single comprehensive staff test near completion, so defer staff-dependent validation until the non-staff work is complete.
- Merge only after review, required checks, and explicit merge approval when required by project policy.

## 6. Prioritization rubric

Score each finding 1–5 for: frequency, user friction, operational/clinical risk, and confidence; subtract an effort penalty (1–3). Fix high-risk correctness/accessibility issues before cosmetic polish. Do not let a visually striking but low-impact change outrank a broken patient/visit workflow.

P0: data/security/clinical correctness regression or task blocker.  
P1: frequent workflow friction, lost work, serious mobile/accessibility barrier.  
P2: consistency and clarity improvements.  
P3: decorative polish with negligible task impact.

## 7. Acceptance criteria

- No unintended changes to clinical business logic, database schema, RLS, permissions or audit behavior.
- All critical routes load for authorized roles; unauthorized actions remain denied server-side.
- Core reception → visit → clinician → lab/pharmacy/finance paths retain existing invariants.
- No real patient data in fixtures, screenshots, logs or test artifacts.
- Arabic RTL and English LTR verified on phone and desktop widths.
- No known critical/serious accessibility blocker in tested flows; WCAG 2.2 AA checks documented with exceptions.
- Forms have persistent labels, useful hints, field-associated errors and safe recovery from invalid submissions.
- Loading, empty, error, offline/stale and saved/unsaved states are distinguishable.
- Targeted tests and the consolidated CI suite pass for the exact head commit; no unreviewed production deployment.
- Performance is no worse without documented justification; no paid services introduced.
- Before/after screenshots and task walkthrough notes are stored without patient identifiers.
- Staff-dependent final acceptance is performed once, comprehensively, after implementation stabilizes.

## 8. Execution and quota discipline

- Use the connected Composio/GitHub/Supabase/Vercel tools where available; use Context7 for current library APIs and existing repo graph tooling for code navigation when it adds value.
- First inspect available tool contracts and existing project docs; do not assume a plugin has the needed permission.
- Prefer source-grounded repository changes over advice-only responses.
- One coherent atomic commit per implementation batch; no per-file commits.
- Avoid production DB changes, repeated deployment triggers, duplicate CI runs and paid resources.
- If a tool fails, inspect its error and use a supported alternative once; do not repeatedly retry identical failed actions.
- Maintain a short progress log: session date, evidence inspected, files changed, commit/PR, checks, blockers, next action. Never label unverified work complete.

## 9. Session reporting format

After each work session, report:
1. **Done** — only verified actions and artifact links.
2. **Evidence** — commit/PR/check result and tests actually run.
3. **Not done / blockers** — exact limitation, not optimistic inference.
4. **Progress** — phase and acceptance criteria, with a percentage only when backed by a defined checklist.
5. **Next session** — one bounded set of actions.
6. **User help needed** — only a concrete decision or access permission that cannot be inferred.

## 10. Initial next actions

1. Complete Phase 0 by reading the complete required docs and mapping the actual UI/routes/components; the prior audit is a starting point, not a substitute.
2. Inspect the latest current CI/deployment state and branch protection.
3. Create a ranked audit issue list with evidence.
4. Implement the design token/component foundation only after audit; do not start a sweeping rewrite.
5. Deliver a first progress report with a precise scope, evidence, and next batch.

## 11. Progress log

### 2026-10-24 — Plan authored
- Researched official NHS, Open Health Stack, GOV.UK, Supabase, Playwright and MDN guidance.
- Defined scope, non-negotiable safety/engineering constraints, phased delivery, acceptance gates and session reporting format.
- Implementation status: **planning documented; Phase 0 verification and UI code changes remain pending**.
