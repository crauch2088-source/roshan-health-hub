# UX acceptance checklist — production read-only and isolated workflow gates

**Release issue:** [#95 — UX release gate](https://github.com/crauch2088-source/roshan-health-hub/issues/95)  
**Purpose:** inspect the current UI without turning production into a test database. This checklist separates production visual inspection from synthetic workflow acceptance.

## 1. Establish the exact build (required)

- Record current main SHA, production deployment ID, deployment state, and deployed Git SHA.
- If production is not a READY deployment for the exact main SHA, record the mismatch as a release blocker. You may inspect the deployed build read-only, but must not claim acceptance for current main.
- Do not force a deployment, create another Vercel project, or bypass free-tier build limits to satisfy this gate.

## 2. Phone viewport matrix

At every width, inspect the application shell, header, breadcrumbs, search, quick actions, bottom navigation/More sheet, dialogs, tables/cards, horizontal overflow, focus visibility, and bottom safe-area clearance.

| Viewport | Required check |
| --- | --- |
| 320 × 640 CSS px | Smallest supported phone width; check clipped actions, long Arabic labels, dialogs and keyboard overlap. |
| 360 × 800 CSS px | Common compact phone; check navigation balance and form control widths. |
| 390 × 844 CSS px | Reference phone viewport; inspect all major screen classes and RTL/LTR. |
| 430 × 932 CSS px | Large phone; check stretching, whitespace, table/card width and fixed controls. |

For each viewport, check English LTR and Arabic RTL. Verify that machine identifiers, MRNs, invoice numbers, dates, lab values and reference ranges remain readable LTR inside the surrounding direction.

## 3. Production pass is strictly read-only

Allowed: sign in with an already-authorized role, navigate to permitted screens, inspect the shell and non-identifying UI states, and observe console/runtime errors. Do not capture or paste patient, clinical, user, or financial details into the report.

**Never create or mutate production records.** Do not submit forms or perform any create, save, update, delete, complete, verify, issue, dispense, receive-stock, claim, payment, reversal, or upload action in production—even with synthetic values. Do not create a synthetic patient, visit, clinical note, lab order/result, certificate, prescription, invoice, payment, inventory movement, insurance claim, or attachment in production.

If a route's details require opening a real person's record or would expose sensitive information, mark that check blocked and move on. A route loading successfully is not sufficient evidence to mark it PASS.

## 4. Isolated synthetic workflow pass — currently deferred

Clinical end-to-end acceptance tests remain deferred until an isolated zero-cost test environment and synthetic doctor identity are available. Do not use the production database as a substitute, and do not create a paid Supabase branch/project.

When the required environment exists, use synthetic identities and data to test the visit → consultation → lab order/result/verification → certificate/print → prescription/dispensing → invoice/payment path, plus role-denial and cross-branch isolation. Keep PostgreSQL 17 CI fixtures isolated; passing fixtures do not prove authenticated browser acceptance.

## 5. Route-by-route evidence and pass/fail

- Use the UX route inventory (UX_ROUTE_INVENTORY.md). Every authenticated route must have an explicit status.
- For each route, record the path, role, language, viewport, deployed SHA, observed state, expected/actual result, severity, reproducible steps, and a redacted screenshot only when it contains no sensitive data.
- Inspect loading, empty, error, validation, dialog, keyboard/focus, permission-denial, and successful read-only states where they can be observed safely. Do not manufacture production state to force a condition.
- Mark PASS only for the specific behavior actually observed. Use NOT VERIFIED or BLOCKED when no browser evidence exists; do not infer acceptance from source checks, a route load, green CI, or a READY deployment.

## 6. Finish safely

- Confirm no unexpected console.error, unhandled promise rejection, horizontal clipping, inaccessible controls, permission leaks, or cross-branch data exposure.
- Never attach unredacted screenshots, user details, patient identifiers, clinical notes, tokens, or financial data to GitHub issues/PRs.
- No clinical-readiness claim is made by this checklist. Do not move to the next project workstream until issue #95 acceptance criteria are met or remaining blockers are explicitly owned and documented.
