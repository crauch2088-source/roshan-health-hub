# Public Unauthenticated UX Source Audit — 2026-10-30

## Scope and baseline

This audit covers the three public page routes listed in `docs/UX_ROUTE_ACCEPTANCE_MATRIX_2026-10-27.md`: `/`, `/auth`, and `/setup`. It is a source-level review on branch `agent/manus-public-ux-20261030`, created from verified `origin/main` SHA `83bcfd9a46f55ff16e9c6a2133f5e01d696f7d79`.

Before implementation, open PR #125 was reviewed and found limited to the authenticated prescription composer, clinical age parsing, and its evidence log; no files from that workstream were edited. PR #135 was already merged. Its `/setup` autocomplete tokens (`name`, `email`, `tel`, `new-password`) are present and were left unchanged. Issue #95 remains open.

## Source audit observations

- `/` checks the session, sends signed-in users to `/dashboard`, and directs unauthenticated users according to `setup_required`. Its loading view uses a full-viewport flex layout, horizontal padding, and localized app/loading text.
- `/auth` uses a semantic main landmark and skip link. Email and password inputs are wrapped in the shared `Field` component, which provides label association. Native email/required/minimum-length constraints, a disabled submitting button, `ErrorBox` error announcements, password-reset/recovery modes, and an Arabic/English toggle are present. Username/current-password/new-password autocomplete tokens are set.
- `/setup` uses a semantic main landmark and skip link. Its fields are labeled, required constraints are native, and the merged PR #135 autocomplete tokens remain intact. The setup status permission-denial handling intentionally renders the completed-setup path after initialization.
- The language provider updates the document `lang` and `dir` when language changes; authentication/setup email and password controls use LTR direction. Public cards and controls use source-level max-width/full-width/padding rules. This is not evidence that any viewport was rendered without overflow.
- No password-visibility toggle is present in the reviewed public forms. This was recorded as an observation, not changed: the source review alone does not establish that a reveal control is a product requirement or a defect.

## Confirmed defects and fixes

### 1. Setup-status RPC failure could be shown as “Setup complete”

Before the change, `required` initialized to `false`. A non-permission rejection from `setup_required` only set an error, after which the route rendered the `!required` completion branch. That could falsely tell a first-run operator that setup had already completed and offered no retry.

The regression test was run before the fix and failed because `/setup` had no dedicated failure branch. The route now keeps a distinct `checkFailed` state, displays an Arabic/English explanation and error alert, and exposes a localized retry button. Only the expected permission-denial path maps to the initialized/completed state.

### 2. Root status-check failure hid the setup recovery route

Before the change, a failed `setup_required` lookup on `/` redirected to `/auth`. The auth route also hid the first-run setup link when its own status lookup failed. The pre-fix root regression test failed because this fallback sent users to sign-in rather than a retry path.

The root fallback now routes to `/setup`, whose status-check failure state is explicit and retryable. This does not expose the bootstrap form when status is unknown.

### 3. Direct `/auth` status-check failure silently hid first-run setup

Opening `/auth` directly previously converted any status-check failure into `setupNeeded=false` with no feedback or path to setup. The pre-fix regression test failed because there was no failure state or `/setup` recovery action.

The auth route now shows a localized status message and a button to `/setup` when the check fails. That destination safely retries and preserves the established permission-denial behavior.

## Regression evidence

Three focused source-contract regressions were added to the existing Phase 42 UX guard so they run under the repository's current `test:guard` script. Each was observed failing before its corresponding route change. After implementation, the focused Phase 42 file passed **10/10** tests. The existing setup permission-denial contract remains asserted.

Final local validation on this branch completed with exit code 0:

- `npm run lint` — passed.
- `npm run typecheck` — passed.
- `npm run build` — passed; Vite completed all build targets.
- `npm run test:guard` — **225 passed, 0 failed**.
- `git diff --check` — passed.

## Acceptance limits and safety

No browser was available for this task. Actual rendering, screenshots, browser autofill, keyboard-only traversal/focus movement, and behavior at 320, 360, 390, and 430 CSS-pixel widths remain **NOT TESTED**. Arabic RTL and English LTR were reviewed only from source; they are not claimed as visual acceptance. No protected Vercel deployment was accessed or inspected, and no deployment was requested.

No production data, Supabase Auth settings, credentials, environment variables, database schema, clinical/financial workflows, or deployment settings were modified. Issue #95 remains open; this source-level change does not close the UX release acceptance gate or claim clinical acceptance.

## Changed files

- `src/routes/index.tsx`
- `src/routes/auth.tsx`
- `src/routes/setup.tsx`
- `tests/phase42-ux-route-rtl-a11y-guard.test.ts`
- `docs/agent-reports/manus-public-ux-audit-20261030.md`
