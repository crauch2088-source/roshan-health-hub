DO $test$
BEGIN
 IF has_function_privilege('anon','private.app_has_attachment_branch_access(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon helper EXECUTE must be revoked'; END IF;
 IF NOT has_function_privilege('authenticated','private.app_has_attachment_branch_access(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'authenticated helper EXECUTE missing'; END IF;
 IF has_function_privilege('anon','private.app_has_patient_visit_branch_access(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'anon patient-visit helper EXECUTE must be revoked'; END IF;
 IF NOT has_function_privilege('authenticated','private.app_has_patient_visit_branch_access(uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'authenticated patient-visit helper EXECUTE missing'; END IF;
 IF private.app_has_attachment_branch_access(NULL,NULL) THEN RAISE EXCEPTION 'branchless parent tuple must fail closed'; END IF;
END
$test$;
SET ROLE authenticated;
DO $test$
DECLARE affected integer;
BEGIN
 -- Follow-ups: read, update, insert, delete across both branches.
 IF (SELECT count(*) FROM public.followups)<>1 THEN RAISE EXCEPTION 'followups SELECT branch leak'; END IF;
 UPDATE public.followups SET notes='tampered' WHERE id='50000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'followups cross-branch UPDATE allowed'; END IF;
 UPDATE public.followups SET notes='updated' WHERE id='50000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 -- Reparenting an otherwise visible row to a different patient's visit must fail.
 BEGIN UPDATE public.followups SET visit_id='40000000-0000-0000-0000-000000000003' WHERE id='50000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>0 THEN RAISE EXCEPTION 'followup patient/visit reassignment allowed'; END IF; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF affected<>1 THEN RAISE EXCEPTION 'followups same-branch UPDATE denied'; END IF;
 BEGIN INSERT INTO public.followups VALUES ('50000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION 'followups cross-branch INSERT allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.followups VALUES ('50000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','local');
 DELETE FROM public.followups WHERE id='50000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'followups cross-branch DELETE allowed'; END IF;
 DELETE FROM public.followups WHERE id='50000000-0000-0000-0000-000000000004'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'followups same-branch DELETE denied'; END IF;
 IF EXISTS (SELECT 1 FROM public.followups WHERE id='50000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION 'followups unauthorized insert residue'; END IF;

 -- Queue: read, update, insert, delete across both branches.
 IF (SELECT count(*) FROM public.queue_tickets)<>1 THEN RAISE EXCEPTION 'queue SELECT branch leak'; END IF;
 UPDATE public.queue_tickets SET status='tampered' WHERE id='60000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'queue cross-branch UPDATE allowed'; END IF;
 UPDATE public.queue_tickets SET status='called' WHERE id='60000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 -- Queue ticket parent reassignment must not bypass the patient/visit invariant.
 BEGIN UPDATE public.queue_tickets SET visit_id='40000000-0000-0000-0000-000000000003' WHERE id='60000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT; IF affected<>0 THEN RAISE EXCEPTION 'queue ticket patient/visit reassignment allowed'; END IF; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF affected<>1 THEN RAISE EXCEPTION 'queue same-branch UPDATE denied'; END IF;
 BEGIN INSERT INTO public.queue_tickets VALUES ('60000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','cross'); RAISE EXCEPTION 'queue cross-branch INSERT allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.queue_tickets VALUES ('60000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','waiting');
 DELETE FROM public.queue_tickets WHERE id='60000000-0000-0000-0000-000000000002'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'queue cross-branch DELETE allowed'; END IF;
 -- Non-super-admin cannot delete even a same-branch ticket (existing policy invariant).
 DELETE FROM public.queue_tickets WHERE id='60000000-0000-0000-0000-000000000001'; GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>0 THEN RAISE EXCEPTION 'queue DELETE should remain super-admin-only'; END IF;
 IF EXISTS (SELECT 1 FROM public.queue_tickets WHERE id='60000000-0000-0000-0000-000000000003') THEN RAISE EXCEPTION 'queue unauthorized insert residue'; END IF;

 -- Mixed-branch and same-branch mismatched patient/visit references must fail closed.
 BEGIN INSERT INTO public.followups VALUES ('50000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','mixed'); RAISE EXCEPTION 'mixed-branch followup allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.queue_tickets VALUES ('60000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','mixed'); RAISE EXCEPTION 'mixed-branch queue ticket allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.followups VALUES ('50000000-0000-0000-0000-000000000006','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','same-branch mismatch'); RAISE EXCEPTION 'same-branch mismatched followup allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.queue_tickets VALUES ('60000000-0000-0000-0000-000000000006','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','same-branch mismatch'); RAISE EXCEPTION 'same-branch mismatched queue ticket allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.followups VALUES ('50000000-0000-0000-0000-000000000007',NULL,'40000000-0000-0000-0000-000000000002','null patient cross-branch visit'); RAISE EXCEPTION 'null patient_id bypassed follow-up branch isolation'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.queue_tickets VALUES ('60000000-0000-0000-0000-000000000007',NULL,'40000000-0000-0000-0000-000000000002','null patient cross-branch visit'); RAISE EXCEPTION 'null patient_id bypassed queue branch isolation'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$test$;
RESET ROLE;
DO $test$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.followups WHERE id='50000000-0000-0000-0000-000000000002' AND notes='B') THEN RAISE EXCEPTION 'branch-B followup mutated'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.queue_tickets WHERE id='60000000-0000-0000-0000-000000000002' AND status='waiting') THEN RAISE EXCEPTION 'branch-B queue ticket mutated'; END IF;
 IF EXISTS (SELECT 1 FROM public.followups WHERE id='50000000-0000-0000-0000-000000000006') THEN RAISE EXCEPTION 'mismatched followup residue'; END IF;
 IF EXISTS (SELECT 1 FROM public.queue_tickets WHERE id='60000000-0000-0000-0000-000000000006') THEN RAISE EXCEPTION 'mismatched queue ticket residue'; END IF;
 IF EXISTS (SELECT 1 FROM public.followups WHERE id='50000000-0000-0000-0000-000000000007') THEN RAISE EXCEPTION 'null-patient cross-branch follow-up residue'; END IF;
 IF EXISTS (SELECT 1 FROM public.queue_tickets WHERE id='60000000-0000-0000-0000-000000000007') THEN RAISE EXCEPTION 'null-patient cross-branch queue residue'; END IF;
END
$test$;
