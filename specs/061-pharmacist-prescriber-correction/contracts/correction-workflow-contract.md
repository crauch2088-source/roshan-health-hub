# Contract: Prescription Correction Workflow

## Create request

`create_prescription_correction_request(p_prescription_id uuid, p_item_id uuid, p_reason_code text, p_reason_text text, p_request_key uuid)`

- Requires authenticated active caller with `pharmacy.update`.
- Derive caller, branch, prescription, patient, visit, prescriber and item snapshot server-side.
- Require pending internal prescription, active visit, consistent patient/visit/branch, and active unlinked item.
- Reject external, cancelled, dispensed, deleted, linked and wrong-branch records.
- Same request key/payload returns existing request; conflicting payload fails. One open request per item.

## Resolve request

`resolve_prescription_correction_request(p_request_id uuid, p_disposition text, p_medicine_id uuid, p_replacement_items jsonb)`

- Requires `emr.update`, original prescriber identity and matching branch.
- Lock and revalidate request, parent and item; compare current item to immutable snapshot.
- `replace_item`: require exact active catalogue medicine id; derive canonical name/price from database; preserve quantity, dose, frequency, duration, instructions, route and dosage form; append before/after event; keep prescription pending.
- `cancel_and_reissue`: require `emr.create` and a complete non-empty replacement item array; create replacement and cancel original atomically.
- Stale/invalid/concurrent state aborts without partial writes.

## Reject request

`reject_prescription_correction_request(p_request_id uuid, p_reason text)`

- Requires `emr.update` and original prescriber identity.
- Require open request and non-empty reason; append event; no clinical/inventory/financial mutation.

## Read scope

RLS enabled and forced. Pharmacist requires `pharmacy.read` + branch access. Prescriber requires `emr.read`, matching original prescriber id and branch access. No direct browser writes. Revoke function EXECUTE from PUBLIC/anon; grant only required authenticated callers.

## Side-effect assertion

PostgreSQL 17 tests snapshot and compare medicines, pharmacy_inventory, stock_movements, invoices, invoice_items, payments, cashbox_transactions and ledger state before/after request, reject and replace. Expected changes: zero.
