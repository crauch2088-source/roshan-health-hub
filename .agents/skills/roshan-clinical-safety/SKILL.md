---
name: roshan-clinical-safety
description: Use whenever changes can affect patient identity, clinical records, diagnoses, observations, medication instructions, prescriptions, certificates, or clinician-facing decisions.
---

# Roshan Clinical Safety

## Clinical source of truth
- Persisted, authorized records are authoritative. Never invent, infer, silently normalize, or auto-complete diagnoses, findings, medication instructions, allergies, weights, dates, signatures, or clinical facts.
- Distinguish absent, unknown, not assessed, pending, negative, and zero.
- Show provenance/status where draft, imported, unverified, or historical information could be mistaken for confirmed data.
- Preserve clinician review and explicit confirmation for professional decisions.
- AI suggestions must never silently become signed, saved, dispensed, or communicated instructions.

## Medication safety
- Separate product identity (ingredient, brand, strength, dosage form, packaging) from administration route and prescription instructions.
- Do not infer route from dosage form, strength from brand string, dose from age/weight, or frequency/duration/indication from medicine name.
- Dose calculators require validated inputs/units, indication-specific authoritative references, hard limits, missing-data handling, and clinician confirmation.
- A medicine catalogue is not a dosing guideline; typed catalogue data does not verify pack authenticity.

## Workflow safeguards
- Preserve draft/partial-save semantics and visible persisted/unsaved state.
- Preserve visit/patient/branch linkage and reject mismatches at authoritative layer.
- Keep cancellation, amendments, signatures, verification, and audit history explicit.
- Critical/abnormal lab results retain source value, unit, range, and status; never silently recalculate or erase critical flags.
- Test missing, malformed, boundary, conflicting, stale, and unauthorized inputs with synthetic records.
- Passing tests do not replace clinician review, staff acceptance, or explicit clinical release gates.
