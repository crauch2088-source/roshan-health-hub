-- Remove duplicate finance-specific audit triggers where the generic row audit
-- trigger already records the same event and payload.
--
-- Keep trg_audit_* / audit_row_change(): it is the canonical audit path for
-- these tables and is covered by the integration regression. Keep
-- fn_finance_audit() itself because insurance tables may still use it.
-- Proposed migration only; validate in a disposable database before rollout.
BEGIN;

DROP TRIGGER IF EXISTS trg_finance_audit ON public.payments;
DROP TRIGGER IF EXISTS trg_finance_audit ON public.expenses;
DROP TRIGGER IF EXISTS trg_finance_audit ON public.supplier_payments;
DROP TRIGGER IF EXISTS trg_finance_audit ON public.cashbox_transactions;

COMMIT;
