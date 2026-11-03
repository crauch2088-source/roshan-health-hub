# Clinical Safety Checklist: Evidence-Based Prescribing

**Purpose:** Requirements-quality and clinical governance review.  
**Feature:** [spec.md](../spec.md)  
**Status:** All items unchecked pending independent review. A checked item would mean reviewed/satisfied, not implementation complete.

## Medication identity and route
- [ ] Product is uniquely distinguished by ingredient, brand, strength, form and concentration.
- [ ] Route constraints are specific to the selected product and formulation.
- [ ] Unverified route mappings cannot be used as defaults.
- [ ] No generic-name-only selection silently prepopulates route or regimen.

## Patient context and dose calculations
- [ ] Weight is an encounter observation with timestamp, unit and actor.
- [ ] Old weight cannot silently satisfy a current-visit weight requirement.
- [ ] Age is calculated at encounter date and includes day-level neonatal boundaries where required.
- [ ] Gestational/corrected age semantics are defined per protocol.
- [ ] mg/kg/dose and mg/kg/day are distinct typed calculations.
- [ ] Max single dose and max daily dose are both represented where applicable.
- [ ] Concentration and volume conversions use explicit units.
- [ ] Rounding and dose-measurement precision are source-defined.
- [ ] Missing renal/hepatic/pregnancy/weight context blocks dependent rules.
- [ ] Unknown data is not represented as negative or normal.

## Evidence and governance
- [ ] Exact source, version, publication date, jurisdiction and relevant section are present.
- [ ] Population, care setting, indication, inclusion and exclusion criteria are explicit.
- [ ] Source is current and permitted for local storage/redistribution.
- [ ] GP and pharmacist reviewer identities and approvals are recorded.
- [ ] Expired, draft, withdrawn or unreviewed rules are inactive.
- [ ] Golden cases and boundary tests pass before activation.
- [ ] Conflicting sources are escalated rather than automatically blended.

## Alerts and overrides
- [ ] Serious allergy and hard-stop interaction behavior is tested.
- [ ] Warning severity and acknowledgement requirements are justified.
- [ ] Low-value informational alerts are non-interruptive.
- [ ] Duplicate alerts are suppressed without hiding a changed risk.
- [ ] Overrides preserve original suggestion, final order, actor, timestamp and reason.
- [ ] Drug interaction coverage and data gaps are disclosed.

## Security, workflow and release
- [ ] All data access is permission- and branch-scoped.
- [ ] Writes use approved atomic RPC boundaries.
- [ ] No real patient/financial data is used in tests, specs or external services.
- [ ] Pharmacy sees exact persisted instructions and route.
- [ ] Arabic RTL, English LTR and mobile workflows are tested.
- [ ] Isolated QA PostgreSQL 17, synthetic role E2E, clinical sign-off and staff acceptance are complete.
- [ ] Production changes have separate backup/restore and owner release approval.
