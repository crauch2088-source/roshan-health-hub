-- Targeted SECURITY DEFINER search_path hardening (2026-11-22, QA-applied only)
-- Pins 17 exact-signature SECURITY DEFINER functions with zero unqualified extension
-- dependencies to empty search_path = ''. Preserves owners, ACLs, and function bodies.
-- Intentionally excludes public.create_staff_user(text,text,text,text), which calls
-- unqualified pgcrypto functions crypt() and gen_salt().
BEGIN;

ALTER FUNCTION public.audit_row_change() SET search_path = '';
ALTER FUNCTION public.bootstrap_super_admin(text, text, text) SET search_path = '';
ALTER FUNCTION public.bootstrap_super_admin(uuid, text, text) SET search_path = '';
ALTER FUNCTION public.current_role_name() SET search_path = '';
ALTER FUNCTION public.fn_cashbox_immutable() SET search_path = '';
ALTER FUNCTION public.fn_finance_audit() SET search_path = '';
ALTER FUNCTION public.fn_ledger_from_expense() SET search_path = '';
ALTER FUNCTION public.fn_ledger_from_payment() SET search_path = '';
ALTER FUNCTION public.fn_ledger_from_supplier_payment() SET search_path = '';
ALTER FUNCTION public.fn_ledger_post(text, numeric, text, text, text, text, uuid, timestamp with time zone, uuid) SET search_path = '';
ALTER FUNCTION public.fn_recompute_invoice_paid() SET search_path = '';
ALTER FUNCTION public.fn_recompute_supplier_bill() SET search_path = '';
ALTER FUNCTION public.get_current_user_profile() SET search_path = '';
ALTER FUNCTION public.record_cashbox_expense() SET search_path = '';
ALTER FUNCTION public.record_cashbox_payment() SET search_path = '';
ALTER FUNCTION public.record_cashbox_supplier_payment() SET search_path = '';
ALTER FUNCTION public.sync_supplier_bill_payment() SET search_path = '';

COMMIT;
