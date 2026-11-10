# Prescription safety and custom-field remediation — 2026-11-03

## Findings reproduced

- Catalogue selection inferred the oral route for tablet/capsule/syrup/suspension products even though dosage form does not establish the intended route for a particular prescription.
- The prescription form displayed “Custom” for dosage form, dose, frequency, duration and route without a usable free-text field for several of those values.
- Client-side completeness validation did not require dosage form or route.
- `calcAge()` accepted impossible date-only values such as `2026-02-30` because the JavaScript Date constructor normalizes them.

## Implemented correction

- Route is always left blank when a medicine is selected. The prescriber must choose a route from the supported list or enter a custom route.
- Custom free-text inputs are available for dosage form, frequency, duration and route. Dose is a free-text field that explicitly asks for the unit.
- The atomic prescription save is blocked by the client completeness guard until all required fields and a positive integer quantity are present.
- Age calculation validates a real `YYYY-MM-DD` calendar date and rejects future dates. The prescription screen warns when age cannot be verified.
- No dose calculator, dosage recommendation, route inference, duration recommendation, or pediatric protocol was added.

## Verification

- TDD regression tests were first run against the pre-fix code and reproduced four failures.
- After implementation, the focused prescription/clinical tests passed.
- The complete repository guard suite passed locally: 267 tests, 0 failures, 0 skipped.
- Local TypeScript typecheck exceeded the remote sandbox memory/time limit; exact-head GitHub CI is the authoritative typecheck/lint/build gate.

## Release boundary

This is application/UI validation, not a clinical protocol approval. No database migration or Production write was performed. Authenticated clinical E2E and staff UAT on the actual clinic devices remain separate acceptance gates.


## Explicit quantity entry — 2026-11-04

- The composer previously inherited `quantity: "1"` from `createEmptyPrescriptionDraft()`. This silently populated a one-unit order before the prescriber made a quantity decision.
- The default is now blank for new drafts, catalogue selections and manual-name resets. The existing completeness validator rejects a blank quantity; the input is marked required and has an accessible bilingual label and placeholder.
- Regression coverage asserts the blank default, catalogue-selection behavior, rejection before save and required UI semantics. The prescription atomicity test fixtures now expect an empty quantity.
- TDD reproduced the defect before the change (`"1" !== ""`) and passed after the change using Node 22.16.0. Exact-head CI on PR #179 commit `4de2bbbb64860ae9f84bd784fa1c56e456d09c00` passed run `41789990771` (18 success, zero failures, one intentional clinical-acceptance skip). The prescription atomicity integration passed run `41789990830`.
- No database migration or patient/financial record write was performed. This does not authorize any default dose, route, frequency, duration or clinical protocol.

## PR consolidation — 2026-11-04

- PRs #125, #183 and #184 were closed as superseded by the consolidated implementation in PR #179. Their route-selection, custom-field, DOB-validation and age-warning changes are present in the current #179 branch, which also contains saved-prescription printing and explicit quantity entry.
- The old READY preview cited by #125 is tied to an earlier implementation commit and is not current acceptance evidence. PR #179 remains Draft until a current authorized preview, RTL/LTR print checks, actual A4 printer behavior and staff acceptance are recorded.
- No clinical E2E acceptance, production migration or production data write is claimed.

## Prescription composer follow-up — 2026-11-10

- Baseline main at recheck: bd3d6fa57de1628f2bbf4846f004ba285d4021c5. PR #179 head at recheck: a9a8ddd703f0c92febc1a563a94515b3090effc9, 35 commits ahead / 1 behind main, still Draft.
- Exact-head CI run 42866378708 (run 1908) completed with 279/280 tests passing. The sole failure was the existing test 'medicine search includes dosage form when the picker advertises form search': the UI promised form search and the query selected dosage_form, but buildMedicineSearchFilter() omitted dosage_form.ilike from its PostgREST OR filter.
- The follow-up adds dosage_form to the search filter. It also clarifies that duration shortcuts are data-entry aids, not treatment recommendations; clarifies that route choices are not checked against the exact selected product; and extends the unknown-age warning to prompt a current visit-linked weight check if the patient may be a child.
- These are search/UX safety clarifications only. No dose, frequency, duration rule, route mapping, treatment template, product identity, database schema, patient/financial record, or hosted environment was changed. No universal duration cap was introduced.
- The first follow-up exact-head checks exposed one stale exact-string expectation in tests/prescription-atomicity.test.ts: it still expected the four pre-existing search columns. The helper now correctly includes dosage_form, so the fixture is being updated to expect the fifth field. CI run 42868119340 (run 1909) was still in progress at this snapshot; Prescription atomicity integration run 42868119501 (run 718) failed only on that stale expected string.
- Exact-head validation also found a formatting-only issue in the newly added route/duration regression: insurance UI validation run 42868119341 (run 621) flagged one Prettier line-wrap in tests/clinical-workflow-redesign.test.ts. The assertion is now wrapped to repository formatting; no behavior change.
- The corrected expected filter string was committed in fb72ca9fe1f456ff5117d89a2e169dbabb7e80ee. Exact-head CI run 42868320003 (run 1910) was queued at the time of this note; the new head still requires a clean full validation pass.
- The next exact-head CI and integration runs must pass before the PR can be considered technically ready. Vercel preview remains pending; no preview or visual acceptance is claimed.
- Exact-head checks for the follow-up commit are pending at the time of this note. Keep PR #179 Draft until they pass and authorized Arabic RTL/English LTR browser, mobile print-preview, A4 output and staff acceptance gates are evidenced. Authenticated clinical E2E remains deferred until the isolated free environment and synthetic doctor identity are available.
