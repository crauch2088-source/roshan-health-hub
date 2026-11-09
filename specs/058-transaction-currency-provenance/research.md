# Research: Single-Currency SDG Provenance

**Date**: 2026-11-09

## Owner decision

The owner has explicitly confirmed Roshan is permanently SDG-only. No currency change, multi-currency, FX, or cross-currency settlement is required or planned.

## Live schema evidence

Read-only information_schema inspection of Production and QA found no currency-code columns on invoices, payments, cashbox_transactions, expenses, supplier_bills, supplier_payments, or pharmacy_inventory. The included seven-table schema matched across the two projects. No business row values were read.

Insurance tables are deferred per the owner's earlier instruction. Employee salary is deferred until payroll exists. Catalogue prices remain under the global SDG invariant; invoice line items inherit their parent invoice currency.

## Financial function source comparison

Read-only pg_get_functiondef fingerprints match across Production and QA for both create_billing_invoice_atomic overloads, create_invoice_atomic, post_invoice_payment, fn_ledger_from_expense, fn_ledger_from_payment, fn_ledger_from_supplier_payment, fn_ledger_post, post_cashbox_entry, post_expense, post_supplier_bill, and post_supplier_payment.

Differences remain for fn_dispense_prescription_with_invoice and reverse_cashbox_entry. reverse_invoice_payment exists in QA only. No function bodies were changed. Replacing these environment-specific SECURITY DEFINER functions before migration/function provenance reconciliation would be unsafe.

## Candidate implementation

The candidate schema migration relies on database defaults for new inserts, preserving existing RPC signatures. It leaves legacy rows NULL, uses a private trigger to reject explicit NULL/non-SDG new rows, and prevents changing a populated currency code. No historical backfill is included.
