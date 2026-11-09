# Contract: Persisted Receipt Currency

## Receipt Read Model

A receipt data response MUST include:

- `payment_id`
- `invoice_id`
- `amount`
- `currency_code`
- `payment_method`
- `received_at`
- `received_by`
- `invoice_number`
- `patient identity`
- `branch_id`
- `ledger integrity/reversal status`

The `currency_code` MUST be sourced from the persisted financial record, not from the current clinic settings.

## Write Contract

### Invoice creation

- The authorized invoice RPC obtains the effective clinic currency from the authoritative configuration inside the transaction.
- It persists the currency with the invoice.
- Invoice line items inherit the invoice currency; no client-supplied currency override is accepted.

### Payment posting

- `post_invoice_payment` locks the invoice and reads its persisted currency.
- The new payment stores the exact invoice currency.
- The generated cashbox ledger row stores the same currency.
- A mismatch, missing currency, or invalid code aborts the entire transaction.
- Idempotent retry returns the original payment and does not recalculate currency from mutable settings.

### Reversal

- The reversal RPC reads the original payment/ledger currency and writes the reversal with the same code.
- Reversal amount sign and audit reason remain governed by the existing reversal contract.

## Print Contract

- The receipt model consumes saved `currency_code`.
- The current settings currency MUST NOT be a fallback for a posted record.
- Missing/invalid/mismatched currency adds a missing-field reason and blocks official printing.
- Reprinting after a settings change preserves the original currency code.
- The receipt displays ISO code and an approved localized label; no FX conversion is performed.

## Authorization and Integrity

- Read operations remain protected by existing permission and branch checks.
- Financial writes remain in approved SECURITY DEFINER RPCs with fixed empty `search_path`, explicit permission/actor/branch checks, and exact decimal validation.
- Browser roles receive no direct INSERT/UPDATE/DELETE grants on financial tables.
- Tests must prove cross-branch rejection, idempotency, ledger atomicity, reversal consistency, and no partial writes.
