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

## Owner Decision — Recorded

The owner has explicitly decided that Roshan is a **permanent SDG-only clinic system**. There is no anticipated reason to change the clinic currency. Do not build a currency selector, multi-currency transactions, FX rates, currency conversion, or cross-currency reports. Enforce `SDG` at authorized database write boundaries and persist it on financial source and ledger rows. The mutable `system_settings.currency` value is display/configuration metadata only and must never determine the currency of an already-posted receipt. Any future policy reversal requires a separate owner-authorized accounting and migration project.

## Supabase Security and Source Guidance

- Preserve the existing SECURITY DEFINER RPC pattern only where its internal permission, actor, branch, and input checks are verified.
- Keep a fixed empty `search_path` and schema-qualify objects in SECURITY DEFINER functions.
- Do not grant browser roles direct financial table DML.
- Do not apply migrations through the Supabase MCP for this feature. Candidate migration source and disposable PG17 validation must precede any owner-approved rollout.

## Remaining Design Questions

1. Complete the inventory of every monetary table, catalogue price, write RPC, trigger, report and export so the SDG-only invariant covers all financial surfaces.
2. Determine evidence-backed treatment of any legacy soft-deleted monetary records with missing provenance before enabling historical reprints.
3. Confirm the localized display presentation of SDG (ISO code plus approved Arabic/English label); the stored canonical code remains `SDG`.



1. Complete the inventory of every monetary table, catalogue price, write RPC, trigger, report and export so the SDG-only invariant covers all financial surfaces.
2. Determine evidence-backed treatment of any legacy soft-deleted monetary records with missing provenance before enabling historical reprints.
3. Confirm the localized display presentation of SDG (ISO code plus approved Arabic/English label); the stored canonical code remains `SDG`.
