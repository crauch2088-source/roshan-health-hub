# Roshan Medication Intelligence & Clinical Decision Support

**Feature:** 056 | **Decision:** 2026-11-11 | **Status:** Owner-approved phased engineering; clinical activation separately gated.

## Intent
Build the complete long-term medication engine: verified product identity, encounter-specific patient context, confirmed indication, source-backed versioned protocols, deterministic dose calculations, medication-safety checks, clinician review and auditable prescription handoff. Engineering proceeds in parallel with core release; unvalidated protocols must not delay the clinic's basic launch or be exposed to clinicians.

## Goals
- Separate ingredient, brand, strength, concentration, dosage form, packaging, route and regimen.
- Use current visit-linked observations; never silently reuse old weight or convert unknown into negative.
- Match only confirmed structured indications and approved current protocols.
- Support fixed mg, mg/kg/dose and mg/kg/day with explicit units, frequency, maxima and source-defined rounding.
- Add governed allergy, interaction, contraindication, duplicate-therapy, renal/hepatic and special-population rules.
- Explain source, version, matched facts, limitations, edits, overrides and clinician acceptance.
- Integrate with existing prescription, pharmacy, inventory, batch, FEFO and correction workflows; do not duplicate them.

## Non-goals for the first slice
No active clinical regimen, no AI-generated or AI-modified dose, no exhaustive interaction claim, no auto-save/sign/dispense, no full FHIR server, no new stock/batch subsystem, and no hosted database migration.

## Functional requirements
1. Product identity and pack metadata have explicit verification status and provenance.
2. Route is never inferred from generic name, brand, inventory unit or an unverified dosage-form label.
3. Weight is an encounter observation with timestamp/unit; weight-based calculations require a current encounter value.
4. Free-text diagnosis cannot activate a protocol; structured confirmed indication and care setting are required.
5. Only approved, current, non-expired protocol versions with passing golden tests may match.
6. Fixed, mg/kg/dose and mg/kg/day are distinct typed operations.
7. Frequency is explicit protocol data; it is never inferred.
8. Maximum per dose and maximum per day are distinct and enforced.
9. All quantities have explicit units. Initial kernel supports mg/kg arithmetic only; concentration/volume conversion is separate.
10. Missing/unknown/stale/not-assessed/negative/zero remain distinct.
11. Suggestions never become signed, saved or dispensed orders without explicit prescriber action.
12. Every result preserves source/version/date/section, population, setting, jurisdiction, reviewer and revalidation date.
13. Audit captures inputs, rule version, result, alerts, edits, overrides, final regimen, actor and time.
14. Arabic RTL and English LTR work on 320–430px Android layouts.

## Evidence governance
Prioritize current Sudan Federal and Gezira MoH standards only when issuer, edition, approval, applicability and licence are verified; then current WHO guidance, appropriate current specialty guidance, and verified product labels for product facts. Record exact source, section, population, setting, jurisdiction, licence, reviewer and revalidation. Conflicting sources are escalated, never blended automatically. No protocol activates without independent GP and pharmacist approval and golden cases.

## Safety
Unknown allergy is not NKDA. Free-text histories are not complete structured medication reconciliation. Missing/stale weight never falls back to a prior visit. Generic ingredient does not establish route. mg/kg/day is not mg/kg/dose. Rounding cannot exceed a ceiling. AI cannot generate or modify clinical doses. Hard-stop, acknowledgement-required and informational alerts are governed separately; overrides require authorization, reason and audit.

## Acceptance
Pure calculations are deterministic and boundary-tested. Protocol matching returns recommendation/needs_data/no_match/blocked rather than guessing. Every active protocol has provenance, approval and golden tests. Existing prescription atomicity, branch/RLS and pharmacy stock/FEFO remain intact. Synthetic role E2E, GP/pharmacist approval and staff/mobile acceptance precede clinical activation.

## Release policy
The arithmetic kernel may merge as an internal non-clinical library after engineering review. The clinical evaluator and UI remain inactive until all content and governance gates pass. The engine is parallel to, not a blocker for, the core Roshan release.


## Matcher scope and arithmetic boundary update — 2026-11-11

- Every protocol and encounter context must explicitly identify population and jurisdiction.
- Source setting, population and jurisdiction must match the protocol exactly; context population and jurisdiction must match the protocol exactly.
- No age-based or text-based population inference is permitted in this matcher slice.
- Doses-per-day is a positive safe integer. Non-daily interval regimens are out of scope until represented by an explicit interval unit.
- Malformed runtime inputs fail closed without exceptions.
