-- Disposable integration tests for the manual billing route.
SELECT set_config('test.perms','billing.create',false);
INSERT INTO public.patients (id,branch_id) VALUES
 ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.visits (id,patient_id,consultation_fee) VALUES
 ('50000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000003',30);
INSERT INTO public.partners (id,active,deleted_at) VALUES
 ('40000000-0000-0000-0000-000000000001',true,NULL),
 ('40000000-0000-0000-0000-000000000002',true,NULL);

DO $$
DECLARE
 v_primary uuid;
 v_appended uuid;
 v_secondary uuid;
 v_standalone uuid;
 v_before integer;
 v_items_before integer;
BEGIN
 v_primary := public.create_billing_invoice_atomic(
  '30000000-0000-0000-0000-000000000003',
  '50000000-0000-0000-0000-000000000004',
  '40000000-0000-0000-0000-000000000001',
  CURRENT_DATE,0,
  jsonb_build_array(jsonb_build_object(
    'item_name','Ultrasound','item_type','procedure','quantity',1,'unit_price',25
  )),false
 );
 IF NOT EXISTS (
   SELECT 1 FROM public.invoices WHERE id=v_primary AND visit_id='50000000-0000-0000-0000-000000000004'
     AND patient_id='30000000-0000-0000-0000-000000000003'
     AND partner_id='40000000-0000-0000-0000-000000000001'
     AND is_primary IS TRUE AND subtotal=25 AND net_amount=25
 ) THEN RAISE EXCEPTION 'manual visit invoice was not created as the primary invoice'; END IF;

 v_appended := public.create_billing_invoice_atomic(
  '30000000-0000-0000-0000-000000000003',
  '50000000-0000-0000-0000-000000000004',
  '40000000-0000-0000-0000-000000000001',
  CURRENT_DATE,0,
  jsonb_build_array(jsonb_build_object(
    'item_name','Dressing','item_type','other','quantity',2,'unit_price',5
  )),false
 );
 IF v_appended IS DISTINCT FROM v_primary THEN RAISE EXCEPTION 'manual billing created a second invoice by default'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.invoices WHERE id=v_primary AND subtotal=35 AND net_amount=35) THEN
   RAISE EXCEPTION 'manual lines were not appended to the primary invoice';
 END IF;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=v_primary AND deleted_at IS NULL) <> 2 THEN
   RAISE EXCEPTION 'manual billing items were not itemized';
 END IF;

 v_secondary := public.create_billing_invoice_atomic(
  '30000000-0000-0000-0000-000000000003',
  '50000000-0000-0000-0000-000000000004',
  '40000000-0000-0000-0000-000000000001',
  CURRENT_DATE,0,
  jsonb_build_array(jsonb_build_object(
    'item_name','Wound review','item_type','procedure','quantity',1,'unit_price',5
  )),true
 );
 IF v_secondary IS NOT DISTINCT FROM v_primary OR NOT EXISTS (
   SELECT 1 FROM public.invoices WHERE id=v_secondary AND visit_id='50000000-0000-0000-0000-000000000004'
     AND is_primary IS FALSE AND partner_id='40000000-0000-0000-0000-000000000001'
     AND subtotal=5 AND net_amount=5
 ) THEN RAISE EXCEPTION 'explicit secondary invoice was not created correctly'; END IF;

 SELECT count(*) INTO v_items_before FROM public.invoice_items WHERE invoice_id=v_primary AND deleted_at IS NULL;
 BEGIN
   PERFORM public.create_billing_invoice_atomic(
    '30000000-0000-0000-0000-000000000003',
    '50000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000002',
    CURRENT_DATE,0,
    jsonb_build_array(jsonb_build_object(
      'item_name','Conflicting partner','item_type','other','quantity',1,'unit_price',3
    )),false
   );
   RAISE EXCEPTION 'test failed: conflicting partner was accepted';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='test failed: conflicting partner was accepted' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=v_primary AND deleted_at IS NULL) <> v_items_before THEN
   RAISE EXCEPTION 'partner conflict left an invoice line behind';
 END IF;

 SELECT count(*) INTO v_before FROM public.invoices;
 BEGIN
   PERFORM public.create_billing_invoice_atomic(
    '30000000-0000-0000-0000-000000000003',NULL,NULL,CURRENT_DATE,0,
    jsonb_build_array(jsonb_build_object(
      'item_name','Unlinked invoice','item_type','other','quantity',1,'unit_price',1
    )),false
   );
   RAISE EXCEPTION 'test failed: standalone invoice was not explicit';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='test failed: standalone invoice was not explicit' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.invoices) <> v_before THEN
   RAISE EXCEPTION 'implicit standalone request created an invoice';
 END IF;

 v_standalone := public.create_billing_invoice_atomic(
  '30000000-0000-0000-0000-000000000003',NULL,NULL,CURRENT_DATE,0,
  jsonb_build_array(jsonb_build_object(
    'item_name','Standalone procedure','item_type','procedure','quantity',1,'unit_price',12
  )),true
 );
 IF NOT EXISTS (
   SELECT 1 FROM public.invoices WHERE id=v_standalone AND visit_id IS NULL
     AND is_primary IS FALSE AND subtotal=12 AND net_amount=12
 ) THEN RAISE EXCEPTION 'explicit standalone invoice was not marked secondary'; END IF;

 SELECT count(*) INTO v_before FROM public.invoices;
 BEGIN
   PERFORM public.create_billing_invoice_atomic(
    '30000000-0000-0000-0000-000000000003',
    '50000000-0000-0000-0000-000000000004',NULL,CURRENT_DATE,0,
    jsonb_build_array(jsonb_build_object(
      'item_name','Forged medicine','item_type','pharmacy','quantity',1,'unit_price',0.01
    )),true
   );
   RAISE EXCEPTION 'test failed: manual pharmacy line bypassed dispense billing';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='test failed: manual pharmacy line bypassed dispense billing' THEN RAISE; END IF;
 END;
 IF (SELECT count(*) FROM public.invoices) <> v_before THEN
   RAISE EXCEPTION 'unsupported manual line created an invoice';
 END IF;
END;
$$;

DO $$
BEGIN
 IF has_function_privilege('authenticated','public.create_billing_invoice_atomic(uuid,uuid,uuid,date,numeric,jsonb,boolean)','EXECUTE') THEN
   RAISE EXCEPTION 'authenticated can bypass idempotent manual billing wrapper';
 END IF;
 IF NOT has_function_privilege('authenticated','public.create_billing_invoice_atomic(uuid,uuid,uuid,date,numeric,jsonb,boolean,uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'authenticated cannot execute idempotent manual billing wrapper';
 END IF;
 IF has_function_privilege('anon','public.create_billing_invoice_atomic(uuid,uuid,uuid,date,numeric,jsonb,boolean,uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'anon can execute idempotent manual billing wrapper';
 END IF;
 IF has_function_privilege('authenticated','public.create_invoice_atomic(uuid,uuid,date,numeric,jsonb)','EXECUTE') THEN
   RAISE EXCEPTION 'authenticated can bypass the manual billing wrapper';
 END IF;
END;
$$;

SELECT set_config('test.perms','billing.create',false);
DO $$
DECLARE a uuid; b uuid; n integer; m integer;
BEGIN
 a := public.create_billing_invoice_atomic('30000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000004',NULL,CURRENT_DATE,0,
  jsonb_build_array(jsonb_build_object('item_name','Retry-safe procedure','item_type','procedure','quantity',1,'unit_price',4)),false,
  '70000000-0000-0000-0000-000000000003'::uuid);
 SELECT count(*) INTO n FROM public.invoices WHERE visit_id='50000000-0000-0000-0000-000000000004';
 SELECT count(*) INTO m FROM public.invoice_items WHERE invoice_id=a AND deleted_at IS NULL;
 b := public.create_billing_invoice_atomic('30000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000004',NULL,CURRENT_DATE,0,
  jsonb_build_array(jsonb_build_object('item_name','Retry-safe procedure','item_type','procedure','quantity',1,'unit_price',4)),false,
  '70000000-0000-0000-0000-000000000003'::uuid);
 IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'manual retry returned a different invoice'; END IF;
 IF (SELECT count(*) FROM public.invoices WHERE visit_id='50000000-0000-0000-0000-000000000004')<>n THEN RAISE EXCEPTION 'manual retry duplicated invoice'; END IF;
 IF (SELECT count(*) FROM public.invoice_items WHERE invoice_id=a AND deleted_at IS NULL)<>m THEN RAISE EXCEPTION 'manual retry duplicated invoice lines'; END IF;
END;
$$;
-- Reusing a manual billing request key with changed item pricing must be rejected.
DO $$
BEGIN
 BEGIN
  PERFORM public.create_billing_invoice_atomic('30000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000004',NULL,CURRENT_DATE,0,jsonb_build_array(jsonb_build_object('item_name','Retry-safe procedure','item_type','procedure','quantity',1,'unit_price',5)),false,'70000000-0000-0000-0000-000000000003'::uuid);
  RAISE EXCEPTION 'test failed: mismatched manual idempotency payload was accepted';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='test failed: mismatched manual idempotency payload was accepted' THEN RAISE; END IF;
  IF SQLERRM NOT LIKE '%idempotency key reused with different request%' THEN RAISE; END IF;
 END;
END;
$$;
SELECT 'manual billing consolidation integration tests passed' AS result;
