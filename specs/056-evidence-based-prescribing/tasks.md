# Tasks: Evidence-Based Prescribing & Clinical Decision Support

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contract](contracts/decision-support-contract.md)  
**Progress**: T001–T006 completed as repository/database and public-source discovery only. No clinical protocol, product route mapping, dose rule, or medication interaction rule has been approved or activated.

## Phase 0 — Reconciliation and evidence acquisition
- [x] T001 Fetch latest main and re-read master plan/tool map/constitution.
- [x] T002 Reconcile PR #125, #179 and #183 against current main; identify safe merge sequence and preserve all newer safety changes.
- [x] T003 Inspect patient registration, first-visit creation, invoice atomic RPC and vitals write path; write down exact contract and test boundaries.
- [x] T004 Inspect medicine inventory create/edit permissions and actual QA formulary metadata without reading patient rows.
- [x] T005 Inspect allergy, adverse reaction, current-medication and medical-history schemas/RLS; distinguish missing from unknown.
- [x] T006 Complete a bounded public-source search for current Sudan Federal/State MoH treatment guidance; assess source/version/licensing and record unavailable primary documents explicitly. This closes the public-search task only; it does not establish that current local guidance was obtained.
- [ ] T007 Select a small initial protocol cohort with GP/pharmacist based on QA formulary and clinic case mix.

## Phase 1 — Product/formulation constraints (US1)
- [ ] T008 [P] Add failing unit tests for product identity, missing mapping and route compatibility.
- [ ] T009 Implement typed product knowledge model with explicit unverified/reviewed/approved status.
- [ ] T010 Add safe route filtering to prescription draft using product-level verified mapping; never infer from generic name.
- [ ] T011 Add bilingual mobile UI for product strength/formulation and unavailable route state.
- [ ] T012 Add tests for multiple strengths, dosage forms, injectable-only and incomplete mappings.
- [ ] T013 Verify inventory edit role/RLS and pharmacy visibility; use a QA migration only if schema is necessary.

## Phase 2 — First-visit weight capture (US2)
- [ ] T014 Add failing test for weight captured in registration/first-visit workflow and stored against the encounter.
- [ ] T015 Implement first-visit intake weight capture while preserving patient registration atomicity and visit/invoice creation contract.
- [ ] T016 Add validation for positive finite kg values and plausible-input warning; do not silently convert unknown units.
- [ ] T017 Verify actor, timestamp, patient_id, visit_id, branch and update semantics for vitals.
- [ ] T018 Add regression proving later visits never inherit a previous encounter's weight.
- [ ] T019 Add pediatric missing/stale-weight UI tests; no dose calculation in this phase.

## Phase 3 — Knowledge and deterministic evaluator
- [ ] T020 Add failing tests for active/draft/expired protocol eligibility and indication/patient predicate matching.
- [ ] T021 Define typed protocol, source, version, patient predicate and provenance contracts.
- [ ] T022 Implement pure deterministic protocol matching outcomes: recommendation, needs_data, no_match, blocked.
- [ ] T023 Add typed dose basis variants (fixed, mg/kg/dose, mg/kg/day, mg/m²/dose) and decimal-safe arithmetic tests.
- [ ] T024 Add unit conversion, max single/daily dose, concentration, volume and rounding tests.
- [ ] T025 Add age/neonatal/gestational/renal/hepatic boundaries and missing-data negative tests.
- [ ] T026 Add immutable protocol version and recommendation audit schema/RPC only after RLS/branch design review.
- [ ] T027 Verify PostgreSQL 17 replay and role/branch negative tests on isolated QA.

## Phase 4 — Clinician-reviewed initial protocols
- [ ] T028 Create source-backed protocol content only after exact source section, applicability and local setting are verified.
- [ ] T029 Add clinician-approved golden cases and boundary tests for every protocol.
- [ ] T030 Obtain separate GP and pharmacist approval for each version and record review/expiry metadata.
- [ ] T031 Keep neonatal/pediatric rules inactive until independent age/weight/max-dose review is complete.
- [ ] T032 Confirm no conflicts with local Sudan MoH guidance or document the absence of a current local source.

## Phase 5 — Medication safety (US5)
- [ ] T033 Add failing tests for allergy unknown/negative/positive states and serious allergy block.
- [ ] T034 Implement structured allergy/adverse reaction distinction and visible status.
- [ ] T035 Add source-backed interaction/contraindication/duplicate therapy rule contracts.
- [ ] T036 Implement severity tiers, duplicate suppression, acknowledgement and governed override reason.
- [ ] T037 Add renal/hepatic/pregnancy/age safety rules only with source-specific patient predicates.
- [ ] T038 Validate interaction source coverage/licensing; state uncovered drugs explicitly rather than claiming exhaustive checks.

## Phase 6 — UX, pharmacy and governance (US6)
- [ ] T039 Add concise source/match explanation to the prescription suggestion.
- [ ] T040 Add pharmacist-facing exact saved regimen, formulation, route, instructions and alert/override context.
- [ ] T041 Add reviewer workflow for draft, approved, active, suspended and retired protocol versions.
- [ ] T042 Add expiry detection and source update/revalidation process.
- [ ] T043 Test 320–430px Android, Arabic RTL, English LTR, keyboard and accessibility paths.

## Phase 7 — Release
- [ ] T044 Run repository test suite, TypeScript, lint, build and exact-head CI.
- [ ] T045 Run disposable PostgreSQL 17 migration/RLS/branch/atomicity tests in QA.
- [ ] T046 Run synthetic clinician/pharmacist E2E and pharmacy handoff tests.
- [ ] T047 Obtain clinical sign-off and staff acceptance; keep issue #95 gate open until accepted.
- [ ] T048 Document production rollback and only then request separate explicit production release authorization.

## Review focus
- No silent old-weight reuse.
- mg/kg/day vs mg/kg/dose dimensional correctness.
- Route compatibility vs indication-specific route.
- Diagnosis free text must not activate a protocol.
- Unknown allergy status must not become NKDA.
- Protocol expiry/withdrawal and source conflict.
- RLS/branch isolation and atomic visit/invoice writes.
- No live clinical defaults before independent sign-off.


### Phase 0 evidence note — 2026-11-03

- PR #179 (saved-prescription printing) has been synchronized with current `main` at head `b2e4f67334f7f49fc4fa86ae8e06614b4f95b263`; it is 18 commits ahead, zero behind, mergeable, and remains Draft while exact-head CI runs. It contains the explicit-route behavior and the age/custom-field safeguards being developed in PRs #183 and #125. Do not merge #125/#183 independently or close them until the final PR #179 diff is reviewed and merged; reconcile any unique documentation separately.
- T003 is complete as an audit: current visit creation is a direct visit insert followed by a separate consultation-invoice RPC; `vitals.visit_id` is unique; and VitalsTab updates the encounter row. The proposed combined transaction still requires implementation and PG17 proof.
- T004 and T005 are complete as read-only discovery tasks. Their findings remain implementation constraints: QA has no formulary rows, Production candidates require physical-pack verification, and allergy/current-medication context is not yet represented by structured records.
- T006 public-source search is complete, but no accessible current Federal/ Gezira primary STG set was verified. T049 now tracks obtaining and validating those documents; clinical activation remains blocked.
- T007 remains blocked until the candidate formulary is normalized and a GP/pharmacist selects and signs off the initial cohort.


- T004 completion evidence: QA catalogue is empty; Production has nine incomplete candidates (see catalogue-audit.md). The inventory create form captures only display name, inventory unit, prices and reorder level; a DB trigger copies `name` into required `generic_name` when absent. Medicines RLS is permission-gated by `pharmacy.read/create/update/delete`; no direct medicine update call was found in the reviewed inventory UI/code search. `medicines_2` is empty and admin-only.
- T005 completion evidence: QA schema has only free-text patient and clinical-note allergy/drug-history fields; no structured allergy/adverse-reaction, interaction or current-medication reconciliation tables were found. Patients, clinical notes, prescriptions, prescription items and vitals have role/branch-scoped RLS as detailed in clinical-context-audit.md.


### T006 completion evidence — Sudan local guideline source audit (2026-11-03)

- FMoH's 2017 National Health Care Quality Policy and Strategy reports 15 published clinical standards and PHC STGs for 26 conditions at that time; it does not enumerate or supply current versions.
- The 2014 FMoH National STG is identified through a WHO comparative review, but the cited primary download could not be retrieved. A 2017 consultancy notice planned an update but does not prove a final approved edition.
- WHO's public Sudan NEML record is for 2019 and is not a treatment guideline.
- A 2020 Red Sea State family-medicine manual exists but is geographically non-transferable to Gezira without formal adoption/review. A 2022 University of Gezira emergency-protocol report is only a secondary lead; the original document and formal State Ministry adoption were not verified.
- A 2024 BMC Primary Care study (data collected in 2021 in Khartoum and Gezira) reports local guidelines were difficult to access and not regularly updated.
- Full source provenance, limitations, URLs and licensing caveats are recorded in [research.md](research.md). No regimen content was extracted.
- **Remaining external dependency:** obtain primary Federal and Gezira State documents and written/current adoption status from the relevant authorities before any local rule is encoded or activated. This is not satisfied by checking T006 complete.

- [ ] T049 Obtain primary Federal Ministry of Health and Gezira State Ministry of Health guideline/circular copies (plus the original University of Gezira emergency protocol if relevant); verify formal approval, edition/date, applicability, supersession, licensing, and GP/pharmacist review. Keep all local rules inactive until this evidence exists.
