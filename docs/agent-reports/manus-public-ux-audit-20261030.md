# Public UX and Public Error-Disclosure Audit — 2026-10-30

## Scope and provenance

This source-level audit covers the public routes listed in `docs/UX_ROUTE_ACCEPTANCE_MATRIX_2026-10-27.md`: `/`, `/auth`, and `/setup`. Work remains on the existing branch `agent/manus-public-ux-20261030` and PR #139, based on main SHA `83bcfd9a46f55ff16e9c6a2133f5e01d696f7d79`. The security follow-up addresses the review comment on PR #139: [raw setup error disclosure finding](https://github.com/crauch2088-source/roshan-health-hub/pull/139#issuecomment-6511240097). No competing PR was created.

PR #125 was reviewed and remains limited to the authenticated prescription composer, clinical age parsing, and its evidence log; no files from that workstream were edited. PR #135 is already merged. Its `/setup` autocomplete tokens (`name`, `email`, `tel`, `new-password`) remain unchanged. Issue #95 remains open.

## Error-path trace and changes

### `/setup`

- `setup_required` initial checks and retry attempts share `checkSetupRequired`. The expected permission-denial branch reads the error message only to distinguish an initialized system; it does not store or display that text. Other failures enter the retry state, whose status copy is fixed and localized.
- Signup, existing-account sign-in, `bootstrap_super_admin`, and auth refresh errors all reach the submit catch. That catch now displays fixed Arabic/English recovery guidance, including a reminder to confirm email if prompted. Provider and RPC messages are not placed in the rendered error state.
- `ErrorBox` remains for accessible submission-error announcement, but its state can now be cleared or set only to fixed localized copy. The status/retry UI provides its own generic recovery text.
- The only diagnostics emitted by these catches are fixed operation labels stating that server details are suppressed; no error object, message, code, stack, token, SQL, schema, or RPC name is logged.

### `/auth`

Direct sign-in, password-reset request, and recovery-password update failures previously flowed verbatim into `ErrorBox`. Each now maps to fixed Arabic/English, action-oriented guidance. The diagnostic breadcrumb includes only the constrained UI mode (`signin`, `forgot`, or `recover`) and never includes provider error data.

### `/`

The route contains no raw-error display. A failed setup-status check redirects to `/setup`, where the status can be retried without rendering a bootstrap form while the check is unknown.

The reviewed acceptance matrix contains no other public recovery page. No additional route or shared error component was changed.

## Regression and local validation evidence

Two new source-contract regressions were first run against the vulnerable version: both failed (**0/2 passed**), because raw error text flowed into the public `ErrorBox` state. After the fix, both passed (**2/2**). The updated focused Phase 42 public-route guard passed **12/12**. The full guard suite passed **227/227**, with zero failures.

The final local validation completed successfully:

- `npm run lint` — passed.
- `npm run typecheck` — passed.
- `npm run build` — passed.
- `npm run test:guard` — 227 passed, 0 failed.
- Prettier check and `git diff --check` — passed.

PR-specific GitHub Actions conclusions and URLs are recorded in the PR #139 follow-up comment after the new commit’s workflows finish.

## Manual browser and accessibility acceptance checklist — not yet performed

Because browser and Vercel access are unavailable, the following items remain for a human reviewer on the preview or an authorized test environment:

- [ ] At **320px**, **360px**, **390px**, and **430px** viewport widths, verify `/`, `/auth`, and `/setup` have no horizontal scrolling, clipped labels/buttons, or content hidden by the on-screen keyboard; confirm the page remains scrollable when needed.
- [ ] With keyboard only, tab and Shift+Tab through each route; confirm logical order, visible focus on every interactive control, working skip links, Enter submission, and reachable retry/setup-navigation actions without a focus trap.
- [ ] Render both **Arabic RTL** and **English LTR**. Confirm page direction, text alignment, navigation, and error/status placement; ensure email, phone, and password inputs remain readable in LTR in both languages.
- [ ] Test browser/password-manager autofill: `/setup` name/email/telephone/new-password; `/auth` username/current-password; and recovery new-password. Confirm values land in the intended fields and toggling language does not clear or misplace them.
- [ ] With a screen reader, confirm labels announce for each input; skip links and button names are meaningful; generic error and recovery messages are announced once and correspond to the active form; retry is discoverable; no raw backend/server text is visible or announced.
- [ ] In an authorized non-production test, simulate distinct failures (status check, retry, signup, sign-in, bootstrap, password-reset request, password update) using a sentinel backend message. Confirm the UI and browser console contain only the fixed localized copy and coarse operation labels—not the sentinel or backend details.

## Acceptance limits and safety

These are source and automated-test results only. The manual viewport, keyboard, RTL/LTR rendering, autofill, screen-reader, and simulated-error checks above are **NOT TESTED** here. No browser or visual acceptance is claimed. No protected Vercel deployment was accessed or inspected, and no deployment, promotion, or preview action was manually performed.

No Supabase/Auth settings, database/schema/migrations, production data, credentials, deployment settings, QA infrastructure, or clinical/financial workflow was modified. The canonical clinical acceptance gate and Issue #95 remain open; this follow-up does not claim clinical acceptance.

## Changed files in PR #139

- `src/routes/index.tsx`
- `src/routes/auth.tsx`
- `src/routes/setup.tsx`
- `tests/phase42-ux-route-rtl-a11y-guard.test.ts`
- `docs/agent-reports/manus-public-ux-audit-20261030.md`
