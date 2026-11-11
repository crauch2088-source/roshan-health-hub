# ADR-056: Phased deterministic medication engine

- **Status:** Accepted for phased engineering; clinical activation gated
- **Date:** 2026-11-11

## Context
Roshan needs an integrated medication engine connecting verified product identity, confirmed indication, encounter context, source-backed protocols, transparent calculations, medication safety and clinician review. PR #185 is useful research but carries an older explicit scope deferral; it must be reconciled rather than merged as-is.

## Decision
Build the full capability incrementally with deterministic, versioned, explainable rules. Run engineering in parallel with the core release. The first code slice is a pure arithmetic kernel with no drug-specific regimen.

## Options
- Static templates only: too limited for indication, weight, formulation and context.
- LLM-generated doses: rejected as non-deterministic and not sufficiently auditable or bounded.
- Full enterprise FHIR server from day one: disproportionate and likely to delay core launch.
- Phased deterministic engine: selected.

## Consequences
The calculation logic is independently testable, evidence and approvals are traceable, and core release can proceed while clinical knowledge is validated. Local primary guidelines, verified formulary data, licensing, clinician review and structured context remain dependencies.

## Follow-up
Implement/verify the kernel in #233; reconcile catalogue with #210 and prescription UI with #179/#229; obtain current Federal/Gezira guidance; design structured allergy/current-medication context; activate no protocol without GP and pharmacist approval.


# Medication Engine Execution Plan

**Canonical PR:** #233 | **Baseline:** current main 2026-11-11 | **Delivery:** parallel workstreams, serial safety gates.

## Architecture
Verified product catalogue → encounter context → confirmed indication and setting → versioned source-backed protocol matcher → deterministic arithmetic and safety evaluator → recommendation / needs_data / no_match / blocked → clinician review and explicit acceptance → existing atomic prescription and pharmacy workflow + audit.

The evaluator is pure and deterministic. DB access, source retrieval, AI and UI state remain outside the arithmetic kernel.

## Workstreams
- **W0 Foundation (active):** typed fixed/mg/kg/dose/mg/kg/day arithmetic; explicit frequency; separate dose/day ceilings; missing weight blocks; invalid numeric values fail closed; rounding is opt-in and bounded. No drug recommendation.
- **W1 Catalogue:** reconcile PR #210; verify ingredient, brand, strength, concentration, form, pack and label. No guessed backfill or duplicate stock/batch model.
- **W2 Context:** current visit-linked weight, freshness policy, age-at-encounter, structured allergy status, current medication reconciliation and structured indication. Preserve atomic visit/invoice/vitals contracts.
- **W3 Evidence:** immutable source and protocol versions, jurisdiction/population/setting, exclusions, licensing, reviewers, expiry and golden cases. Verify Federal/Gezira primary guidance.
- **W4 Matcher:** confirmed structured indication only; product and patient predicates; recommendation/needs_data/no_match/blocked; no free-text trigger, network fetch, LLM or silent fallback.
- **W5 Safety:** allergy, interaction, contraindication, duplicate therapy, age, pregnancy, renal and hepatic rules; source-specific and coverage-transparent.
- **W6 Workflow:** show source and matched facts; explicit accept/edit; use existing atomic prescription RPC; audit suggestion/edits/alerts/override/final order; exact persisted regimen to pharmacy.
- **W7 Release:** unit/integration/PG17/RLS/branch/browser tests, Arabic RTL/English LTR, synthetic GP/pharmacist E2E, independent approvals and staff acceptance.

## Parallel execution
Run W0, W1, W3 and W2 contract design concurrently. Build W4 against typed interfaces while W1–W3 supply verified data. Develop W5 framework in parallel but do not activate it until structured context and evidence exist. W6 UI integration waits for PR #229 conflict reconciliation to avoid overlapping pharmacy/prescription edits.

## Stop conditions
No verified source → no protocol. No verified product → no product route/concentration. No current weight → no weight-based calculation. No confirmed indication → no match. Expired/unreviewed/conflicting source → no recommendation. No GP + pharmacist approval → no activation. Any RLS/branch/atomicity regression → stop integration.

## Current status
Test contract is committed first in PR #233. Pure calculator implementation is now added on the same branch. No hosted database, patient data, clinical protocol, production deployment or role/ACL change has occurred.


## Matcher safety hardening — 2026-11-11

- Added a regression test for a source whose stated care setting conflicts with the protocol's care setting; such a protocol must be blocked as invalid provenance.
- Source-setting equality is now enforced at both matcher branches (including the missing-age path), not merely recorded as descriptive metadata.
- Dual approval actor IDs are normalized by trimming and case-folding before distinct-person comparison, preventing the same UUID-like actor represented with different hex casing from satisfying two-person control.
- A non-array protocol payload now fails closed as invalid context rather than throwing at runtime.
- Regression tests added for all three boundaries. No real protocols, patient data, database changes or clinical activation.


## Explicit protocol scope and runtime-input hardening — 2026-11-11

- Protocol and encounter context now require explicit population and jurisdiction in addition to indication, setting and medicine identity. The matcher does not infer these dimensions from age or diagnosis text.
- Source provenance must exactly agree with protocol setting, population and jurisdiction; mismatches block.
- Dose calculation rejects malformed runtime payloads without throwing and requires a positive safe-integer doses-per-day count. Non-daily interval regimens need a separate interval representation.
- Regression coverage added for source/context scope mismatches, missing context, malformed calculator payloads and fractional frequency.
- This remains a non-clinical foundation: no active clinical protocols or patient-specific recommendations.


## Decimal rounding safety correction — 2026-11-11

- Replaced epsilon-adjusted binary floating-point floor/ceil with exact decimal-rational quotient/remainder rounding using BigInt.
- "Down" can no longer cross upward and "up" can no longer cross downward merely because a value is within a fixed epsilon of an increment boundary.
- Rounding increments below the kernel's declared 1e-10 mg precision are rejected as invalid parameters rather than silently normalised.
- Added near-boundary directional and 0.3/0.1 decimal regression cases. No clinical regimen is supplied or activated.


### Rounding-order correction — 2026-11-11

The calculator now retains the full raw/capped decimal value until directional rounding has completed. Normalising to the 1e-10 mg output precision before rounding could erase a value's position just below or above an increment boundary. The boundary regression tests cover both directions; output normalisation occurs only after the rounding decision.
