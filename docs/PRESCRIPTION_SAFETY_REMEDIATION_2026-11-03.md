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

- Current main remains bd3d6fa57de1628f2bbf4846f004ba285d4021c5. PR #179 current head is 21abea4efe98da1f8e51fba5e3e741cb41349d7e; it is Open/Draft/Mergeable, 38 commits ahead and 1 behind main. Its base is d42baae4f5bdbb6319cd389630f0b4ad349150ab, so the main documentation-only commit still needs a normal merge into the feature branch before eventual merge; do not force-push.
- The initial exact-head regression at a9a8ddd703f0c92febc1a563a94515b3090effc9 (CI run 42866378708 / #1908) exposed a real mismatch: the picker advertised search by formulation and selected dosage_form, but buildMedicineSearchFilter omitted dosage_form.ilike. Commit d1b98721a9b6c35f3083c35ffeecc9e6e3ea8f51 adds that field. The atomicity fixture was updated in fb72ca9fe1f456ff5117d89a2e169dbabb7e80ee to expect all five search fields, and the Prettier-only test formatting issue was corrected in 21abea4efe98da1f8e51fba5e3e741cb41349d7e.
- The unknown-DOB warning now says that if the patient may be a child, a current visit-linked weight must be verified before weight-based dosing. The existing VitalsTab labels weight in kg and stores it against the visit; the prescription screen reads the latest non-deleted weight for that visit and does not calculate a dose.
- The route selector now explicitly warns that its options are generic and are not validated against the selected product; the exact product label must be checked. No product-route mapping or compatibility engine was introduced. Medicine selection still leaves dose, frequency, duration and route unfilled; no regimen or route is inferred.
- The duration shortcuts (1–90 days and ongoing) are explicitly described as data-entry conveniences, not treatment recommendations. Custom duration remains available. No universal maximum, diagnosis-based duration, dose, frequency or other clinical rule was added.
- The saved prescription read/print model maps dosage form, route, frequency, duration, quantity and instructions; the pharmacy queue displays formulation, route, timing and instructions. Additional instructions remain optional text, not a substitute for structured prescribing fields.
- Exact-head CI [42868462093](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868462093) (#1911) passed: 18 jobs succeeded, one canonical PostgreSQL 17 baseline/authenticated clinical-acceptance job was intentionally skipped, and the unit-test step reported 282/282 passed. Typecheck, lint, security audits and production build all succeeded.
- Supporting exact-head workflows passed: prescription atomicity [42868462141](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868462141) (#720); insurance UI [42868461983](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868461983) (#623); insurance integrity [42868462020](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868462020) (#724); privileged role guard [42868462066](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868462066) (#723); finance-only RPC [42868461896](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868461896) (#537); clinical child RPC-only writes [42868461816](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868461816) (#354); Phase 48 storage/branch binding [42868462014](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/42868462014) (#88).
- The code-bearing commit d1b98721a9b6c35f3083c35ffeecc9e6e3ea8f51 has a READY Vercel preview deployment [9w5X6ceKYbqH9LaN15WUu114eiev](https://vercel.com/roshan45/roshan-health-hub/9w5X6ceKYbqH9LaN15WUu114eiev) at https://roshan-health-lrkgytmxw-roshan45.vercel.app. The later commits fb72ca9 and 21abea4 changed only tests/docs; Vercel correctly canceled their redundant deployments because the Ignore Build Step found no source/config changes. The final-head Vercel status is therefore not evidence of a new preview build; the READY code-bearing preview remains the one to inspect.
- PR #179 remains Draft despite green CI. No Arabic RTL/English LTR browser review, mobile print-preview, physical A4 printer check or staff acceptance is claimed. Clinical E2E remains deferred until an isolated free test environment and synthetic doctor identity are available. PR #210 remains a separate shared-catalogue identity/pack-attestation candidate and was not changed; it does not provide route compatibility. PR #185 remains stale and must not be merged as-is.
- No database migration, QA/Production DDL/DML, medicine-row seeding, patient/clinical/financial record creation, role/security change, dose protocol, interaction rule, route mapping or production deployment was performed.

Next: merge the single newer main documentation commit into the feature branch without rewriting history; inspect the READY preview in Arabic RTL and English LTR, including the composer, pharmacy queue and print pages; verify mobile and A4 print preview. Keep #179 Draft until those checks and separate staff acceptance are documented. Keep authenticated clinical E2E deferred under the existing environment/identity gate.
