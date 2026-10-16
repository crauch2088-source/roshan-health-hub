-- Proposed follow-up migration. Do not apply to production before migration reconciliation and isolated validation.
CREATE TABLE IF NOT EXISTS private.billing_rpc_idempotency (
 request_id uuid PRIMARY KEY, operation text NOT NULL, actor_id uuid NOT NULL,
 request_payload jsonb NOT NULL, result_id uuid, created_at timestamptz NOT NULL DEFAULT pg_catalog.now()
);
REVOKE ALL ON TABLE private.billing_rpc_idempotency FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION public.create_lab_order_with_invoice_atomic(
 p_visit_id uuid, p_priority text, p_notes text, p_test_ids uuid[],
 p_separate_invoice boolean, p_request_id uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
 v_uid uuid := public.current_app_user_id(); v_payload jsonb;
 v_operation text := 'create_lab_order_with_invoice_atomic';
 v_old_operation text; v_old_actor uuid; v_old_payload jsonb; v_result uuid;
BEGIN
 IF v_uid IS NULL OR NOT public.app_has_perm('lab.create') THEN RAISE EXCEPTION 'laboratory order permission denied' USING ERRCODE = '42501'; END IF;
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'idempotency request id is required'; END IF;
 v_payload := pg_catalog.jsonb_build_object('visit_id',p_visit_id,'priority',p_priority,'notes',p_notes,'test_ids',pg_catalog.to_jsonb(p_test_ids),'separate_invoice',p_separate_invoice);
 INSERT INTO private.billing_rpc_idempotency(request_id,operation,actor_id,request_payload) VALUES(p_request_id,v_operation,v_uid,v_payload) ON CONFLICT(request_id) DO NOTHING;
 SELECT operation,actor_id,request_payload,result_id INTO v_old_operation,v_old_actor,v_old_payload,v_result FROM private.billing_rpc_idempotency WHERE request_id=p_request_id FOR UPDATE;
 IF v_old_operation IS DISTINCT FROM v_operation OR v_old_actor IS DISTINCT FROM v_uid OR v_old_payload IS DISTINCT FROM v_payload THEN RAISE EXCEPTION 'idempotency key reused with different request'; END IF;
 IF v_result IS NOT NULL THEN RETURN v_result; END IF;
 v_result := public.create_lab_order_with_invoice_atomic(p_visit_id,p_priority,p_notes,p_test_ids,p_separate_invoice);
 UPDATE private.billing_rpc_idempotency SET result_id=v_result WHERE request_id=p_request_id;
 RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid,text,text,uuid[],boolean,uuid) TO authenticated;
