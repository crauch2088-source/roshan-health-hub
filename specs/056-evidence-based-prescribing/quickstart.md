# Quickstart: Evidence-Based Prescribing (QA only)

This document is a reviewer/tester checklist, not an instruction to apply migrations or prescribe from unapproved rules.

## Before any implementation
1. Start from latest `main`; fetch `docs/MASTER_PLAN.md`, `docs/PLUGIN_TOOLING_MAP.md`, constitution and open PRs.
2. Reconcile PR #125, #179 and #183. They share prescription authoring files and are not merge-ready solely because automation is green.
3. Confirm QA project ref `hopfohcnrtbiqjkgeukz`; never run synthetic tests on production.
4. Read current patient/visit atomic RPC definitions, visit form route, inventory medicine maintenance and pharmacy query contracts.
5. Read source documents and verify publication date, jurisdiction, population and licensing before encoding any clinical content.

## Safe non-clinical smoke scenarios
- Select a known injectable product and verify incompatible routes are absent.
- Select a product with unknown route mapping and verify the UI asks for review instead of guessing.
- Register a synthetic patient and create the first encounter with an initial weight; verify weight belongs to that encounter.
- Create a later encounter without weight; verify no prior weight is treated as current.
- Confirm diagnosis selection is explicit and a free-text keyword alone cannot activate a protocol.
- Confirm all protocol records remain Draft/inactive until reviewer approval.

## Protocol validation before any clinical activation
- Compare each rule with the cited guideline's exact age, indication, setting and exclusion scope.
- Verify dose basis, unit, interval, max per dose/day, concentration, rounding, duration and monitoring.
- Test boundary ages/weights, missing values, conflicting context and out-of-scope cases.
- Obtain independent GP and pharmacist approval and retain a signed version/review record.
- Verify the source is current and permitted to be stored/redistributed.
- Run unit, integration, PG17, RLS/branch and synthetic clinician tests.
- Complete Android phone, Arabic RTL and English LTR acceptance.

## Prohibited
- Do not paste real patient data into test fixtures.
- Do not enter live medication orders for testing.
- Do not apply a candidate migration to production.
- Do not enable or seed a protocol merely because its arithmetic test passes.
- Do not claim interaction checking is exhaustive without verified dataset coverage.


## Verified current QA limitation
The QA medicine catalogue currently has zero rows. Do not attempt a protocol cohort selection until a reviewed Roshan formulary/product list has been agreed and loaded into QA.
