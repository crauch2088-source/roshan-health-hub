# Quickstart — Phase 53 Print Validation

This is a developer/QA checklist. Use synthetic fixtures only.

## Prerequisites
- Node version from repository runtime pin.
- Dependencies installed from the committed lockfile.
- Isolated QA project and PostgreSQL 17 test workflow.
- No production patient or financial records.
- A browser with print preview; thermal tests additionally require the actual center printer and driver.

## Focused validation
1. Run the repository's guard/unit tests before changing print behavior.
2. Add failing tests for one-document print isolation before implementation.
3. Create synthetic fixtures for one invoice, two payments (one partial and one reversed), one complete prescription, one incomplete prescription, and two certificates.
4. Verify that each print action renders only its selected document.
5. Verify receipt totals and reversal labels against saved payment/ledger rows.
6. Verify prescription values exactly match persisted fields; incomplete instructions must not be filled automatically.
7. Verify clinic identity uses the same settings source as the settings page.
8. Test Arabic RTL and English LTR at A4; inspect line breaks, tables, numerals, mixed Arabic/Latin strings, and page breaks.
9. Test 58 mm and 80 mm only on the actual target printer/browser and record model, driver, paper setting, and screenshots/PDF evidence.
10. Verify unauthorized role and cross-branch access are denied by database policy, not merely hidden by the UI.

## Release checklist
- [ ] G0 schema/RLS/permission contracts verified in QA.
- [ ] G1 canonical clinic identity mapping verified.
- [ ] G2 prescription authorization semantics verified.
- [ ] Single-record print isolation tests pass.
- [ ] Financial and clinical fidelity tests pass.
- [ ] Arabic and English A4 checks pass.
- [ ] Thermal formats physically tested before claiming support.
- [ ] Exact-head CI passes.
- [ ] Finance/clinical staff acceptance recorded.
- [ ] No production migration or production data write was required.
