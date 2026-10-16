-- Proposed follow-up migration. Keep unapplied until the recovered migration history
-- is reconciled and the behavior is verified on a disposable PostgreSQL/Supabase DB.
--
-- Phase 1's generic audit trigger and Phase 4's finance-specific audit trigger both
-- insert equivalent audit_logs payloads on these five tables. Keep trg_finance_audit:
-- it is the canonical finance audit path and resolves the application user through
-- current_app_user_id(), including RPC writes. Remove only the duplicate generic
-- audit trigger from these finance tables; retain generic audit on clinical tables.

DROP TRIGGER IF EXISTS trg_audit_cashbox_transactions ON public.cashbox_transactions;
DROP TRIGGER IF EXISTS trg_audit_expenses ON public.expenses;
DROP TRIGGER IF EXISTS trg_audit_payments ON public.payments;
DROP TRIGGER IF EXISTS trg_audit_supplier_bills ON public.supplier_bills;
DROP TRIGGER IF EXISTS trg_audit_supplier_payments ON public.supplier_payments;
