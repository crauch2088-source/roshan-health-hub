# Data Model: Pharmacist-to-Prescriber Correction Workflow

## prescription_correction_requests

Proposed fields; exact SQL types and FK delete behavior must be checked against the canonical baseline before implementation.

- `id`: immutable request UUID.
- `request_key`: client idempotency UUID, unique.
- `prescription_id`, `prescription_item_id`, `patient_id`, `visit_id`, `branch_id`, `prescriber_id`, `requested_by`: immutable server-derived links.
- `item_snapshot`: immutable JSONB captured from the locked database row; includes item id, medicine_id, medication_name, quantity, dose/dosage, frequency, duration, instructions, dosage_form and route.
- `reason_code`, `reason_text`: immutable pharmacist-provided explanation.
- `status`: open / resolved / rejected / cancelled_stale; RPC-only.
- `resolved_by`, `resolved_at`, `disposition`, `replacement_prescription_id`, `created_at`, `updated_at`.

Constraints:
- Unique request key.
- Partial unique index: one open request per prescription item.
- CHECK constraints for status/disposition.
- Foreign keys preserve audit history; prefer RESTRICT/soft-delete semantics over cascading deletion.

## prescription_correction_events

Append-only event log:
- id, request_id, event_type, actor_id, occurred_at;
- before_snapshot, after_snapshot JSONB;
- reason, disposition, replacement_prescription_id where applicable.
- No application-role UPDATE/DELETE/TRUNCATE; trigger rejects mutation even if a grant is accidentally added.
- RLS read scope matches the request's authorized pharmacy branch and original prescriber.

## Lifecycle

- `open → resolved`, `open → rejected`, or `open → cancelled_stale`. Never reopen or overwrite a terminal request.
- `replace_item`: update only the target item's explicit catalogue identity and server-derived name/price; preserve regimen; retain before/after snapshots; parent prescription remains pending.
- `cancel_and_reissue`: create a complete replacement order and cancel the original in one transaction; link replacement id in request/event.
- `reject`: require a reason; do not mutate prescription or item.

## Security and side-effect invariants

Request linkage and item snapshot are derived from locked database rows. Requester requires pharmacy.update and branch access. Reader requires pharmacy.read + branch access or emr.read + original prescriber identity + branch access. Resolver/rejector requires emr.update and original prescriber identity. Super-admin status is not a clinical authorship substitute.

Request, reject and replace actions must leave medicines, pharmacy_inventory, stock_movements, invoices, invoice_items, payments, cashbox_transactions and ledger state unchanged.
