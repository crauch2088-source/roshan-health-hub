# Roshan Health Hub — Screen-by-Screen UX and Workflow Audit Register

Snapshot: 2026-10-15  
Baseline: `main` at `a64f804679aeaae7299b034176f2265ac1806db0`  
Status definitions: `Not started` → `Mapped` → `Reviewed` → `Prototyped` → `Implemented` → `Verified`.

This is a work register, not a claim that the listed surfaces have already been audited. Every route is a separate audit item. Every nested form, dialog, drawer, confirmation, dropdown, empty/error state, and multi-step flow discovered during code inspection must also receive its own item and parent/child relationship. Priorities are provisional risk/frequency estimates and must be recalibrated after task observation.

| ID | Surface | Current source | Primary audit focus | Priority | Status |
|---|---|---|---|---|---|
| UX-001 | Shell | `src/routes/__root.tsx` | Global layout, app shell, route transitions | P0 | Not started |
| UX-002 | Entry | `src/routes/index.tsx` | Landing/redirect and first-use path | P1 | Not started |
| UX-003 | Authentication | `src/routes/auth.tsx` | Login, errors, session recovery | P0 | Not started |
| UX-004 | Initial setup | `src/routes/setup.tsx` | First-run setup and configuration | P1 | Not started |
| UX-005 | Authenticated shell | `src/routes/_authenticated/route.tsx` | Auth gate, permissions, branch/user context | P0 | Not started |
| UX-006 | Dashboard | `src/routes/_authenticated/dashboard.tsx` | Role-specific work queue and next actions | P1 | Not started |
| UX-007 | Queue | `src/routes/_authenticated/queue.tsx` | Check-in, waiting, priority, open encounter | P1 | Not started |
| UX-008 | Appointments | `src/routes/_authenticated/appointments.tsx` | Schedule, booking, check-in, reschedule | P1 | Not started |
| UX-009 | Patient list | `src/routes/_authenticated/patients.tsx` | Search, deduplication, registration | P0 | Not started |
| UX-010 | Patient chart | `src/routes/_authenticated/patients_.$patientId.tsx` | Longitudinal chart and patient context | P0 | Mapped |
| UX-011 | Visits | `src/routes/_authenticated/visits.tsx` | Visit lifecycle and encounter worklist | P1 | Mapped |
| UX-012 | Clinic consultation | `src/routes/_authenticated/clinic.tsx` | Clinical note, diagnosis, orders, prescription | P0 | Not started |
| UX-013 | Visit detail | `src/routes/_authenticated/clinic_.$visitId.tsx` | Resume/review a specific encounter | P0 | Not started |
| UX-014 | Follow-ups | `src/routes/_authenticated/followups.tsx` | Due follow-up and closure loop | P2 | Not started |
| UX-015 | Certificates | `src/routes/_authenticated/certificates.tsx` | Certificate/referral document workflow | P2 | Not started |
| UX-016 | Lab orders | `src/routes/_authenticated/lab.tsx` | Order, collect, process, track result | P0 | Not started |
| UX-017 | Lab order detail | `src/routes/_authenticated/lab_.$orderId.tsx` | Result entry, review, correction, escalation | P0 | Mapped |
| UX-018 | Lab catalog | `src/routes/_authenticated/lab-catalog.tsx` | Test catalog, price, specimen/reference settings | P2 | Not started |
| UX-019 | Pharmacy | `src/routes/_authenticated/pharmacy.tsx` | Prescription validation, dispensing, counseling | P0 | Mapped |
| UX-020 | Inventory | `src/routes/_authenticated/inventory.tsx` | Batches, receipts, FEFO, stock movements | P0 | Not started |
| UX-021 | Billing | `src/routes/_authenticated/billing.tsx` | Invoice creation, payment, balance | P0 | Not started |
| UX-022 | Invoice detail | `src/routes/_authenticated/billing_.$invoiceId.tsx` | Invoice lifecycle, receipt, corrections | P1 | Not started |
| UX-023 | Insurance | `src/routes/_authenticated/insurance.tsx` | Claim creation, validation, submission, rejection | P1 | Not started |
| UX-024 | Finance | `src/routes/_authenticated/finance.tsx` | Financial overview and reconciliation | P1 | Not started |
| UX-025 | Accounting | `src/routes/_authenticated/accounting.tsx` | Ledger, entries, reversals, reconciliation | P1 | Not started |
| UX-026 | Expenses | `src/routes/_authenticated/expenses.tsx` | Expense capture and approval | P2 | Not started |
| UX-027 | Partners | `src/routes/_authenticated/partners.tsx` | Partner/supplier/contract relationships | P2 | Not started |
| UX-028 | Analytics | `src/routes/_authenticated/analytics.tsx` | Actionable metrics and drill-down | P2 | Not started |
| UX-029 | Reports | `src/routes/_authenticated/reports.tsx` | Report filters, exports, auditability | P2 | Not started |
| UX-030 | Users | `src/routes/_authenticated/users.tsx` | Accounts, role/permission changes | P0 | Not started |
| UX-031 | Settings | `src/routes/_authenticated/settings.tsx` | Configuration, branch and system settings | P1 | Not started |
| UX-032 | Audit log | `src/routes/_authenticated/audit.tsx` | Searchable audit evidence and access review | P1 | Not started |
| UX-033 | Global search dialog | `src/components/global-search-dialog.tsx` | Search patients/tasks and keyboard/touch use | P1 | Not started |
| UX-034 | Patient picker | `src/components/patient-picker.tsx` | Patient selection, disambiguation, context safety | P0 | Mapped |
| UX-035 | Desktop nav rail | `src/components/nav-rail.tsx` | Information architecture and role-aware nav | P1 | Not started |
| UX-036 | Mobile bottom nav | `src/components/mobile-bottom-nav.tsx` | Mobile navigation and reachability | P1 | Not started |
| UX-037 | Breadcrumb nav | `src/components/breadcrumb-nav.tsx` | Back/return paths and context preservation | P2 | Not started |
| UX-038 | Dialog primitive | `src/components/ui/dialog.tsx` | Focus, escape, scroll, unsaved changes | P0 | Mapped |
| UX-039 | Alert dialog primitive | `src/components/ui/alert-dialog.tsx` | Consequential/destructive confirmation | P0 | Not started |
| UX-040 | Drawer primitive | `src/components/ui/drawer.tsx` | Contextual secondary tasks and mobile behavior | P1 | Not started |
| UX-041 | Sidebar primitive | `src/components/ui/sidebar.tsx` | Navigation states, responsive layout | P1 | Not started |
| UX-042 | Prescription authoring | `src/features/clinic/consultation/components/PrescriptionTab.tsx` | Medicine-specific regimen, patient context, units, catalog search, atomic save | P0 | Mapped |

## Required audit record for every item

- **Current behavior:** screenshot/reference, component and route dependencies, actions, field inventory, data source, states.
- **User/job:** role(s), entry point, goal, successful outcome, handoff and next step.
- **Task baseline:** actions/clicks, typed fields, navigation/context switches, time, errors/rework (measured or explicitly unknown).
- **Workflow:** happy path, alternate paths, cancellations, missing data, invalid input, slow network, server failure, retry, duplicate submission, stale state, and permission denial.
- **Safety/security:** patient identity, branch context, authorization/RLS, data integrity, audit events, clinical/financial risk, destructive actions.
- **UX/accessibility:** hierarchy, visual density, responsive layout, RTL/LTR, focus/keyboard, touch target, screen-reader labels, validation/recovery, loading/empty/success states.
- **Automation:** safe prefill, defaults, reusable templates, task queues, calculated fields, rule-based checks, reminders, batch operations, retry/idempotency.
- **Evidence:** relevant official guideline/standard and version/date; clinical reviewer where applicable.
- **Decision:** retain/refine/rebuild, alternatives considered, reason, impact/risk/effort.
- **Acceptance:** tests, end-to-end scenarios, measured before/after, residual risks, reviewer, date.

## Overlay discovery checklist

Search code and runtime for all use sites of Dialog, AlertDialog, Drawer, Popover, Select, command/search palette, confirmation, toast, and custom fixed/absolute overlays. Add one row per concrete workflow, not only one row per primitive. For each, capture: trigger, context, purpose, dismiss behavior, focus management, mobile adaptation, validation, loading, server error, retry, unsaved changes, and whether a full page would be safer.

## Completion gate

A route cannot be marked Verified until its core task, high-risk alternate paths, mobile viewport, Arabic RTL and English LTR, permission-negative case, network/server failure, and relevant regression suite have been tested. Clinical decision support or drug content also requires source/version provenance and approval by the designated clinical reviewer. Record objective before/after metrics wherever possible.
