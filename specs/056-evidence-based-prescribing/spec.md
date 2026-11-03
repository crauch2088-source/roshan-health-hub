# Feature Specification: Evidence-Based Prescribing & Clinical Decision Support

**Feature Branch**: `feat/056-evidence-based-prescribing`  
**Created**: 2026-11-03  
**Status**: Draft — owner authorized planning and implementation; clinical protocol activation remains separately gated  
**Input**: Make prescribing medication-aware, indication-aware and patient-specific, with minimal clicks, transparent evidence, clinician control and medication-safety alerts.

## Intent

Roshan should recognize the selected medicinal product and the clinical context so the prescriber does not repeatedly enter facts the system already knows. It should offer a safe, explainable draft regimen only when an approved protocol matches the confirmed indication and patient context. The prescriber remains responsible for the final order.

## Approaches considered

1. **Static medicine templates** — rejected as the primary design: a medicine name alone cannot distinguish indication, severity, age, weight, organ function or care setting.
2. **Deterministic, versioned clinical knowledge and rule engine** — selected: product constraints, indication-specific protocols, patient-context predicates, explicit calculations, traceable sources, review and expiry. Broad architecture; deliberately narrow initial content.
3. **Generative model writes the dose** — rejected for prescribing calculations and contraindication decisions: outputs are not sufficiently deterministic or auditable. AI may later assist with search/classification, never silently author a regimen.

## User Scenarios & Testing

### US1 — Select a valid product and formulation (P1)
As a prescriber, I search by generic or brand name and select a real catalogue product. The UI displays strength and dosage form and only offers routes compatible with that exact formulation/product. It must not offer oral for an injectable-only ceftriaxone product.

**Independent Test**: Product fixtures with known route constraints render only the mapped routes; unknown/incomplete product mappings request explicit verification rather than guessing.

**Acceptance Scenarios**
1. Given an injectable-only catalogue item, when selected, then oral is unavailable and the product's permitted route(s) are shown.
2. Given a product whose route mapping is incomplete, when selected, then no route is inferred and the prescriber must verify/select from a safe, reviewed list.
3. Given a medicine name without a selected product/strength/formulation, when typed, then no regimen is auto-filled.

### US2 — Capture current weight at intake and use encounter-specific measurements (P1)
As reception/clinical staff, I can capture an optional initial weight during new-patient intake/first-visit workflow. The value is stored as a dated encounter observation, not a permanent patient demographic. A later visit must use its own current weight and must not silently reuse an old measurement for a weight-based calculation.

**Independent Test**: Synthetic first-visit flow persists the initial weight to the correct visit's vitals; a later visit with no weight remains missing and cannot inherit the old value.

**Acceptance Scenarios**
1. Given a new patient and a first visit being created, when a valid weight in kg is entered, then it is saved as that visit's vital measurement with actor and timestamp.
2. Given patient registration without an encounter, when a weight is entered, then the UI clearly explains that the value will be saved with the first visit; it is never silently stored as a permanent patient attribute.
3. Given a child with no current-visit weight, when a weight-dependent protocol is evaluated, then calculation is withheld and a clear missing-weight prompt is shown.
4. Given an older weight from a previous encounter, when the current visit has no weight, then the old value is not used as current.

### US3 — Match an indication-specific protocol (P1)
As a prescriber, I select/confirm a structured diagnosis for the current visit. Roshan finds only protocols whose indication, age group, setting, severity and required context match. A diagnosis keyword in free text may suggest a diagnosis but must not silently activate a regimen.

**Independent Test**: Same medicine under two different confirmed indications produces different protocol candidates; no match or ambiguous match produces no regimen.

**Acceptance Scenarios**
1. Given a confirmed diagnosis and a protocol with matching patient/context criteria, when the prescriber chooses the protocol, then a sourced draft regimen is populated.
2. Given a meningitis diagnosis, when the patient falls outside the protocol's age scope or required context is absent, then that protocol is not applied and its scope limitation is shown.
3. Given free-text diagnosis only, when the text contains a keyword, then Roshan may offer a diagnosis candidate but requires clinician confirmation before protocol matching.

### US4 — Calculate only validated patient-specific doses (P1 for engine safety; protocol content staged)
As a prescriber, I see the dose calculation inputs and output, including units, basis, interval, per-dose and daily maximums, formulation concentration and rounding. I can edit the draft, with appropriate reason capture for safety-significant deviations.

**Independent Test**: Unit tests cover dimensional correctness and protocol boundaries; independent clinical golden cases are approved before any live protocol can be activated.

**Acceptance Scenarios**
1. Given a validated mg/kg/dose protocol and a current valid weight, when evaluated, then the dose is calculated using the per-dose basis, capped at the protocol's maximum and displayed with units.
2. Given mg/kg/day, when evaluated, then the daily amount is calculated first and divided only by the protocol-defined frequency; it is never treated as mg/kg/dose.
3. Given missing/invalid weight, unknown age, out-of-scope gestational age, missing concentration or missing renal function required by the rule, then the dependent calculation is withheld.
4. Given a clinician changes a suggested dose/frequency/route, then the change is visible and audited; the original suggestion and source remain available.
5. Given a protocol does not define a rounding rule or maximum where clinically required, then it cannot be activated.

### US5 — Check allergies, interactions and patient-specific contraindications (P1)
As a prescriber and pharmacist, I receive prioritized, actionable warnings using known allergies, reaction details, active medication list, age, pregnancy/lactation when relevant, diagnoses, renal/hepatic status and other protocol-specific factors.

**Independent Test**: Synthetic patient/medication pairs trigger each seeded rule at the correct severity; unknown history is never treated as negative history.

**Acceptance Scenarios**
1. Given a documented serious allergy to the product/ingredient/class, when prescribing, then a critical alert blocks routine continuation and requires a governed override path if clinically justified.
2. Given a clinically significant interaction, when adding the second medicine, then the warning explains the mechanism/clinical consequence and recommended action with its source.
3. Given unknown allergy status, when prescribing, then the system asks to verify status and does not label the patient as having no known allergies.
4. Given a low-value informational alert, then it is non-interruptive; duplicate alerts are suppressed within the same prescribing episode.

### US6 — Explain and govern every clinical recommendation (P1)
As a clinician/reviewer, I can open the source, see its version/date/population/scope, understand which patient facts matched, see the rule's review/expiry status and report an unsafe or stale recommendation.

**Independent Test**: Every active protocol and alert resolves to a complete source/review record; expired or withdrawn rules cannot be returned as active recommendations.

## Functional Requirements

- **FR-001**: Product identity MUST distinguish ingredient, brand, strength, dosage form, concentration, route compatibility and product-specific restrictions.
- **FR-002**: Route choices MUST be constrained by the selected product/formulation; no route may be inferred from a generic medicine name alone.
- **FR-003**: The system MUST keep product metadata separate from indication-specific treatment protocols.
- **FR-004**: A protocol MUST be keyed to a structured indication and define population, setting, inclusion/exclusion predicates, regimen, monitoring and source provenance.
- **FR-005**: The system MUST require clinician confirmation of structured diagnosis/indication before applying a protocol. Free-text matching may suggest but MUST NOT silently activate it.
- **FR-006**: Weight MUST be captured with units, measurement time, actor and encounter context. Current encounter weight MUST take precedence; historical weight MUST NOT be silently reused.
- **FR-007**: Initial weight captured in patient registration MUST be persisted as a first-visit observation, not as a timeless patient demographic. Existing atomic registration and visit/invoice RPC boundaries MUST be preserved.
- **FR-008**: Patient context MUST represent known, absent and unknown states distinctly for allergy, current medicines, pregnancy/lactation and relevant medical history.
- **FR-009**: Any dose calculation MUST explicitly define dose basis (e.g. mg/kg/dose or mg/kg/day), units, interval, maximum per dose/day, age/gestational limits, concentration, route, rounding and required monitoring.
- **FR-010**: Calculations MUST use decimal-safe arithmetic and explicit unit conversion; no implicit unit assumptions or unvalidated concentration conversions.
- **FR-011**: The engine MUST withhold recommendations when required inputs are missing, stale, contradictory or outside protocol scope.
- **FR-012**: Clinicians MUST be able to edit recommendations. Safety-significant overrides MUST record original value, final value, actor, timestamp and reason.
- **FR-013**: Alerts MUST have governed severity, evidence, patient-specific rationale and an action; severity determines acknowledgement/override requirements.
- **FR-014**: Alert logic MUST reduce duplicate/non-actionable alerts and must not equate unknown data with a negative finding.
- **FR-015**: Every protocol/interaction/contraindication rule MUST have source, version/date, jurisdiction/population, owner, independent clinical reviewer, effective/review/expiry dates and test coverage.
- **FR-016**: Expired, withdrawn, draft or unreviewed rules MUST NOT be used for live recommendations.
- **FR-017**: The UI MUST show why a suggestion was made, which patient facts were used, and links to the source at the point of prescribing.
- **FR-018**: Pharmacy review MUST receive the exact saved dose, route, dosage form, frequency, duration and instructions, without reconstructing or inferring missing values.
- **FR-019**: All flows MUST support Arabic RTL and English LTR and be usable on phone-sized screens.
- **FR-020**: All knowledge reads/writes MUST respect role permissions, branch isolation, audit and server-authoritative write boundaries.
- **FR-021**: AI MUST NOT generate or autonomously modify doses, frequencies, durations, contraindications or interaction severities.
- **FR-022**: Clinical protocols MUST be independently testable and disabled by default until signed off.

## Non-Goals
- Replacing clinician judgment or creating autonomous prescribing.
- Enabling every medicine or disease in the first release.
- Generating regimens from free-text or a language model.
- A full FHIR server or paid commercial interaction database in the initial architecture.
- Automatic patient diagnosis or autonomous treatment selection.
- Production activation before independent review and staff acceptance.

## Edge Cases
- Neonate with gestational/postnatal age boundary; corrected age where protocol requires it.
- Weight absent, stale, implausible, or measured in a non-kg unit.
- Dose basis confusion (mg/kg/dose vs mg/kg/day), maximum single dose and daily ceiling.
- Multiple product strengths/concentrations and dosage forms for one ingredient.
- Renal/hepatic function missing or changing; dialysis where protocol-specific.
- Allergy status unknown, reaction unclear, intolerance vs true allergy, cross-reactivity evidence uncertain.
- Duplicate therapy within same class or same ingredient under brand/generic names.
- Two conflicting protocols, outdated guideline, withdrawn recommendation or jurisdiction conflict.
- Diagnosis code and free text disagree.
- Product unavailable in inventory but prescribed externally.
- Clinician override after a critical alert; pharmacist review after an override.
- Network loss or source service unavailable: no silent fallback to unverified regimen.

## Success Criteria
- **SC-001**: 100% of active product entries with route constraints expose no incompatible route in the prescription UI.
- **SC-002**: 100% of weight-based calculations use a current-visit measurement and pass approved golden-case tests.
- **SC-003**: 100% of live recommendations expose their source, version, scope and rule match explanation.
- **SC-004**: 0 draft/unreviewed/expired rules are eligible for live matching.
- **SC-005**: 100% of hard-stop alerts have tested block/override behavior and audit evidence.
- **SC-006**: In staff usability testing, common prescription completion requires fewer manual fields/clicks than baseline without increasing unsafe defaults; target median reduction ≥30% after a measured baseline.
- **SC-007**: Unknown allergy/history/weight data are never represented as negative/normal facts.
- **SC-008**: All critical journeys pass 320–430px mobile, Arabic RTL and English LTR checks.

## Assumptions and Decisions
- Roshan is a general outpatient/primary-care centre with referral for conditions outside its capabilities; protocols must encode care setting and referral/escalation.
- Actual initial protocol list will be selected from the QA medicine catalogue and clinic case mix, then prioritized by GP and pharmacist.
- A Sudanese national essential medicines list publicly discoverable via WHO is dated 2019; it is not sufficient evidence for current dosing. Local Ministry of Health treatment protocols must be located and checked before claiming national alignment.
- Current visit vitals already store weight; the feature extends intake flow while preserving encounter-based measurement semantics.
- No current clinical dose database or licensed interaction database has been verified as available to Roshan.
