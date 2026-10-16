DO $test$
BEGIN
  IF has_function_privilege('anon','private.app_has_branch_access(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'anonymous role must not execute private branch helper';
  END IF;
  IF NOT has_function_privilege('authenticated','private.app_has_branch_access(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated role must execute private branch helper for RLS';
  END IF;
END
$test$;

SELECT set_config('test.auth_uid','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.permissions','pharmacy.read|emr.read|lab.read|pharmacy.create|emr.create|lab.create|pharmacy.update|emr.update|lab.update|pharmacy.delete|emr.delete|lab.delete|certificates.read|certificates.create|certificates.update|certificates.delete|billing.read|billing.create|billing.update|billing.delete|patients.read|insurance.read|insurance.create|insurance.update',false);
SELECT set_config('test.super_admin','false',false);

INSERT INTO public.users(id,auth_user_id,branch_id,active)
VALUES ('10000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000001',true);
INSERT INTO public.patients(id,branch_id) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.visits(id,patient_id,branch_id) VALUES
 ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.patients(id,branch_id)
VALUES ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.visits(id,patient_id,branch_id)
VALUES ('40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001');
INSERT INTO public.prescriptions(id,patient_id,visit_id,notes) VALUES
 ('50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','branch A'),
 ('50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','branch B');
INSERT INTO public.prescription_items(prescription_id,medication_name) VALUES
 ('50000000-0000-0000-0000-000000000001','medicine A'),
 ('50000000-0000-0000-0000-000000000002','medicine B');
INSERT INTO public.lab_orders(id,patient_id,visit_id,branch_id) VALUES
 ('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('60000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.lab_order_items(order_id,status) VALUES
 ('60000000-0000-0000-0000-000000000001','pending'),
 ('60000000-0000-0000-0000-000000000002','pending');
INSERT INTO public.patient_insurance(id,patient_id) VALUES
 ('70000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001'),
 ('70000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002');
INSERT INTO public.medical_certificates(id,patient_id) VALUES
 ('80000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001'),
 ('80000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002');
INSERT INTO public.patient_discounts(id,patient_id) VALUES
 ('90000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001'),
 ('90000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002');
INSERT INTO public.insurance_prior_authorizations(id,patient_insurance_id) VALUES
 ('a0000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001'),
 ('a0000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000002');

SET ROLE authenticated;

DO $test$
DECLARE affected integer;
BEGIN
  IF (SELECT count(*) FROM public.prescriptions) <> 1 THEN
    RAISE EXCEPTION 'prescriptions SELECT leaked or hid a branch-local row';
  END IF;
  IF (SELECT count(*) FROM public.prescription_items) <> 1 THEN
    RAISE EXCEPTION 'prescription_items SELECT leaked or hid a branch-local row';
  END IF;
  IF (SELECT count(*) FROM public.lab_order_items) <> 1 THEN
    RAISE EXCEPTION 'lab_order_items SELECT leaked or hid a branch-local row';
  END IF;
  -- A same-branch lab order is valid.
  INSERT INTO public.lab_orders(id,patient_id,visit_id,branch_id)
  VALUES ('60000000-0000-0000-0000-000000000003',
          '30000000-0000-0000-0000-000000000001',
          '40000000-0000-0000-0000-000000000001',
          '20000000-0000-0000-0000-000000000001');

  -- Both records are in the same branch, but the visit belongs to a different patient.
  -- Branch equality alone is not enough to preserve clinical linkage integrity.
  BEGIN
    INSERT INTO public.lab_orders(id,patient_id,visit_id,branch_id)
    VALUES ('60000000-0000-0000-0000-000000000005',
            '30000000-0000-0000-0000-000000000001',
            '40000000-0000-0000-0000-000000000003',
            '20000000-0000-0000-0000-000000000001');
    RAISE EXCEPTION 'mismatched patient/visit lab order INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.lab_orders
    SET patient_id='30000000-0000-0000-0000-000000000001',
        visit_id='40000000-0000-0000-0000-000000000003'
    WHERE id='60000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'mismatched patient/visit lab order UPDATE was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  IF (SELECT count(*) FROM public.medical_certificates) <> 1 THEN
    RAISE EXCEPTION 'medical_certificates SELECT leaked or hid a branch-local row';
  END IF;
  IF (SELECT count(*) FROM public.patient_discounts) <> 1 THEN
    RAISE EXCEPTION 'patient_discounts SELECT leaked or hid a branch-local row';
  END IF;
  IF (SELECT count(*) FROM public.insurance_prior_authorizations) <> 1 THEN
    RAISE EXCEPTION 'insurance_prior_authorizations SELECT leaked or hid a branch-local row';
  END IF;

  UPDATE public.prescriptions SET notes='tampered' WHERE id='50000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch prescription UPDATE was allowed'; END IF;
  UPDATE public.prescriptions SET notes='updated locally' WHERE id='50000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch prescription UPDATE was denied'; END IF;

  BEGIN
    INSERT INTO public.prescriptions(id,patient_id,visit_id,notes)
    VALUES ('50000000-0000-0000-0000-000000000003',
            '30000000-0000-0000-0000-000000000001',
            '40000000-0000-0000-0000-000000000003',
            'mismatched patient/visit');
    RAISE EXCEPTION 'mismatched patient/visit prescription INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    UPDATE public.prescriptions SET visit_id='40000000-0000-0000-0000-000000000003'
    WHERE id='50000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'mismatched patient/visit prescription UPDATE was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  UPDATE public.prescription_items SET medication_name='tampered'
  WHERE prescription_id='50000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch prescription item UPDATE was allowed'; END IF;
  UPDATE public.prescription_items SET medication_name='updated locally'
  WHERE prescription_id='50000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch prescription item UPDATE was denied'; END IF;

  UPDATE public.lab_order_items SET status='tampered'
  WHERE order_id='60000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch lab order item UPDATE was allowed'; END IF;
  UPDATE public.lab_order_items SET status='in_progress'
  WHERE order_id='60000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch lab order item UPDATE was denied'; END IF;

  UPDATE public.medical_certificates SET patient_id='30000000-0000-0000-0000-000000000001'
  WHERE id='80000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch medical certificate UPDATE was allowed'; END IF;
  UPDATE public.medical_certificates SET patient_id='30000000-0000-0000-0000-000000000001'
  WHERE id='80000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch medical certificate UPDATE was denied'; END IF;

  UPDATE public.patient_discounts SET patient_id='30000000-0000-0000-0000-000000000001'
  WHERE id='90000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch patient discount UPDATE was allowed'; END IF;
  UPDATE public.patient_discounts SET patient_id='30000000-0000-0000-0000-000000000001'
  WHERE id='90000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch patient discount UPDATE was denied'; END IF;

  UPDATE public.insurance_prior_authorizations SET patient_insurance_id='70000000-0000-0000-0000-000000000001'
  WHERE id='a0000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch prior authorization UPDATE was allowed'; END IF;
  UPDATE public.insurance_prior_authorizations SET patient_insurance_id='70000000-0000-0000-0000-000000000001'
  WHERE id='a0000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch prior authorization UPDATE was denied'; END IF;

  DELETE FROM public.medical_certificates WHERE id='80000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch medical certificate DELETE was allowed'; END IF;
  DELETE FROM public.medical_certificates WHERE id='80000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch medical certificate DELETE was denied'; END IF;

  DELETE FROM public.patient_discounts WHERE id='90000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch patient discount DELETE was allowed'; END IF;
  DELETE FROM public.patient_discounts WHERE id='90000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch patient discount DELETE was denied'; END IF;

  BEGIN
    INSERT INTO public.prescriptions(patient_id,visit_id,notes)
    VALUES('30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','cross-branch');
    RAISE EXCEPTION 'cross-branch prescription INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.prescription_items(prescription_id,medication_name)
    VALUES('50000000-0000-0000-0000-000000000002','cross-branch');
    RAISE EXCEPTION 'cross-branch prescription item INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.lab_order_items(order_id,status)
    VALUES('60000000-0000-0000-0000-000000000002','cross-branch');
    RAISE EXCEPTION 'cross-branch lab item INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.medical_certificates(patient_id)
    VALUES('30000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'cross-branch medical certificate INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.patient_discounts(patient_id)
    VALUES('30000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'cross-branch patient discount INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.insurance_prior_authorizations(patient_insurance_id)
    VALUES('70000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'cross-branch prior authorization INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END
$test$;

RESET ROLE;

DO $test$
BEGIN
  IF EXISTS (SELECT 1 FROM public.prescriptions WHERE id='50000000-0000-0000-0000-000000000002' AND notes <> 'branch B') THEN
    RAISE EXCEPTION 'branch B prescription was mutated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.prescription_items WHERE prescription_id='50000000-0000-0000-0000-000000000002' AND medication_name <> 'medicine B') THEN
    RAISE EXCEPTION 'branch B prescription item was mutated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.lab_order_items WHERE order_id='60000000-0000-0000-0000-000000000002' AND status <> 'pending') THEN
    RAISE EXCEPTION 'branch B lab item was mutated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.medical_certificates WHERE id='80000000-0000-0000-0000-000000000002' AND patient_id <> '30000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'branch B medical certificate was mutated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.patient_discounts WHERE id='90000000-0000-0000-0000-000000000002' AND patient_id <> '30000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'branch B patient discount was mutated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.insurance_prior_authorizations WHERE id='a0000000-0000-0000-0000-000000000002' AND patient_insurance_id <> '70000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'branch B prior authorization was mutated';
  END IF;
END
$test$;
