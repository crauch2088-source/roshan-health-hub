# Laboratory Reference Range and Result-Type Approval Register

**Purpose:** prepare the existing Roshan laboratory catalogue for clinician/laboratory-lead review before relying on automated abnormal-result flags.  
**Source snapshot:** read-only SELECT from Supabase project `jewzonxplxhogqrnhosl`, 2026-10-19.  
**Status:** NOT CLINICALLY APPROVED — blank fields are intentional. Do not enter guessed values or enable clinical reliance until each applicable row is signed off.

## Why this is a release blocker

The live catalogue currently has 18 active parameters, 14 typed numeric, no active rows in `lab_reference_ranges`, and no non-empty `reference_text` values. Two qualitative results are currently typed as numeric and two numeric-typed parameters have no unit. The mapper treats nonnumeric text conservatively, but catalogue metadata must be reviewed before routine use.

## Approval rules

1. Use a source appropriate to the exact assay, method, unit, age group and patient population. Record source title/organization, version/date, and URL or document identifier.
2. A qualified clinician/laboratory lead must approve the result type, unit, applicable age/sex population, reference interval or expected qualitative values, and any critical threshold/escalation policy.
3. Distinguish reference intervals from critical limits. Critical thresholds and notification procedures require explicit clinical approval and must not be inferred from a normal reference interval.
4. Keep qualitative results (e.g. reactive/non-reactive, positive/negative, parasite detected/not detected) as text/coded values, not numeric, unless the actual assay produces a validated quantitative measurement.
5. Confirm units and local analyzer/kit method before entering numeric intervals. If a valid range cannot be sourced, leave the interval absent and do not label the result normal.
6. After approval, import/update the catalogue through the supported application/admin workflow or a reviewed migration. Never edit production catalogue rows directly as part of this review without a recorded change and rollback plan.
7. Test the selected range with synthetic patients around the lower/upper boundary, outside the range, with missing demographics, and with qualitative results in the isolated PostgreSQL 17/browser test environment.

## Current catalogue snapshot and required review

All approval fields below are intentionally unfilled.

| Test | Parameter | Code | Current type | Current unit | Approved type | Approved unit | Approved interval / expected values | Age/sex applicability | Critical limits & escalation SOP | Source / method | Reviewer / date |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ALT | ALT | ALT | numeric | U/L | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| AST | AST | AST | numeric | U/L | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Blood Glucose | Result | RBS | text | — | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Blood Glucose | Glucose | GLU | numeric | mg/dL | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Blood Urea | Urea | UREA | numeric | mg/dL | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Complete Blood Count | Hemoglobin | HB | numeric | g/dL | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Complete Blood Count | White Blood Cells | WBC | numeric | 10^9/L | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Complete Blood Count | Red Blood Cells | RBC | numeric | 10^12/L | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Complete Blood Count | Platelets | PLT | numeric | 10^9/L | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Complete Blood Count | MCV | MCV | numeric | fL | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Complete Blood Count | MCH | MCH | numeric | pg | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Complete Blood Count | MCHC | MCHC | numeric | g/dL | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Malaria Parasite | Malaria Parasite Result | MP_RESULT | numeric | — | **REVIEW TYPE** | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Pregnancy Test | Result | PT | text | — | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Pregnancy Test | Pregnancy Test Result | UPT_RESULT | numeric | — | **REVIEW TYPE** | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Serum Creatinine | Creatinine | CREAT | numeric | mg/dL | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Urinalysis | Result | UA | text | — | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |
| Urinalysis | Result | URINE | text | — | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW | TO REVIEW |

## Sign-off checklist

- [ ] Every active numeric parameter has a clinician-approved unit.
- [ ] Reference intervals are recorded with appropriate age/sex/method applicability and source provenance, or explicitly documented as not applicable.
- [ ] Qualitative result types for `MP_RESULT` and `UPT_RESULT` are reviewed and corrected if the assay is qualitative.
- [ ] Critical thresholds and notification/escalation steps are approved separately from normal reference intervals.
- [ ] Boundary, missing-demographic, qualitative, and abnormal-result tests pass in an isolated environment.
- [ ] A named clinician/laboratory lead has signed off the completed register and catalogue update.

**No clinical ranges or thresholds are prescribed by this template.**
