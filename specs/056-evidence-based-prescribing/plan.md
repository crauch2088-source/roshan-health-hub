# Implementation Plan: Evidence-Based Prescribing & Clinical Decision Support

**Branch**: `feat/056-evidence-based-prescribing` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

## Summary

Build a deterministic and explainable prescribing decision-support capability around the existing React/TypeScript, Supabase and PostgreSQL 17 application. Preserve existing patient registration, visit, prescription atomicity, inventory, RLS and branch boundaries. Separate medicine-product identity from indication-specific, versioned clinical protocols. Start with formulation/route correctness and encounter weight capture; activate no dosing content until evidence and independent clinical approval exist.

## Technical Context

- **Language**: TypeScript; SQL/PostgreSQL 17 only where schema/RPC changes are proven necessary.
- **UI**: React + TanStack Start + Tailwind, existing components and i18n, phone-first Arabic RTL/English LTR.
- **Data**: Supabase PostgreSQL; authenticated client through existing RLS and approved SECURITY DEFINER RPCs.
- **Tests**: repository Node test suite, Vitest/TypeScript/lint/build per package scripts, disposable PostgreSQL 17 integration and authorization tests.
- **External runtime dependencies**: none required initially; no paid service or new hosted database.
- **Clinical content**: curated, source-versioned records; no runtime model-generated dosing.

## Constitution Check

- Clinical safety/data fidelity: PASS by design; no invented defaults, no dose rules without signed sources.
- Privacy/least privilege: PASS subject to RLS/branch tests; synthetic fixtures only.
- Database/atomicity: CONDITIONAL; first-visit weight persistence must reuse/extend approved atomic RPC boundaries; no direct browser writes.
- Migration/production safety: PASS; QA-only migrations and isolated PG17; production explicitly excluded.
- Evidence/test-first: PASS as requirement; TDD and exact-head CI mandatory.
- Source-of-truth: PASS; Spec Kit feature docs plus MASTER_PLAN roadmap.
- Mobile/bilingual: PASS as acceptance gate.
- Cost efficiency: PASS; existing infrastructure and quota-safe atomic commits.

## Architecture

### A. Medication product catalogue
Existing `medicines` rows provide generic/brand names, strength and dosage form, but route compatibility and concentration semantics are not fully structured. Keep inventory/stock data separate from clinical product knowledge. Introduce a normalized product knowledge layer only after verifying current schema and maintenance permissions:
- ingredient identity and synonyms;
- marketed product/brand, strength and strength unit;
- dosage form, concentration and concentration unit;
- permitted administration routes for that exact product;
- dose/dispense unit mapping and product-specific restrictions;
- catalogue provenance and verification state.

A missing or ambiguous route mapping must remain unverified; never infer route from generic name or dosage-form label alone. Product route metadata is not an indication-specific dosing regimen.

### B. Encounter and patient context
The current patient registration UI calls `create_patient_atomic(text,text,date,text,text)`. Current `vitals.weight` is nullable numeric and visit-linked; prescription UI already queries the latest weight for the active visit. Do not add a timeless `patients.weight` field.
- Add optional weight capture to the new-patient/first-visit intake journey.
- Persist it only as a first-visit `vitals` observation with visit_id, patient_id, recorded_by and timestamp.
- Investigate the existing visit creation and invoice RPCs before selecting an atomic implementation. If patient + visit + vitals must be one transaction, extend/create a single permission/branch-checked RPC that preserves current billing semantics. Do not call an existing invoice RPC twice or bypass it.
- Later encounters require their own measurement for weight-dependent rules. The engine reports age and measurement timestamp used.

Clinical context should model allergy status (unknown / no known allergy / known allergy), reaction, active medicines, relevant diagnoses, pregnancy/lactation where applicable, renal/hepatic function and other rule-specific variables with source/time and confidence.

### C. Diagnosis and protocol knowledge
Diagnosis remains linked to visit and retains ICD-10. Protocol matching uses confirmed structured diagnosis/indication plus patient and setting predicates. Free text may suggest a diagnosis candidate; it cannot activate a protocol. Multiple/ambiguous matches must be shown for clinician selection.

Protocol record fields:
- stable identifier, version, status (draft/review/approved/active/suspended/retired);
- medicine ingredient/product constraints and indication/ICD mapping;
- population (adult/child/neonate, age/gestational boundaries), setting, severity and exclusions;
- dose expression and basis, route, frequency/interval, duration, max per dose/day, concentration, units, rounding and monitoring;
- required context (weight, renal/hepatic data, pregnancy, allergy, etc.);
- source references, source date/version, jurisdiction, evidence grade, reviewer and effective/review/expiry dates;
- golden test cases and activation approval.

### D. Deterministic evaluator
Pure TypeScript evaluator; input is a selected product, confirmed indication, current encounter context and active protocol versions. Output is one of:
- `recommendation` with exact source and matched predicates;
- `needs_data` with missing/stale/conflicting inputs;
- `no_match` with reason;
- `blocked` with safety rule and next action.

The evaluator does not fetch the web, call an LLM or infer missing values. It is deterministic, version-pinned and unit-tested. Calculations use explicit units and decimal-safe arithmetic. Every dose basis is represented as a tagged variant (e.g. weight-based per dose vs weight-based per day) so they cannot be confused.

### E. Medication safety rules
Separate rule types for allergy, interaction, contraindication, duplicate therapy, age/pregnancy restrictions, renal/hepatic adjustment and dose range. Severity levels: hard stop, acknowledgeable warning, non-interruptive information. Hard-stop override is restricted and reasoned; every alert shows patient-specific rationale and source. Unknown status is never treated as negative.

### F. Audit and governance
Preserve immutable protocol versions and record the exact version used in each prescription recommendation. Audit input snapshot identifiers/measurement timestamps, rule match, initial suggestion, clinician edits, override reasons, actor and time. Avoid duplicating PHI in logs; reference source records by ID and minimize snapshot fields.

## Project Structure Decision

- `src/lib/clinical-decision-support/`: pure types, protocol matcher, dose arithmetic and alert evaluation.
- `src/features/clinic/consultation/components/`: prescribing and vitals UX integration.
- `src/routes/_authenticated/patients.tsx` and existing visit flow: initial weight capture only after atomic-flow contract is understood.
- `db/`: only verified, minimal QA migration(s) if schema changes are needed.
- `tests/`: unit, integration, PG17, role/branch and clinical golden cases.
- `specs/056-evidence-based-prescribing/`: feature-specific Spec Kit artifacts.

## Delivery stages

1. **Foundation and source audit** — reconcile PR #125/#179/#183; inspect complete visit creation, inventory maintenance, allergy/history capture and pharmacy read contracts; query QA catalogue counts and columns read-only.
2. **Product/formulation safety** — structured product identity and verified route compatibility; explicit unknown mapping state; no dose recommendations yet.
3. **Intake weight** — optional initial weight in registration/first-visit flow, stored only in visit vitals with provenance; prevent historical weight reuse.
4. **Protocol knowledge model and evaluator** — schema, deterministic typed rules, protocol versioning, source traceability and test harness; default all clinical content to draft/inactive.
5. **Small reviewed protocol cohort** — select actual QA formulary and high-frequency cases with GP/pharmacist. Add adult protocols first where source is current and local setting fits. Do not activate pediatric protocols until neonatal/age/weight/maximum-dose/rounding and clinical golden cases are independently approved.
6. **Interaction/allergy and contraindication rules** — after identifying a licensed or appropriately redistributable evidence source; begin with verified high-severity rules. Do not claim exhaustive coverage.
7. **UX, pharmacy continuity and governance** — recommendation explanation, overrides, alert acknowledgement, source/version display, review queue, Arabic/English mobile testing.
8. **Release** — isolated QA PG17, RLS/branch tests, synthetic-clinician E2E, independent clinical sign-off, staff acceptance, rollback and monitoring. Production changes remain a separate explicit gate.

## Risks and mitigations

- **Incorrect dose**: inactive-by-default content, strict scope predicates, typed dose basis, maxima, unit tests, clinician/pharmacist approval.
- **Alert fatigue**: severity tiers, duplicate suppression, relevance, source and action.
- **Stale weight**: encounter-scoped measurement only; display timestamp; no silent carry-forward.
- **Conflicting guidelines**: explicit jurisdiction/source precedence, conflict state, human review.
- **Data gaps**: unknown state and needs_data result, not assumed normal.
- **Licensing/cost**: verify source redistribution rights before ingestion; no paid API in MVP.
- **Shared PR conflicts**: reconcile existing prescription UI branches before editing shared components.

## Open design checks before schema/code
- Confirm current `create_visit_atomic`/visit+invoice creation contract and how Save & New Visit flows from patient registration.
- Confirm whether patient allergies/history currently exist in any other table/view and their RLS contracts.
- Confirm actual QA catalogue and stock product identities without retrieving patient data.
- Confirm source licensing and exact local clinical review owner.


## Verified QA workflow constraints — 2026-11-03 follow-up

A further source and QA read-only inspection established:
- The current QA `medicines` table contains **0 rows**. There is no actual formulary cohort to prioritize yet. Phase 0 must therefore obtain a reviewed Roshan formulary/product list, verify product identity/strength/formulation/route, then seed only reviewed catalogue records in QA. No protocol content should be selected from assumed stock.
- The current patient registration form's `Save & new visit` action creates the patient through `create_patient_atomic` then navigates to `/visits?patient=<id>`.
- The current visit form inserts the visit row directly, then calls `create_visit_consultation_invoice_atomic` separately when the consultation fee is positive. It does not currently use one combined visit+invoice transaction.
- The vitals form saves the weight as a visit-linked row and updates the latest row. This is the correct measurement destination, but simply adding a second client write after visit creation would create a partial-success failure mode.

**Implementation consequence:** before adding weight to registration, design and test a server-authoritative, idempotent intake/visit creation boundary that persists visit + initial weight and preserves consultation invoice semantics. If a single atomic boundary cannot safely include existing billing behavior, capture weight in the visit intake UI and save it through the existing vitals flow with explicit retry/pending state; never silently discard it or create a patient-level weight cache. The implementer must prove rollback/idempotency and branch/permission checks before choosing.


## Sudan-specific evidence update — 2026-11-03

A WHO Bulletin comparative review identifies Sudan Federal Ministry of Health National Standard Treatment Guidelines (2014), but the primary file was inaccessible during this review. Obtain it and check for superseding federal/state guidance before claiming local alignment. A 2025 Sudan PHC observational study reported high Watch-antibiotic use and low AWaRe compliance; it supports stewardship prioritization only and is not a dosing source. See research.md.
