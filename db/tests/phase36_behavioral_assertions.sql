-- Apply the exact tracked Phase 36 migration in an isolated PostgreSQL 17 database.
BEGIN;

DO $guard_update_tests$
DECLARE t text; v_id uuid;
BEGIN
  FOR t IN SELECT unnest(ARRAY['lab_orders','lab_order_items','prescriptions','prescription_items','medical_certificates']) LOOP
    v_id := CASE t WHEN 'lab_orders' THEN '00000000-0000-0000-0000-000000009101'::uuid WHEN 'lab_order_items' THEN '00000000-0000-0000-0000-000000009111'::uuid WHEN 'prescriptions' THEN '00000000-0000-0000-0000-000000009121'::uuid WHEN 'prescription_items' THEN '00000000-0000-0000-0000-000000009131'::uuid ELSE '00000000-0000-0000-0000-000000009141'::uuid END;
    BEGIN
      EXECUTE format('UPDATE public.%I SET patient_id=$1 WHERE id=$2',t)
        USING '00000000-0000-0000-0000-000000009202'::uuid, v_id;
      RAISE EXCEPTION 'Phase 36 failed to reject patient_id UPDATE on %',t;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
      EXECUTE format('UPDATE public.%I SET visit_id=$1 WHERE id=$2',t)
        USING '00000000-0000-0000-0000-000000009002'::uuid, v_id;
      RAISE EXCEPTION 'Phase 36 failed to reject visit_id UPDATE on %',t;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
  END LOOP;
END $guard_update_tests$;

DO $cancelled_tests$
DECLARE t text; active_id uuid; cancelled_id uuid;
BEGIN
  FOR t IN SELECT unnest(ARRAY['lab_orders','lab_order_items','prescriptions','prescription_items','medical_certificates']) LOOP
    BEGIN
      IF t='lab_order_items' THEN
        INSERT INTO public.lab_order_items(id,patient_id,visit_id,order_id,value)
        VALUES ('00000000-0000-0000-0000-000000009151','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009102','cancelled');
      ELSIF t='prescription_items' THEN
        INSERT INTO public.prescription_items(id,patient_id,visit_id,prescription_id,value)
        VALUES ('00000000-0000-0000-0000-000000009152','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009122','cancelled');
      ELSIF t='lab_orders' THEN
        INSERT INTO public.lab_orders(id,patient_id,visit_id,branch_id,status,value)
        VALUES ('00000000-0000-0000-0000-000000009153','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009301','ordered','cancelled');
      ELSIF t='prescriptions' THEN
        INSERT INTO public.prescriptions(id,patient_id,visit_id,branch_id,value)
        VALUES ('00000000-0000-0000-0000-000000009154','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009301','cancelled');
      ELSE
        INSERT INTO public.medical_certificates(id,patient_id,visit_id,branch_id,diagnosis,value)
        VALUES ('00000000-0000-0000-0000-000000009155','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009301','cancelled','cancelled');
      END IF;
      RAISE EXCEPTION 'Phase 36 failed to reject INSERT on cancelled visit for %',t;
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    cancelled_id := CASE t
      WHEN 'lab_orders' THEN '00000000-0000-0000-0000-000000009102'::uuid
      WHEN 'lab_order_items' THEN '00000000-0000-0000-0000-000000009112'::uuid
      WHEN 'prescriptions' THEN '00000000-0000-0000-0000-000000009122'::uuid
      WHEN 'prescription_items' THEN '00000000-0000-0000-0000-000000009132'::uuid
      ELSE '00000000-0000-0000-0000-000000009142'::uuid END;
    BEGIN
      EXECUTE format('UPDATE public.%I SET value=$1 WHERE id=$2',t) USING 'update-cancelled',cancelled_id;
      RAISE EXCEPTION 'Phase 36 failed to reject UPDATE on a child of a cancelled visit: %',t;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
  END LOOP;
END $cancelled_tests$;

DO $audit_tests$
DECLARE t text; row_id uuid; op text; n bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY['insurance_prior_authorizations','medical_certificates','patient_discounts'] LOOP
    row_id := CASE t WHEN 'insurance_prior_authorizations' THEN '00000000-0000-0000-0000-000000009161'::uuid
      WHEN 'medical_certificates' THEN '00000000-0000-0000-0000-000000009162'::uuid
      ELSE '00000000-0000-0000-0000-000000009163'::uuid END;
    EXECUTE format('INSERT INTO public.%I(id,value) VALUES ($1,$2)',t) USING row_id,'insert';
    EXECUTE format('UPDATE public.%I SET value=$1 WHERE id=$2',t) USING 'update',row_id;
    EXECUTE format('DELETE FROM public.%I WHERE id=$1',t) USING row_id;
    FOREACH op IN ARRAY ARRAY['INSERT','UPDATE','DELETE'] LOOP
      SELECT count(*) INTO n FROM public.audit_logs WHERE table_name=t AND record_id=row_id AND action=op;
      IF n <> 1 THEN RAISE EXCEPTION 'Expected exactly one audit row for %.%, got %',t,op,n; END IF;
    END LOOP;
  END LOOP;
  IF (SELECT count(*) FROM public.audit_logs WHERE table_name IN ('insurance_prior_authorizations','medical_certificates','patient_discounts')) <> 9 THEN
    RAISE EXCEPTION 'Expected exactly 9 audit rows total for Phase 36 audit tables';
  END IF;
END $audit_tests$;
ROLLBACK;
