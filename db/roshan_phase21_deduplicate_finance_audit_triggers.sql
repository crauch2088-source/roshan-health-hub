-- Remove duplicate generic audit triggers from finance tables.
-- These tables already use trg_finance_audit -> fn_finance_audit(), which writes
-- the same row-change payload to audit_logs. Keeping both trigger families doubles
-- audit records for a single operation. Generic audit triggers on non-finance tables
-- are intentionally untouched.
BEGIN;

DROP TRIGGER IF EXISTS trg_audit_payments ON public.payments;
DROP TRIGGER IF EXISTS trg_audit_expenses ON public.expenses;
DROP TRIGGER IF EXISTS trg_audit_supplier_payments ON public.supplier_payments;
DROP TRIGGER IF EXISTS trg_audit_cashbox_transactions ON public.cashbox_transactions;

COMMIT;
