# Data Model: Prescription Item Correction

## prescription_item_correction_requests

One row tracks the current state of a correction request. The original clinical item is never deleted as part of request creation or rejection.

| Field | Type | Rule |
|---|---|---|
| id | uuid | Primary key |
| prescription_id | uuid | Required FK to prescriptions; restrict delete |
| prescription_item_id | uuid | Required FK to prescription_items; restrict delete |
| patient_id | uuid | Required FK to patients; restrict delete |
| visit_id | uuid | Required FK to visits; restrict delete |
| branch_id | uuid | Required, copied from the active visit |
| item_snapshot | jsonb | Required immutable original item snapshot |
| reason | text | Required, trimmed, 10–1000 characters |
| requested_by | uuid | Required application-user FK |
| requested_at | timestamptz | Server-generated |
| status | text | pending / resolved / rejected |
| resolved_by | uuid | Nullable application-user FK |
| resolved_at | timestamptz | Server-generated |
| disposition | text | replace_item / reject / cancel_and_reissue |
| resolution_note | text | Required for reject; optional for other actions |
| corrected_item_id | uuid | Item changed by replace_item |
| replacement_prescription_id | uuid | New prescription created by cancel_and_reissue |

Constraints:
- One pending request per prescription item (partial unique index).
- The RPC validates that item and parent relationships match; client-supplied IDs are never trusted without server joins.
- Request snapshot, request actor/time, and initial reason are immutable after creation. State changes occur only through the resolver RPC.

## prescription_item_correction_events

Append-only audit stream.

| Field | Type | Rule |
|---|---|---|
| id | uuid | Primary key |
| request_id | uuid | Required FK to request; restrict delete |
| event_type | text | requested / item_replaced / rejected / cancelled_and_reissued |
| actor_id | uuid | Required application-user FK |
| occurred_at | timestamptz | Server-generated |
| payload | jsonb | Before/after snapshots, resolution reason, corrected item/order references |

The event table is immutable to application roles and protected by UPDATE/DELETE/TRUNCATE rejection triggers. The request and event rows are readable only by same-branch pharmacists with `pharmacy.correction.request`, the responsible doctor with `prescriptions.correction.resolve`, and Super Admin through the existing bypass.

## State Machine

```text
pending ── replace_item ──────────────> resolved
pending ── reject ────────────────────> rejected
pending ── cancel_and_reissue ────────> resolved
```

A rejected request does not unblock dispensing. The prescription remains pending with its original unlinked item. A new request may be opened after rejection.

## No-Side-Effect Invariants

Request and rejection operations do not update:
- prescriptions or prescription_items
- medicines or pharmacy_inventory
- stock_movements
- invoices or invoice_items
- payments or cashbox_transactions

`replace_item` may update only the selected prescription item and request/event state. `cancel_and_reissue` may update the original prescription status and create a new prescription and its items, but must not create stock, invoice, payment, cashbox or dispense state.
