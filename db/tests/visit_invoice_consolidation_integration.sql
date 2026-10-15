SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.perms','visits.create,lab.create',false);
SELECT set_config('test.super_admin','false',false);
INSERT INTO public.users (id,branch_id) VALUES ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
INSERT INTO public.patients (id,branch_id) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.visits (id,patient_id) VALUES
 ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001'),
 ('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002');
INSERT INTO public.lab_tests (id,name,price,active) VALUES
 ('60000000-0000-0000-0000-000000000001','CBC',20,true),
 ('60000000-0000-0000-0000-000000000002','Glucose',5,true),
 ('60000000-0000-0000-0000-000000000003','Creatinine',10,true);

DO $$
DECLARE v_invoice uuid;
BEGIN
 v_invoice := public.create_or_append_visit_invoice_atomic(
  '50000000-0000-0000-0000-000000000001', CURRENT_DATE, 0,
  '[{"item_name":"Consultation","item_type":"consultation","quantity":1,"unit_price":30}]'::jsonb, false
 );
 IF NOT EXISTS (SELECT 1 FROM public.invoices WHERE id=v_invoice AND is_primary IS TRUE AND visit_id='50000000-0000-0000-0000-000000000001' AND subtotal=30 AND net_amount=30) THEN
   RAISE EXCEPTION 'primary consultation invoice not created correctly';
 END IF;
END;
$$;

DO $$
DECLARE v_order uuid; v_invoice uuid;
BEGIN
 v_order := public.create_lab_order_with_invoice_atomic(
  '50000000-0000-0000-0000-000000000001','normal',NULL,
  ARRAY['60000000-0000-0000-0000-000000000001'::uuid,'60000000-0000-0000-0000-000000000002'::uuid],false
 );
 SELECT id INTO v_invoice FROM public.invoices WHERE visit_id='50000000-0000-0000-0000-000000000001' AND is_primary IS TRUE AND deleted_at IS NULL;
 IF (SELECT count(*) FROM public.invoices WHERE visit_id='50000000-0000-0000-0000-000000000001' AND is_primary IS TRUE AND deleted_at IS NULL) <> 1 THEN
   RAISE EXCEPTION 'more than one primary invoice exists for the visit';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.invoices WHERE id=v_invoice AND subtotal=55 AND total_amount=55 AND net_amount=55) THEN
   RAISE EXCEPTION 'lab items did not reconcile into the primary invoice';
 END IF;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=v_invoice AND deleted_at IS NULL) <> 3 THEN
   RAISE EXCEPTION 'consultation and laboratory lines are not all present';
 END IF;
 IF (SELECT count(*) FROM public.lab_order_items WHERE order_id=v_order) <> 2 THEN
   RAISE EXCEPTION 'lab order items were not created';
 END IF;
END;
$$;

-- Appending to a partially paid invoice preserves the payment and recomputes the balance.
UPDATE public.invoices SET paid_amount=10,status='partial',payment_status='partial'
 WHERE visit_id='50000000-0000-0000-0000-000000000001' AND is_primary IS TRUE;
SELECT set_config('test.perms','lab.create',false);
DO $$
DECLARE v_order uuid;
BEGIN
 v_order := public.create_lab_order_with_invoice_atomic(
  '50000000-0000-0000-0000-000000000001','normal',NULL,
  ARRAY['60000000-0000-0000-0000-000000000003'::uuid],false
 );
 IF NOT EXISTS (
   SELECT 1 FROM public.invoices
    WHERE visit_id='50000000-0000-0000-0000-000000000001'
      AND is_primary IS TRUE AND subtotal=65 AND net_amount=65
      AND paid_amount=10 AND payment_status='partial' AND status='partial'
 ) THEN RAISE EXCEPTION 'partial payment was not preserved after adding a lab line'; END IF;
END;
$$;

-- Explicit secondary invoices are permitted only for billing-authorized users.
SELECT set_config('test.perms','billing.create',false);
DO $$
DECLARE v_secondary uuid; v_primary uuid;
BEGIN
 SELECT id INTO v_primary FROM public.invoices WHERE visit_id='50000000-0000-0000-0000-000000000001' AND is_primary IS TRUE;
 v_secondary := public.create_or_append_visit_invoice_atomic(
  '50000000-0000-0000-0000-000000000001', CURRENT_DATE, 0,
  '[{"item_name":"Separate approved service","item_type":"other","quantity":1,"unit_price":7}]'::jsonb, true
 );
 IF NOT EXISTS (SELECT 1 FROM public.invoices WHERE id=v_secondary AND is_primary IS FALSE AND visit_id='50000000-0000-0000-0000-000000000001') THEN
   RAISE EXCEPTION 'explicit secondary invoice was not marked separately';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.invoices WHERE id=v_primary AND is_primary IS TRUE) THEN
   RAISE EXCEPTION 'primary invoice was lost when secondary invoice was created';
 END IF;
END;
$$;

-- A paid primary invoice must not be mutated; a failed lab+invoice transaction must roll back its order.
UPDATE public.invoices SET paid_amount=net_amount,status='paid',payment_status='paid'
 WHERE visit_id='50000000-0000-0000-0000-000000000001' AND is_primary IS TRUE;
SELECT set_config('test.perms','lab.create',false);
CREATE FUNCTION public.test_fail_invoice_item() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF COALESCE(current_setting('test.fail_invoice_item',true)='true',false) THEN RAISE EXCEPTION 'injected invoice item failure'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER test_fail_invoice_item BEFORE INSERT ON public.invoice_items FOR EACH ROW EXECUTE FUNCTION public.test_fail_invoice_item();
SELECT set_config('test.fail_invoice_item','true',false);
DO $$
DECLARE v_before integer;
BEGIN
 SELECT count(*) INTO v_before FROM public.lab_orders;
 BEGIN
  PERFORM public.create_lab_order_with_invoice_atomic(
   '50000000-0000-0000-0000-000000000001','normal',NULL,
   ARRAY['60000000-0000-0000-0000-000000000003'::uuid],false
  );
  RAISE EXCEPTION 'test failed: paid invoice append should fail';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='test failed: paid invoice append should fail' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.lab_orders) <> v_before THEN
   RAISE EXCEPTION 'lab order was not rolled back after invoice failure';
 END IF;
END;
$$;

SELECT set_config('test.fail_invoice_item','false',false);
SELECT set_config('test.perms','lab.create',false);
DO $$
BEGIN
 BEGIN
  PERFORM public.create_lab_order_with_invoice_atomic(
   '50000000-0000-0000-0000-000000000002','normal',NULL,
   ARRAY['60000000-0000-0000-0000-000000000001'::uuid],false
  );
  RAISE EXCEPTION 'test failed: cross-branch lab invoice accepted';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='test failed: cross-branch lab invoice accepted' THEN RAISE; END IF;
 END;
END;
$$;

DO $$
BEGIN
 IF NOT has_function_privilege('authenticated','public.create_or_append_visit_invoice_atomic(uuid,date,numeric,jsonb,boolean)','EXECUTE') THEN RAISE EXCEPTION 'authenticated cannot execute visit invoice RPC'; END IF;
 IF has_function_privilege('anon','public.create_or_append_visit_invoice_atomic(uuid,date,numeric,jsonb,boolean)','EXECUTE') THEN RAISE EXCEPTION 'anon can execute visit invoice RPC'; END IF;
 IF NOT has_function_privilege('authenticated','public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean)','EXECUTE') THEN RAISE EXCEPTION 'authenticated cannot execute lab invoice RPC'; END IF;
 IF has_function_privilege('anon','public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean)','EXECUTE') THEN RAISE EXCEPTION 'anon can execute lab invoice RPC'; END IF;
END;
$$;
SELECT 'consolidated visit invoice integration tests passed' AS result;
