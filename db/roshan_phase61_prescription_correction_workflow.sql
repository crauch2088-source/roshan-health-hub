-- Phase 61: auditable pharmacist-to-prescriber correction workflow.
-- Candidate only: run in disposable PostgreSQL 17; no hosted apply.
BEGIN;

CREATE TABLE public.prescription_correction_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 request_key uuid NOT NULL UNIQUE,
 prescription_id uuid NOT NULL REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
 prescription_item_id uuid NOT NULL REFERENCES public.prescription_items(id) ON DELETE RESTRICT,
 patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE RESTRICT,
 visit_id uuid NOT NULL REFERENCES public.visits(id) ON DELETE RESTRICT,
 branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE RESTRICT,
 prescriber_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
 requested_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
 item_snapshot jsonb NOT NULL CHECK(jsonb_typeof(item_snapshot)='object'),
 reason_code text NOT NULL CHECK(reason_code IN('unlinked_free_text','ambiguous_name','strength_mismatch','dosage_form_mismatch','other')),
 reason_text text NOT NULL CHECK(length(btrim(reason_text)) BETWEEN 1 AND 1000),
 status text NOT NULL DEFAULT 'open' CHECK(status IN('open','resolved','rejected')),
 resolved_by uuid REFERENCES public.users(id) ON DELETE RESTRICT,
 resolved_at timestamptz,
 disposition text CHECK(disposition IN('replace_item','cancel_and_reissue','reject')),
 replacement_prescription_id uuid REFERENCES public.prescriptions(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((status='open' AND resolved_by IS NULL AND resolved_at IS NULL AND disposition IS NULL)
    OR (status<>'open' AND resolved_by IS NOT NULL AND resolved_at IS NOT NULL AND disposition IS NOT NULL))
);
CREATE UNIQUE INDEX prescription_correction_one_open_request_per_item
 ON public.prescription_correction_requests(prescription_item_id) WHERE status='open';
CREATE INDEX prescription_correction_branch_status_created_idx
 ON public.prescription_correction_requests(branch_id,status,created_at DESC);
CREATE INDEX prescription_correction_prescriber_status_created_idx
 ON public.prescription_correction_requests(prescriber_id,status,created_at DESC);

CREATE TABLE public.prescription_correction_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 request_id uuid NOT NULL REFERENCES public.prescription_correction_requests(id) ON DELETE RESTRICT,
 event_type text NOT NULL CHECK(event_type IN('request_created','item_replaced','prescription_cancelled_and_reissued','request_rejected')),
 actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
 occurred_at timestamptz NOT NULL DEFAULT now(),
 before_snapshot jsonb, after_snapshot jsonb, reason_text text, disposition text,
 replacement_prescription_id uuid REFERENCES public.prescriptions(id) ON DELETE RESTRICT
);
CREATE INDEX prescription_correction_events_request_time_idx
 ON public.prescription_correction_events(request_id,occurred_at,id);

-- Strict branch equality: unlike app_has_branch_access(), no super-admin bypass.
CREATE OR REPLACE FUNCTION private.current_user_assigned_branch_access(_branch_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $$
 SELECT EXISTS(SELECT 1 FROM public.users u WHERE u.id=public.current_app_user_id()
   AND u.branch_id=_branch_id AND COALESCE(u.active,true) IS TRUE AND u.deleted_at IS NULL)
$$;

CREATE OR REPLACE FUNCTION private.guard_prescription_correction_request_immutable()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF (to_jsonb(NEW)-ARRAY['status','resolved_by','resolved_at','disposition','replacement_prescription_id','updated_at'])
    IS DISTINCT FROM
    (to_jsonb(OLD)-ARRAY['status','resolved_by','resolved_at','disposition','replacement_prescription_id','updated_at']) THEN
   RAISE EXCEPTION 'prescription_correction_request_snapshot_is_immutable' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION private.prevent_prescription_correction_event_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$ BEGIN RAISE EXCEPTION 'prescription_correction_events_are_append_only' USING ERRCODE='42501'; END $$;

CREATE TRIGGER prescription_correction_request_immutable BEFORE UPDATE
 ON public.prescription_correction_requests FOR EACH ROW
 EXECUTE FUNCTION private.guard_prescription_correction_request_immutable();
CREATE TRIGGER prescription_correction_events_append_only BEFORE UPDATE OR DELETE
 ON public.prescription_correction_events FOR EACH ROW
 EXECUTE FUNCTION private.prevent_prescription_correction_event_mutation();

ALTER TABLE public.prescription_correction_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_correction_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY prescription_correction_requests_select ON public.prescription_correction_requests
 FOR SELECT TO authenticated USING(
  private.current_user_assigned_branch_access(branch_id)
  AND (public.app_has_perm('pharmacy.read')
    OR (public.app_has_perm('emr.read') AND prescriber_id=public.current_app_user_id()))
);
CREATE POLICY prescription_correction_events_select ON public.prescription_correction_events
 FOR SELECT TO authenticated USING(EXISTS(
  SELECT 1 FROM public.prescription_correction_requests r
  WHERE r.id=prescription_correction_events.request_id
   AND private.current_user_assigned_branch_access(r.branch_id)
   AND (public.app_has_perm('pharmacy.read')
    OR (public.app_has_perm('emr.read') AND r.prescriber_id=public.current_app_user_id()))
));

REVOKE ALL ON public.prescription_correction_requests,public.prescription_correction_events FROM PUBLIC,anon,authenticated,service_role,authenticator;
GRANT SELECT ON public.prescription_correction_requests,public.prescription_correction_events TO authenticated;

CREATE OR REPLACE FUNCTION public.create_prescription_correction_request(
 p_prescription_id uuid,p_item_id uuid,p_reason_code text,p_reason_text text,p_request_key uuid
) RETURNS TABLE(request_id uuid,status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
 v_uid uuid:=public.current_app_user_id(); v_branch uuid;
 v_old public.prescription_correction_requests; v_rx public.prescriptions;
 v_visit public.visits; v_item public.prescription_items; v_snap jsonb; v_id uuid;
BEGIN
 IF v_uid IS NULL OR NOT public.app_has_perm('pharmacy.update') THEN RAISE EXCEPTION 'insufficient_permission' USING ERRCODE='42501'; END IF;
 IF p_request_key IS NULL OR p_prescription_id IS NULL OR p_item_id IS NULL OR p_reason_code IS NULL
  OR p_reason_code NOT IN('unlinked_free_text','ambiguous_name','strength_mismatch','dosage_form_mismatch','other')
  OR length(btrim(COALESCE(p_reason_text,''))) NOT BETWEEN 1 AND 1000 THEN
  RAISE EXCEPTION 'invalid_correction_request' USING ERRCODE='22023';
 END IF;
 SELECT r.* INTO v_old FROM public.prescription_correction_requests r WHERE r.request_key=p_request_key;
 IF FOUND THEN
  IF v_old.prescription_id IS DISTINCT FROM p_prescription_id OR v_old.prescription_item_id IS DISTINCT FROM p_item_id
   OR v_old.requested_by IS DISTINCT FROM v_uid OR v_old.reason_code IS DISTINCT FROM p_reason_code
   OR v_old.reason_text IS DISTINCT FROM btrim(p_reason_text) THEN
   RAISE EXCEPTION 'correction_request_idempotency_key_conflict' USING ERRCODE='23505';
  END IF;
  RETURN QUERY SELECT v_old.id,v_old.status; RETURN;
 END IF;
 SELECT u.branch_id INTO v_branch FROM public.users u
 WHERE u.id=v_uid AND COALESCE(u.active,true) IS TRUE AND u.deleted_at IS NULL;
 IF NOT FOUND OR v_branch IS NULL THEN RAISE EXCEPTION 'active_user_branch_required' USING ERRCODE='42501'; END IF;
 -- Parent -> item -> request is the shared lock order for create and resolution.
 SELECT p.* INTO v_rx FROM public.prescriptions p
 WHERE p.id=p_prescription_id AND p.deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR v_rx.status IS DISTINCT FROM 'pending' THEN RAISE EXCEPTION 'prescription_not_pending' USING ERRCODE='22023'; END IF;
 IF COALESCE(v_rx.is_external,false) OR v_rx.visit_id IS NULL OR v_rx.branch_id IS NULL
  OR v_rx.prescribed_by IS NULL OR v_rx.branch_id IS DISTINCT FROM v_branch THEN
  RAISE EXCEPTION 'prescription_not_eligible_or_cross_branch' USING ERRCODE='42501';
 END IF;
 SELECT v.* INTO v_visit FROM public.visits v WHERE v.id=v_rx.visit_id AND v.patient_id=v_rx.patient_id
  AND v.branch_id=v_rx.branch_id AND v.deleted_at IS NULL AND v.status IS DISTINCT FROM 'cancelled' FOR KEY SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'active_visit_link_required' USING ERRCODE='23514'; END IF;
 SELECT i.* INTO v_item FROM public.prescription_items i
 WHERE i.id=p_item_id AND i.prescription_id=p_prescription_id AND i.deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'active_prescription_item_not_found' USING ERRCODE='22023'; END IF;
 -- Recheck after acquiring parent/item locks so concurrent retries with the same key are idempotent.
 SELECT r.* INTO v_old FROM public.prescription_correction_requests r WHERE r.request_key=p_request_key FOR UPDATE;
 IF FOUND THEN
  IF v_old.prescription_id IS DISTINCT FROM p_prescription_id OR v_old.prescription_item_id IS DISTINCT FROM p_item_id
   OR v_old.requested_by IS DISTINCT FROM v_uid OR v_old.reason_code IS DISTINCT FROM p_reason_code
   OR v_old.reason_text IS DISTINCT FROM btrim(p_reason_text) THEN
   RAISE EXCEPTION 'correction_request_idempotency_key_conflict' USING ERRCODE='23505';
  END IF;
  RETURN QUERY SELECT v_old.id,v_old.status; RETURN;
 END IF;
 IF v_item.medicine_id IS NOT NULL THEN RAISE EXCEPTION 'item_not_unlinked' USING ERRCODE='22023'; END IF;
 IF COALESCE(v_item.is_dispensed,false) OR COALESCE(v_item.dispensed_quantity,0)>0 THEN
  RAISE EXCEPTION 'prescription_item_already_dispensed' USING ERRCODE='22023';
 END IF;
 v_snap:=jsonb_build_object('id',v_item.id,'prescription_id',v_item.prescription_id,'medicine_id',v_item.medicine_id,
  'medication_name',v_item.medication_name,'quantity',v_item.quantity,'dose',v_item.dose,'dosage',v_item.dosage,
  'frequency',v_item.frequency,'duration',v_item.duration,'instructions',v_item.instructions,
  'dosage_form',v_item.dosage_form,'route',v_item.route,'unit_price',v_item.unit_price);
 BEGIN
  INSERT INTO public.prescription_correction_requests(request_key,prescription_id,prescription_item_id,
   patient_id,visit_id,branch_id,prescriber_id,requested_by,item_snapshot,reason_code,reason_text)
  VALUES(p_request_key,p_prescription_id,p_item_id,v_rx.patient_id,v_rx.visit_id,v_rx.branch_id,
   v_rx.prescribed_by,v_uid,v_snap,p_reason_code,btrim(p_reason_text)) RETURNING id INTO v_id;
 EXCEPTION WHEN unique_violation THEN
  SELECT r.* INTO v_old FROM public.prescription_correction_requests r WHERE r.request_key=p_request_key;
  IF FOUND THEN
   IF v_old.prescription_id IS DISTINCT FROM p_prescription_id OR v_old.prescription_item_id IS DISTINCT FROM p_item_id
    OR v_old.requested_by IS DISTINCT FROM v_uid OR v_old.reason_code IS DISTINCT FROM p_reason_code
    OR v_old.reason_text IS DISTINCT FROM btrim(p_reason_text) THEN
    RAISE EXCEPTION 'correction_request_idempotency_key_conflict' USING ERRCODE='23505';
   END IF;
   RETURN QUERY SELECT v_old.id,v_old.status; RETURN;
  END IF;
  RAISE EXCEPTION 'correction_request_already_open' USING ERRCODE='23505';
 END;
 INSERT INTO public.prescription_correction_events(request_id,event_type,actor_id,after_snapshot,reason_text)
 VALUES(v_id,'request_created',v_uid,v_snap,btrim(p_reason_text));
 RETURN QUERY SELECT v_id,'open'::text;
END $$;

CREATE OR REPLACE FUNCTION public.resolve_prescription_correction_request(
 p_request_id uuid,p_disposition text,p_medicine_id uuid DEFAULT NULL,p_replacement_items jsonb DEFAULT NULL
) RETURNS TABLE(request_id uuid,status text,replacement_prescription_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
 v_uid uuid:=public.current_app_user_id(); v_branch uuid;
 v_req public.prescription_correction_requests; v_rx public.prescriptions;
 v_item public.prescription_items; v_med public.medicines;
 v_name text; v_price numeric; v_before jsonb; v_after jsonb; v_new_rx uuid;
BEGIN
 IF v_uid IS NULL OR NOT public.app_has_perm('emr.update') THEN RAISE EXCEPTION 'insufficient_permission' USING ERRCODE='42501'; END IF;
 IF p_disposition IS NULL OR p_disposition NOT IN('replace_item','cancel_and_reissue') THEN
  RAISE EXCEPTION 'invalid_correction_disposition' USING ERRCODE='22023';
 END IF;
 SELECT r.* INTO v_req FROM public.prescription_correction_requests r WHERE r.id=p_request_id;
 IF NOT FOUND OR v_req.status IS DISTINCT FROM 'open' THEN RAISE EXCEPTION 'correction_request_not_open' USING ERRCODE='22023'; END IF;
 SELECT p.* INTO v_rx FROM public.prescriptions p WHERE p.id=v_req.prescription_id AND p.deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR v_rx.status IS DISTINCT FROM 'pending' OR COALESCE(v_rx.is_external,false)
  OR v_rx.prescribed_by IS DISTINCT FROM v_uid OR v_rx.prescribed_by IS DISTINCT FROM v_req.prescriber_id
  OR v_rx.branch_id IS DISTINCT FROM v_req.branch_id OR v_rx.patient_id IS DISTINCT FROM v_req.patient_id
  OR v_rx.visit_id IS DISTINCT FROM v_req.visit_id THEN
  RAISE EXCEPTION 'correction_prescriber_or_parent_mismatch' USING ERRCODE='42501';
 END IF;
 SELECT u.branch_id INTO v_branch FROM public.users u
 WHERE u.id=v_uid AND COALESCE(u.active,true) IS TRUE AND u.deleted_at IS NULL;
 IF NOT FOUND OR v_branch IS DISTINCT FROM v_req.branch_id THEN RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.visits v WHERE v.id=v_rx.visit_id AND v.patient_id=v_rx.patient_id
  AND v.branch_id=v_rx.branch_id AND v.deleted_at IS NULL AND v.status IS DISTINCT FROM 'cancelled' FOR KEY SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'active_visit_link_required' USING ERRCODE='23514'; END IF;
 SELECT i.* INTO v_item FROM public.prescription_items i WHERE i.id=v_req.prescription_item_id
  AND i.prescription_id=v_rx.id AND i.deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR COALESCE(v_item.is_dispensed,false) OR COALESCE(v_item.dispensed_quantity,0)>0
  OR v_item.medicine_id IS NOT NULL THEN RAISE EXCEPTION 'correction_snapshot_stale' USING ERRCODE='23514'; END IF;
 SELECT r.* INTO v_req FROM public.prescription_correction_requests r WHERE r.id=p_request_id FOR UPDATE;
 IF NOT FOUND OR v_req.status IS DISTINCT FROM 'open' THEN RAISE EXCEPTION 'correction_request_not_open' USING ERRCODE='22023'; END IF;
 v_before:=jsonb_build_object('id',v_item.id,'prescription_id',v_item.prescription_id,'medicine_id',v_item.medicine_id,
  'medication_name',v_item.medication_name,'quantity',v_item.quantity,'dose',v_item.dose,'dosage',v_item.dosage,
  'frequency',v_item.frequency,'duration',v_item.duration,'instructions',v_item.instructions,
  'dosage_form',v_item.dosage_form,'route',v_item.route,'unit_price',v_item.unit_price);
 IF v_before IS DISTINCT FROM v_req.item_snapshot THEN RAISE EXCEPTION 'correction_snapshot_stale' USING ERRCODE='23514'; END IF;
 IF p_disposition='replace_item' THEN
  IF p_medicine_id IS NULL OR p_replacement_items IS NOT NULL THEN RAISE EXCEPTION 'explicit_replacement_medicine_required' USING ERRCODE='22023'; END IF;
  SELECT m.* INTO v_med FROM public.medicines m WHERE m.id=p_medicine_id AND m.deleted_at IS NULL
   AND COALESCE(m.active,true) AND COALESCE(m.is_active,true) FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'replacement_medicine_inactive' USING ERRCODE='22023'; END IF;
  v_name:=COALESCE(NULLIF(btrim(v_med.name),''),NULLIF(btrim(v_med.generic_name),''));
  v_price:=v_med.selling_price;
  IF v_name IS NULL OR v_price IS NULL OR v_price::text IN('NaN','Infinity','-Infinity')
   OR v_price<0 OR v_price<>round(v_price,2) THEN RAISE EXCEPTION 'replacement_medicine_identity_or_price_invalid' USING ERRCODE='22023'; END IF;
  UPDATE public.prescription_items i SET medicine_id=p_medicine_id,medication_name=v_name,
   unit_price=v_price,updated_by=v_uid,updated_at=now() WHERE i.id=v_item.id;
  SELECT jsonb_build_object('id',i.id,'prescription_id',i.prescription_id,'medicine_id',i.medicine_id,
   'medication_name',i.medication_name,'quantity',i.quantity,'dose',i.dose,'dosage',i.dosage,
   'frequency',i.frequency,'duration',i.duration,'instructions',i.instructions,
   'dosage_form',i.dosage_form,'route',i.route,'unit_price',i.unit_price)
  INTO v_after FROM public.prescription_items i WHERE i.id=v_item.id;
  UPDATE public.prescription_correction_requests r SET status='resolved',resolved_by=v_uid,
   resolved_at=now(),disposition='replace_item',updated_at=now() WHERE r.id=v_req.id;
  INSERT INTO public.prescription_correction_events(request_id,event_type,actor_id,before_snapshot,after_snapshot,disposition)
  VALUES(v_req.id,'item_replaced',v_uid,v_before,v_after,'replace_item');
 ELSE
  IF p_medicine_id IS NOT NULL OR p_replacement_items IS NULL OR jsonb_typeof(p_replacement_items)<>'array'
   OR jsonb_array_length(p_replacement_items)=0 OR NOT public.app_has_perm('emr.create') THEN
   RAISE EXCEPTION 'complete_replacement_order_required' USING ERRCODE='22023';
  END IF;
  v_new_rx:=public.create_prescription_atomic(v_rx.visit_id,false,p_replacement_items);
  UPDATE public.prescriptions p SET status='cancelled',updated_by=v_uid,updated_at=now() WHERE p.id=v_rx.id;
  v_after:=jsonb_build_object('original_prescription_id',v_rx.id,'original_status','cancelled',
   'replacement_prescription_id',v_new_rx,'replacement_items',p_replacement_items);
  UPDATE public.prescription_correction_requests r SET status='resolved',resolved_by=v_uid,
   resolved_at=now(),disposition='cancel_and_reissue',replacement_prescription_id=v_new_rx,updated_at=now()
  WHERE r.id=v_req.id;
  INSERT INTO public.prescription_correction_events(request_id,event_type,actor_id,before_snapshot,after_snapshot,
   disposition,replacement_prescription_id)
  VALUES(v_req.id,'prescription_cancelled_and_reissued',v_uid,
   jsonb_build_object('original_prescription_id',v_rx.id,'item_snapshot',v_before),v_after,
   'cancel_and_reissue',v_new_rx);
 END IF;
 RETURN QUERY SELECT v_req.id,'resolved'::text,v_new_rx;
END $$;

CREATE OR REPLACE FUNCTION public.reject_prescription_correction_request(p_request_id uuid,p_reason text)
RETURNS TABLE(request_id uuid,status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
 v_uid uuid:=public.current_app_user_id(); v_branch uuid;
 v_req public.prescription_correction_requests; v_rx public.prescriptions;
BEGIN
 IF v_uid IS NULL OR NOT public.app_has_perm('emr.update') THEN RAISE EXCEPTION 'insufficient_permission' USING ERRCODE='42501'; END IF;
 IF length(btrim(COALESCE(p_reason,''))) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'rejection_reason_required' USING ERRCODE='22023'; END IF;
 SELECT r.* INTO v_req FROM public.prescription_correction_requests r WHERE r.id=p_request_id;
 IF NOT FOUND OR v_req.status IS DISTINCT FROM 'open' THEN RAISE EXCEPTION 'correction_request_not_open' USING ERRCODE='22023'; END IF;
 SELECT p.* INTO v_rx FROM public.prescriptions p WHERE p.id=v_req.prescription_id AND p.deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND OR v_rx.status IS DISTINCT FROM 'pending' OR COALESCE(v_rx.is_external,false)
  OR v_rx.prescribed_by IS DISTINCT FROM v_uid OR v_rx.prescribed_by IS DISTINCT FROM v_req.prescriber_id
  OR v_rx.branch_id IS DISTINCT FROM v_req.branch_id THEN RAISE EXCEPTION 'correction_prescriber_or_parent_mismatch' USING ERRCODE='42501'; END IF;
 SELECT u.branch_id INTO v_branch FROM public.users u WHERE u.id=v_uid AND COALESCE(u.active,true) AND u.deleted_at IS NULL;
 IF NOT FOUND OR v_branch IS DISTINCT FROM v_req.branch_id THEN RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE='42501'; END IF;
 SELECT r.* INTO v_req FROM public.prescription_correction_requests r WHERE r.id=p_request_id FOR UPDATE;
 IF NOT FOUND OR v_req.status IS DISTINCT FROM 'open' THEN RAISE EXCEPTION 'correction_request_not_open' USING ERRCODE='22023'; END IF;
 UPDATE public.prescription_correction_requests r SET status='rejected',resolved_by=v_uid,
  resolved_at=now(),disposition='reject',updated_at=now() WHERE r.id=v_req.id;
 INSERT INTO public.prescription_correction_events(request_id,event_type,actor_id,before_snapshot,after_snapshot,reason_text,disposition)
 VALUES(v_req.id,'request_rejected',v_uid,v_req.item_snapshot,v_req.item_snapshot,btrim(p_reason),'reject');
 RETURN QUERY SELECT v_req.id,'rejected'::text;
END $$;

REVOKE ALL ON FUNCTION private.current_user_assigned_branch_access(uuid) FROM PUBLIC,anon,service_role,authenticator;
REVOKE ALL ON FUNCTION private.guard_prescription_correction_request_immutable() FROM PUBLIC,anon,authenticated,service_role,authenticator;
REVOKE ALL ON FUNCTION private.prevent_prescription_correction_event_mutation() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.current_user_assigned_branch_access(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.create_prescription_correction_request(uuid,uuid,text,text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.resolve_prescription_correction_request(uuid,text,uuid,jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.reject_prescription_correction_request(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_prescription_correction_request(uuid,uuid,text,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_prescription_correction_request(uuid,text,uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_prescription_correction_request(uuid,text) TO authenticated;

COMMENT ON TABLE public.prescription_correction_requests IS 'Branch-scoped RPC-only pharmacist-to-original-prescriber correction requests.';
COMMENT ON TABLE public.prescription_correction_events IS 'Append-only lifecycle events and before/after snapshots for prescription correction requests.';
COMMIT;
