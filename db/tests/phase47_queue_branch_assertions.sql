-- Phase 47 PostgreSQL 17 behavioral assertions.
BEGIN;
DO $schema$
DECLARE v_type text;
BEGIN
 SELECT data_type INTO v_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='queue_tickets' AND column_name='branch_id';
 IF v_type IS DISTINCT FROM 'uuid' THEN RAISE EXCEPTION 'queue_tickets.branch_id must be uuid'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.queue_tickets'::regclass AND conname='queue_tickets_branch_id_fkey' AND contype='f') THEN RAISE EXCEPTION 'queue branch FK missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND tablename='queue_tickets' AND indexname='queue_tickets_branch_visit_date_idx') THEN RAISE EXCEPTION 'queue branch index missing'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='private' AND p.proname IN ('phase47_visit_branch_attribution','phase47_queue_ticket_branch_attribution') AND (p.prosecdef OR COALESCE(p.proconfig,ARRAY[]::text[]) NOT @> ARRAY['search_path=""'])) THEN RAISE EXCEPTION 'branch triggers must be SECURITY INVOKER with empty search_path'; END IF;
 IF has_function_privilege('anon','private.phase47_visit_branch_attribution()','EXECUTE')
 OR has_function_privilege('authenticated','private.phase47_visit_branch_attribution()','EXECUTE')
 OR has_function_privilege('anon','private.phase47_queue_ticket_branch_attribution()','EXECUTE')
 OR has_function_privilege('authenticated','private.phase47_queue_ticket_branch_attribution()','EXECUTE') THEN
  RAISE EXCEPTION 'browser roles must not execute private trigger functions directly';
 END IF;
END
$schema$;

DO $backfill$
BEGIN
 IF (SELECT branch_id FROM public.visits WHERE id='00000000-0000-0000-0000-000000047201') IS DISTINCT FROM '00000000-0000-0000-0000-000000047001'::uuid THEN RAISE EXCEPTION 'single-active-branch patient visit backfill failed'; END IF;
 IF (SELECT branch_id FROM public.queue_tickets WHERE id='00000000-0000-0000-0000-000000047301') IS DISTINCT FROM '00000000-0000-0000-0000-000000047001'::uuid THEN RAISE EXCEPTION 'queue ticket branch backfill failed'; END IF;
 IF (SELECT branch_id FROM public.visits WHERE id='00000000-0000-0000-0000-000000047202') IS NOT NULL THEN RAISE EXCEPTION 'inactive patient branch must not be inferred'; END IF;
 IF (SELECT branch_id FROM public.visits WHERE id='00000000-0000-0000-0000-000000047204') IS NOT NULL THEN RAISE EXCEPTION 'unassigned patient branch must not be guessed'; END IF;
END
$backfill$;

-- New visits inherit the patient branch and new queue tickets inherit the visit branch.
INSERT INTO public.visits(id,patient_id,status)
VALUES ('00000000-0000-0000-0000-000000047211','00000000-0000-0000-0000-000000047101','waiting');
DO $new_visit$
BEGIN
 IF (SELECT branch_id FROM public.visits WHERE id='00000000-0000-0000-0000-000000047211') IS DISTINCT FROM '00000000-0000-0000-0000-000000047001'::uuid THEN RAISE EXCEPTION 'new visit did not inherit patient branch'; END IF;
END
$new_visit$;
INSERT INTO public.queue_tickets(id,visit_id,queue_number,status,visit_date)
VALUES ('00000000-0000-0000-0000-000000047311','00000000-0000-0000-0000-000000047211','Q002','waiting',current_date);
DO $new_ticket$
BEGIN
 IF (SELECT branch_id FROM public.queue_tickets WHERE id='00000000-0000-0000-0000-000000047311') IS DISTINCT FROM '00000000-0000-0000-0000-000000047001'::uuid THEN RAISE EXCEPTION 'new queue ticket did not inherit visit branch'; END IF;
 IF (SELECT patient_id FROM public.queue_tickets WHERE id='00000000-0000-0000-0000-000000047311') IS DISTINCT FROM '00000000-0000-0000-0000-000000047101'::uuid THEN RAISE EXCEPTION 'new queue ticket did not inherit visit patient'; END IF;
END
$new_ticket$;

-- Cross-branch and patient mismatches, missing/deleted visits, and unassigned visits fail closed.
DO $reject$
BEGIN
 BEGIN
  INSERT INTO public.visits(id,patient_id,branch_id,status)
  VALUES ('00000000-0000-0000-0000-000000047212','00000000-0000-0000-0000-000000047101','00000000-0000-0000-0000-000000047002','waiting');
  RAISE EXCEPTION 'cross-branch visit accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO public.visits(id,patient_id,status)
  VALUES ('00000000-0000-0000-0000-000000047213','00000000-0000-0000-0000-000000047103','waiting');
  RAISE EXCEPTION 'branchless patient visit accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO public.queue_tickets(id,visit_id,branch_id,queue_number,status,visit_date)
  VALUES ('00000000-0000-0000-0000-000000047312','00000000-0000-0000-0000-000000047211','00000000-0000-0000-0000-000000047002','Q003','waiting',current_date);
  RAISE EXCEPTION 'cross-branch queue ticket accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO public.queue_tickets(id,visit_id,patient_id,queue_number,status,visit_date)
  VALUES ('00000000-0000-0000-0000-000000047313','00000000-0000-0000-0000-000000047211','00000000-0000-0000-0000-000000047102','Q004','waiting',current_date);
  RAISE EXCEPTION 'queue patient mismatch accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO public.queue_tickets(id,visit_id,queue_number,status,visit_date)
  VALUES ('00000000-0000-0000-0000-000000047314','00000000-0000-0000-0000-000000047203','Q005','waiting',current_date);
  RAISE EXCEPTION 'deleted visit queue ticket accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  INSERT INTO public.queue_tickets(id,visit_id,queue_number,status,visit_date)
  VALUES ('00000000-0000-0000-0000-000000047315','00000000-0000-0000-0000-000000047299','Q006','waiting',current_date);
  RAISE EXCEPTION 'missing visit queue ticket accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
END
$reject$;

-- Legacy unlinked queue ticket metadata updates are allowed, but cannot change identity or branch.
UPDATE public.queue_tickets SET status='cancelled' WHERE id='00000000-0000-0000-0000-000000047302';
DO $legacy$
BEGIN
 BEGIN
  UPDATE public.queue_tickets SET branch_id='00000000-0000-0000-0000-000000047001' WHERE id='00000000-0000-0000-0000-000000047302';
  RAISE EXCEPTION 'legacy unlinked queue ticket accepted arbitrary branch';
 EXCEPTION WHEN check_violation THEN NULL; END;
END
$legacy$;
ROLLBACK;
