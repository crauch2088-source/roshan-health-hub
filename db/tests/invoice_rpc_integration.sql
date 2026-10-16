SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.has_perm','true',false);
SELECT set_config('test.super_admin','false',false);
INSERT INTO public.users (id,branch_id) VALUES ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
INSERT INTO public.patients (id,branch_id) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.partners (id,active) VALUES ('40000000-0000-0000-0000-000000000001',true);

DO $$
DECLARE v_invoice uuid;
BEGIN
 v_invoice := public.create_invoice_atomic(
  '30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',DATE '2026-10-15',5,
  '[{"item_name":"Consultation","item_type":"consultation","quantity":2,"unit_price":15},{"item_name":"CBC","item_type":"lab","quantity":1,"unit_price":20}]'::jsonb
 );
 IF NOT EXISTS (SELECT 1 FROM public.invoices WHERE id=v_invoice AND invoice_number='INV-TEST-00001' AND branch_id='20000000-0000-0000-0000-000000000001' AND total_amount=50 AND subtotal=50 AND discount_amount=5 AND net_amount=45 AND status='unpaid' AND created_by='10000000-0000-0000-0000-000000000001') THEN
  RAISE EXCEPTION 'invoice header totals or ownership are incorrect';
 END IF;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=v_invoice) <> 2 THEN RAISE EXCEPTION 'invoice items missing'; END IF;
 IF (SELECT sum(total_price) FROM public.invoice_items WHERE invoice_id=v_invoice) <> 50 THEN RAISE EXCEPTION 'invoice item totals do not reconcile'; END IF;
END;
$$;

DO $$
BEGIN
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000001',NULL,CURRENT_DATE,0,'[]'::jsonb);
  RAISE EXCEPTION 'test failed: empty invoice accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: empty invoice accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000001',NULL,CURRENT_DATE,100,'[{"item_name":"service","item_type":"other","quantity":1,"unit_price":10}]'::jsonb);
  RAISE EXCEPTION 'test failed: excessive discount accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: excessive discount accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000001',NULL,CURRENT_DATE,0,'[{"item_name":"service","item_type":"other","quantity":0,"unit_price":10}]'::jsonb);
  RAISE EXCEPTION 'test failed: zero quantity accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: zero quantity accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000001',NULL,CURRENT_DATE,0,'[{"item_name":"service","item_type":"other","quantity":1,"unit_price":1.234}]'::jsonb);
  RAISE EXCEPTION 'test failed: over-precision unit price accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: over-precision unit price accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000001',NULL,CURRENT_DATE,0,'[{"item_name":"service","item_type":"unknown","quantity":1,"unit_price":10}]'::jsonb);
  RAISE EXCEPTION 'test failed: unsupported item type accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: unsupported item type accepted' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000002',NULL,CURRENT_DATE,0,'[{"item_name":"cross branch","item_type":"other","quantity":1,"unit_price":10}]'::jsonb);
  RAISE EXCEPTION 'test failed: cross-branch patient accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: cross-branch patient accepted' THEN RAISE; END IF; END;
 IF (SELECT count(*) FROM public.invoices) <> 1 THEN RAISE EXCEPTION 'invalid invoice request left a header'; END IF;
END;
$$;
SELECT set_config('test.has_perm','false',false);
DO $$
BEGIN
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000001',NULL,CURRENT_DATE,0,'[{"item_name":"unauthorized","item_type":"other","quantity":1,"unit_price":10}]'::jsonb);
  RAISE EXCEPTION 'test failed: unauthorized invoice accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='test failed: unauthorized invoice accepted' THEN RAISE; END IF; END;
END;
$$;
SELECT set_config('test.has_perm','true',false);

CREATE FUNCTION public.test_fail_invoice_item() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF COALESCE(current_setting('test.fail_item',true)='true',false) THEN RAISE EXCEPTION 'injected invoice item failure'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER test_fail_invoice_item BEFORE INSERT ON public.invoice_items FOR EACH ROW EXECUTE FUNCTION public.test_fail_invoice_item();
SELECT set_config('test.fail_item','true',false);
DO $$
BEGIN
 BEGIN
  PERFORM public.create_invoice_atomic('30000000-0000-0000-0000-000000000001',NULL,CURRENT_DATE,0,'[{"item_name":"rollback","item_type":"other","quantity":1,"unit_price":10}]'::jsonb);
  RAISE EXCEPTION 'test failed: injected failure not raised';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='test failed: injected failure not raised' THEN RAISE; END IF;
  IF SQLERRM <> 'injected invoice item failure' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.invoices) <> 1 THEN RAISE EXCEPTION 'orphan invoice header after failure'; END IF;
 IF (SELECT count(*) FROM public.invoice_items) <> 2 THEN RAISE EXCEPTION 'partial invoice items after failure'; END IF;
END;
$$;
DO $$
BEGIN
 IF NOT has_function_privilege('authenticated','public.create_invoice_atomic(uuid,uuid,date,numeric,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'authenticated cannot execute'; END IF;
 IF has_function_privilege('anon','public.create_invoice_atomic(uuid,uuid,date,numeric,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'anon can execute'; END IF;
END;
$$;
SELECT set_config('test.fail_item','false',false);
SELECT set_config('test.super_admin','true',false);
DO $branch$
DECLARE v_invoice uuid;
BEGIN
 v_invoice := public.create_invoice_atomic(
  '30000000-0000-0000-0000-000000000002',NULL,CURRENT_DATE,0,
  '[{"item_name":"Super-admin branch check","item_type":"other","quantity":1,"unit_price":10}]'::jsonb
 );
 IF NOT EXISTS (
   SELECT 1 FROM public.invoices
    WHERE id = v_invoice
      AND patient_id = '30000000-0000-0000-0000-000000000002'
      AND branch_id = '20000000-0000-0000-0000-000000000002'
 ) THEN
   RAISE EXCEPTION 'super-admin invoice was not assigned to the patient branch';
 END IF;
END;
$branch$;
SELECT 'atomic invoice integration tests passed' AS result;
