# Roshan Health Hub — UX, Workflow & Clinical Logic Redesign Program

**Status:** Planned; evidence-informed audit and redesign program  
**Snapshot:** 2026-10-15  
**Repository baseline inspected:** production commit `a64f804679aeaae7299b034176f2265ac1806db0`  
**Scope:** every route, page, dialog, drawer, form, search surface, navigation state, and end-to-end clinic workflow.

## Product goal

Make Roshan a calm, elegant, fast, mobile-first clinical operations system that helps each role complete the next safe action with minimal unnecessary typing, navigation, context switching, and cognitive load. A visually polished interface is not sufficient: each screen must have a clear job, a coherent workflow, understandable state, safe recovery from errors, and measurable outcomes.

A radical redesign is permitted when evidence shows the current interaction model is costly or confusing. It is not a mandate to rewrite everything: preserve proven behavior, permissions, data integrity, and user muscle memory where doing so reduces risk.

## Evidence reviewed

1. **AHRQ — Clinical Decision Support:** CDS can provide patient-specific recommendations, order sets, reminders, and actionable safety checks; design and evaluation must be planned around the actual care setting. https://www.ahrq.gov/cpi/about/otherwebsites/clinical-decision-support/index.html
2. **AHRQ — Workflow and CDS integration:** workflow fit, user-centered design, cognitive walkthroughs, think-aloud testing, and scenario testing matter; poorly integrated automation can add cognitive load or create errors. https://digital.ahrq.gov/key-topics/clinical-decision-support/clinical-practice-improvement-and-redesign-how-change-workflow-can-be-supported-clinical-decision
3. **AHRQ — eMAR redesign project (2024):** medication ordering/review is a prominent source of technology-related medication errors; display, alerts, and workflow must be evaluated together. https://digital.ahrq.gov/ahrq-funded-projects/improving-patient-safety-and-clinician-cognitive-support-through-emar-redesign
4. **ONC 2025 SAFER Guides:** current safety-assurance guidance includes patient identification, CPOE with decision support, test-result follow-up, clinician communication, system management, and contingency planning. https://healthit.gov/clinical-quality-and-safety/safer-guides/
5. **ONC — CPOE with Decision Support, updated 2026:** https://healthit.gov/resources/2025-safer-guide-computerized-provider-order-entry-with-decision-support/
6. **WHO — Medication Without Harm policy brief (2024):** prioritize medication safety across patients, medicines, health workers, and medication systems; focus on high-risk situations, polypharmacy, and transitions of care. https://www.who.int/publications/i/item/9789240062764/
7. **WHO — High-risk medication situations:** https://www.who.int/initiatives/medication-without-harm/medication-safety-in-high-risk-situations
8. **HL7 FHIR MedicationRequest:** a standard model for medication orders and administration instructions. Use as an interoperability/design reference rather than assuming a full FHIR migration is required now. https://fhir.hl7.org/fhir/medicationrequest-definitions.html
9. **HL7 CDS Hooks:** invoke decision support at appropriate workflow points; avoid unnecessary or repetitive interruptions and prefer non-interruptive, actionable guidance when appropriate. https://cds-hooks.org/best-practices/
10. **W3C WCAG 2.2 Mobile guidance:** includes touch target size and reducing redundant entry, among other accessibility considerations. https://www.w3.org/TR/wcag2mobile-22/
11. **GOV.UK Design System — error messages:** clear field-level errors, preserve entered values after validation failure, and make recovery specific. https://design-system.service.gov.uk/components/error-message/
12. **GOV.UK Design System — error summary:** summarize errors and let users navigate to the affected fields. https://design-system.service.gov.uk/components/error-summary/

These sources are design/safety guidance, not a substitute for local clinical governance, licensed drug references, or Sudanese regulatory requirements. Search findings and standards must be versioned in the project as the work proceeds.

## Non-negotiable principles

- **Patient safety before speed.** Reduce needless actions; never remove clinically required verification or make dangerous actions easy to trigger.
- **One screen, one primary job.** Make the main action obvious, secondary actions quiet, and status visible.
- **Progressive disclosure.** Show common actions first; expose advanced options when relevant. Do not hide critical warnings or contraindications.
- **Context-aware defaults, never silent assumptions.** Prefill only from verified patient/encounter/product data; show what was inferred; permit correction; log consequential overrides.
- **No duplicate entry.** Reuse patient demographics, encounter, vitals, allergies, active medicines, clinician, branch, and billing context when appropriate.
- **Preserve user work.** Autosave drafts where safe, warn before losing unsaved changes, retain values after validation errors, and support recovery after network failure.
- **Mobile-first and low-bandwidth aware.** Design for phone screens, variable connectivity, touch use, Arabic RTL and English LTR; avoid hover-only controls and excessively wide tables.
- **Accessibility.** Keyboard support where relevant, visible focus, semantic labels, adequate contrast, touch targets, accessible dialogs, understandable validation, and screen-reader states.
- **Role and branch aware.** The interface may hide irrelevant actions but backend RLS/permission checks remain authoritative.
- **Explainable automation.** Recommendations should state the reason, data used, source/version, uncertainty, and next action. Do not present unverified AI output as clinical fact.
- **Actionable alerts, not alert spam.** Interrupt only for significant, time-sensitive risks; use inline/non-blocking guidance for lower-risk items; record overrides where appropriate.
- **Measure actual outcomes.** Track task completion time, steps, error/redo rates, failed submissions, abandonment, and safety events—without logging unnecessary patient-identifying data.

## Required screen-by-screen audit method

Every screen and modal gets its own audit entry; route-level review alone is insufficient. For each surface:

1. Identify its users/roles, job-to-be-done, entry points, expected result, and exit/next step.
2. Map the real current workflow, including manual workarounds, duplicated entry, role handoffs, exceptions, and failure states.
3. Inspect UI hierarchy, navigation, responsive behavior, scrolling, information density, labels, keyboard/touch ergonomics, loading/empty/error/success states, and dialog behavior.
4. Inspect business rules, permissions, data source of truth, validation, concurrency, audit trail, branch isolation, and recoverability.
5. Compare the workflow with authoritative clinical/operational guidance relevant to that module.
6. Propose options (retain/refine/rebuild), score expected impact/risk/effort, and record the reason for the chosen approach.
7. Build a prototype or implementation, then test the real task with representative users/scenarios and regression tests.
8. Record evidence, known limitations, telemetry/acceptance criteria, and the follow-up owner/status.

Each audit record must include: `surface_id`, route/component, role, primary job, baseline steps/time, observed friction, safety/security risks, recommended design, workflow/business-rule changes, automation candidates, accessibility/mobile notes, tests, evidence/source dates, priority, status, and acceptance result.

## Current application surface inventory (to be verified against the full route tree)

The following routes were found in the current repository. Each page and its nested dialogs/forms will be tracked separately in the audit matrix.

### Shell, navigation, access, and discovery
- `src/routes/index.tsx` — entry/redirect
- `src/routes/auth.tsx` — authentication
- `src/routes/setup.tsx` — initial setup
- `src/routes/_authenticated/route.tsx` — authenticated shell/access boundary
- `src/routes/_authenticated/settings.tsx` — settings
- `src/routes/_authenticated/users.tsx` — users/roles
- `src/routes/_authenticated/audit.tsx` — audit log
- `src/components/nav-rail.tsx`, `mobile-bottom-nav.tsx`, `breadcrumb-nav.tsx`, `global-search-dialog.tsx`, `patient-picker.tsx`
- Shared overlays: `src/components/ui/dialog.tsx`, `alert-dialog.tsx`, `drawer.tsx`, `sidebar.tsx`

### Front desk and clinical work
- `dashboard.tsx` — dashboard
- `queue.tsx` — queue/waiting list
- `appointments.tsx` — appointments
- `patients.tsx` and `patients_.$patientId.tsx` — patient list and patient chart
- `visits.tsx` and `clinic.tsx` — visits/consultation
- `clinic_.$visitId.tsx` — visit detail
- `followups.tsx` — follow-up workflow
- `certificates.tsx` — certificates/referrals as applicable

### Diagnostics, pharmacy, and stock
- `lab.tsx`, `lab_.$orderId.tsx`, `lab-catalog.tsx` — lab orders, result workflow, catalog
- `pharmacy.tsx` — dispensing
- `inventory.tsx` — stock/batches/suppliers and stock movements

### Billing, finance, and reporting
- `billing.tsx`, `billing_.$invoiceId.tsx` — invoices
- `insurance.tsx` — insurance claims
- `finance.tsx` — finance
- `accounting.tsx` — accounting
- `expenses.tsx` — expenses
- `partners.tsx` — partners
- `analytics.tsx` — analytics
- `reports.tsx` — reports

### Required cross-cutting overlays and components
Audit every dialog, alert dialog, drawer, popover, confirmation, command/search palette, patient picker, form wizard, dropdown, context menu, empty state, and toast. Build an inventory from actual component usage rather than assuming the shared UI primitives are the only overlays.

## Navigation and shell redesign

Evaluate the information architecture against real user tasks and role frequency. Explore, then test, a compact role-aware shell with:
- a stable primary navigation model on desktop and phone;
- a persistent patient/encounter context when clinically appropriate;
- global search that can find patients and common tasks with permission-aware results;
- a clear “next action” model for queues, unsigned work, pending lab results, refill/stock alerts, invoices, and follow-ups;
- breadcrumbs/back behavior that does not discard work;
- consistent page titles, status, filters, and primary action placement;
- sensible keyboard shortcuts for high-frequency desktop work, with visible discovery and no mobile dependency;
- loading/skeleton, no-results, offline/connection failure, empty, and permission-denied states that explain recovery;
- no navigation dead ends or actions that silently switch patient/branch/context.

Do not commit to a new navigation structure from aesthetics alone. Compare at least two IA options with task-based walkthroughs for receptionist, GP, specialist, lab, pharmacist, and admin.

## Dialogs, drawers, forms, and overlays

Create a dialog/overlay inventory and classify each use:
- **Dialog:** a focused short task that must be resolved before returning.
- **Drawer/side panel:** contextual detail or secondary work that benefits from retaining the underlying page.
- **Full page:** complex, high-risk, multi-step, or lengthy workflows (e.g., clinical note, prescription, claim review) that should not be squeezed into a small modal.
- **Inline disclosure:** optional details or low-severity guidance.
- **Confirmation:** reserve for destructive, irreversible, financial, or clinically consequential actions; state the consequence clearly.
- **Toast/banner:** brief result/status; never the only way to report a critical failure or a pending action.

Standardize focus entry/return, escape/backdrop behavior, scroll containment, mobile sizing, close-with-unsaved-work handling, button labels, field validation, error summary, retry, duplicate-submit prevention, and success confirmation. Avoid nested dialogs and long forms in tiny modals.

## Clinical workflow and prescribing redesign

### Prescription authoring
Design a guided, patient-context-aware medication order flow:
1. Confirm the correct patient and encounter, age/date of birth, weight (with date/source), allergies, relevant diagnoses, pregnancy/lactation status when applicable, renal/hepatic context where known, and current medications.
2. Search/select a canonical medicine and distinguish ingredient, brand, strength, dosage form, route, and formulation. Reduce look-alike/sound-alike selection errors.
3. Load a **versioned, reviewed medicine knowledge record** with applicable indications, age/weight restrictions, dose basis/range, route, frequency options, duration options, max single/daily dose, contraindications, interactions, monitoring, counseling, and source/version/effective date where available.
4. Suggest common regimens only when the medicine, indication, patient characteristics, formulation, and source support them. Do not infer a regimen from the medicine name alone.
5. Calculate weight-based doses only when current weight and units are available and the rule is explicitly sourced; show calculation, dose range, maximum cap, rounded deliverable dose, and the resulting quantity. Validate unit conversions and mg-versus-mL concentration carefully.
6. Make duration/frequency choices medication- and indication-specific, not one universal dropdown. Distinguish PRN from scheduled use; require an indication and maximum use where appropriate.
7. Check duplicate therapy, allergy, clinically significant interactions, dose limits, age restrictions, contraindications, and relevant monitoring. Keep alerts specific and actionable; allow documented overrides only where clinically appropriate.
8. Present a readable final prescription for clinician review, including generic/brand, strength, form, dose, route, frequency, duration, quantity, refills if supported, and patient instructions.
9. Sign/submit only after required fields and safety checks pass. Preserve drafts, support correction/cancellation, and audit consequential changes.
10. Provide pharmacist verification/clarification workflows without silently changing the prescriber's intent.

### Clinical content governance — critical
- Never invent or scrape arbitrary “latest dose” values into production.
- Maintain a named source hierarchy approved for the clinic (e.g., WHO guidance, applicable national guidance, current licensed drug reference, specialty guidelines, and local formulary); verify applicability, age group, indication, country, formulation, and date.
- Drug reference licensing, copyright, data redistribution, and API terms must be checked before integrating commercial sources.
- Every rule must carry provenance, version, review date, population/indication, contraindications, and responsible clinical reviewer.
- Clinical content updates require review, regression testing, staged release, monitoring, and rollback.
- If data are missing, contradictory, stale, or outside a validated population, the system must say so and not fabricate a confident recommendation.
- Initial implementation should prioritize a small, high-volume, high-risk set selected by the clinic's clinical lead, then expand only after verification. A qualified clinician/pharmacist must approve every production regimen.

## Workflow redesign by module

- **Registration/patient identity:** minimize duplicate records; search before create; show strong identity cues; handle unknown DOB/weight/allergies honestly; preserve branch isolation.
- **Queue/appointments:** check in once, clear statuses, estimated wait where defensible, one-click open encounter, prioritize urgent cases through a clinically approved process; prevent duplicate queue tickets.
- **Consultation:** one longitudinal chart context; reuse vitals and history; structured and free-text notes; templates by presentation/specialty; problem/diagnosis-to-orders links; autosave; clearly distinguish draft, signed, amended, and closed.
- **Orders/results:** clear order status and ownership, specimen/collection states, abnormal-result highlighting with context, escalation and acknowledgment for critical results, no “complete” state without required follow-up.
- **Pharmacy dispensing:** prescription verification, product/strength/form match, batch FEFO, stock availability, partial fill/backorder/shortage handling, counseling, substitution policy, inventory movement, and sale posting must form a consistent auditable workflow.
- **Inventory/suppliers:** atomic stock receipt, explicit batch/expiry/cost/supplier, FEFO, reorder thresholds, near-expiry and stockout worklists, supplier invoice matching, controlled adjustments with reason, and one source-of-truth policy for legacy aggregate versus batch stock.
- **Billing/insurance:** prevent duplicate invoices/claims, show patient balance and coverage, validate invoice-claim linkage, explain rejection/correction paths, and keep financial actions atomic/idempotent.
- **Cashbox/accounting/expenses:** explicit opening/closing balances, reconciliations, reversals rather than silent edits, clear source transaction links, permission checks, branch/currency context, and exportable audit trails.
- **Lab:** order-to-collection-to-processing-to-result-to-review-to-notification lifecycle, critical values escalation, corrections with audit trail, and no orphaned results.
- **Follow-up/referral/certificates:** due-date queues, clear owner and status, structured reason/outcome, missed follow-up worklist, and privacy-aware printed outputs.
- **Dashboard/analytics/reports:** role-specific actionable worklists rather than decorative charts; consistent definitions and date filters; drill-down to source records; no metric without documented calculation.
- **Users/settings/audit:** least privilege, preview permission changes, prevent accidental lockout, searchable audit trail, clear branch/role scoping, and secure configuration.
- **Search/global navigation:** support patient and task search, keyboard/touch, recent items only where privacy-safe, visible context, and permission-filtered results.

## Automation backlog (candidate features, gated by validation)

- Autofill verified patient/encounter context and avoid repeated data entry.
- Medication-specific, versioned order sets and favorite templates.
- Weight-based dose calculator with explicit units, caps, rounded deliverable dose, and hard stops for missing required inputs.
- Duplicate/allergy/interaction checks with severity tiers and override logging.
- Auto-generated prescription directions and patient instructions from structured, reviewed orders.
- Queue and pending-work dashboards that surface the next action.
- Lab critical-result routing and acknowledgment.
- Appointment/follow-up reminders when contact consent and local constraints permit.
- FEFO batch suggestion and low-stock/expiry alerts.
- Atomic/idempotent posting for stock, billing, cashbox, and claim workflows.
- Autosave, draft recovery, retry-safe submissions, and prevention of double clicks.
- Smart defaults and keyboard shortcuts for repetitive safe tasks.
- Report/export generation from a single documented source of truth.
- Background automation should have a visible status, failure queue, retry strategy, audit trail, and human override where consequential.

## Measurement and acceptance gates

Establish baseline before redesign. For each high-frequency workflow, measure:
- median and 90th-percentile time to complete;
- number of actions/field entries and context switches;
- validation failures, duplicate submissions, cancellations, and rework;
- wrong-patient/wrong-product/incorrect-dose near misses and other safety signals;
- completion rate, user-reported confidence, and accessibility defects;
- mobile viewport and low-bandwidth performance;
- authorization, branch-isolation, RLS, and audit correctness.

No screen is considered complete solely because it compiles. A redesign must pass:
1. unit/contract tests for logic and permissions;
2. typecheck/lint/build;
3. end-to-end scenarios for the relevant role;
4. mobile/RTL/LTR/accessibility checks;
5. negative tests and failure/retry paths;
6. review of audit events and source-of-truth behavior;
7. clinical review for any clinical content or CDS behavior.

## Prioritization and delivery sequence

**P0 — safety and foundation**
- Patient identity/context, role/branch permission consistency, modal/dialog failure handling.
- Medication order model, formulary/source governance, patient-specific dose safeguards.
- Critical lab result ownership/follow-up.
- Inventory/dispensing transaction integrity and data source of truth.
- Baseline test and screen/overlay inventory.

**P1 — highest-frequency work**
- Navigation shell, global search, dashboard/work queues.
- Registration, queue, patient chart, consultation, prescription.
- Pharmacy dispensing, stock receipt, lab order/result, invoice/claim.

**P2 — operational completion**
- Follow-up, appointments, finance/cashbox/accounting, expenses, analytics/reports, certificates, partners, settings/users/audit.

**P3 — optimization**
- Advanced keyboard workflows, saved views, personalization, richer automation, offline/resilience improvements, and further analytics after data quality is proven.

This is a risk-weighted order, not a substitute for measured baseline usage; reprioritize if clinic observations show a different risk/frequency profile.

## Open decisions to resolve during the audit

- Which medicine references/formulary are licensed, affordable, accessible, and clinically approved for use in Sudan?
- Who is the named clinical owner for medicine protocols, and who covers review/update when that person is unavailable?
- Which flows must work during unstable connectivity, and what offline data can be safely cached?
- Which user roles and branches are expected at launch versus later?
- What is the approved policy for substitutions, partial fills, high-alert medicines, pediatric prescriptions, pregnancy/lactation, and renal/hepatic dose adjustments?
- Which workflows need printed Arabic/English outputs and what legal/regulatory fields must appear?

## Implementation tracking

For each route and overlay, create a separate row in the audit register and attach screenshots/prototypes, observed task traces, chosen decision, code/test links, and status. Do not mark a screen “audited” until its primary and failure workflows have been reviewed. Do not batch-rewrite all routes without a reviewed design foundation and a staged migration plan.
