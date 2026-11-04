# Phase 56A — pharmacist-authorized medicine identity correction

**Status:** source candidate in PR #189; no schema migration or database write.

## Verified database boundary

Read-only catalog-only queries were run against Production (`jewzonxplxhogqrnhosl`) and isolated QA (`hopfohcnrtbiqjkgeukz`) on 2026-11-04. Both returned the same relevant structure:

- `public.medicines` has no `branch_id`; it is a shared catalogue record, so identity edits affect every branch.
- RLS is enabled and forced.
- Authenticated UPDATE is guarded by the existing `medicines_update` policy, whose USING and WITH CHECK both call `app_has_perm('pharmacy.update')`.
- `trg_audit_medicines` writes row changes through `audit_row_change()`.
- `trg_guard_medicine_stock_aggregate` remains installed and rejects browser-role changes to `stock_quantity`.
- `normalize_medicine_names()` fills `generic_name` only when the supplied value is blank; the edit builder requires a non-empty generic ingredient.

No patient, prescription, invoice, payment, stock, or other business rows were queried.

## Edit contract

The UI exposes editing only when the current app permission set includes `pharmacy.update`. The server-side RLS policy remains authoritative if the client is stale or manipulated.

The pure builder returns exactly these columns:

1. `name` (display name; generated from brand or generic + strength + dosage form when blank)
2. `generic_name`
3. `brand_name` (nullable)
4. `strength`
5. `dosage_form`

It never includes `unit`, cost/selling price, reorder level, stock quantity, expiry, batch number, barcode, active flags or branch identifiers. Packaging unit is intentionally immutable in this dialog because existing batch quantities are already expressed using the stored unit.

Before saving, the pharmacist must confirm that the product name, strength and dosage form were compared with the physical pack. The dialog also warns that the record is shared across branches.

**Important audit limitation:** the checkbox is a per-save acknowledgement only. The existing audit trigger records the changed row's old/new values and authenticated actor; it does not persist the checkbox, source, pack image, reviewer attestation or a dedicated verification date. The UI therefore does not label the product “verified”.

## Validation and release boundary

- Pure helper RED/GREEN TDD was exercised locally before repository integration (2 failing tests before implementation; 2 passing after).
- Repository regression tests are added to the existing `test:guard` suite.
- Exact-head GitHub Actions remains pending for the combined PR #189 candidate.
- No DDL, DML, permission changes, seed data, deployment promotion or production data access occurred.
- Authenticated pharmacist browser acceptance remains deferred until an approved synthetic QA identity/Auth Admin path is available. Do not modify `auth.users` directly or create a new credential endpoint.
- Keep PR #189 Draft until exact-head CI, independent review and the deferred authorized acceptance gate are separately evidenced.
