# Data Model: Evidence-Based Prescribing

**Status:** conceptual model for review; not a migration specification. Existing schema must be reconciled before DDL.

## Existing entities verified on QA schema
- `patients`: identity, DOB, gender, allergy text and chronic-condition text currently exist; these text fields are not a sufficient structured medication-safety model.
- `visits`: encounter and patient/branch relationship.
- `vitals`: visit-linked nullable numeric weight and height; `visit_id` is required. Weight is an observation, not a patient master attribute.
- `diagnoses`: visit-linked diagnosis name and optional ICD-10 code.
- `medicines`: generic name, brand name, strength, dosage form, active flags and inventory/price fields.
- `prescriptions` / `prescription_items`: visit/patient order and saved dose, frequency, duration, quantity, instructions, dosage form and route.
- Existing atomic functions include `create_patient_atomic(text,text,date,text,text)` and `create_prescription_atomic(uuid,boolean,jsonb)`; preserve them unless a reviewed compatibility migration is necessary.

## Proposed logical entities

### MedicationProductKnowledge
One clinically verified product/formulation record linked to an inventory medicine where possible.
- id, medicine_id nullable, ingredient_code, ingredient_display, brand_display
- strength_value, strength_unit, concentration_value, concentration_unit
- dosage_form_code, permitted_routes[], dose_unit_code, dispense_unit_code
- mapping_status (unverified/reviewed/approved/retired), source_id, version, effective dates
- Distinguish a product (e.g. injection vial) from its ingredient (molecule).

### ClinicalSource
- id, organization, title, document_identifier, version/edition, published_at, jurisdiction
- population, setting, source_url, section/page, evidence_grade, licence
- retrieved_at, reviewed_by, reviewed_at, next_review_at, status

### MedicationProtocol
Stable logical identity:
- id, protocol_key, indication_code_system, indication_code, indication_display
- medicine ingredient/product constraint, jurisdiction, population, care_setting
- owner, current_version_id, lifecycle status

### MedicationProtocolVersion
Immutable content:
- id, protocol_id, version, status, effective_from, effective_to
- inclusion_predicates, exclusion_predicates, required_context
- dose_expression (typed basis, value, unit, weight/age/BSA dependency)
- route, frequency/interval, duration, max_per_dose, max_per_day
- concentration assumptions, dose/volume conversion, rounding rule, monitoring
- source_id(s), reviewer(s), approval record, test_fixture_version

### PatientClinicalContext
A projection/read model, not a duplicate clinical record. References:
- patient_id, visit_id, measurement ids/timestamps
- allergy status: unknown / no_known_allergies / known_allergy
- allergy and reaction references, active medication references
- relevant condition/diagnosis, pregnancy/lactation, renal/hepatic data and provenance
- missing/unknown/stale flags per datum

### MedicationSafetyRule
- id, version, type (allergy, interaction, contraindication, duplicate, age, pregnancy, renal, hepatic, dose-range)
- ingredient/product pair or patient predicate
- severity, condition expression, rationale, recommended action
- source_id(s), lifecycle status, effective/review/expiry dates, tests

### PrescriptionRecommendationAudit
- id, visit_id, prescription_item_id nullable until saved, actor_id
- protocol_version_id, source_id(s), matched_context references/timestamps
- proposed regimen, final regimen, edits, override reason, alert acknowledgements
- created_at; immutable append-only audit semantics

## Invariants
1. Inventory stock quantity/price/dispensing semantics are not mixed with clinical protocol knowledge.
2. Product route compatibility is a product/formulation constraint; regimen route is also indication/protocol-specific.
3. No active recommendation without a reviewed source, reviewer, current validity window and passing golden tests.
4. No weight-based calculation without a current encounter weight, units, timestamp and protocol-defined weight policy.
5. No silent use of historical patient weight, no implicit age defaults and no unknown-to-negative conversion.
6. No dose calculation without explicit dose basis, units, frequency, maxima, rounding and concentration semantics as applicable.
7. Recommendation audit captures source/protocol version and final clinician decision.
8. All new tables/views/RPCs must preserve RLS, branch scoping, least privilege, audit and atomicity.


## Additional QA verification — 2026-11-03
- `patients.allergies` and `patients.chronic_conditions` are free-text fields. The read-only schema audit did not identify dedicated structured allergy/adverse-reaction or interaction knowledge tables. Treat this as a gap requiring a designed, permission-scoped model; do not parse free text as a complete allergy history.
- The QA `medicines` table currently has zero rows. Product knowledge must not be pre-seeded from guesses or from generic online catalogues. Obtain and clinically/pharmaceutically verify the intended Roshan formulary first.
- Visit creation currently inserts `visits` directly and calls the consultation invoice RPC in a separate request. Any new intake/weight workflow must explicitly address partial failure and idempotency before extending that flow.
