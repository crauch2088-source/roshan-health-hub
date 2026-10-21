# UX release-gate route inventory — 2026-10-21

Issue: [#95 — full-screen and mobile UX acceptance](https://github.com/crauch2088-source/roshan-health-hub/issues/95)  
Baseline main SHA: 311d1073327499b628f04c5d398c9e51e0c7a1ff  
Status: static source scan only. **NOT VERIFIED: no authenticated screenshots or viewport evidence are recorded.**

## Evidence and rules

- A source scan is not a behavior review. Route loading, source-contract tests, green CI, or a READY deployment never counts as visual acceptance.
- Main had 23/23 successful check runs. Exact-head runs: [CI 39517281809](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39517281809), [source parity 39517281812](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39517281812), [finance RPC 39517281807](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/39517281807). These are not browser acceptance.
- Latest READY production SHA observed: b604b8762663ac5ff7482afe5b04632743c0df32. Current-main deployment attempt for 311d1073327499b628f04c5d398c9e51e0c7a1ff was CANCELED. Exact-main deployment remains unverified; do not bypass free-tier limits.
- Production is read-only: no production record creation/mutation, even with synthetic values. Clinical end-to-end acceptance tests remain deferred until an isolated zero-cost test environment and synthetic doctor identity are available.
- All route rows below remain NOT VERIFIED. No route is marked PASS merely because it loads.

## Authenticated routes

| File | Surface | Source scan | Visual status | Next inspection |
| --- | --- | --- | --- | --- |
| src/routes/_authenticated/accounting.tsx | Accounting | Static only | NOT VERIFIED | Journal, filters, amounts, RTL, empty/error. |
| src/routes/_authenticated/analytics.tsx | Analytics | Static only | NOT VERIFIED | Charts, legends, empty states, numeric LTR. |
| src/routes/_authenticated/appointments.tsx | Appointments | Static only | NOT VERIFIED | Date controls, validation, dialogs, permissions. |
| src/routes/_authenticated/audit.tsx | Audit log | Static only | NOT VERIFIED | Long metadata, filters, read-only behavior. |
| src/routes/_authenticated/billing.tsx | Billing list | Static only | NOT VERIFIED | Invoice table, create dialog, amount alignment. |
| src/routes/_authenticated/billing_.$invoiceId.tsx | Invoice detail | Static only | NOT VERIFIED | Totals, status/error and narrow layout; no payment. |
| src/routes/_authenticated/certificates.tsx | Certificates | Static only | NOT VERIFIED | Visit link, serial LTR, print layout; no issue/upload. |
| src/routes/_authenticated/clinic.tsx | Clinic | Static only | NOT VERIFIED | Active visits, navigation, role denial. |
| src/routes/_authenticated/clinic_.$visitId.tsx | Visit redirect | Static only | NOT VERIFIED | Valid/invalid route transitions; no clinical writes. |
| src/routes/_authenticated/dashboard.tsx | Dashboard | Static only | NOT VERIFIED | Cards/charts, role metrics, dates and amounts. |
| src/routes/_authenticated/expenses.tsx | Expenses | Static only | NOT VERIFIED | Filters, amount fields, permissions; no submit. |
| src/routes/_authenticated/finance.tsx | Finance hub | Static only | NOT VERIFIED | Cashbox, receivables, dialogs; no posting/reversal. |
| src/routes/_authenticated/followups.tsx | Follow-ups | Static only | NOT VERIFIED | Dates, statuses, long text and empty/error. |
| src/routes/_authenticated/insurance.tsx | Insurance | Static only | NOT VERIFIED | Claims/tabs, amounts, role restrictions; no writes. |
| src/routes/_authenticated/inventory.tsx | Inventory | Static only | NOT VERIFIED | Batch/expiry tables, dialogs; no stock movement. |
| src/routes/_authenticated/lab-catalog.tsx | Lab catalog | Static only | NOT VERIFIED | Units/ranges, warnings; do not save or invent values. |
| src/routes/_authenticated/lab.tsx | Lab queue | Static only | NOT VERIFIED | Queue states, identifiers, verification entry points. |
| src/routes/_authenticated/lab_.$orderId.tsx | Lab detail | Static only | NOT VERIFIED | Results, units, verified state; no save/verify/upload. |
| src/routes/_authenticated/partners.tsx | Partners | Static only | NOT VERIFIED | Long names, validation, edit dialog; no save. |
| src/routes/_authenticated/patients.tsx | Patient list | Static only | NOT VERIFIED | Search, table/cards, form labels; no submit. |
| src/routes/_authenticated/patients_.$patientId.tsx | Patient detail | Static only | NOT VERIFIED | Tabs, history, identifier direction; avoid real details. |
| src/routes/_authenticated/pharmacy.tsx | Pharmacy | Static only | NOT VERIFIED | Medicine/strength LTR, stock warnings; no dispense. |
| src/routes/_authenticated/queue.tsx | Queue | Static only | NOT VERIFIED | Ticket readability, status controls; no updates. |
| src/routes/_authenticated/reports.tsx | Reports | Static only | NOT VERIFIED | Filters, charts/tables; no sensitive exports. |
| src/routes/_authenticated/route.tsx | Authenticated boundary | Static only | NOT VERIFIED | Redirects and no protected-content flash. |
| src/routes/_authenticated/settings.tsx | Settings | Static only | NOT VERIFIED | Status/errors; no configuration changes. |
| src/routes/_authenticated/users.tsx | Users/roles | Static only | NOT VERIFIED | Role matrix, labels, responsive layout; no user changes. |
| src/routes/_authenticated/visits.tsx | Visits | Static only | NOT VERIFIED | Registration validation/list; no visit creation. |

## Cross-cutting surfaces

| File | Visual status | Next inspection |
| --- | --- | --- |
| src/components/app-shell.tsx | NOT VERIFIED | Header collisions, skip link, safe area, all widths/directions. |
| src/components/nav-rail.tsx | NOT VERIFIED | Expanded/collapsed, tooltips, favorites, keyboard/touch. |
| src/components/mobile-bottom-nav.tsx | NOT VERIFIED | Labels, FAB overlap, More sheet, safe area. |
| src/components/breadcrumb-nav.tsx | NOT VERIFIED | Nested routes, long translated labels. |
| src/components/global-search-dialog.tsx | NOT VERIFIED | Focus, loading/empty/error, keyboard and narrow viewport. |
| src/components/command-palette-provider.tsx | NOT VERIFIED | Ctrl/Cmd+K, typing/IME and permission denial. |
| src/features/clinic/consultation/ConsultationPage.tsx | NOT VERIFIED | Tabs/focus and read-only layout; no clinical writes. |
| src/components/clinical-attachment-uploader.tsx | NOT VERIFIED | Disabled/fallback UI only; no upload. |

## Release decision

Keep issue #95 open. Next: obtain a zero-cost authenticated browser session and READY deployment matching main, run the route matrix at 320 × 640, 360 × 800, 390 × 844 and 430 × 932 in Arabic RTL and English LTR, then remediate P0/P1 findings with regression tests. Do not start another feature workstream before this gate closes.
