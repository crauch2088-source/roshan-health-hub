# Patient medication and allergy context — schema/RLS audit

**Audit date:** 2026-11-03  
**Environment:** Isolated QA Supabase `hopfohcnrtbiqjkgeukz`  
**Scope:** Metadata, table counts and RLS policy definitions only. No patient or clinical-note rows were read.

## Findings

- `patients.allergies` and `patients.chronic_conditions` are nullable free-text fields.
- `clinical_notes.allergy_history` and `clinical_notes.drug_history` are nullable free-text fields.
- No dedicated structured allergy, adverse-reaction, drug-interaction, or patient current-medication reconciliation table was found in the inspected `public` schema.
- `prescriptions` and `prescription_items` store historical orders and dispensing state (`status`, `is_external`, `dispensed_at/by`, `is_dispensed`, `dispensed_quantity`). These are not a reconciled active-medication list: a historical order may be stopped, completed, superseded, or externally prescribed.
- QA `clinical_notes` and legacy `medicines_2` each contained zero rows. No patient or clinical-note data was queried.
- `medicines_2` is a legacy table with integer ID/name/price/stock columns and an `admin.full`-only policy. The current catalogue is `medicines`.
- `medicines` policies require `pharmacy.read/create/update/delete`.
- `patients` policies require the corresponding `patients.read/create/update/delete` permission and `private.app_has_branch_access(branch_id)`.
- `clinical_notes` and `vitals` policies require the corresponding `emr.read/create/update/delete` permission and `private.app_has_visit_branch_access(visit_id)`.
- `prescriptions` and `prescription_items` policies allow the corresponding pharmacy or EMR permission and enforce their parent visit/prescription branch-access helper.

## Design consequences

1. Preserve three distinct allergy states: **unknown**, **known negative**, and **known positive**. An empty text field is not NKDA.
2. Introduce structured allergy/adverse-reaction records with reaction, severity, certainty, source, verification status, recorder, timestamp, and branch-safe access. Do not conflate an adverse effect/intolerance with immune-mediated allergy.
3. Introduce a current-medication reconciliation record with status (active, stopped, completed, historical, uncertain), source, dates, dose as recorded, and reviewer. Do not infer current use from prescription history alone.
4. Keep free-text clinical notes for narrative context, but do not parse them into hard-stop rules without clinician verification.
5. Build all read/write paths around existing EMR permissions and visit/patient branch guards. Test unauthorized, cross-branch, unknown-state, and deleted-parent cases in PostgreSQL 17 before any QA migration.
6. Do not activate allergy or interaction hard stops until the structured record model, data provenance, and review workflow exist.

No schema or data was changed by this audit.
