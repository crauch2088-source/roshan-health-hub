-- Disposable PostgreSQL 17 fixture for source-aware financial reversals.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA private;
CREATE TABLE public.users (id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz, active boolean NOT NULL DEFAULT true);
CREATE TABLE public.invoices (id uuid PRIMARY KEY, net_amount numeric(14,2) NOT NULL, total_amount numeric(14,2) NOT NULL, paid_amount numeric(14,2) NOT NULL DEFAULT 0, branch_id uuid, deleted_at timestamptz, status text NOT NULL DEFAULT 'unpaid', payment_status text NOT NULL DEFAULT 'unpaid', updated_at timestamptz, updated_by uuid);
CREATE TABLE public.payments (id uuid PRIMARY KEY, invoice_id uuid NOT NULL REFERENCES public.invoices(id), amount numeric(14,2) NOT NULL, payment_method text, method text, reference_no text, reference text, payment_date date, received_at timestamptz, received_by uuid, created_by uuid, branch_id uuid, deleted_at timestamptz, deleted_by uuid, updated_at timestamptz, updated_by uuid);
CREATE TABLE public.cashbox_transactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, transaction_type text NOT NULL, amount numeric(14,2) NOT NULL, payment_method text, category text, description text, source_type text, source_id uuid, transaction_date timestamptz NOT NULL DEFAULT now(), created_by uuid NOT NULL, reversal_of uuid REFERENCES public.cashbox_transactions(id), reversal_reason text, is_reversed boolean NOT NULL DEFAULT false);
CREATE UNIQUE INDEX uq_cashbox_source ON public.cashbox_transactions(source_type, source_id) WHERE source_type IS NOT NULL AND source_id IS NOT NULL;
CREATE UNIQUE INDEX uq_cashbox_reversal_of ON public.cashbox_transactions(reversal_of) WHERE reversal_of IS NOT NULL;
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('test.user_id', true), '')::uuid $$;
CREATE FUNCTION public.app_has_perm(p text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT COALESCE(current_setting('test.permissions', true) LIKE '%' || p || '%', false) $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE AS $ SELECT COALESCE(current_setting('test.super_admin', true) = 'true', false) $;
CREATE FUNCTION private.app_has_branch_access(p_branch uuid) RETURNS boolean LANGUAGE sql STABLE AS $ SELECT public.is_super_admin() OR p_branch = (SELECT u.branch_id FROM public.users u WHERE u.id = public.current_app_user_id() AND u.deleted_at IS NULL AND u.active IS TRUE) $;
CREATE FUNCTION public.fn_recompute_invoice_paid() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_invoice_id uuid; v_paid numeric; v_net numeric;
BEGIN
  v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
  SELECT COALESCE(sum(p.amount), 0) INTO v_paid FROM public.payments p WHERE p.invoice_id = v_invoice_id AND p.deleted_at IS NULL;
  SELECT COALESCE(i.net_amount, i.total_amount, 0) INTO v_net FROM public.invoices i WHERE i.id = v_invoice_id;
  UPDATE public.invoices SET paid_amount = v_paid,
    status = CASE WHEN v_paid <= 0 THEN 'unpaid' WHEN v_paid >= v_net THEN 'paid' ELSE 'partial' END,
    payment_status = CASE WHEN v_paid <= 0 THEN 'unpaid' WHEN v_paid >= v_net THEN 'paid' ELSE 'partial' END,
    updated_at = now() WHERE id = v_invoice_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_recompute_invoice_paid AFTER INSERT OR UPDATE OR DELETE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.fn_recompute_invoice_paid();
CREATE FUNCTION public.fn_cashbox_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('roshan.cashbox_write', true) IS DISTINCT FROM 'on' THEN RAISE EXCEPTION 'cashbox entries are immutable'; END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_cashbox_immutable BEFORE UPDATE OR DELETE ON public.cashbox_transactions FOR EACH ROW EXECUTE FUNCTION public.fn_cashbox_immutable();

-- The assertion block runs as authenticated and inspects outcomes directly.
GRANT SELECT ON public.users, public.invoices, public.payments, public.cashbox_transactions TO authenticated;
INSERT INTO public.users(id, branch_id, active) VALUES
  ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',true),
  ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002',true);
INSERT INTO public.invoices(id, net_amount, total_amount, paid_amount, branch_id, status, payment_status) VALUES
  ('50000000-0000-0000-0000-000000000001',100,100,0,'20000000-0000-0000-0000-000000000001','unpaid','unpaid'),
  ('50000000-0000-0000-0000-000000000002',100,100,0,'20000000-0000-0000-0000-000000000002','unpaid','unpaid'),
  ('50000000-0000-0000-0000-000000000003',100,100,0,NULL,'unpaid','unpaid');
INSERT INTO public.payments(id, invoice_id, amount, payment_method, method, payment_date, received_by, created_by, branch_id) VALUES
  ('60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',40,'cash','cash',CURRENT_DATE,'10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
  ('60000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000002',25,'bank','bank',CURRENT_DATE,'10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002'),
  ('60000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001',10,'cash','cash',CURRENT_DATE,'10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
  ('60000000-0000-0000-0000-000000000004','50000000-0000-0000-0000-000000000003',20,'cash','cash',CURRENT_DATE,'10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',NULL);
INSERT INTO public.cashbox_transactions(id, branch_id, transaction_type, amount, payment_method, category, description, source_type, source_id, created_by) VALUES
  ('70000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','customer_payment',40,'cash','patient_payment','Invoice payment','payment','60000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','customer_payment',25,'bank','patient_payment','Invoice payment','payment','60000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002'),
  ('70000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000001','customer_payment',10,'cash','patient_payment','Second invoice payment','payment','60000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','expense',-5,'cash','operations','Office supplies','expense','80000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','supplier_payment',-10,'cash','supplier','Supplier settlement','supplier_payment','80000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','income',15,'bank','insurance','Insurance claim payment','insurance_claim_payment','80000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001'),
  ('70000000-0000-0000-0000-000000000007',NULL,'customer_payment',20,'cash','patient_payment','Branchless invoice payment','payment','60000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001');
