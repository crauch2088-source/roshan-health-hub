-- SECURITY DEFINER functions are executable by PUBLIC by default unless explicitly revoked.
-- Restrict the public API surface to authenticated application RPCs only.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind='f' AND p.prosecdef=true
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC, anon, authenticated', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

-- Only application-facing RPCs retain authenticated EXECUTE. Each of these
-- already performs its own permission/identity checks where appropriate.
GRANT EXECUTE ON FUNCTION public.add_cashbox_entry(text,numeric,text,text,text,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_insurance_claim(uuid,uuid,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_calculate_insurance_coverage(uuid,text,uuid,text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_dispense_prescription(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_receive_pharmacy_batch(uuid,numeric,text,date,date,numeric,numeric,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_mrn() TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_cashbox_entry(text,numeric,text,text,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_expense(text,numeric,text,date,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_insurance_claim_payment(uuid,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_invoice_payment(uuid,numeric,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_supplier_bill(uuid,text,date,date,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_supplier_payment(uuid,numeric,text,text,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_insurance_claim_status(uuid,text,numeric,text) TO authenticated;
