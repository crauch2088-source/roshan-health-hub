# Prescription safety and print reconciliation — 2026-11-15

**Status:** Draft candidate in PR #255  
**Current main base:** `fe8d770f1bd666d00b1bf1b3385f21e109e50872`  
**Latest code-bearing candidate commit:** `86134c0df686830db194fa7f29686a90f89f11ca`

## 1. Why PR #179 was not merged wholesale

PR #179 had diverged substantially from current main and contained older pharmacy/prescription code that predates the current Phase 61 pharmacist-role and correction-workflow boundaries. The safe prescription-composer, age-validation and print-isolation changes were selectively ported to a fresh current-main branch. The current pharmacy route and role gates were retained; old PR #179 pharmacy code was not overlaid.

PR #255 is the replacement candidate for the selectively ported functionality. PR #179 should be closed as superseded only after the PR #255 candidate remains green and the owner has reviewed the replacement.

## 2. Clinical input safety changes

- New prescription drafts start with a blank quantity; no implicit one-unit order is created.
- Selecting a medicine may populate its catalogue dosage form, but it does **not** infer route from dosage form.
- Dose, frequency, duration, dosage form, route and positive whole quantity must be explicitly present before an item can be added/saved.
- Custom text fields are available for dosage form, frequency, duration and route. Dose remains an explicit free-text field including its unit.
- The route selector warns that its generic choices are not checked against the selected product; the prescriber must verify the actual product label.
- Duration shortcuts are data-entry conveniences, not treatment recommendations.
- Quantity parsing rejects scientific notation, fractions, zero, negative values and values outside the RPC integer range.
- Date-only DOB parsing validates the actual calendar date and rejects malformed/future dates. If age cannot be verified, the composer warns the clinician to verify DOB and age-specific precautions.
- Pediatric missing-weight handling remains a warning, not a universal save block. The UI asks the clinician to verify a current visit-linked weight before weight-based dosing. No automated dose calculation, dose/frequency recommendation, route inference or pediatric protocol was added.
- A blanket pediatric hard block is intentionally deferred until the catalogue has a clinically validated medication-specific weight-based classification and an audited exception policy. This avoids blocking non-weight-based medicines or inventing a universal rule.

## 3. Server-side Phase 63 guard

The candidate migration `db/roshan_phase63_prescription_item_completeness_guard.sql` adds a private trigger to `public.prescription_items` before inserts and updates to clinical instruction fields. It requires:
- medication name;
- dose (accepting the legacy `dosage` twin and normalizing the blank twin);
- frequency;
- duration;
- dosage form;
- administration route; and
- a positive whole quantity no greater than the RPC integer limit.

It skips soft-deleted rows so historical incomplete records can be preserved or archived. It does not calculate or infer clinical values. Because the trigger runs at the table boundary, it also protects writes performed by the SECURITY DEFINER prescription RPC, not only the React form. Direct EXECUTE on the trigger function is revoked from API roles.

A dedicated PostgreSQL 17 fixture and regression test cover valid writes, missing fields, invalid quantities, legacy dose/dosage normalization, soft-deleted rows, and trigger-function ACL.

## 4. Printing changes

- Saved prescription printing builds from one persisted prescription and its saved items, not an unsaved composer draft.
- Official prescription print is blocked when required saved identity/clinical fields are missing, the prescription or patient branch is missing/mismatched against the visit branch, or the persisted status is not exactly `pending` or `dispensed`.
- Invoice printing is target-scoped and blocked for soft-deleted invoice/patient records or a known invoice/patient branch mismatch.
- Certificate printing is target-scoped and blocked for soft-deleted patients or a known certificate/visit/patient branch mismatch.
- Printed documents are copies, not digital signatures or proof of dispensing.

## 5. Exact-head verification

Candidate code head `86134c0df686830db194fa7f29686a90f89f11ca`:
- 8/8 PR-triggered workflows succeeded;
- 345/345 main unit/guard tests passed;
- TypeScript, lint, production build and blocking dependency audits passed;
- dedicated Phase 63 PostgreSQL 17 guard integration passed;
- prescription atomicity, privileged-role guard, clinical child-RPC, finance-only RPC, insurance integrity/UI workflows passed;
- a null patient-branch regression test was added after the source review found that nullable `patients.branch_id` could otherwise pass the print-model guard; and
- Vercel status passed.

The canonical PG17 baseline replay/authenticated clinical-acceptance job remained intentionally skipped by its workflow gate. No authenticated browser E2E, Android print preview, physical A4 printer test or staff acceptance is claimed.

## 6. Release boundary

- Phase 63 remains a source candidate in PR #255; it is not applied to hosted QA or Production.
- No production migration, merge, deployment promotion, patient/clinical/financial data write or stock mutation was performed.
- This is application/database completeness validation, not a clinical protocol approval.
- Any automated dosing engine requires a separate clinician-approved source and validation of age, weight, indication, formulation, route, strength, maximum dose, renal/allergy constraints and explicit prescriber override.
- Operational release still requires authenticated synthetic role/branch E2E, Arabic RTL/English LTR browser review, mobile print preview, physical A4 printer verification and clinic staff acceptance.
