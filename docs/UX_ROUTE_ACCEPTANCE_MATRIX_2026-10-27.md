# UX Route Acceptance Matrix — 2026-10-27

## Scope and evidence identity

- Inventory source: current repository tree and `src/config/nav.ts`.
- Source baseline inspected: `main` `5c92e2fa921d7de86e2f9b1e45ba8bf92fb301c0`.
- Latest production code deployment verified at this snapshot: `dpl_9NgLmr4sGFvcVbcWHawKAFFo8ZHN`, state `READY`, source SHA `224e0f7bc4aa02292571b6cee5a2716502e70acf`, alias `roshan-health-hub.vercel.app`. The newer `main` commit is documentation-only; its Vercel deployment was canceled by the configured build-ignore rule.
- Exact-main checks for documentation SHA `5c92e2fa...`: CI `40460461471`, finance-only RPC isolation `40460461379`, and push-on-main `40460460823` all succeeded.
- Inventory contains **27 authenticated page routes** (23 top-level navigation destinations plus four detail routes) and **3 public page routes**. The authenticated layout `/_authenticated` and root layout are structural routes, not counted as pages.

## Status vocabulary

- **SOURCE-GUARDED** means the existing Phase 42 source-contract test checks that the navigation destination has the configured `PermissionGate` permission. It is not proof of runtime authorization or a successful user journey.
- **SOURCE-INVENTORIED** means the route file exists and is listed here, but this matrix does not claim a route-specific permission test.
- **NOT TESTED** means no browser screenshot, viewport, keyboard, or visual-state evidence was captured in this run.
- **BLOCKED/DEFERRED** means authenticated role/workflow acceptance awaits the authorized isolated QA login path and suitable synthetic clinician identity. It is not a pass.

## Authenticated page routes

| Route | Source file | Navigation permission | Source-contract status | Browser / visual / keyboard | Authenticated role / workflow |
|---|---|---|---|---|---|
| `/dashboard` | `src/routes/_authenticated/dashboard.tsx` | `dashboard.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/patients` | `src/routes/_authenticated/patients.tsx` | `patients.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/patients/$patientId` | `src/routes/_authenticated/patients_.$patientId.tsx` | Detail route; not a nav item | SOURCE-INVENTORIED | NOT TESTED | BLOCKED/DEFERRED |
| `/visits` | `src/routes/_authenticated/visits.tsx` | `visits.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/queue` | `src/routes/_authenticated/queue.tsx` | `queue.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/clinic` | `src/routes/_authenticated/clinic.tsx` | `visits.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/clinic/$visitId` | `src/routes/_authenticated/clinic_.$visitId.tsx` | Detail route; not a nav item | SOURCE-INVENTORIED | NOT TESTED | BLOCKED/DEFERRED |
| `/appointments` | `src/routes/_authenticated/appointments.tsx` | `appointments.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/followups` | `src/routes/_authenticated/followups.tsx` | `followups.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/certificates` | `src/routes/_authenticated/certificates.tsx` | `certificates.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/pharmacy` | `src/routes/_authenticated/pharmacy.tsx` | `pharmacy.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/inventory` | `src/routes/_authenticated/inventory.tsx` | `pharmacy.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/lab` | `src/routes/_authenticated/lab.tsx` | `lab.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/lab/$orderId` | `src/routes/_authenticated/lab_.$orderId.tsx` | Detail route; not a nav item | SOURCE-INVENTORIED | NOT TESTED | BLOCKED/DEFERRED |
| `/lab-catalog` | `src/routes/_authenticated/lab-catalog.tsx` | `lab_admin.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/billing` | `src/routes/_authenticated/billing.tsx` | `billing.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/billing/$invoiceId` | `src/routes/_authenticated/billing_.$invoiceId.tsx` | Detail route; not a nav item | SOURCE-INVENTORIED | NOT TESTED | BLOCKED/DEFERRED |
| `/finance` | `src/routes/_authenticated/finance.tsx` | `cashbox.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/accounting` | `src/routes/_authenticated/accounting.tsx` | `accounting.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/expenses` | `src/routes/_authenticated/expenses.tsx` | `accounting.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/partners` | `src/routes/_authenticated/partners.tsx` | `partners.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/reports` | `src/routes/_authenticated/reports.tsx` | `reports.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/analytics` | `src/routes/_authenticated/analytics.tsx` | `reports.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/insurance` | `src/routes/_authenticated/insurance.tsx` | `insurance.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/users` | `src/routes/_authenticated/users.tsx` | `users.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/audit` | `src/routes/_authenticated/audit.tsx` | `audit.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/settings` | `src/routes/_authenticated/settings.tsx` | `settings.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |

## Public page routes

| Route | Source file | Existing source evidence | Browser / visual / keyboard | Status |
|---|---|---|---|---|
| `/` | `src/routes/index.tsx` | Route exists; this matrix makes no behavioral claim | NOT TESTED | NOT TESTED |
| `/auth` | `src/routes/auth.tsx` | Phase 42 tests assert POST form, skip link, and semantic main landmark | NOT TESTED | NOT TESTED |
| `/setup` | `src/routes/setup.tsx` | Phase 42 tests assert POST form, skip link, semantic main landmark, and setup permission-denial handling | NOT TESTED | NOT TESTED |

## Coverage gaps and next acceptance session

1. No screenshot or interactive browser evidence was captured in this run. All routes remain **NOT TESTED** for the required 320/360/390/430 CSS-pixel viewports, Arabic RTL, English LTR, dialogs, loading/empty/error/retry states, focus order, and keyboard-only navigation.
2. The 23 navigation permission checks are source contracts only; they do not prove server-side rejection for every role. The four detail routes require independent role/permission review.
3. Authenticated clinical E2E and staff acceptance remain **BLOCKED/DEFERRED** until the free isolated QA environment has a supported login path and suitable synthetic clinician identity. Do not create production fixtures or treat a route rendering as acceptance.
4. During the authorized comprehensive session, capture route + viewport + language + role + action + expected/actual result for each finding, with redacted screenshots. Record PASS only after the relevant interaction is exercised.
5. Keep Issue #95 open until this matrix's NOT TESTED/BLOCKED entries are resolved or explicitly accepted under the documented release gate.
