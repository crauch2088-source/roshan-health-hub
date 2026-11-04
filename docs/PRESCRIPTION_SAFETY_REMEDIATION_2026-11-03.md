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