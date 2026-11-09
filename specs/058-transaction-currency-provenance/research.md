# Research: Transaction Currency Provenance

**Date**: 2026-11-09

## Existing Application Behavior

- PR #181 adds `src/lib/print/receipt.ts` with `buildInvoicePaymentReceiptModel(payment, invoice, ledger, cashierNameValue, currencyValue)`.
- The model trims and validates the externally supplied `currencyValue`, but the value is supplied from mutable `system_settings.currency`; it is not read from the posted payment or invoice.
- A settings change after posting can therefore change the currency label on a historical reprint without changing the numeric amount.
- The current PR is Draft and has not been accepted for Production.

## Live Schema Evidence

Read-only catalog queries against Production and QA on 2026-11-09 found:

- `public.invoices`, `public.payments`, and `public.cashbox_transactions` have no currency-code column.
- Production `system_settings.currency` is `SDG`; QA has no `currency` setting row.
- Both projects currently have zero total rows in invoices, payments, and cashbox_transactions.
- No business row values were selected; the counts and setting metadata only were read.

## Existing Financial Write Boundary

- Invoice payments are posted through `public.post_invoice_payment`, a SECURITY DEFINER RPC with fixed empty `search_path`, application permission checks, branch checks, invoice row locking, overpayment validation, exact two-decimal input validation, and idempotency handling.
- Payment insertion triggers the corresponding cashbox ledger entry and invoice balance/status recalculation.
- Phase54C provides `get_invoice_payment_receipt_status(uuid[])` in QA only. It checks payment/ledger linkage, branch consistency, amount match, and reversal metadata; it does not supply a transaction currency.
- Production does not yet have Phase54C. This feature does not authorize promoting Phase54C or any other migration to Production.
- Direct browser writes to finance tables are intended to remain denied; all currency provenance must be written inside existing authorized RPC/trigger boundaries.

## Owner Decision

The owner has not yet selected single-currency or multi-currency behavior. The recommended low-complexity initial operating model is a single immutable clinic currency (currently configured as SDG in Production), with the code persisted on every relevant monetary source/ledger row. Currency changes after monetary activity should be blocked unless a separately approved migration/reconciliation workflow is performed.

If multi-currency is chosen, each monetary record and report must carry/group by currency; FX rates and converted totals require a separate feature specification.

## Supabase Security and Source Guidance

- Preserve the existing SECURITY DEFINER RPC pattern only where its internal permission, actor, branch, and input checks are verified.
- Keep a fixed empty `search_path` and schema-qualify objects in SECURITY DEFINER functions.
- Do not grant browser roles direct financial table DML.
- Do not apply migrations through the Supabase MCP for this feature. Candidate migration source and disposable PG17 validation must precede any owner-approved rollout.

## Open Questions

1. Owner policy: single immutable clinic currency or multi-currency?
2. Which monetary tables and price catalogues must be included in the setting-change lock or currency provenance model? Current inventory includes invoices, invoice items, payments, cashbox transactions, expenses, insurance claims/payments, supplier bills/payments, lab/procedure/service prices, and pharmacy inventory prices.
3. How should legacy soft-deleted records be treated if historical reprint is later enabled for them?
4. Does the owner require a displayed currency symbol, an ISO code, or both on official receipts? The safe default is ISO code plus localized display name.
