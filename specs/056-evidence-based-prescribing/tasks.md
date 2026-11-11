# Medication Engine Tasks

**Status:** 2026-11-11 | **Canonical PR:** #233. Engineering progress is not clinical approval.

## Phase 0 — Foundation
- [x] Specify tests for fixed, mg/kg/dose and mg/kg/day arithmetic, explicit frequency, missing weight, invalid values, ceilings and rounding.
- [x] Register focused tests in test:guard.
- [x] Implement pure arithmetic kernel.
- [x] Verify exact-head focused/full tests, typecheck, lint and build (283/283 guard tests; CI run 42993044633; authenticated clinical acceptance intentionally skipped).
- [ ] Independent review of dimensional semantics, rounding and safety-cap behavior.

## Phase 1 — Product catalogue and physical verification
- [ ] Reconcile PR #210 with current main.
- [ ] Define canonical ingredient/product/formulation/pack contract.
- [ ] Verify physical packs, strength, concentration, dosage form and product label.
- [ ] Add reviewed/unverified status and provenance without duplicating inventory.
- [ ] Select the initial formulary cohort with GP and pharmacist.

## Phase 2 — Encounter context
- [ ] Define age-at-encounter and current-weight semantics.
- [ ] Define freshness policy and stale-weight blocking.
- [ ] Design structured allergy/adverse-reaction states and provenance.
- [ ] Design current medication reconciliation and structured indication.
- [ ] Preserve atomic visit/invoice and clinical child-RPC contracts.

## Phase 3 — Evidence registry and protocol governance
- [ ] Obtain primary current Federal/Gezira protocols; verify edition, endorsement, applicability and licence.
- [ ] Define immutable source and protocol version lifecycle.
- [ ] Define predicates, exclusions, units, dose basis, frequency, ceilings, rounding, monitoring and stop criteria.
- [ ] Define deterministic outcomes: recommendation, needs_data, no_match, blocked.
- [ ] Define golden-case format and independent approval workflow.

## Phase 4 — Protocol matcher and limited cohort
- [ ] Implement deterministic matching with structured confirmed indication only.
- [ ] Add source/protocol provenance to every result.
- [ ] Add adult protocols only after signed GP/pharmacist selection.
- [ ] Test missing, stale, conflicting, boundary and out-of-scope context.
- [ ] Keep unsupported indication/population as no_match.

## Phase 5 — Medication safety
- [ ] Structured allergy checks and explicit unknown status.
- [ ] Duplicate therapy and contraindication framework.
- [ ] Interaction data source/licence and coverage statement.
- [ ] Severity, acknowledgement, override reason and audit.
- [ ] Renal/hepatic/pregnancy/age rules only when source-backed.

## Phase 6 — Workflow and release
- [ ] Review integration with PRs #179 and #229.
- [ ] Show source, version, matched facts, calculation and limitations.
- [ ] Clinician accept/edit; no automatic save/sign/dispense.
- [ ] Pharmacy handoff displays exact persisted regimen.
- [ ] Arabic RTL / English LTR and 320–430px mobile acceptance.
- [ ] Exact-head CI, disposable PG17/RLS/branch tests for any schema, synthetic GP/pharmacist E2E.
- [ ] Independent GP and pharmacist approval for every active protocol.
- [ ] Staff acceptance, backup/restore and separate owner production authorization.
