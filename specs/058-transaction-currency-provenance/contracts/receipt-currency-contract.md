# Contract: Persisted SDG Currency

## Product invariant

Roshan supports SDG only. There is no configurable currency switch, multi-currency, FX, or cross-currency settlement.

## Database write contract

- New invoices, payments, cashbox transactions, expenses, supplier bills/payments, and pharmacy inventory batches default to currency_code='SDG'.
- Explicit NULL and any non-SDG code are rejected on new records.
- A populated currency code is immutable and cannot be cleared.
- Existing legacy NULL values remain NULL until a separately reviewed, evidence-backed reconciliation assigns SDG.
- The application must never infer historical currency from system_settings.currency.

## Receipt contract

- Receipt currency must come from persisted payment/invoice/ledger provenance.
- Payment, invoice, and cashbox ledger currency must agree.
- Missing or contradictory currency blocks official printing.
- Reprinting remains SDG regardless of display settings because the saved record is authoritative.
- No FX conversion or localized numeric conversion is performed.

## Authorization and safety

- Existing atomic RPC and trigger write paths remain the only financial write boundary.
- No direct browser DML grants are introduced.
- Existing branch, actor, audit, idempotency, and exact decimal guards remain unchanged.
- Phase54C Production/QA function differences must be reconciled before any function replacement.
- No hosted migration is applied by this candidate.
