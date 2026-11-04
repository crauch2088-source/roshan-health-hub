# Phase 57 — Pharmacy quantity must be explicit

**Status:** candidate migration and regression coverage prepared; QA replay required; Production not modified.

## Finding

The live `public.prescription_items.quantity` column is nullable and has no positive-whole-number constraint. The atomic pharmacy dispensing function previously used `COALESCE(pi.quantity, 1)` in its invoice-line, aggregate-stock, and FEFO-consumption paths. A legacy prescription row with a missing quantity could therefore be interpreted as a one-unit dispensing instruction. The pharmacy queue also displayed missing quantity as `1` in the print branch.

The function already rejects non-finite, non-positive, fractional, and excessively large quantities, but the `COALESCE` happened before that validation and hid NULL.

## Change

`db/roshan_phase57_pharmacy_quantity_required_guard.sql` replaces only `public.fn_dispense_prescription_with_invoice(uuid, boolean)`. It rejects any active, non-deleted, catalogue-linked prescription item whose quantity is NULL, before invoice construction or stock mutation, then uses the explicit quantity in all three downstream paths. Existing permission checks, branch isolation, FEFO selection, aggregate-stock validation, invoice atomicity, and function ACLs are preserved.

No data is backfilled. No default is added. No table constraint is added. Existing NULL-quantity prescriptions remain pending until a clinician reviews and corrects them; the system must not guess a quantity.

## Regression coverage

The PostgreSQL 17 CI job now replays Phase49, Phase17, and Phase57 in sequence against the synthetic fixture (including an active-user field required by the current branch-safe function). The synthetic SQL integration test sets one test prescription item's quantity to NULL, expects the exact `prescription quantity is required` error, and verifies that batch stock, aggregate stock, invoice lines, and prescription status remain unchanged. It restores the fixture quantity before later scenarios. The integration privilege assertions are aligned with the live contract: the idempotent wrapper is authenticated-only, and the legacy non-idempotent `fn_dispense_prescription(uuid)` remains revoked.

## Rollout boundary

1. Run the repository's `test:guard`, typecheck, lint, and build checks.
2. Apply the migration to isolated QA only after CI is green.
3. Verify the function definition and execute the synthetic integration script on QA.
4. Do not apply to Production until the encrypted backup and isolated restore gate is independently verified.

No patient records or production data were read or changed for this finding; only schema metadata and function definitions were inspected.
