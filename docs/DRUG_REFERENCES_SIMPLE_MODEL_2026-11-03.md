# Roshan Drug References — Simple Operating Model

**Status:** design decision for the medicine-catalogue work; not clinical approval or a data-import authorization.

## The simple rule

Roshan keeps three things separate:

1. **Medicine product** — what is physically sold/stocked: generic ingredient, brand, strength, dosage form, manufacturer and pack.
2. **Medicine information** — what clinicians need to know: indications, precautions, adverse effects, interactions and administration.
3. **Treatment protocol** — what to do for a particular condition and patient group.

A product match must never generate a patient's dose, route, frequency or duration.

## Which sources do what?

| Need | Preferred source | How Roshan uses it |
|---|---|---|
| Sudan brand/product discovery | NMPB and NMSF; Sudan Drug Index (Wasila) as a human cross-check | Verify against current official records and the physical pack before marking a product verified |
| Essential-medicine status | Latest officially confirmed Sudan EML; WHO Model EML/EMLc as a secondary comparison | Show list and edition; do not assume WHO listing means Sudan registration or local availability |
| Drug monographs and interactions | Licensed/authorized reference where available; Medscape as a clinician-opened external reference | Link out; do not copy or scrape protected content |
| Condition-specific treatment | Current applicable Sudan guidance first; otherwise the relevant WHO or specialty/national guideline | Show publisher, jurisdiction, population and publication/update date |

Useful public starting points:
- NMPB: https://www.nmpb.gov.sd/
- NMSF medicines/prices: https://www.nmsf.gov.sd/prices/medicines
- Sudan Drug Index (Wasila): https://play.google.com/store/apps/details?id=com.wasila.sudandrugindex
- WHO Model Lists: https://www.who.int/groups/expert-committee-on-selection-and-use-of-essential-medicines/essential-medicines-lists
- Medscape: https://reference.medscape.com/

The latest Sudan EML located during this review was the 2019 edition. Confirm with the responsible Sudan authority before treating it as current. RxNorm and DailyMed can help with terminology and label cross-checking, but their US scope does not establish Sudan registration.

## Minimum information to retain

For each imported or curated reference, keep only: **source, title/version, country or jurisdiction, population, publication/update date, date checked, link, reviewer and review status**.

For each Sudan product, retain the physical product identity and its verification source/date. Keep dosage form, administration route and stock/pack unit as separate fields.

## Safe first release

1. Finish the structured product catalogue already being added.
2. Let authorized pharmacy staff review product identity against the pack and trusted Sudan sources.
3. Add a small read-only reference panel with external links and visible source dates.
4. Add treatment protocols only as separately reviewed content, starting with common primary-care conditions.
5. Consider interaction alerts or decision support later, only with validated data, test cases and clinician oversight.

## Explicit boundaries

- No scraping or bulk copying from Wasila or Medscape without written permission/licensing.
- No paid data service without the owner's approval.
- No automatic prescribing, patient-specific dose generation or protocol auto-approval.
- No product becomes “verified” solely because it appears in an app, search result or imported file.
- Conflicting recommendations must remain visible with their sources; do not silently combine them.
- This document does not authorize database seeding, migrations or production writes.

**Design objective:** make the safe path the easy path. Keep the first release small: verified product identity, clear references and clinician control.
