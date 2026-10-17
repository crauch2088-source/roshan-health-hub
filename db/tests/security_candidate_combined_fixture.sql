-- Combined candidate fixture: one schema, one role set, one shared helper graph.
-- Synthetic rows only. This fixture is not the production migration baseline.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  auth_user_id uuid NOT NULL,
  branch_id uuid,
  active boolean NOT NULL DEFAULT true,
  deleted_at timestamptz
);
CREATE TABLE public.patients (id uuid PRIMARY KEY, branch_id uuid);
CREATE TABLE public.visits (id uuid PRIMARY KEY, patient_id uuid, branch_id uuid);
CREATE TABLE public.invoices (
  id uuid PRIMARY KEY, branch_id uuid, net_amount numeric, total_amount numeric,
  paid_amount numeric DEFAULT 0, deleted_at timestamptz
);
CREATE TABLE public.invoice_items (id uuid PRIMARY KEY, invoice_id uuid NOT NULL, description text NOT NULL);
CREATE TABLE public.certificates (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, content text);
CREATE TABLE public.medical_certificates (id uuid PRIMARY KEY, patient_id uuid, diagnosis text);
CREATE TABLE public.patient_discounts (id uuid PRIMARY KEY, patient_id uuid, discount_percent numeric);
CREATE TABLE public.procedure_orders (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, status text);
CREATE TABLE public.procedure_results (id uuid PRIMARY KEY, procedure_order_id uuid, findings text);
CREATE TABLE public.followups (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, notes text);
CREATE TABLE public.queue_tickets (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, status text);
CREATE TABLE public.prescriptions (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, status text);
CREATE TABLE public.prescription_items (id uuid PRIMARY KEY, prescription_id uuid, medication_name text);
CREATE TABLE public.lab_orders (id uuid PRIMARY KEY, patient_id uuid, visit_id uuid, branch_id uuid);
CREATE TABLE public.lab_order_items (id uuid PRIMARY KEY, order_id uuid, status text);

CREATE TABLE public.suppliers (id uuid PRIMARY KEY, active boolean NOT NULL DEFAULT true, deleted_at timestamptz);
CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, transaction_type text, amount numeric,
  payment_method text, category text, description text, source_type text, transaction_date timestamptz, created_by uuid
);
CREATE TABLE public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, category text, amount numeric, description text,
  expense_date date, payment_method text, paid_to text, created_by uuid
);
CREATE TABLE public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invoice_id uuid, amount numeric, payment_method text, method text,
  reference_no text, reference text, idempotency_key text UNIQUE, payment_date date, received_at timestamptz,
  received_by uuid, created_by uuid, branch_id uuid
);
CREATE TABLE public.supplier_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, supplier_id uuid, invoice_number text,
  bill_date date, due_date date, subtotal numeric, discount_amount numeric, total_amount numeric, paid_amount numeric,
  status text, notes text, created_by uuid, deleted_at timestamptz, updated_at timestamptz, updated_by uuid
);
CREATE TABLE public.supplier_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, supplier_bill_id uuid, supplier_id uuid,
  amount numeric, payment_method text, reference text, payment_date date, notes text, created_by uuid, deleted_at timestamptz
);

CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid $function$;
CREATE FUNCTION public.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT position('|' || p_permission || '|' IN '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0
$function$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT COALESCE(NULLIF(current_setting('test.super_admin', true), '')::boolean, false) $function$;
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $function$;
CREATE FUNCTION private.is_super_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT public.is_super_admin() $function$;
CREATE FUNCTION private.app_has_perm(p_permission text) RETURNS boolean LANGUAGE sql STABLE
AS $function$ SELECT public.app_has_perm(p_permission) $function$;
CREATE FUNCTION private.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE
AS $function$ SELECT public.current_app_user_id() $function$;
CREATE FUNCTION private.app_has_branch_access(_branch_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false) OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid() AND COALESCE(u.active, true)
      AND u.deleted_at IS NULL AND u.branch_id = _branch_id
  )
$function$;
CREATE FUNCTION private.app_has_patient_branch(_patient_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false) OR EXISTS (
    SELECT 1 FROM public.patients p WHERE p.id = _patient_id AND private.app_has_branch_access(p.branch_id)
  )
$function$;
CREATE FUNCTION private.app_has_attachment_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN private.is_super_admin() THEN true
    WHEN _patient_id IS NULL AND _visit_id IS NULL THEN false
    ELSE
      (_patient_id IS NULL OR EXISTS (
        SELECT 1 FROM public.patients p WHERE p.id = _patient_id AND private.app_has_branch_access(p.branch_id)
      ))
      AND (_visit_id IS NULL OR EXISTS (
        SELECT 1 FROM public.visits v LEFT JOIN public.patients p ON p.id = v.patient_id
        WHERE v.id = _visit_id AND private.app_has_branch_access(COALESCE(v.branch_id, p.branch_id))
      ))
  END
$function$;
CREATE FUNCTION private.app_has_invoice_branch(_invoice_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.invoices i WHERE i.id = _invoice_id AND private.app_has_branch_access(i.branch_id)
  )
$function$;
GRANT EXECUTE ON FUNCTION private.app_has_branch_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_patient_branch(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_invoice_branch(uuid) TO authenticated;

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY invoices_select ON public.invoices FOR SELECT TO authenticated
  USING ((SELECT public.app_has_perm('billing.read')) AND (SELECT private.app_has_branch_access(invoices.branch_id)));
CREATE POLICY invoice_items_select ON public.invoice_items FOR SELECT TO authenticated
  USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('billing.view')));
CREATE POLICY invoice_items_insert ON public.invoice_items FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY invoice_items_update ON public.invoice_items FOR UPDATE TO authenticated
  USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')))
  WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY invoice_items_delete ON public.invoice_items FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('billing.delete')));

CREATE POLICY certificates_select ON public.certificates FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('certificates.read')));
CREATE POLICY certificates_insert ON public.certificates FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('certificates.create')));
CREATE POLICY certificates_update ON public.certificates FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('certificates.update'))) WITH CHECK ((SELECT public.app_has_perm('certificates.update')));
CREATE POLICY certificates_delete ON public.certificates FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('certificates.delete')));
CREATE POLICY medical_certificates_select ON public.medical_certificates FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('certificates.read')));
CREATE POLICY medical_certificates_insert ON public.medical_certificates FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('certificates.create')));
CREATE POLICY medical_certificates_update ON public.medical_certificates FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('certificates.update'))) WITH CHECK ((SELECT public.app_has_perm('certificates.update')));
CREATE POLICY medical_certificates_delete ON public.medical_certificates FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('certificates.delete')));
CREATE POLICY patient_discounts_select ON public.patient_discounts FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('patients.read')));
CREATE POLICY patient_discounts_insert ON public.patient_discounts FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY patient_discounts_update ON public.patient_discounts FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit'))) WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY patient_discounts_delete ON public.patient_discounts FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('billing.delete')));
CREATE POLICY procedure_orders_select ON public.procedure_orders FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('procedures.read')));
CREATE POLICY procedure_orders_insert ON public.procedure_orders FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('procedures.create')));
CREATE POLICY procedure_orders_update ON public.procedure_orders FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('procedures.update'))) WITH CHECK ((SELECT public.app_has_perm('procedures.update')));
CREATE POLICY procedure_orders_delete ON public.procedure_orders FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('procedures.delete')));
CREATE POLICY procedure_results_select ON public.procedure_results FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('procedures.read')));
CREATE POLICY procedure_results_insert ON public.procedure_results FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('procedures.create')));
CREATE POLICY procedure_results_update ON public.procedure_results FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('procedures.update'))) WITH CHECK ((SELECT public.app_has_perm('procedures.update')));
CREATE POLICY procedure_results_delete ON public.procedure_results FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('procedures.delete')));

CREATE POLICY followups_select ON public.followups FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('followups.read')));
CREATE POLICY followups_insert ON public.followups FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('followups.create')));
CREATE POLICY followups_update ON public.followups FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('followups.update'))) WITH CHECK ((SELECT public.app_has_perm('followups.update')));
CREATE POLICY followups_delete ON public.followups FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('followups.delete')));
CREATE POLICY queue_tickets_sel ON public.queue_tickets FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('queue.read')));
CREATE POLICY queue_tickets_ins ON public.queue_tickets FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('queue.create')));
CREATE POLICY queue_tickets_upd ON public.queue_tickets FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('queue.update'))) WITH CHECK ((SELECT public.app_has_perm('queue.update')));
CREATE POLICY queue_tickets_del ON public.queue_tickets FOR DELETE TO authenticated USING ((SELECT public.is_super_admin()));

CREATE POLICY prescriptions_select ON public.prescriptions FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')));
CREATE POLICY prescriptions_insert ON public.prescriptions FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')));
CREATE POLICY prescriptions_update ON public.prescriptions FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update'))) WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')));
CREATE POLICY prescriptions_delete ON public.prescriptions FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')));
CREATE POLICY prescription_items_select ON public.prescription_items FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')));
CREATE POLICY prescription_items_insert ON public.prescription_items FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')));
CREATE POLICY prescription_items_update ON public.prescription_items FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update'))) WITH CHECK ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')));
CREATE POLICY prescription_items_delete ON public.prescription_items FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')));
CREATE POLICY lab_order_items_select ON public.lab_order_items FOR SELECT TO authenticated USING ((SELECT public.app_has_perm('lab.read')));
CREATE POLICY lab_order_items_insert ON public.lab_order_items FOR INSERT TO authenticated WITH CHECK ((SELECT public.app_has_perm('lab.create')));
CREATE POLICY lab_order_items_update ON public.lab_order_items FOR UPDATE TO authenticated USING ((SELECT public.app_has_perm('lab.update'))) WITH CHECK ((SELECT public.app_has_perm('lab.update')));
CREATE POLICY lab_order_items_delete ON public.lab_order_items FOR DELETE TO authenticated USING ((SELECT public.app_has_perm('lab.delete')));

GRANT SELECT,INSERT,UPDATE,DELETE ON public.invoices,public.invoice_items,public.certificates,public.medical_certificates,
 public.patient_discounts,public.procedure_orders,public.procedure_results,public.followups,public.queue_tickets,
 public.prescriptions,public.prescription_items,public.lab_order_items TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON
 public.cashbox_transactions,public.expenses,public.payments,public.supplier_bills,public.supplier_payments TO authenticated,anon;

CREATE FUNCTION public.add_cashbox_entry(_direction text,_amount numeric,_type text,_method text,_category text,_description text,_date timestamptz)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
CREATE FUNCTION public.post_expense(_category text,_amount numeric,_description text,_expense_date date,_method text,_paid_to text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
CREATE FUNCTION public.post_supplier_payment(_bill_id uuid,_amount numeric,_method text,_reference text,_payment_date date,_notes text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
CREATE FUNCTION public.reverse_cashbox_entry(_transaction_id uuid,_reason text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$ SELECT gen_random_uuid() $function$;
GRANT EXECUTE ON FUNCTION public.add_cashbox_entry(text,numeric,text,text,text,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_expense(text,numeric,text,date,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_supplier_payment(uuid,numeric,text,text,date,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid,text) TO authenticated;

CREATE FUNCTION public.test_sync_invoice_paid_amount() RETURNS trigger LANGUAGE plpgsql
AS $function$ BEGIN UPDATE public.invoices SET paid_amount=COALESCE(paid_amount,0)+NEW.amount WHERE id=NEW.invoice_id; RETURN NEW; END $function$;
CREATE TRIGGER test_payment_paid_amount AFTER INSERT ON public.payments FOR EACH ROW EXECUTE FUNCTION public.test_sync_invoice_paid_amount();

INSERT INTO public.users(id,auth_user_id,branch_id,active,deleted_at) VALUES
 ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001',true,NULL);
INSERT INTO public.patients VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),
 ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.visits VALUES
 ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),
 ('40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.invoices(id,branch_id,net_amount,total_amount,paid_amount,deleted_at) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',10,10,0,NULL),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002',10,10,0,NULL),
 ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',10,10,0,NULL);
INSERT INTO public.invoice_items VALUES
 ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','branch A item'),
 ('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','branch B item');
INSERT INTO public.certificates VALUES
 ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','A'),
 ('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','B');
INSERT INTO public.medical_certificates VALUES
 ('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','A'),
 ('60000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','B');
INSERT INTO public.patient_discounts VALUES
 ('70000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',5),
 ('70000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002',10);
INSERT INTO public.procedure_orders VALUES
 ('80000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','ordered'),
 ('80000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','ordered');
INSERT INTO public.procedure_results VALUES
 ('90000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001','A'),
 ('90000000-0000-0000-0000-000000000002','80000000-0000-0000-0000-000000000002','B');
INSERT INTO public.followups VALUES
 ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','A'),
 ('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','B');
INSERT INTO public.queue_tickets VALUES
 ('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','waiting'),
 ('60000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','waiting');
INSERT INTO public.prescriptions VALUES
 ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','active'),
 ('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','active');
INSERT INTO public.prescription_items VALUES
 ('60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','medicine A'),
 ('60000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000002','medicine B');
INSERT INTO public.lab_orders VALUES
 ('70000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('70000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),
 ('70000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.lab_order_items VALUES
 ('80000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','ordered'),
 ('80000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000002','ordered'),
 ('80000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000003','mismatched-parent');
INSERT INTO public.suppliers VALUES ('30000000-0000-0000-0000-000000000001',true,NULL);

SELECT set_config('test.auth_uid','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.permissions',
 'billing.read|billing.view|billing.create|billing.update|billing.edit|billing.delete|' ||
 'certificates.read|certificates.create|certificates.update|certificates.delete|' ||
 'patients.read|procedures.read|procedures.create|procedures.update|procedures.delete|' ||
 'followups.read|followups.create|followups.update|followups.delete|' ||
 'queue.read|queue.create|queue.update|' ||
 'pharmacy.read|pharmacy.create|pharmacy.update|pharmacy.delete|emr.read|emr.create|emr.update|emr.delete|' ||
 'lab.read|lab.create|lab.update|lab.delete|cashbox.create|accounting.create|payments.create|debts.create',false);
SELECT set_config('test.super_admin','false',false);
