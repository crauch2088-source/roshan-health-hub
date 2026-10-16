SELECT set_config('test.auth_uid','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.permissions','pharmacy.read|emr.read|lab.read|pharmacy.create|emr.create|lab.create|pharmacy.update|emr.update|lab.update|pharmacy.delete|emr.delete|lab.delete',false);
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

  UPDATE public.prescriptions SET notes='tampered' WHERE id='50000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch prescription UPDATE was allowed'; END IF;
  UPDATE public.prescriptions SET notes='updated locally' WHERE id='50000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch prescription UPDATE was denied'; END IF;

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
END
$test$;
