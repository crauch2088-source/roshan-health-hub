# UX Route Acceptance Matrix — 2026-10-27

## Scope and evidence identity

- Inventory source: current repository tree and `src/config/nav.ts`.
- Source baseline refreshed: `main` `e54892d7158c85c1832afe361ec7f81e0f05f87c`; this merge changes the route-contract test and acceptance documentation only, not application runtime.
- Current production deployment: `dpl_HSXd9Ss53pMX5uvnKKBEnHLBwq2f`, state `READY`, application source SHA `123bc8b92ddbc64ef236d50c6c822d030b38d390`, alias `roshan-health-hub.vercel.app`, `aliasError: null`. The source/runtime difference consists of later test/documentation-only commits.
- Production dependency batch PR #118 is merged on application SHA `123bc8b...`; exact application CI and Vercel deployment evidence is recorded in the master plan. This does not imply browser/clinical acceptance.
- Inventory contains **27 authenticated page routes** (23 top-level navigation destinations plus four detail routes) and **3 public page routes**. The authenticated layout `/_authenticated` and root layout are structural routes, not counted as pages.

## Status vocabulary

- **SOURCE-GUARDED** means the Phase 42 source-contract test checks the configured `PermissionGate` permission for a navigation destination or detail route. It is not proof of runtime authorization or a successful user journey.
- **SOURCE-INVENTORIED** means the route file exists and is listed here, but this matrix does not claim a route-specific permission test.
- **NOT TESTED** means no browser screenshot, viewport, keyboard, or visual-state evidence was captured in this run.
- **BLOCKED/DEFERRED** means authenticated role/workflow acceptance awaits the authorized isolated QA login path and suitable synthetic clinician identity. It is not a pass.

## Authenticated page routes

| Route | Source file | Configured permission | Source-contract status | Browser / visual / keyboard | Authenticated role / workflow |
|---|---|---|---|---|---|
| `/dashboard` | `src/routes/_authenticated/dashboard.tsx` | `dashboard.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/patients` | `src/routes/_authenticated/patients.tsx` | `patients.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/patients/$patientId` | `src/routes/_authenticated/patients_.$patientId.tsx` | `patients.read` (detail) | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/visits` | `src/routes/_authenticated/visits.tsx` | `visits.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/queue` | `src/routes/_authenticated/queue.tsx` | `queue.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/clinic` | `src/routes/_authenticated/clinic.tsx` | `visits.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/clinic/$visitId` | `src/routes/_authenticated/clinic_.$visitId.tsx` | `visits.read` (detail) | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/appointments` | `src/routes/_authenticated/appointments.tsx` | `appointments.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/followups` | `src/routes/_authenticated/followups.tsx` | `followups.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/certificates` | `src/routes/_authenticated/certificates.tsx` | `certificates.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/pharmacy` | `src/routes/_authenticated/pharmacy.tsx` | `pharmacy.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/inventory` | `src/routes/_authenticated/inventory.tsx` | `pharmacy.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/lab` | `src/routes/_authenticated/lab.tsx` | `lab.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/lab/$orderId` | `src/routes/_authenticated/lab_.$orderId.tsx` | `lab.read` (detail) | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/lab-catalog` | `src/routes/_authenticated/lab-catalog.tsx` | `lab_admin.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/billing` | `src/routes/_authenticated/billing.tsx` | `billing.read` | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
| `/billing/$invoiceId` | `src/routes/_authenticated/billing_.$invoiceId.tsx` | `billing.read` (detail) | SOURCE-GUARDED | NOT TESTED | BLOCKED/DEFERRED |
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
| `/` | `src/routes/index.tsx` | Redirects to `/auth` in the production fetch | PUBLIC SMOKE PASS (redirect) | NOT TESTED |
| `/auth` | `src/routes/auth.tsx` | Arabic sign-in title, skip link, email/password fields, closed public registration notice, English toggle visible | PUBLIC SMOKE PASS (Arabic) | NOT TESTED |
| `/setup` | `src/routes/setup.tsx` | Arabic completed-setup state and sign-in link; no form submitted | PUBLIC SMOKE PASS (completed state) | NOT TESTED |

## Coverage gaps and next acceptance session

1. No screenshot or interactive browser evidence was captured in this run. All routes remain **NOT TESTED** for the required 320/360/390/430 CSS-pixel viewports, Arabic RTL, English LTR, dialogs, loading/empty/error/retry states, focus order, and keyboard-only navigation.
2. The 23 navigation permission checks are source contracts only; they do not prove server-side rejection for every role. The four detail routes require independent role/permission review.
3. Authenticated clinical E2E and staff acceptance remain **BLOCKED/DEFERRED** until the free isolated QA environment has a supported login path and suitable synthetic clinician identity. Do not create production fixtures or treat a route rendering as acceptance.
4. During the authorized comprehensive session, capture route + viewport + language + role + action + expected/actual result for each finding, with redacted screenshots. Record PASS only after the relevant interaction is exercised.
5. Keep Issue #95 open until this matrix's NOT TESTED/BLOCKED entries are resolved or explicitly accepted under the documented release gate.


## Public route smoke supplement — 2026-10-27 06:24 UTC

- Used TinyFish's free public fetch/extraction endpoint on the canonical production alias for `/`, `/auth`, and `/setup`. All three fetches returned without per-URL errors.
- `/` redirected to `/auth`; the sign-in page returned Arabic content, `width=device-width, initial-scale=1` viewport metadata, email/password fields, the closed-registration notice, skip-to-content text, and the English toggle.
- `/setup` returned the Arabic completed-setup state and a sign-in link. No login, form submission, or mutation was attempted.
- This is a public-content/metadata smoke only. The fetch tool does not prove interactive behavior, viewport rendering at 320/360/390/430px, English LTR behavior, keyboard focus, or visual accessibility. Those entries remain **NOT TESTED**.


## Baseline refresh after PR #118 merge — 2026-10-27 07:10 UTC

- The route inventory itself did not change. This refresh only binds the acceptance matrix to current `main` `123bc8b92ddbc64ef236d50c6c822d030b38d390` and the exact production deployment `dpl_HSXd9Ss53pMX5uvnKKBEnHLBwq2f`, both on the same SHA. Exact-main CI, finance isolation, clinical-child RPC-only, push-on-main/CodeQL, and Dependabot dynamic workflow are green (runs `40464623894`, `40464623888`, `40464623978`, `40464663442`, `40464733500`).
- The previous public route smoke evidence predates this deployment and was a non-interactive fetch; it is not a fresh browser pass for this SHA. Every authenticated route remains **NOT TESTED** for viewport/RTL/LTR/keyboard acceptance and **BLOCKED/DEFERRED** for role/workflow acceptance. Do not infer UI compatibility from a dependency-only production deploy or green source tests.
- PR #114's major-update candidate currently fails Typecheck on `react-day-picker`/Recharts API breaks (run `40465003880`); it is not merged and does not describe the deployed application.
- Next: continue the non-authenticated source-level UX review and prepare the authorized interactive acceptance session; keep Issue #95 open. Clinical E2E stays deferred until the isolated free QA login and suitable synthetic clinician identity are available.


## Detail-route permission contract — source-level verification candidate (2026-10-27)

- At base `main` `d3102a6618e09337676fccfeb3f75f28530c71a9`, source inspection confirmed four detail routes already wrap their content in explicit `PermissionGate`s: patient chart (`patients.read`), visit consultation (`visits.read`), lab order (`lab.read`), and invoice detail (`billing.read`).
- The prior matrix understated these source guards as `SOURCE-INVENTORIED` and did not list the expected permissions. This candidate updates those rows and extends the Phase 42 regression test to require the exact guard and matrix permission for every detail route.
- This is a source-contract check only. It does not prove runtime/server authorization, correct data scoping, browser rendering, or an authenticated workflow. All four routes remain `NOT TESTED` for browser/visual/keyboard acceptance and `BLOCKED/DEFERRED` for role/workflow acceptance until the authorized QA session.
- No runtime code, dependency manifests, database migrations, Supabase Auth settings, or production data are changed. Exact-head CI evidence is pending on the candidate PR.


## Detail-route source-guard test — merged verification (2026-10-27 07:21 UTC)

- PR [#123](https://github.com/crauch2088-source/roshan-health-hub/pull/123) merged as `e54892d7158c85c1832afe361ec7f81e0f05f87c`, final tested head `7b0dd708a07c99ca550fd829367a56c2fd2f7c1f`.
- Exact-head CI `40466473738`, dynamic PR workflow `40466470524`, insurance-claim UI validation `40466475532`, insurance-claim integrity `40466473616`, privileged-role guard `40466473558`, and prescription atomicity `40466473693` all succeeded. Final combined Vercel status was success; no new production app deployment was needed for this test/docs-only change.
- The Phase 42 regression test asserts explicit `PermissionGate` read permissions for patient chart, visit consultation, lab order, and invoice detail. The matrix records `patients.read`, `visits.read`, `lab.read`, and `billing.read` and marks these rows `SOURCE-GUARDED`.
- Post-merge main CI `40466624118`, finance isolation `40466624144`, and push-on-main/CodeQL `40466623836` passed on merge SHA `e54892d...`. The production app remains READY on `123bc8b...` because the merged commit does not alter watched runtime/build paths.
- These are source-level assertions only. All protected-route visual/keyboard/viewport checks remain `NOT TESTED`; role and clinical workflows remain `BLOCKED/DEFERRED`. Keep Issue #95 open.
