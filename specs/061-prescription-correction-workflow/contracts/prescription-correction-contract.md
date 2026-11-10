# Contract: Prescription Item Correction

## Request RPC

`request_prescription_item_correction(p_prescription_item_id uuid, p_reason text) RETURNS uuid`

- Authenticated application user only.
- Requires `pharmacy.correction.request`.
- Resolves parent prescription, patient, visit and branch from the item; never trusts client-supplied parent IDs.
- Requires active, pending, internal, non-external prescription; active patient, visit and item; `medicine_id IS NULL`; known visit branch; consistent non-NULL parent branches.
- Captures exact item snapshot and server actor/time.
- At most one pending request per item. Retry returns the existing pending request ID without appending a second request event.
- Does not modify the prescription/item, stock, invoice, payment, cashbox or dispense state.

## Resolution RPC

`resolve_prescription_item_correction(p_request_id uuid, p_action text, p_replacement jsonb, p_reason text) RETURNS uuid`

Supported actions:
- `replace_item`: explicit active `medicine_id`, complete dose/frequency/duration/quantity/dosage_form/route. Server derives canonical medicine name and selling price. No fuzzy lookup.
- `reject`: required reason; request becomes rejected; prescription and item remain unchanged.
- `cancel_and_reissue`: complete new internal prescription item array; original pending prescription is cancelled and a new order is created atomically through the established prescription RPC contract.

## Resolver Authorization

- Requires `prescriptions.correction.resolve`.
- Actor must be the original prescriber, prescription doctor, or doctor assigned to the parent visit.
- Actor must be active and in the same branch as the visit.
- Unrelated same-branch doctors and all wrong-branch actors are denied.
- Super Admin follows only the established explicit bypass.

## Concurrency and Audit

- Lock order is prescription → item → request.
- Revalidate request pending status, prescription state, external flag, item active/unlinked state and captured snapshot under lock.
- Exactly one concurrent resolution may commit.
- Every transition appends an immutable event with actor, server timestamp, disposition and before/after references.
- Request/event tables are RLS-protected and browser roles have no direct write grants.

## No-Side-Effect Contract

Request, duplicate retry and rejection cannot mutate clinical order, inventory, stock movement or financial tables. Item replacement is limited to the selected item. Cancel-and-reissue may cancel the original prescription and create a replacement order, but cannot dispense or bill it.
