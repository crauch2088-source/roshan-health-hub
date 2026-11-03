# Roshan medicine catalogue — read-only candidate audit

**Audit date:** 2026-11-03  
**Environment:** Production Supabase `jewzonxplxhogqrnhosl`  
**Scope:** Read-only catalogue identity fields only. No patient, clinical, stock-quantity, price, invoice, payment, or other financial rows were read. No Production writes were performed.

## Findings

- Active, non-deleted medicine rows: **9**.
- QA `public.medicines` rows: **0**.
- All nine Production rows have NULL `brand_name`, `strength`, and `dosage_form`.
- The `unit` column appears to describe inventory units/packaging. It is not a verified administration route and must not be used as a substitute for normalized dosage form.
- Display-name strength fragments are not accepted as normalized strength data until checked against the physical pack.

## Candidate rows

| Stored display name | Stored generic name | Inventory unit | Normalized strength | Normalized dosage form | Brand |
|---|---|---|---|---|---|
| Amoxicillin 500mg | Amoxicillin | Capsule | Missing | Missing | Missing |
| Coartem 20/120 | Artemether / Lumefantrine | Tablet | Missing | Missing | Missing |
| Cefpodoxim | Cefpodoxim | Inj | Missing | Missing | Missing |
| Ceftriaxone 1g Injection | Ceftriaxone | Vial | Missing | Missing | Missing |
| Ciprofloxacin 500mg | Ciprofloxacin | Tablet | Missing | Missing | Missing |
| Ibuprofen 400mg | Ibuprofen | Tablet | Missing | Missing | Missing |
| Metronidazole 500mg | Metronidazole | Tablet | Missing | Missing | Missing |
| Omeprazole 20mg | Omeprazole | Capsule | Missing | Missing | Missing |
| Paracetamol 500mg | Paracetamol | Tablet | Missing | Missing | Missing |

## High-priority identity discrepancy

The `Cefpodoxim` row has no brand, strength, or dosage form, and its inventory unit is `Inj`. If this is intended to represent cefpodoxime proxetil, the DailyMed tablet and oral-suspension labels specify oral use only:

- [DailyMed cefpodoxime proxetil tablet label (updated 2026-10-22)](https://www.dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ce5646cb-a450-4c2c-8499-6ecf71b12b0e)
- [DailyMed cefpodoxime proxetil oral-suspension label](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=63777889-d306-4fc3-88da-b24859040ef4)

This does **not** establish that the local row is cefpodoxime proxetil. The row must be excluded from route auto-fill and regimen recommendations until the physical package, active ingredient, manufacturer, strength, and formulation are verified. Correct the product identity only after that check.

## Required normalization before QA import

For each candidate product, verify and record:

1. Exact generic/active ingredient(s) and salt/ester.
2. Brand and manufacturer, if present on the pack.
3. Strength per tablet/capsule/vial or concentration per mL after reconstitution.
4. Exact dosage form and release characteristics.
5. Label-authorized route(s) for that exact product.
6. Package/dispensing unit separately from dosage form.
7. Product-label source, version/retrieval date, reviewer, and verification status.

Until these checks are complete, every candidate remains **unverified**. Do not seed dose, frequency, indication, route, contraindication, interaction, or protocol content from these rows. This audit is a candidate inventory list, not a clinical formulary or prescribing authorization.


## Inventory maintenance and permissions

The current `src/routes/_authenticated/inventory.tsx` create form inserts into `public.medicines` using only `name`, `unit`, cost/selling prices, zero initial stock and reorder level. It does not separately collect `generic_name`, `brand_name`, `strength`, or `dosage_form`. The database requires non-null `generic_name`; the `normalize_medicine_names` trigger falls back to `name` (then `brand_name`) when it is missing. This preserves the constraint but does not guarantee that the stored generic name is a clean active-ingredient identity.

RLS on `medicines` requires `pharmacy.read`, `pharmacy.create`, `pharmacy.update`, and `pharmacy.delete` for the corresponding operations. The reviewed inventory page exposes creation but no direct medicine update call was found in the current code search. A product-identity editor and explicit verification status are therefore part of the required catalogue foundation; do not treat the trigger fallback as verification.

The separate legacy `medicines_2` table contains zero QA rows, has a legacy integer ID/name/price/stock shape, and only an `admin.full` policy. It is not the current prescribing catalogue and must not be used as a substitute.
