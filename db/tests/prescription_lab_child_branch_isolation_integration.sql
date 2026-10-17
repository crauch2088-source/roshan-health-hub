DO $test$
BEGIN
 IF has_function_privilege('anon','private.app_has_prescription_parent_branch_access(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon prescription parent helper EXECUTE must be revoked'; END IF;
 IF has_function_privilege('anon','private.app_has_prescription_branch_access(uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon prescription helper EXECUTE must be revoked'; END IF;
 IF has_function_privilege('anon','private.app_has_lab_order_item_branch_access(uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon lab-item helper EXECUTE must be revoked'; END IF;
 IF NOT has_function_privilege('authenticated','private.app_has_prescription_branch_access(uuid)','EXECUTE') THEN RAISE EXCEPTION 'authenticated prescription helper EXECUTE missing'; END IF;
 IF private.app_has_prescription_branch_access('ffffffff-ffff-ffff-ffff-ffffffffffff') THEN RAISE EXCEPTION 'missing prescription must fail closed'; END IF;
 IF private.app_has_lab_order_item_branch_access('ffffffff-ffff-ffff-ffff-ffffffffffff') THEN RAISE EXCEPTION 'missing lab order must fail closed'; END IF;
END
$test$;
SET ROLE authenticated;
DO $test$
DECLARE affected integer;
BEGIN
 -- Prescription parent: branch-scoped SELECT/UPDATE/INSERT/DELETE.
 IF (SELECT count(*) FROM public.prescriptions)<>1 THEN RAISE EXCEPTION 'prescription SELECT branch leak'; END IF;
 UPDATE public.prescriptions SET status='tampered' WHERE id='50000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'cross-branch prescription UPDATE allowed'; END IF;
 UPDATE public.prescriptions SET status='updated' WHERE id='50000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'same-branch prescription UPDATE denied'; END IF;
 BEGIN INSERT INTO public.prescriptions VALUES ('50000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION 'cross-branch prescription INSERT allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.prescriptions VALUES ('50000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.prescriptions WHERE id='50000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'cross-branch prescription DELETE allowed'; END IF;
 DELETE FROM public.prescriptions WHERE id='50000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'same-branch prescription DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.prescriptions WHERE id='50000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION 'unauthorized prescription insert residue'; END IF;

 -- Prescription items inherit scope from their prescription.
 IF (SELECT count(*) FROM public.prescription_items)<>1 THEN RAISE EXCEPTION 'prescription-item SELECT branch leak'; END IF;
 UPDATE public.prescription_items SET medication_name='tampered' WHERE id='60000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'cross-branch prescription-item UPDATE allowed'; END IF;
 UPDATE public.prescription_items SET medication_name='updated' WHERE id='60000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'same-branch prescription-item UPDATE denied'; END IF;
 BEGIN UPDATE public.prescription_items SET prescription_id='50000000-0000-0000-0000-000000000002' WHERE id='60000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>0 THEN RAISE EXCEPTION 'prescription item cross-branch parent reassignment allowed'; END IF; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.prescription_items VALUES ('60000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION 'cross-branch prescription-item INSERT allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.prescription_items VALUES ('60000000-0000-0000-0000-000000000004','50000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.prescription_items WHERE id='60000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'cross-branch prescription-item DELETE allowed'; END IF;
 DELETE FROM public.prescription_items WHERE id='60000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'same-branch prescription-item DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.prescription_items WHERE id='60000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION 'unauthorized prescription-item insert residue'; END IF;

 -- Lab-order items inherit branch from the lab order and its patient/visit.
 IF (SELECT count(*) FROM public.lab_order_items)<>1 THEN RAISE EXCEPTION 'lab-order-item SELECT branch leak'; END IF;
 UPDATE public.lab_order_items SET status='tampered' WHERE id='80000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'cross-branch lab-order-item UPDATE allowed'; END IF;
 UPDATE public.lab_order_items SET status='tampered' WHERE id='80000000-0000-0000-0000-000000000003'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'same-branch mismatched patient/visit lab-order-item UPDATE allowed'; END IF;
 UPDATE public.lab_order_items SET status='updated' WHERE id='80000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'same-branch lab-order-item UPDATE denied'; END IF;
 BEGIN UPDATE public.lab_order_items SET order_id='70000000-0000-0000-0000-000000000002' WHERE id='80000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>0 THEN RAISE EXCEPTION 'lab-order item cross-branch parent reassignment allowed'; END IF; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.lab_order_items SET order_id='70000000-0000-0000-0000-000000000003' WHERE id='80000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>0 THEN RAISE EXCEPTION 'lab-order item reassignment to same-branch mismatched patient/visit order was allowed'; END IF; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.lab_order_items VALUES ('80000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION 'cross-branch lab-order-item INSERT allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.lab_order_items VALUES ('80000000-0000-0000-0000-000000000005','70000000-0000-0000-0000-000000000003','mismatched'); RAISE EXCEPTION 'mismatched patient/visit lab-order-item INSERT allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.lab_order_items VALUES ('80000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.lab_order_items WHERE id='80000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'cross-branch lab-order-item DELETE allowed'; END IF;
 DELETE FROM public.lab_order_items WHERE id='80000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'same-branch lab-order-item DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.lab_order_items WHERE id='80000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION 'unauthorized lab-order-item insert residue'; END IF;

 -- Same-branch but mismatched patient/visit linkage is rejected.
 BEGIN INSERT INTO public.prescriptions VALUES ('50000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','mismatch'); RAISE EXCEPTION 'same-branch mismatched prescription patient/visit allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF EXISTS (SELECT 1 FROM public.prescriptions WHERE id='50000000-0000-0000-0000-000000000005') THEN RAISE EXCEPTION 'mismatched prescription residue'; END IF;
END
$test$;
RESET ROLE;
DO $test$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.prescriptions WHERE id='50000000-0000-0000-0000-000000000002' AND status='active') THEN RAISE EXCEPTION 'foreign prescription mutated'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.prescription_items WHERE id='60000000-0000-0000-0000-000000000002' AND medication_name='medicine B') THEN RAISE EXCEPTION 'foreign prescription item mutated'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.lab_order_items WHERE id='80000000-0000-0000-0000-000000000002' AND status='ordered') THEN RAISE EXCEPTION 'foreign lab order item mutated'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.lab_order_items WHERE id='80000000-0000-0000-0000-000000000003' AND status='mismatched-parent') THEN RAISE EXCEPTION 'mismatched-parent lab item was mutated'; END IF;
 IF EXISTS (SELECT 1 FROM public.lab_order_items WHERE id='80000000-0000-0000-0000-000000000005') THEN RAISE EXCEPTION 'mismatched lab item insert residue'; END IF;
END
$test$;
