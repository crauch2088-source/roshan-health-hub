-- Roshan production hardening: security-definer exposure, mutable search paths,
-- duplicate/multiple RLS policies, and missing FK indexes.

-- 1) Lock down SECURITY DEFINER functions from anonymous API callers.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.prosecdef = true
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM anon', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

-- 2) Pin search_path on application trigger/security functions flagged by Advisor.
ALTER FUNCTION public.enforce_public_system_setting_keys() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_medicines_2_stock_columns() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_pharmacy_inventory_legacy_columns() SET search_path = public, pg_temp;
ALTER FUNCTION public.users(follow_ups public.follow_ups) SET search_path = public, pg_temp;

-- 3) Consolidate overlapping permissive policies while preserving the existing
-- authorization semantics (logical OR of the two old permission checks).
DROP POLICY IF EXISTS cashbox_ins ON public.cashbox_transactions;
DROP POLICY IF EXISTS cashbox_transactions_fin_ins ON public.cashbox_transactions;
CREATE POLICY cashbox_ins ON public.cashbox_transactions
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT app_has_perm('accounting.create')) OR (SELECT app_has_perm('cashbox.create')));

DROP POLICY IF EXISTS cashbox_sel ON public.cashbox_transactions;
DROP POLICY IF EXISTS cashbox_transactions_fin_sel ON public.cashbox_transactions;
CREATE POLICY cashbox_sel ON public.cashbox_transactions
  FOR SELECT TO authenticated
  USING ((SELECT app_has_perm('accounting.read')) OR (SELECT app_has_perm('cashbox.read')));

DROP POLICY IF EXISTS supplier_bills_fin_ins ON public.supplier_bills;
DROP POLICY IF EXISTS supplier_bills_ins ON public.supplier_bills;
CREATE POLICY supplier_bills_ins ON public.supplier_bills
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT app_has_perm('debts.create')) OR (SELECT app_has_perm('accounting.create')));

DROP POLICY IF EXISTS supplier_bills_fin_sel ON public.supplier_bills;
DROP POLICY IF EXISTS supplier_bills_sel ON public.supplier_bills;
CREATE POLICY supplier_bills_sel ON public.supplier_bills
  FOR SELECT TO authenticated
  USING ((SELECT app_has_perm('debts.read')) OR (SELECT app_has_perm('accounting.read')));

DROP POLICY IF EXISTS supplier_bills_fin_upd ON public.supplier_bills;
DROP POLICY IF EXISTS supplier_bills_upd ON public.supplier_bills;
CREATE POLICY supplier_bills_upd ON public.supplier_bills
  FOR UPDATE TO authenticated
  USING ((SELECT app_has_perm('debts.update')) OR (SELECT app_has_perm('accounting.update')))
  WITH CHECK ((SELECT app_has_perm('debts.update')) OR (SELECT app_has_perm('accounting.update')));

DROP POLICY IF EXISTS supplier_payments_fin_ins ON public.supplier_payments;
DROP POLICY IF EXISTS supplier_payments_ins ON public.supplier_payments;
CREATE POLICY supplier_payments_ins ON public.supplier_payments
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT app_has_perm('debts.create')) OR (SELECT app_has_perm('accounting.create')));

DROP POLICY IF EXISTS supplier_payments_fin_sel ON public.supplier_payments;
DROP POLICY IF EXISTS supplier_payments_sel ON public.supplier_payments;
CREATE POLICY supplier_payments_sel ON public.supplier_payments
  FOR SELECT TO authenticated
  USING ((SELECT app_has_perm('debts.read')) OR (SELECT app_has_perm('accounting.read')));

DROP POLICY IF EXISTS suppliers_fin_ins ON public.suppliers;
DROP POLICY IF EXISTS suppliers_insert ON public.suppliers;
CREATE POLICY suppliers_insert ON public.suppliers
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT app_has_perm('suppliers.create')) OR (SELECT app_has_perm('pharmacy.create')));

DROP POLICY IF EXISTS suppliers_fin_sel ON public.suppliers;
DROP POLICY IF EXISTS suppliers_select ON public.suppliers;
CREATE POLICY suppliers_select ON public.suppliers
  FOR SELECT TO authenticated
  USING ((SELECT app_has_perm('suppliers.read')) OR (SELECT app_has_perm('pharmacy.read')));

DROP POLICY IF EXISTS suppliers_fin_upd ON public.suppliers;
DROP POLICY IF EXISTS suppliers_update ON public.suppliers;
CREATE POLICY suppliers_update ON public.suppliers
  FOR UPDATE TO authenticated
  USING ((SELECT app_has_perm('suppliers.update')) OR (SELECT app_has_perm('pharmacy.update')))
  WITH CHECK ((SELECT app_has_perm('suppliers.update')) OR (SELECT app_has_perm('pharmacy.update')));

-- 4) Add indexes for all 22 currently unindexed foreign keys reported by Advisor.
CREATE INDEX IF NOT EXISTS idx_cashbox_transactions_created_by ON public.cashbox_transactions(created_by);
CREATE INDEX IF NOT EXISTS idx_cashbox_transactions_deleted_by ON public.cashbox_transactions(deleted_by);
CREATE INDEX IF NOT EXISTS idx_followups_created_by ON public.followups(created_by);
CREATE INDEX IF NOT EXISTS idx_followups_updated_by ON public.followups(updated_by);
CREATE INDEX IF NOT EXISTS idx_insurance_claim_items_coverage_rule_id ON public.insurance_claim_items(coverage_rule_id);
CREATE INDEX IF NOT EXISTS idx_insurance_claims_invoice_id ON public.insurance_claims(invoice_id);
CREATE INDEX IF NOT EXISTS idx_insurance_prior_authorizations_patient_insurance_id ON public.insurance_prior_authorizations(patient_insurance_id);
CREATE INDEX IF NOT EXISTS idx_invoices_partner_id ON public.invoices(partner_id);
CREATE INDEX IF NOT EXISTS idx_medical_certificates_doctor_id ON public.medical_certificates(doctor_id);
CREATE INDEX IF NOT EXISTS idx_medical_certificates_patient_id ON public.medical_certificates(patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_insurance_company_id ON public.patient_insurance(company_id);
CREATE INDEX IF NOT EXISTS idx_patient_insurance_plan_id ON public.patient_insurance(plan_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_branch_id ON public.stock_movements(branch_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_by ON public.stock_movements(created_by);
CREATE INDEX IF NOT EXISTS idx_supplier_bills_branch_id ON public.supplier_bills(branch_id);
CREATE INDEX IF NOT EXISTS idx_supplier_bills_created_by ON public.supplier_bills(created_by);
CREATE INDEX IF NOT EXISTS idx_supplier_bills_deleted_by ON public.supplier_bills(deleted_by);
CREATE INDEX IF NOT EXISTS idx_supplier_bills_updated_by ON public.supplier_bills(updated_by);
CREATE INDEX IF NOT EXISTS idx_supplier_payments_branch_id ON public.supplier_payments(branch_id);
CREATE INDEX IF NOT EXISTS idx_supplier_payments_created_by ON public.supplier_payments(created_by);
CREATE INDEX IF NOT EXISTS idx_supplier_payments_deleted_by ON public.supplier_payments(deleted_by);
CREATE INDEX IF NOT EXISTS idx_supplier_payments_supplier_id ON public.supplier_payments(supplier_id);

-- 5) Remove the exact duplicate stock-movement index; retain the created-date composite.
DROP INDEX IF EXISTS public.idx_stock_movements_medicine;
