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


## Reconciled mainline status — 2026-11-11

PR #233 is based on main after Phase58/59 finance integration. Exact code head 60ea37e499f2733020cd32706d43e5c76fbeac20 passed 20 successful jobs, one intentional authenticated clinical-acceptance skip, zero failures; 292/292 guard tests passed. This is an arithmetic foundation only and is not clinically approved or activated.
