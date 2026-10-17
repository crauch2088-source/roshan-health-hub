-- 50 explicit checks: each of five sensitive tables is tested for
-- SELECT, cross-branch UPDATE denial, same-branch UPDATE success,
-- cross-branch INSERT denial, same-branch INSERT success,
-- cross-branch DELETE denial, same-branch DELETE success, and no residual write.
DO $test$
BEGIN
 IF has_function_privilege('anon','private.app_has_patient_branch(uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon patient helper EXECUTE must be revoked'; END IF;
 IF has_function_privilege('anon','private.app_has_attachment_branch_access(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon attachment helper EXECUTE must be revoked'; END IF;
 IF has_function_privilege('anon','private.app_has_procedure_order_branch_access(uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon procedure helper EXECUTE must be revoked'; END IF;
 IF NOT has_function_privilege('authenticated','private.app_has_procedure_order_branch_access(uuid)','EXECUTE') THEN RAISE EXCEPTION 'authenticated procedure helper EXECUTE missing'; END IF;
 IF private.app_has_procedure_order_branch_access('ffffffff-ffff-ffff-ffff-ffffffffffff') THEN RAISE EXCEPTION 'missing procedure order must fail closed'; END IF;
END
$test$;

SET ROLE authenticated;
DO $test$
DECLARE affected integer;
BEGIN
 -- 1-8: certificates
 IF (SELECT count(*) FROM public.certificates) <> 1 THEN RAISE EXCEPTION '1 certificates SELECT branch leak'; END IF;
 UPDATE public.certificates SET content='tampered' WHERE id='50000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '2 certificates cross-branch UPDATE'; END IF;
 UPDATE public.certificates SET content='local update' WHERE id='50000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '3 certificates same-branch UPDATE denied'; END IF;
 BEGIN INSERT INTO public.certificates VALUES ('50000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION '4 certificates cross-branch INSERT'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.certificates VALUES ('50000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.certificates WHERE id='50000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '6 certificates cross-branch DELETE'; END IF;
 DELETE FROM public.certificates WHERE id='50000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '7 certificates same-branch DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.certificates WHERE id='50000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION '8 certificate unauthorized insert residue'; END IF;

 -- 9-16: medical_certificates
 IF (SELECT count(*) FROM public.medical_certificates) <> 1 THEN RAISE EXCEPTION '9 medical certificates SELECT branch leak'; END IF;
 UPDATE public.medical_certificates SET diagnosis='tampered' WHERE id='60000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '10 medical certificates cross-branch UPDATE'; END IF;
 UPDATE public.medical_certificates SET diagnosis='local update' WHERE id='60000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '11 medical certificates same-branch UPDATE denied'; END IF;
 BEGIN INSERT INTO public.medical_certificates VALUES ('60000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION '12 medical certificates cross-branch INSERT'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.medical_certificates VALUES ('60000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.medical_certificates WHERE id='60000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '14 medical certificates cross-branch DELETE'; END IF;
 DELETE FROM public.medical_certificates WHERE id='60000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '15 medical certificates same-branch DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.medical_certificates WHERE id='60000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION '16 medical certificate unauthorized insert residue'; END IF;

 -- 17-24: patient_discounts
 IF (SELECT count(*) FROM public.patient_discounts) <> 1 THEN RAISE EXCEPTION '17 patient discounts SELECT branch leak'; END IF;
 UPDATE public.patient_discounts SET discount_percent=99 WHERE id='70000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '18 patient discounts cross-branch UPDATE'; END IF;
 UPDATE public.patient_discounts SET discount_percent=6 WHERE id='70000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '19 patient discounts same-branch UPDATE denied'; END IF;
 BEGIN INSERT INTO public.patient_discounts VALUES ('70000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002',20); RAISE EXCEPTION '20 patient discounts cross-branch INSERT'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.patient_discounts VALUES ('70000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001',7);
 DELETE FROM public.patient_discounts WHERE id='70000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '22 patient discounts cross-branch DELETE'; END IF;
 DELETE FROM public.patient_discounts WHERE id='70000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '23 patient discounts same-branch DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.patient_discounts WHERE id='70000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION '24 patient discount unauthorized insert residue'; END IF;

 -- 25-32: procedure_orders
 IF (SELECT count(*) FROM public.procedure_orders) <> 1 THEN RAISE EXCEPTION '25 procedure orders SELECT branch leak'; END IF;
 UPDATE public.procedure_orders SET status='tampered' WHERE id='80000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '26 procedure orders cross-branch UPDATE'; END IF;
 UPDATE public.procedure_orders SET status='local update' WHERE id='80000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '27 procedure orders same-branch UPDATE denied'; END IF;
 BEGIN INSERT INTO public.procedure_orders VALUES ('80000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION '28 procedure orders cross-branch INSERT'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.procedure_orders VALUES ('80000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.procedure_orders WHERE id='80000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '30 procedure orders cross-branch DELETE'; END IF;
 DELETE FROM public.procedure_orders WHERE id='80000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '31 procedure orders same-branch DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.procedure_orders WHERE id='80000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION '32 procedure order unauthorized insert residue'; END IF;

 -- 33-40: procedure_results inherit branch from parent order
 IF (SELECT count(*) FROM public.procedure_results) <> 1 THEN RAISE EXCEPTION '33 procedure results SELECT branch leak'; END IF;
 UPDATE public.procedure_results SET findings='tampered' WHERE id='90000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '34 procedure results cross-branch UPDATE'; END IF;
 UPDATE public.procedure_results SET findings='local update' WHERE id='90000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '35 procedure results same-branch UPDATE denied'; END IF;
 BEGIN INSERT INTO public.procedure_results VALUES ('90000000-0000-0000-0000-000000000003','80000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION '36 procedure results cross-branch INSERT'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.procedure_results VALUES ('90000000-0000-0000-0000-000000000004','80000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.procedure_results WHERE id='90000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION '38 procedure results cross-branch DELETE'; END IF;
 DELETE FROM public.procedure_results WHERE id='90000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION '39 procedure results same-branch DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.procedure_results WHERE id='90000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION '40 procedure result unauthorized insert residue'; END IF;

 -- 41-50: fail-closed and identity/permission invariants.
 IF private.app_has_patient_branch('ffffffff-ffff-ffff-ffff-ffffffffffff') THEN RAISE EXCEPTION '41 missing patient branch must fail closed'; END IF;
 IF private.app_has_attachment_branch_access(NULL,NULL) THEN RAISE EXCEPTION '42 missing attachment parents must fail closed'; END IF;
 IF private.app_has_procedure_order_branch_access('ffffffff-ffff-ffff-ffff-ffffffffffff') THEN RAISE EXCEPTION '43 missing procedure parent must fail closed'; END IF;
 BEGIN INSERT INTO public.certificates VALUES ('50000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','mismatched'); RAISE EXCEPTION '44 mixed-branch certificate linkage was allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.procedure_orders VALUES ('80000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','mismatched'); RAISE EXCEPTION '45 mixed-branch procedure linkage was allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF EXISTS (SELECT 1 FROM public.certificates WHERE id='50000000-0000-0000-0000-000000000005') THEN RAISE EXCEPTION '46 mixed-branch certificate residue'; END IF;
 IF EXISTS (SELECT 1 FROM public.procedure_orders WHERE id='80000000-0000-0000-0000-000000000005') THEN RAISE EXCEPTION '47 mixed-branch procedure order residue'; END IF;

 -- Additional patient/visit integrity checks: same-branch IDs can still belong to different patients.
 BEGIN INSERT INTO public.certificates VALUES ('50000000-0000-0000-0000-000000000006','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','same-branch mismatched patient'); RAISE EXCEPTION '51 same-branch mismatched certificate patient/visit was allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.procedure_orders VALUES ('80000000-0000-0000-0000-000000000006','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','same-branch mismatched patient'); RAISE EXCEPTION '52 same-branch mismatched procedure patient/visit was allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF EXISTS (SELECT 1 FROM public.certificates WHERE id='50000000-0000-0000-0000-000000000006') THEN RAISE EXCEPTION '53 mismatched certificate residue'; END IF;
 IF EXISTS (SELECT 1 FROM public.procedure_orders WHERE id='80000000-0000-0000-0000-000000000006') THEN RAISE EXCEPTION '54 mismatched procedure order residue'; END IF;
END
$test$;
RESET ROLE;

-- 48-50: confirm the untouched branch-B rows were not modified or deleted.
DO $test$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.certificates WHERE id='50000000-0000-0000-0000-000000000002' AND content='B') THEN RAISE EXCEPTION '48 branch-B certificate changed'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.medical_certificates WHERE id='60000000-0000-0000-0000-000000000002' AND diagnosis='B') THEN RAISE EXCEPTION '49 branch-B medical certificate changed'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.procedure_results WHERE id='90000000-0000-0000-0000-000000000002' AND findings='B') THEN RAISE EXCEPTION '50 branch-B procedure result changed'; END IF;
END
$test$;
