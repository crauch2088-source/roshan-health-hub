-- Roshan security hardening: replace broad authenticated CRUD policies with permission-aware RLS.
-- No patient/application data is modified.

-- Remove anonymous Data API table privileges from public schema. Roshan requires authenticated staff access.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  LOOP
    EXECUTE format('REVOKE ALL ON TABLE %I.%I FROM anon', r.table_schema, r.table_name);
  END LOOP;
END $$;

-- TRUNCATE is not controlled by RLS; remove it from the browser roles.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  LOOP
    EXECUTE format('REVOKE TRUNCATE ON TABLE %I.%I FROM anon, authenticated', r.table_schema, r.table_name);
  END LOOP;
END $$;

-- Helper: replace an existing broad ALL policy with permission-aware CRUD policies.
-- Existing application-specific policies (appointments, patients, visits, queue, audit_logs) are intentionally preserved.

-- Attachments
DROP POLICY IF EXISTS optimized_auth_policy_attachments ON public.attachments;
CREATE POLICY attachments_select ON public.attachments FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('attachments.read')));
CREATE POLICY attachments_insert ON public.attachments FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('attachments.create')));
CREATE POLICY attachments_update ON public.attachments FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('attachments.update'))) WITH CHECK ((SELECT public.app_has_perm('attachments.update')));
CREATE POLICY attachments_delete ON public.attachments FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('attachments.delete')));

-- Administrative/configuration tables
DROP POLICY IF EXISTS optimized_auth_policy_branches ON public.branches;
CREATE POLICY branches_select ON public.branches FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY branches_insert ON public.branches FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY branches_update ON public.branches FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('admin.full'))) WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY branches_delete ON public.branches FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('admin.full')));

DROP POLICY IF EXISTS optimized_auth_policy_departments ON public.departments;
CREATE POLICY departments_select ON public.departments FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY departments_insert ON public.departments FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY departments_update ON public.departments FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('admin.full'))) WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY departments_delete ON public.departments FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('admin.full')));

DROP POLICY IF EXISTS optimized_auth_policy_roles ON public.roles;
CREATE POLICY roles_select ON public.roles FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY roles_insert ON public.roles FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY roles_update ON public.roles FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('admin.full'))) WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY roles_delete ON public.roles FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('admin.full')));

DROP POLICY IF EXISTS optimized_auth_policy_permissions ON public.permissions;
CREATE POLICY permissions_select ON public.permissions FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY permissions_insert ON public.permissions FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY permissions_update ON public.permissions FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('admin.full'))) WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY permissions_delete ON public.permissions FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('admin.full')));

DROP POLICY IF EXISTS optimized_auth_policy_role_permissions ON public.role_permissions;
CREATE POLICY role_permissions_select ON public.role_permissions FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY role_permissions_insert ON public.role_permissions FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY role_permissions_update ON public.role_permissions FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('admin.full'))) WITH CHECK ((SELECT public.app_has_perm('admin.full')));
CREATE POLICY role_permissions_delete ON public.role_permissions FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('admin.full')));

DROP POLICY IF EXISTS optimized_auth_policy_users ON public.users;
CREATE POLICY users_select ON public.users FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('users.read')));
CREATE POLICY users_insert ON public.users FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('users.create')));
CREATE POLICY users_update ON public.users FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('users.update'))) WITH CHECK ((SELECT public.app_has_perm('users.update')));
CREATE POLICY users_delete ON public.users FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('users.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_employees ON public.employees;
CREATE POLICY employees_select ON public.employees FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('users.read')));
CREATE POLICY employees_insert ON public.employees FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('users.create')));
CREATE POLICY employees_update ON public.employees FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('users.update'))) WITH CHECK ((SELECT public.app_has_perm('users.update')));
CREATE POLICY employees_delete ON public.employees FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('users.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_system_settings ON public.system_settings;
CREATE POLICY system_settings_select ON public.system_settings FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('settings.read')));
CREATE POLICY system_settings_insert ON public.system_settings FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('settings.create')));
CREATE POLICY system_settings_update ON public.system_settings FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('settings.update'))) WITH CHECK ((SELECT public.app_has_perm('settings.update')));
CREATE POLICY system_settings_delete ON public.system_settings FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('settings.delete')));

-- Clinical / EMR
DROP POLICY IF EXISTS optimized_auth_policy_clinical_notes ON public.clinical_notes;
CREATE POLICY clinical_notes_select ON public.clinical_notes FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('emr.read')));
CREATE POLICY clinical_notes_insert ON public.clinical_notes FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('emr.create')));
CREATE POLICY clinical_notes_update ON public.clinical_notes FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('emr.update'))) WITH CHECK ((SELECT public.app_has_perm('emr.update')));
CREATE POLICY clinical_notes_delete ON public.clinical_notes FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('emr.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_diagnoses ON public.diagnoses;
CREATE POLICY diagnoses_select ON public.diagnoses FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('emr.read')));
CREATE POLICY diagnoses_insert ON public.diagnoses FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('emr.create')));
CREATE POLICY diagnoses_update ON public.diagnoses FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('emr.update'))) WITH CHECK ((SELECT public.app_has_perm('emr.update')));
CREATE POLICY diagnoses_delete ON public.diagnoses FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('emr.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_followups ON public.followups;
CREATE POLICY followups_select ON public.followups FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('followups.read')));
CREATE POLICY followups_insert ON public.followups FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('followups.create')));
CREATE POLICY followups_update ON public.followups FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('followups.update'))) WITH CHECK ((SELECT public.app_has_perm('followups.update')));
CREATE POLICY followups_delete ON public.followups FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('followups.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_vitals ON public.vitals;
CREATE POLICY vitals_select ON public.vitals FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('emr.read')));
CREATE POLICY vitals_insert ON public.vitals FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('emr.create')));
CREATE POLICY vitals_update ON public.vitals FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('emr.update'))) WITH CHECK ((SELECT public.app_has_perm('emr.update')));
CREATE POLICY vitals_delete ON public.vitals FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('emr.delete')));

-- Laboratory
DROP POLICY IF EXISTS optimized_auth_policy_lab_tests ON public.lab_tests;
CREATE POLICY lab_tests_select ON public.lab_tests FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_tests_insert ON public.lab_tests FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('lab_admin.create')));
CREATE POLICY lab_tests_update ON public.lab_tests FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('lab_admin.update'))) WITH CHECK ((SELECT public.app_has_perm('lab_admin.update')));
CREATE POLICY lab_tests_delete ON public.lab_tests FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('lab_admin.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_lab_parameters ON public.lab_parameters;
CREATE POLICY lab_parameters_select ON public.lab_parameters FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_parameters_insert ON public.lab_parameters FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('lab_admin.create')));
CREATE POLICY lab_parameters_update ON public.lab_parameters FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('lab_admin.update'))) WITH CHECK ((SELECT public.app_has_perm('lab_admin.update')));
CREATE POLICY lab_parameters_delete ON public.lab_parameters FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('lab_admin.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_lab_reference_ranges ON public.lab_reference_ranges;
CREATE POLICY lab_reference_ranges_select ON public.lab_reference_ranges FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_reference_ranges_insert ON public.lab_reference_ranges FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('lab_admin.create')));
CREATE POLICY lab_reference_ranges_update ON public.lab_reference_ranges FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('lab_admin.update'))) WITH CHECK ((SELECT public.app_has_perm('lab_admin.update')));
CREATE POLICY lab_reference_ranges_delete ON public.lab_reference_ranges FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('lab_admin.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_lab_orders ON public.lab_orders;
CREATE POLICY lab_orders_select ON public.lab_orders FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_orders_insert ON public.lab_orders FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('lab.create')));
CREATE POLICY lab_orders_update ON public.lab_orders FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('lab.update'))) WITH CHECK ((SELECT public.app_has_perm('lab.update')));
CREATE POLICY lab_orders_delete ON public.lab_orders FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('lab.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_lab_order_items ON public.lab_order_items;
CREATE POLICY lab_order_items_select ON public.lab_order_items FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_order_items_insert ON public.lab_order_items FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('lab.create')));
CREATE POLICY lab_order_items_update ON public.lab_order_items FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('lab.update'))) WITH CHECK ((SELECT public.app_has_perm('lab.update')));
CREATE POLICY lab_order_items_delete ON public.lab_order_items FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('lab.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_lab_results ON public.lab_results;
CREATE POLICY lab_results_select ON public.lab_results FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_results_insert ON public.lab_results FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('lab.create')));
CREATE POLICY lab_results_update ON public.lab_results FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('lab.update'))) WITH CHECK ((SELECT public.app_has_perm('lab.update')));
CREATE POLICY lab_results_delete ON public.lab_results FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('lab.delete')));

-- Pharmacy
DROP POLICY IF EXISTS optimized_auth_policy_medicines ON public.medicines;
CREATE POLICY medicines_select ON public.medicines FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('pharmacy.read')));
CREATE POLICY medicines_insert ON public.medicines FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')));
CREATE POLICY medicines_update ON public.medicines FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.update'))) WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')));
CREATE POLICY medicines_delete ON public.medicines FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_pharmacy_inventory ON public.pharmacy_inventory;
CREATE POLICY pharmacy_inventory_select ON public.pharmacy_inventory FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('pharmacy.read')));
CREATE POLICY pharmacy_inventory_insert ON public.pharmacy_inventory FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')));
CREATE POLICY pharmacy_inventory_update ON public.pharmacy_inventory FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.update'))) WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')));
CREATE POLICY pharmacy_inventory_delete ON public.pharmacy_inventory FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_prescriptions ON public.prescriptions;
CREATE POLICY prescriptions_select ON public.prescriptions FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')));
CREATE POLICY prescriptions_insert ON public.prescriptions FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')));
CREATE POLICY prescriptions_update ON public.prescriptions FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update'))) WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')));
CREATE POLICY prescriptions_delete ON public.prescriptions FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_prescription_items ON public.prescription_items;
CREATE POLICY prescription_items_select ON public.prescription_items FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')));
CREATE POLICY prescription_items_insert ON public.prescription_items FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')));
CREATE POLICY prescription_items_update ON public.prescription_items FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update'))) WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')));
CREATE POLICY prescription_items_delete ON public.prescription_items FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_suppliers ON public.suppliers;
CREATE POLICY suppliers_select ON public.suppliers FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('pharmacy.read')));
CREATE POLICY suppliers_insert ON public.suppliers FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')));
CREATE POLICY suppliers_update ON public.suppliers FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.update'))) WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')));
CREATE POLICY suppliers_delete ON public.suppliers FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.delete')));

-- Procedures
DROP POLICY IF EXISTS optimized_auth_policy_procedures_catalog ON public.procedures_catalog;
CREATE POLICY procedures_catalog_select ON public.procedures_catalog FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('procedures.read')));
CREATE POLICY procedures_catalog_insert ON public.procedures_catalog FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('procedures.create')));
CREATE POLICY procedures_catalog_update ON public.procedures_catalog FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('procedures.update'))) WITH CHECK ((SELECT public.app_has_perm('procedures.update')));
CREATE POLICY procedures_catalog_delete ON public.procedures_catalog FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('procedures.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_procedure_orders ON public.procedure_orders;
CREATE POLICY procedure_orders_select ON public.procedure_orders FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('procedures.read')));
CREATE POLICY procedure_orders_insert ON public.procedure_orders FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('procedures.create')));
CREATE POLICY procedure_orders_update ON public.procedure_orders FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('procedures.update'))) WITH CHECK ((SELECT public.app_has_perm('procedures.update')));
CREATE POLICY procedure_orders_delete ON public.procedure_orders FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('procedures.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_procedure_results ON public.procedure_results;
CREATE POLICY procedure_results_select ON public.procedure_results FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('procedures.read')));
CREATE POLICY procedure_results_insert ON public.procedure_results FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('procedures.create')));
CREATE POLICY procedure_results_update ON public.procedure_results FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('procedures.update'))) WITH CHECK ((SELECT public.app_has_perm('procedures.update')));
CREATE POLICY procedure_results_delete ON public.procedure_results FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('procedures.delete')));

-- Billing / accounting / commercial
DROP POLICY IF EXISTS optimized_auth_policy_invoices ON public.invoices;
CREATE POLICY invoices_select ON public.invoices FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('billing.view')));
CREATE POLICY invoices_insert ON public.invoices FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY invoices_update ON public.invoices FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit'))) WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY invoices_delete ON public.invoices FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('billing.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_invoice_items ON public.invoice_items;
CREATE POLICY invoice_items_select ON public.invoice_items FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('billing.view')));
CREATE POLICY invoice_items_insert ON public.invoice_items FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY invoice_items_update ON public.invoice_items FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit'))) WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY invoice_items_delete ON public.invoice_items FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('billing.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_payments ON public.payments;
CREATE POLICY payments_select ON public.payments FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('payments.read')));
CREATE POLICY payments_insert ON public.payments FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('payments.create')));
CREATE POLICY payments_update ON public.payments FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('payments.update'))) WITH CHECK ((SELECT public.app_has_perm('payments.update')));
CREATE POLICY payments_delete ON public.payments FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('payments.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_expenses ON public.expenses;
CREATE POLICY expenses_select ON public.expenses FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('accounting.read')));
CREATE POLICY expenses_insert ON public.expenses FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('accounting.create')));
CREATE POLICY expenses_update ON public.expenses FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('accounting.update'))) WITH CHECK ((SELECT public.app_has_perm('accounting.update')));
CREATE POLICY expenses_delete ON public.expenses FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('accounting.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_partners ON public.partners;
CREATE POLICY partners_select ON public.partners FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('partners.read')));
CREATE POLICY partners_insert ON public.partners FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('partners.create')));
CREATE POLICY partners_update ON public.partners FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('partners.update'))) WITH CHECK ((SELECT public.app_has_perm('partners.update')));
CREATE POLICY partners_delete ON public.partners FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('partners.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_patient_discounts ON public.patient_discounts;
CREATE POLICY patient_discounts_select ON public.patient_discounts FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('patients.read')));
CREATE POLICY patient_discounts_insert ON public.patient_discounts FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY patient_discounts_update ON public.patient_discounts FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit'))) WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY patient_discounts_delete ON public.patient_discounts FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('billing.delete')));

DROP POLICY IF EXISTS optimized_auth_policy_corporate_accounts ON public.corporate_accounts;
CREATE POLICY corporate_accounts_select ON public.corporate_accounts FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('billing.view')));
CREATE POLICY corporate_accounts_insert ON public.corporate_accounts FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY corporate_accounts_update ON public.corporate_accounts FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit'))) WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY corporate_accounts_delete ON public.corporate_accounts FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('billing.delete')));

-- Certificates
DROP POLICY IF EXISTS optimized_auth_policy_certificates ON public.certificates;
CREATE POLICY certificates_select ON public.certificates FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('certificates.read')));
CREATE POLICY certificates_insert ON public.certificates FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('certificates.create')));
CREATE POLICY certificates_update ON public.certificates FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('certificates.update'))) WITH CHECK ((SELECT public.app_has_perm('certificates.update')));
CREATE POLICY certificates_delete ON public.certificates FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('certificates.delete')));

-- Legacy duplicate tables are still protected by RLS; do not expose their rows to ordinary authenticated users.
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON public.medicines_2;
CREATE POLICY medicines_2_admin_only ON public.medicines_2 FOR ALL TO authenticated USING ((SELECT public.app_has_perm('admin.full'))) WITH CHECK ((SELECT public.app_has_perm('admin.full')));

DROP POLICY IF EXISTS authenticated_select_medical_certificates ON public.medical_certificates;
DROP POLICY IF EXISTS authenticated_insert_medical_certificates ON public.medical_certificates;
DROP POLICY IF EXISTS authenticated_update_medical_certificates ON public.medical_certificates;
DROP POLICY IF EXISTS authenticated_delete_medical_certificates ON public.medical_certificates;
CREATE POLICY medical_certificates_select ON public.medical_certificates FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('certificates.read')));
CREATE POLICY medical_certificates_insert ON public.medical_certificates FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('certificates.create')));
CREATE POLICY medical_certificates_update ON public.medical_certificates FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('certificates.update'))) WITH CHECK ((SELECT public.app_has_perm('certificates.update')));
CREATE POLICY medical_certificates_delete ON public.medical_certificates FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('certificates.delete')));

-- Profiles: user may manage only their own profile row.
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON public.profiles;
CREATE POLICY profiles_select_own ON public.profiles FOR SELECT TO authenticated USING ((SELECT auth.uid()) = id);
CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = id) WITH CHECK ((SELECT auth.uid()) = id);

-- Revoke browser-side destructive access to audit logs; existing SELECT policy remains authoritative.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.audit_logs FROM authenticated, anon;

-- Force RLS on the application tables so table owners cannot accidentally bypass it through ordinary ownership-based access.
-- service_role/postgres remain administrative paths by design.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
  LOOP
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', r.table_name);
  END LOOP;
END $$;
