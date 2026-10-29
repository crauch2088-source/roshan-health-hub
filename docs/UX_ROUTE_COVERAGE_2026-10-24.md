# Roshan Health Hub — Route Coverage Inventory (2026-10-24)

**Source SHA:** 82c9a8306e4f611bcd593eeb5b192fd15b693265  
**Generation:** Git tree-derived inventory. This is a baseline, not evidence of browser testing. All routes are NOT TESTED until a valid current-session check is recorded.

## Status vocabulary

PASS, FAIL, BLOCKED, NOT TESTED, N/A (reason required). Never infer PASS from a source guard, CI success or an older deployment.

## Public/root routes

| Route/source | Scope | Status | Evidence / next action |
|---|---|---|---|
| src/routes/__root.tsx | Root document/layout | NOT TESTED | Capture current route behavior and record source/deployment SHA |
| src/routes/auth.tsx | Authentication | NOT TESTED | Check unauthenticated flow and accessible form behavior |
| src/routes/index.tsx | Public landing/redirect | NOT TESTED | Check current canonical behavior |
| src/routes/setup.tsx | Setup access/denial | NOT TESTED | Check authorized and denied states without bypassing access |

## Authenticated routes

| Route/source | Main task family | Status | Required evidence |
|---|---|---|---|
| src/routes/_authenticated/accounting.tsx | Accounting | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/analytics.tsx | Analytics | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/appointments.tsx | Appointments | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/audit.tsx | Audit trail | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/billing.tsx | Billing and invoices | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/billing_.$invoiceId.tsx | Invoice details | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/certificates.tsx | Medical certificates | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/clinic.tsx | Consultation | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/clinic_.$visitId.tsx | Visit-specific consultation | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/dashboard.tsx | Dashboard | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/expenses.tsx | Expenses | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/finance.tsx | Finance/cashbox | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/followups.tsx | Follow-ups | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/insurance.tsx | Deferred insurance — regression checks only | NOT TESTED | Check only for regressions; do not expand scope |
| src/routes/_authenticated/inventory.tsx | Inventory | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/lab-catalog.tsx | Laboratory catalogue | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/lab.tsx | Laboratory worklist | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/lab_.$orderId.tsx | Laboratory order/results | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/partners.tsx | Finance partners | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/patients.tsx | Patient search/registration | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/patients_.$patientId.tsx | Patient profile/identity | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/pharmacy.tsx | Pharmacy/dispensing | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/queue.tsx | Queue | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/reports.tsx | Reports | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/settings.tsx | Settings/branch context | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/users.tsx | Users/roles | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |
| src/routes/_authenticated/visits.tsx | Visits | NOT TESTED | Role/permission, RTL/LTR, 320/360/390/430px, loading/empty/error/success and primary actions |

## Evidence record template

For each check record route, action/state, role and permission, branch, language/direction, viewport, browser/device, source SHA, deployment SHA/URL, expected versus observed, status, evidence reference, defect ID, regression test, retest SHA and UTC timestamp. Never put patient identifiers, credentials, cookies, tokens or raw sensitive HAR/trace files in this repository.

## Coverage note

- Authenticated route files enumerated: 27.
- Public/root TSX route files enumerated: 4 (route README excluded).
- Dialogs/drawers/command palette are not all separate routes; inventory them during Phase 1.
- Regenerate/reconcile this list if route source changes.
