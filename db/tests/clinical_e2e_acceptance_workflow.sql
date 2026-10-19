-- End-to-end clinical acceptance workflow.
-- Run only on a disposable PostgreSQL 17 CI database after the Phase 31 Expand + Contract SQL.
-- All identities below are synthetic; never point this script at Supabase production.
BEGIN;

INSERT INTO public.branches(id, branch_code, branch_name)
VALUES ('00000000-0000-0000-0000-000000001001','CI-CLIN','CI Clinical Branch');

INSERT INTO public.roles(id, code) VALUES
 ('00000000-0000-0000-0000-000000001101','receptionist'),
 ('00000000-0000-0000-0000-000000001102','doctor'),
 ('00000000-0000-0000-0000-000000001103','lab_technician'),
 ('00000000-0000-0000-0000-000000001104','pharmacist');

INSERT INTO public.permissions(id, code) VALUES
 ('00000000-0000-0000-0000-000000001201','visits.update'),
 ('00000000-0000-0000-0000-000000001202','lab.update'),
 ('00000000-0000-0000-0000-000000001203','certificates.create');

INSERT INTO public.users(id, auth_user_id, active, deleted_at, branch_id, role_id)
VALUES
 ('00000000-0000-0000-0000-000000001301','00000000-0000-0000-0000-000000001401',true,NULL,'00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000001101'),
 ('00000000-0000-0000-0000-000000001302','00000000-0000-0000-0000-000000001402',true,NULL,'00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000001102'),
 ('00000000-0000-0000-0000-000000001303','00000000-0000-0000-0000-000000001403',true,NULL,'00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000001103'),
 ('00000000-0000-0000-0000-000000001304','00000000-0000-0000-0000-000000001404',true,NULL,'00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000001104');

-- Receptionist: authenticated patient registration, visit and queue ticket.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001401',true);
INSERT INTO public.patients(id, branch_id, national_id, deleted_at)
VALUES ('00000000-0000-0000-0000-000000001501','00000000-0000-0000-0000-000000001001','CI-E2E-2026',NULL);
INSERT INTO public.visits(id, branch_id, patient_id, status, deleted_at)
VALUES ('00000000-0000-0000-0000-000000001601','00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000001501','waiting',NULL);
INSERT INTO public.queue_tickets(id, visit_id, patient_id, status, deleted_at)
VALUES ('00000000-0000-0000-0000-000000001701','00000000-0000-0000-0000-000000001601','00000000-0000-0000-0000-000000001501','waiting',NULL);
RESET ROLE;

-- Seed the ordered lab request and its two tests as the disposable database owner.
INSERT INTO public.lab_orders(id, status, patient_id, visit_id, branch_id, deleted_at)
VALUES ('00000000-0000-0000-0000-000000001801','ordered','00000000-0000-0000-0000-000000001501','00000000-0000-0000-0000-000000001601','00000000-0000-0000-0000-000000001001',NULL);
INSERT INTO public.lab_order_items(id, order_id, test_id, status, deleted_at)
VALUES
 ('00000000-0000-0000-0000-000000001901','00000000-0000-0000-0000-000000001801','00000000-0000-0000-0000-000000001911','pending',NULL),
 ('00000000-0000-0000-0000-000000001902','00000000-0000-0000-0000-000000001801','00000000-0000-0000-0000-000000001912','pending',NULL);
INSERT INTO public.lab_parameters(id, code, name) VALUES
 ('00000000-0000-0000-0000-000000001921','CI-P1','Synthetic parameter 1'),
 ('00000000-0000-0000-0000-000000001922','CI-P2','Synthetic parameter 2'),
 ('00000000-0000-0000-0000-000000001923','CI-P3','Synthetic parameter 3');

-- Lab technician: save only the first item. The order must remain open and item 2 pending.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001403',true);
INSERT INTO public.lab_results(id, order_item_id, parameter_id, result_value, numeric_value, deleted_at)
VALUES ('00000000-0000-0000-0000-000000001931','00000000-0000-0000-0000-000000001901','00000000-0000-0000-0000-000000001921','12.4',12.4,NULL);
SELECT public.complete_lab_order_item('00000000-0000-0000-0000-000000001901');
DO $partial$
BEGIN
 IF (SELECT status FROM public.lab_order_items WHERE id='00000000-0000-0000-0000-000000001901') <> 'completed' THEN
   RAISE EXCEPTION 'partial save did not complete item 1';
 END IF;
 IF (SELECT status FROM public.lab_order_items WHERE id='00000000-0000-0000-0000-000000001902') <> 'pending' THEN
   RAISE EXCEPTION 'partial save unexpectedly completed item 2';
 END IF;
 IF (SELECT status FROM public.lab_orders WHERE id='00000000-0000-0000-0000-000000001801') <> 'ordered' THEN
   RAISE EXCEPTION 'partial save closed the parent lab order';
 END IF;
END
$partial$;

-- Enter item 2 results, complete it, then resave item 1: the completed item must be idempotent.
INSERT INTO public.lab_results(id, order_item_id, parameter_id, result_value, numeric_value, deleted_at)
VALUES
 ('00000000-0000-0000-0000-000000001932','00000000-0000-0000-0000-000000001902','00000000-0000-0000-0000-000000001922','5.1',5.1,NULL),
 ('00000000-0000-0000-0000-000000001933','00000000-0000-0000-0000-000000001902','00000000-0000-0000-0000-000000001923','7.8',7.8,NULL);
SELECT public.complete_lab_order_item('00000000-0000-0000-0000-000000001902');
SELECT public.complete_lab_order_item('00000000-0000-0000-0000-000000001901');
UPDATE public.lab_orders SET status='completed' WHERE id='00000000-0000-0000-0000-000000001801';
DO $lab_complete$
BEGIN
 IF EXISTS (SELECT 1 FROM public.lab_order_items WHERE order_id='00000000-0000-0000-0000-000000001801' AND status <> 'completed') THEN
   RAISE EXCEPTION 'lab order has an incomplete item after final save';
 END IF;
 IF (SELECT status FROM public.lab_orders WHERE id='00000000-0000-0000-0000-000000001801') <> 'completed' THEN
   RAISE EXCEPTION 'lab order did not close after all items were completed';
 END IF;
END
$lab_complete$;
RESET ROLE;

-- Doctor: complete visit atomically and issue a visit-linked certificate.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001402',true);
SELECT public.complete_visit_atomic('00000000-0000-0000-0000-000000001601');
SELECT public.create_medical_certificate(
 '00000000-0000-0000-0000-000000001501','Acute viral illness',
 CURRENT_DATE,CURRENT_DATE + 2,'00000000-0000-0000-0000-000000001601'
);
DO $doctor_assert$
DECLARE v_number bigint;
BEGIN
 IF (SELECT status FROM public.visits WHERE id='00000000-0000-0000-0000-000000001601') <> 'completed' THEN
   RAISE EXCEPTION 'visit was not completed';
 END IF;
 IF (SELECT status FROM public.queue_tickets WHERE visit_id='00000000-0000-0000-0000-000000001601') <> 'completed' THEN
   RAISE EXCEPTION 'queue ticket was not completed atomically';
 END IF;
 SELECT certificate_number INTO v_number FROM public.medical_certificates
 WHERE visit_id='00000000-0000-0000-0000-000000001601' AND deleted_at IS NULL;
 IF v_number IS NULL OR v_number <> 1 THEN
   RAISE EXCEPTION 'certificate serial was not generated as expected, got %',v_number;
 END IF;
END
$doctor_assert$;

-- A pharmacist cannot issue a certificate, even though the test permission helper is permissive.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001404',true);
DO $pharmacist_rejection$
DECLARE v_message text;
BEGIN
 BEGIN
   PERFORM public.create_medical_certificate(
     '00000000-0000-0000-0000-000000001501','Unauthorized issue',
     CURRENT_DATE,CURRENT_DATE,'00000000-0000-0000-0000-000000001601');
   RAISE EXCEPTION 'pharmacist certificate issuance unexpectedly succeeded';
 EXCEPTION WHEN insufficient_privilege THEN
   GET STACKED DIAGNOSTICS v_message = MESSAGE_TEXT;
   IF position('only a doctor' IN lower(v_message))=0 THEN RAISE; END IF;
 END;
END
$pharmacist_rejection$;
RESET ROLE;

-- A cancelled visit is rejected by the doctor-specific RPC guard.
INSERT INTO public.visits(id, branch_id, patient_id, status, deleted_at)
VALUES ('00000000-0000-0000-0000-000000001602','00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000001501','cancelled',NULL);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000001402',true);
DO $cancelled_rejection$
DECLARE v_state text;
BEGIN
 BEGIN
   PERFORM public.create_medical_certificate(
     '00000000-0000-0000-0000-000000001501','Cancelled visit',
     CURRENT_DATE,CURRENT_DATE,'00000000-0000-0000-0000-000000001602');
   RAISE EXCEPTION 'certificate for cancelled visit unexpectedly succeeded';
 EXCEPTION WHEN SQLSTATE '22023' THEN
   GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
   IF v_state <> '22023' THEN RAISE; END IF;
 END;
END
$cancelled_rejection$;
RESET ROLE;

ROLLBACK;
