# Roshan Health Hub — Unified UX, Clinical Workflow & Visual Modernization Plan

**Canonical source of truth for this workstream.** Last reconciled: 2026-10-24.  
**Status:** Phase 0 started. Inventory generated from main SHA 82c9a8306e4f611bcd593eeb5b192fd15b693265. This is not visual acceptance and does not claim production matches main.

## 1. Objective

Use the supplied reference video as inspiration for a polished, coherent mobile-first experience—not as a product specification to clone. Roshan is an internal clinic operations system for reception, clinicians, laboratory, pharmacy, finance and administration, not a consumer appointment-booking app. Improve visual identity and reduce task friction while preserving clinical/business logic, role permissions, branch context, auditability and low-cost constraints.

Target a calm, modern clinical workspace: clear hierarchy, restrained semantic color, consistent surfaces/spacing/typography, useful status cues, responsive layouts, accessible controls, explicit loading/error/empty/saved states, and a distinct Roshan identity. Teal/ink is a direction to evaluate, not permission to recolor blindly. Reuse current components and dependencies unless evidence demonstrates they are insufficient.

## 2. One plan; previous plans reconciled

This plan consolidates:
- docs/UX_AUDIT_2026-10-17.md — code audit of navigation/quick actions; not a complete visual audit.
- docs/REDESIGN_40_ITEM_PLAN.md — historical record of the 40-item source implementation and its outstanding release evidence.
- docs/UX_AUDIT_AND_REMEDIATION_MASTER_PLAN_2026-10-21.md — route coverage, evidence rules, risk model, workflow and release gates.
- docs/UX_AUDIT_AND_REMEDIATION_PLAN_ADDENDUM_2026-10-21.md — assumptions, S×L×E ranking, clinical, network, privacy and acceptance checks.
- The October 24 modernization draft — design system and phased modernization.
- docs/MASTER_PLAN.md, AGENTS.md, docs/DB_MIGRATION_RECONCILIATION.md, docs/PLUGIN_TOOLING_MAP.md and docs/SECURITY_PR_REVIEW.md remain governing engineering/security sources; this plan does not override them.

Older docs are historical evidence, not separate active plans. Their unique requirements are incorporated below. Old CI, screenshot and deployment results do not prove acceptance for the current SHA/deployment.

## 3. Non-negotiable constraints

1. No paid services, paid testing platforms, recurring infrastructure, or duplicate production projects.
2. Never write test data to production. Production Supabase diagnostics are SELECT-only. Write workflows run only in isolated PostgreSQL 17/disposable QA environments with clearly synthetic data.
3. No schema/migration/RLS/role/auth change as a visual shortcut. Preserve RPC contracts, atomic financial/clinical operations, idempotency, audit protections, visit/patient/branch linkage and soft-delete rules.
4. Do not invent clinical doses, reference ranges, critical thresholds or protocols. Never imply an unmeasured vital is normal. Clinical rules/wording requiring governance remain pending clinical review.
5. Never expose secrets, tokens, patient identifiers or real clinical/financial data in screenshots, logs, traces, reports, fixtures or PRs. Use authorized QA access; never bypass authentication.
6. Preserve Arabic RTL, English LTR, mixed-direction identifiers, keyboard/focus behavior, reduced motion, dark/light and print styles where supported.
7. Insurance remains deferred except for checking existing routes do not regress. Do not expand insurance scope without a separate decision.
8. Preserve the existing app; no parallel app, sweeping rewrite or dependency addition without demonstrated need.
9. Follow AGENTS.md: one atomic commit per coherent batch, one CI run per completed stage, squash-merge PRs, protect free Vercel quota, no force-push/rewrite of published history, no redundant diagnostics/build retries.
10. Verify current main, PRs, CI and deployment identity before each implementation batch. Evidence is valid only for the exact source SHA, deployment, role, environment and scope it describes.

## 4. Research principles

- Healthcare usability and safety: ONC 2025 SAFER Guides, especially patient identification, computerized provider order entry, test-result reporting/follow-up and contingency planning: https://healthit.gov/clinical-quality-and-safety/safer-guides/
- Accessibility: WCAG 2.2 AA as practical design/test baseline; W3C mobile guidance, visible focus, keyboard access, contrast, reflow, target size, labels and error associations: https://www.w3.org/TR/wcag2mobile-22/ and https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- Task simplicity and consistency: NHS Service Manual: https://service-manual.nhs.uk/standards-and-technology/service-standard-points/4-make-the-service-simple-to-use and https://service-manual.nhs.uk/design-system/index
- Data entry and low-connectivity design: Google Open Health Stack: https://developers.google.com/open-health-stack/design; GOV.UK forms: https://www.gov.uk/service-manual/design/form-structure
- Test discipline: Supabase testing guidance https://supabase.com/docs/guides/database/testing and Playwright best practices https://playwright.dev/docs/best-practices
- Mobile accessibility: MDN checklist https://developer.mozilla.org/en-US/docs/Web/Accessibility/Guides/Mobile_accessibility_checklist

These sources guide evaluation; they do not certify Roshan's compliance, clinical readiness or legal status in Sudan.

## 5. Evidence/status vocabulary

Use exactly one state for each finding/criterion:
- PASS — evidence proves the criterion for the recorded scope.
- FAIL — defect reproduced or criterion not met.
- BLOCKED — a named prerequisite prevents the check; record the next action.
- NOT TESTED — no valid check occurred.
- N/A — genuinely inapplicable, with rationale.

Evidence strength is bounded: source inspection proves code structure; unit tests prove tested logic; CI proves checks run at a specific SHA; READY proves deployment-platform readiness; browser evidence proves only the observed route/session/viewport; staff/clinical review proves only the reviewed task. None substitutes for another. Never claim the whole app is tested from a smoke test or green CI alone.

## 6. Risk-based prioritization

Record consequence/severity S, likelihood L and exposure E (each 1–5) to rank defects using S×L×E; this score never overrides severity rules.
- P0 critical: wrong-patient attribution, privacy exposure/authorization bypass, financial corruption or duplicate transaction, unintended clinical order, or essential workflow blocked without a safe alternative.
- P1 high: essential task blocked, likely loss of entered work, materially misleading clinical/financial state, or broken core mobile workflow.
- P2 medium: recurring navigation/friction/display defect with a safe workaround.
- P3 low: cosmetic/text refinement with negligible task or safety impact.

Fix P0 then P1 before polish. No P0 may remain at acceptance. P1 exceptions require explicit documented product-owner approval and a safe alternative; identity, privacy and financial-integrity risks are never waived.

## 7. Phased execution

### Phase 0 — Current source/deployment baseline (in progress)
- Pin main SHA; inspect open PRs, CI, branch policies and latest deployment for canonical alias https://roshan-health-hub.vercel.app/.
- Compare deployment SHA/status with main; do not infer production behavior from source or an older preview.
- Read governing docs and UX records; record environment/access limitations without storing credentials.
- Generate a source-derived route inventory. Current pinned main lists 27 authenticated TSX page routes and four public/root TSX route files; see docs/UX_ROUTE_COVERAGE_2026-10-24.md. This is not proof routes were visually tested.

Gate: no visual acceptance claims until source/deployment identity and evidence scope are recorded.

### Phase 1 — Route, navigation and task audit
- Inventory routes, screens, dialogs/drawers, forms, command palette and quick actions; map route to component, role/permission, data source, next action and destination.
- Audit direct entry/refresh, navigation, stale draft reset, permission-gated visibility and handler checks, empty/error/loading/submitting states, back/cancel behavior and dead ends.
- Treat prior quick-action fixes and the 40-item batch as completed source-level work unless current evidence reveals a regression; do not reimplement them merely because visual acceptance remains open.
- For every defect, record steps, expected/observed result, severity/confidence, evidence, root cause, regression test and retest SHA.

### Phase 2 — Visual baseline and reference translation
- Capture valid screenshots of the current app using authorized browser access and a deployment/preview whose identity is known; inspect each saved screenshot before accepting it.
- Review shell/navigation, dashboard, patient lookup/profile, visit/consultation, lab order/result, prescription/pharmacy, billing/payment and settings/role administration.
- Required widths: 320, 360, 390, 430 CSS px and desktop where applicable; test Arabic RTL and English LTR. Record theme, browser, viewport, role and SHA.
- Translate the reference video's quality into a distinct Roshan visual language. Do not copy its business purpose or add decorative assets that slow the product.
- If authenticated visual capture is unavailable, mark protected routes BLOCKED; continue source/unit work without claiming visual acceptance.

### Phase 3 — Design system and shell
- Audit semantic tokens, typography, spacing, radius, shadows, focus ring, density, status colors, motion and safe-area behavior.
- Reuse existing primitives for headers, navigation, buttons, inputs, select/autocomplete, cards, tables, status labels, loading/empty/error states, dialogs, toasts and field errors.
- Confirm contrast, zoom/reflow, keyboard navigation, focus restoration, reduced motion, RTL/LTR and print before broad adoption.
- Role-aware visibility is not the security boundary; server/RPC/RLS remain authoritative.

### Phase 4 — High-frequency workflows
Fix only defects proven by audit, in this dependency order:
1. Reception: patient search/registration, duplicate awareness, visit creation, queue token and service routing.
2. Clinician: patient/visit context, history, vitals, note draft, ICD-10, supported prescription entry and lab ordering.
3. Laboratory: active-visit order, sample/order status, result entry/save/review/verification, numeric zero versus empty/text/coded values, abnormal acknowledgement.
4. Pharmacy: prescription identity/formulation/instructions, stock/expiry, dispensing and atomic inventory/invoice effects where supported.
5. Finance: invoice, payment/receipt, cashbox/expense/accounting, duplicate submit and reversal.
6. Administration/reporting and specialist routes.

For each workflow verify loading, empty, success, error/retry, invalid input, disabled/submitting, cancellation, permission-denied and narrow-viewport states where applicable. Do not add unsupported product capabilities as part of a visual pass.

### Phase 5 — Clinical safety, roles and reliability
- Confirm patient/MRN/visit/branch context before sensitive actions; switching patients/branches must not leak stale queries, drafts, results or cache.
- Show saved/draft/verified/completed only after correct server confirmation; prevent silent loss on navigation/session expiry.
- Verify role × route × action allow/deny in isolated environments, including server/RPC/RLS denial of unauthorized sensitive actions.
- Exercise slow/stale reads, timeout, interrupted writes, retry/double-click, session expiry and relevant 401/403/409/422/429/5xx behavior without stale context or duplicate writes.
- Do not claim offline writes or add local storage of sensitive clinical data without separately reviewed design and end-to-end proof.

### Phase 6 — Accessibility, performance and regression
- Use existing scripts first: npm run test:guard, npm run typecheck, npm run lint, npm run build; Node 22.x is required. Re-check package.json at the implementation SHA.
- Write a failing regression test before behavior changes. Prefer unit tests; add focused component/browser tests for visible behavior and a small number of synthetic-data E2E paths for critical flows.
- Use available free automated accessibility checks if compatible; manual keyboard/focus/screen-reader review remains separate.
- Measure baseline and after-change task steps/time, re-entry, validation failures, request/console errors and bundle/runtime impact where tools permit. Do not invent targets before baseline.
- Protect CI/Vercel quota: finish a coherent batch, use focused checks during development, then one consolidated check per stage. No forced/repeated deployment.

### Phase 7 — Final comprehensive acceptance
- After non-staff work stabilizes, conduct one comprehensive staff walkthrough rather than many partial sessions.
- Cover critical role workflows, required widths, RTL/LTR, keyboard/focus and visual behavior with synthetic identities in an isolated environment.
- Record any role/environment still blocked. Issue #95 stays open until current evidence exists; close only with explicit ACCEPTED or BLOCKED decision, source/deployment identity, linked evidence, no open P0 and no unapproved P1.

## 8. Minimum test matrix

| Dimension | Required coverage |
|---|---|
| Routes | Direct entry/refresh and every real route classified; dialogs/subviews inventoried |
| UI states | Loading, success, empty, error/retry, disabled, submitting, permission denied, saved/unsaved |
| Viewports | 320/360/390/430 CSS px and relevant desktop widths |
| Languages | Arabic RTL and English LTR; mixed-direction MRNs, IDs, codes, dates, numbers and currency |
| Accessibility | Tab/Shift+Tab, Enter/Space/Escape, tab arrows/Home/End, visible/restored focus, semantic labels/state, zoom/reflow, contrast, reduced motion; manual screen-reader review where available |
| Identity | Correct patient/visit/branch context; no stale response/draft when context changes |
| Laboratory | Empty/whitespace/nonnumeric/zero/numeric values, save/reopen, abnormal acknowledgement, block verification before save, idempotent retry |
| Prescription/pharmacy | Completeness, formulation clarity, stock failure, retry/double-submit, atomic dispense/inventory/invoice, no auto-dosing |
| Finance | Valid/invalid/zero/negative/decimal values, duplicate submissions, atomicity, reversal/cancellation, no false success |
| Permissions | UI visibility and server/RPC/RLS allow/deny for sensitive actions by actual roles in isolated QA |
| Reliability/privacy | Slow/stale/error/session states; screenshots/traces/logs checked for secrets and patient data |

Pairwise coverage may reduce low-risk combinations, never identity, medication, results, authorization or financial-integrity tests.

## 9. Ready / done definitions

Ready: defect reproducible or requirement precise; expected/actual behavior, severity, source/deployment identity and environment recorded; regression check selected; no unauthorized schema/security change assumed.

Done: root cause fixed; regression check proves intended behavior; connected high-risk flows retested; affected role/language/direction/viewport checked; no unintended RPC/RLS/domain contract change; evidence privacy-safe and SHA-linked; session log and issue updated. A source fix without runtime proof may be “FIXED — AWAITING VISUAL VERIFICATION”, never “VERIFIED”.

## 10. Acceptance criteria

- Every actual route inventoried with explicit status; no unsupported blanket claims.
- Source and deployment identities recorded; production is not assumed to match main.
- Core screens have valid visual evidence at required widths and both languages, or are BLOCKED with next action.
- Zero open P0; no unapproved P1; no silent data loss, false saved/verified state or duplicate sensitive write in tested cases.
- Existing permissions, RLS, atomic RPCs, audit trail, branch/patient context and database contracts remain intact.
- No real patient data/secrets in test artifacts; no production test writes.
- Automated checks pass for exact SHA; manual keyboard/screen-reader and staff review reported separately.
- No paid service or unnecessary deployment/build retry.
- Issue #95 has an evidence-backed ACCEPTED or BLOCKED decision.

## 11. Previously implemented source work — avoid duplication

The 40-item report records source-level implementation of: semantic teal/ink tokens and surfaces; shell/desktop rail/mobile navigation; safe-area, focus, selected-state, reduced-motion/dark/print guards; bilingual accessible consultation tabs and keyboard navigation; patient/visit context hierarchy and unsaved-note warnings; lab search debounce/sanitization/loading/error, selected-test totals, supported active-visit ordering, idempotent atomic order/invoice RPC, persisted five-stage worklist, abnormal-result acknowledgement and unsaved-result verification guard; prescription completeness validation, no-auto-dosing text and pediatric age/weight warnings without dose calculation. It records the empty lab result → zero coercion fix and regression tests.

PR #62 records quick-action destination handling, read+create permission gates, supported lab-order routing, desktop quick actions and draft reset. The October 21 plan reports later phases through Phase 45 merged by 2026-10-23, including route/RTL/accessibility guards. These are historical/source-level facts, not proof of current deployment or full visual acceptance. Re-read current source/tests before touching these areas.

## 12. Current baseline and next actions

- Current main verified in this session: 82c9a8306e4f611bcd593eeb5b192fd15b693265 (2026-10-24). This supersedes older dated SHAs for current-session work.
- Exact-head GitHub check query returned 24 runs with successful conclusions. Combined status reports Vercel successful because the build was canceled by the ignored-build-step rule; this is not a fresh production deployment or visual pass.
- Source inventory lists 27 authenticated page route files and four public/root TSX route files. All browser-facing rows start NOT TESTED until evidence is captured.
- Issue #95 was not found via pull-request endpoint because it is an issue; check through issue search/endpoint before modifying it.
- Next: verify canonical Vercel deployment SHA/status and authorized QA browser access; complete source-to-role/action mapping; capture first valid screenshots; then implement the highest-priority reproducible defect test-first in one atomic code/test/docs batch.

## 13. References

ONC 2025 SAFER Guides, W3C WCAG 2.2/mobile guidance, NHS Service Manual, Google Open Health Stack, GOV.UK form design, Supabase testing guidance, Playwright best practices and MDN mobile accessibility checklist. See Section 4. Existing Roshan docs remain the primary evidence for project-specific decisions.
