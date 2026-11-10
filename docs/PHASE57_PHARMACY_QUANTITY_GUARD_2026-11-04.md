# Phase 57 — Pharmacy quantity must be explicit

**Status:** applied to isolated QA as migration `20261104065852`; disposable PostgreSQL 17 and read-only catalog verification passed; Production not modified and remains gated by encrypted backup plus isolated restore.

## Finding

The live `public.prescription_items.quantity` column is nullable and has no positive-whole-number constraint. The atomic pharmacy dispensing function previously used `COALESCE(pi.quantity, 1)` in its invoice-line, aggregate-stock, and FEFO-consumption paths. A legacy prescription row with a missing quantity could therefore be interpreted as a one-unit dispensing instruction. The pharmacy queue also displayed missing quantity as `1` in the print branch.

The function already rejects non-finite, non-positive, fractional, and excessively large quantities, but the `COALESCE` happened before that validation and hid NULL.

## Change

`db/roshan_phase57_pharmacy_quantity_required_guard.sql` replaces only `public.fn_dispense_prescription_with_invoice(uuid, boolean)`. It rejects any active, non-deleted, catalogue-linked prescription item whose quantity is NULL, before invoice construction or stock mutation, then uses the explicit quantity in all three downstream paths. Existing permission checks, branch isolation, FEFO selection, aggregate-stock validation, invoice atomicity, and function ACLs are preserved.

No data is backfilled. No default is added. No table constraint is added. Existing NULL-quantity prescriptions remain pending until a clinician reviews and corrects them; the system must not guess a quantity.

## Regression coverage

The synthetic SQL integration test sets one test prescription item's quantity to NULL, expects the exact `prescription quantity is required` error, and verifies that batch stock, aggregate stock, invoice lines, and prescription status remain unchanged. It restores the fixture quantity before later scenarios. The integration privilege assertions are aligned with the live contract: the idempotent wrapper is authenticated-only, and the legacy non-idempotent `fn_dispense_prescription(uuid)` remains revoked.

## Rollout boundary

1. Run the repository's `test:guard`, typecheck, lint, and build checks.
2. Apply the migration to isolated QA only after CI is green.
3. Verify the function definition and execute the synthetic integration script on QA.
4. Do not apply to Production until the encrypted backup and isolated restore gate is independently verified.

No patient records or production data were read or changed for this finding; only schema metadata and function definitions were inspected.


## QA application and verification — 2026-11-04

- Applied to isolated QA only as migration version `20261104065852` (`roshan_phase57_pharmacy_quantity_required_guard`) on PostgreSQL 17.11. The exact SQL blob was `9db6768999352c32081f69b5e665c3cc95452616`.
- Post-apply read-only catalog checks passed: function exists; SECURITY DEFINER; fixed empty `search_path`; explicit NULL-quantity guard present; the `COALESCE(pi.quantity, 1)` fallback absent; `anon` EXECUTE denied; `authenticated` EXECUTE retained; the idempotent wrapper remains authenticated-only.
- PR #191 code head `809ca724b9ec991a31c5a860edd820267e9d427e` passed CI run `41756609987` with 17 successful jobs, zero failures and one intentional skip. Its disposable PostgreSQL 17 pharmacy dispense/invoice integration passed the synthetic NULL-quantity rejection and no-side-effect assertions.
- No synthetic pharmacist transaction was run against persistent QA because there is no approved synthetic pharmacist identity/Auth Admin path. The CI integration used its disposable PostgreSQL 17 fixture instead. No patient, prescription, invoice, payment or stock business rows were created or changed in QA.
- Production remains unchanged. The encrypted backup and isolated restore gate remains open. PR #191 remains Draft pending the QA-authenticated pharmacist scenario and independent review.

## Main reconciliation and exact-head validation — 2026-11-05

- Reconciled PR #191 with current main in merge commit `1a5bd04c99aa0395118181d36133147cb1c4ab96` (feature parent `be8abd4965227c8622a7fb5dbbe3740c0b87629a`; main parent `0b1785b69dd0d2cbc523757db79a886780495d25`). The branch is 7 ahead / 0 behind and GitHub reports it mergeable. The current-main pinned Actions checkout and least-privilege workflow settings were preserved.
- The pharmacy PostgreSQL 17 job now applies the Phase 49 atomic dispensing function, Phase 17 legacy RPC revocation, and Phase 57 NULL-quantity guard before running integration scripts. Exact-head CI `41980421806` passed 18 jobs with zero failures and one intentional skip; the pharmacy integration job passed. CodeQL `41980417962` passed both supported language analyses. Supporting workflows `41980421804`, `41980421935`, `41980422003`, and `41980421979` passed.
- Live read-only recheck: QA has Phase 57 migration `20261104065852` and the guard; Production does not. No Production migration, grant change, Auth/Storage write, patient row, prescription, invoice, payment or stock movement was created or modified.
- Keep PR #191 Draft. No persistent QA pharmacist scenario was run because the approved synthetic pharmacist identity/Auth Admin path is unavailable. Clinical authenticated E2E remains deferred at the owner's request; staff UAT is separate. Production rollout remains blocked by the encrypted off-site backup and isolated restore rehearsal.

Next: independent review of PR #191, then an approved synthetic pharmacist identity and bounded QA-only acceptance scenario. Do not apply Phase 57 to Production before the backup/restore gate passes.


## Pharmacy queue fail-closed display — 2026-11-09

- The queue no longer substitutes `1` for a missing prescription quantity. A pure parser accepts only finite positive whole units within the dispensing integer limit.
- Missing/invalid quantities display as missing in both mobile and desktop layouts; line and prescription totals are withheld rather than estimated from an invented unit count.
- The dispense action is disabled while any active item has an invalid quantity, with an Arabic/English warning directing the pharmacist to return the prescription to the prescriber for correction.
- The SQL RPC repeats the NULL check after its `FOR UPDATE` row read, so the authoritative locked item value is checked as well as the early preflight.
- The disposable fixture now matches live QA/Production metadata: `prescription_items.quantity` is nullable and has no default. The live read-only column audit confirmed that in both projects.
- Added unit/source assertions for NULL, blank, zero, negative, fractional, NaN/Infinity, over-limit and valid whole quantities. No hosted database change was made.


- The queue also displays the saved medication name for free-text items, explains that they must be linked to an active catalogue medicine, and disables dispense when any active item is unlinked. Soft-deleted child items are excluded from queue totals and blockers.


## Live schema/function recheck — 2026-11-09

Read-only catalog verification confirms:
- QA has migration `20261104065852`, the quantity column remains nullable with no default, and the deployed dispense function contains the original preflight NULL guard.
- Production does not have Phase 57; its dispense function has no Phase 57 NULL guard. The quantity column is nullable with no default in both environments.
- The new pharmacy queue display/blocking behavior is source-only. No hosted SQL, data, Auth, grants, or deployment changes were made in this follow-up.


## Historical source integrity and Phase 57B follow-up — 2026-11-10

- Read-only retrieval of QA ledger row `20261104065852` confirmed one stored SQL statement, 10,954 bytes, MD5 `921970d4d86b32dccd430a0ea0ef8745`. The original Phase 57 source was restored from code-bearing commit `809ca724b9ec991a31c5a860edd820267e9d427e` (Git blob `9db6768999352c32081f69b5e665c3cc95452616`) and is byte-identical to the QA-applied body.
- The later free-text and external-prescription guards were not part of the QA-applied Phase 57 body. They are now separated into `db/roshan_phase57b_free_text_external_prescription_guard.sql`, a forward-only replacement that retains the explicit NULL/whole-unit guard and rejects unlinked free-text items and externally sourced prescriptions before invoice, stock, movement, item, or status mutation.
- Disposable PostgreSQL 17 CI applies Phase 57 and then Phase 57B before the integration assertions. The Phase 57B migration is **not applied** to QA or Production.
- Read-only live function checks: QA has the explicit NULL-quantity guard but not the free-text/external guards; Production has neither the Phase 57 NULL guard nor the Phase 57B guards and still contains the legacy `COALESCE(pi.quantity,1)` fallback. The `prescriptions.is_external` column exists in both environments.
- No hosted migration, business-row write, stock movement, or Production action was performed. Production remains gated by verified encrypted backup, isolated restore, and explicit release approval.
