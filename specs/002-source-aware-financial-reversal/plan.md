# Implementation Plan: Source-aware financial reversal

## Design

Keep all state transitions inside SECURITY DEFINER RPCs with an empty `search_path`. The client never directly updates payment or cashbox ledger rows.

1. `reverse_invoice_payment(uuid,text)` is the only supported reversal path for invoice-payment rows.
2. `reverse_cashbox_entry(uuid,text)` remains the generic correction path for non-payment entries and rejects source-linked payment types.
3. `get_invoice_payment_receipt_status(uuid[])` provides a narrowly scoped read model for receipt printing without granting `cashbox.read`.
4. Existing payment triggers recompute invoice totals; no new balance-maintenance logic or schema columns are introduced.
5. Historical Phase54 and Phase54B migration files remain immutable. Phase54C is the forward-only final guard/read-model migration.

## Migration order

1. Phase54 — initial source-aware reversal RPC.
2. Phase54B — compatibility correction for the actual `payments` schema (`updated_by` exists; `updated_at` does not).
3. Phase54C — branch-binding hardening and receipt-status read model.

The PostgreSQL 17 CI workflow replays all three in order against synthetic fixtures.

## Validation

- PostgreSQL 17 integration assertions cover source guards, duplicate reversal, branch isolation, branchless rejection, receipt consistency and RPC grants.
- QA migration ledger records Phase54, Phase54B and Phase54C.
- QA catalog confirms SECURITY DEFINER, empty search path, authenticated EXECUTE and no anon EXECUTE.
- Production remains unchanged pending encrypted backup and isolated restore evidence.
