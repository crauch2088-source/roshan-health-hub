-- Minimal PostgreSQL 17 fixture for invoice payment amount precision.
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE TABLE public.users(id uuid PRIMARY KEY, branch_id uuid, deleted_at timestamptz, active boolean);
CREATE TABLE public.invoices(id uuid PRIMARY KEY, net_amount numeric(14,2), total_amount numeric(14,2), paid_amount numeric(14,2) NOT NULL DEFAULT 0, branch_id uuid NOT NULL, deleted_at timestamptz, status text NOT NULL DEFAULT 'unpaid', payment_status text NOT NULL DEFAULT 'unpaid', updated_at timestamptz);
CREATE TABLE public.payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invoice_id uuid NOT NULL REFERENCES public.invoices(id), amount numeric(14,2) NOT NULL, payment_method text, method text, reference_no text, reference text, payment_date date, received_at timestamptz, received_by uuid, created_by uuid, branch_id uuid, idempotency_key text UNIQUE, deleted_at timestamptz);
CREATE TABLE public.cashbox_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), branch_id uuid, transaction_type text, amount numeric, payment_method text, category text, description text, source_type text, source_id uuid, transaction_date timestamptz, created_by uuid);
CREATE UNIQUE INDEX cashbox_source_unique ON public.cashbox_transactions(source_type,source_id) WHERE source_type IS NOT NULL AND source_id IS NOT NULL;
GRANT SELECT ON public.invoices, public.payments, public.cashbox_transactions TO authenticated;
CREATE FUNCTION public.current_app_user_id() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('test.user_id',true),'')::uuid $$;
CREATE FUNCTION public.app_has_perm(p text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT COALESCE(current_setting('test.permissions',true) LIKE '%' || p || '%',false) $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT COALESCE(current_setting('test.super_admin',true)='true',false) $$;
CREATE FUNCTION public.fn_ledger_post(_type text,_amount numeric,_method text,_category text,_description text,_source_type text,_source_id uuid,_date timestamptz,_branch uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$ DECLARE tx uuid; uid uuid; BEGIN uid:=public.current_app_user_id();
INSERT INTO public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,source_type,source_id,transaction_date,created_by)
VALUES(_branch,_type,_amount,COALESCE(_method,'cash'),_category,_description,_source_type,_source_id,COALESCE(_date,now()),uid)
ON CONFLICT(source_type,source_id) WHERE source_type IS NOT NULL AND source_id IS NOT NULL DO NOTHING RETURNING id INTO tx; RETURN tx; END; $$;
CREATE FUNCTION public.fn_ledger_from_payment() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$ BEGIN
PERFORM public.fn_ledger_post('customer_payment',abs(NEW.amount),COALESCE(NEW.payment_method,NEW.method,'cash'),'patient_payment','Invoice payment','payment',NEW.id,COALESCE(NEW.payment_date::timestamptz,NEW.received_at,now()),NEW.branch_id); RETURN NEW; END; $$;
CREATE FUNCTION public.fn_recompute_invoice_paid() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$ DECLARE inv uuid; total numeric; net numeric; BEGIN
inv:=COALESCE(NEW.invoice_id,OLD.invoice_id); SELECT COALESCE(SUM(amount),0) INTO total FROM public.payments WHERE invoice_id=inv AND deleted_at IS NULL;
SELECT COALESCE(i.net_amount,i.total_amount,0) INTO net FROM public.invoices i WHERE i.id=inv;
UPDATE public.invoices SET paid_amount=total,status=CASE WHEN total<=0 THEN 'unpaid' WHEN total>=net THEN 'paid' ELSE 'partial' END,payment_status=CASE WHEN total<=0 THEN 'unpaid' WHEN total>=net THEN 'paid' ELSE 'partial' END,updated_at=now() WHERE id=inv; RETURN COALESCE(NEW,OLD); END; $$;
CREATE TRIGGER trg_ledger_from_payment AFTER INSERT ON public.payments FOR EACH ROW EXECUTE FUNCTION public.fn_ledger_from_payment();
CREATE TRIGGER trg_recompute_invoice_paid AFTER INSERT OR UPDATE OR DELETE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.fn_recompute_invoice_paid();
CREATE FUNCTION public.post_invoice_payment(_invoice_id uuid,_amount numeric,_method text DEFAULT 'cash'::text,_reference text DEFAULT NULL::text,_idempotency_key text DEFAULT NULL::text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$ BEGIN RAISE EXCEPTION 'unpatched invoice payment RPC'; END; $$;
GRANT EXECUTE ON FUNCTION public.post_invoice_payment(uuid,numeric,text,text,text) TO authenticated;
INSERT INTO public.users VALUES('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',NULL,true);
INSERT INTO public.invoices(id,net_amount,total_amount,paid_amount,branch_id) VALUES('50000000-0000-0000-0000-000000000001',100,100,0,'20000000-0000-0000-0000-000000000001');
