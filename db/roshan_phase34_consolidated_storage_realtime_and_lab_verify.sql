-- Phase 34 consolidated candidate: private clinical Storage, branch-scoped Realtime, atomic lab verification and append-only audit logs.
-- Apply only after the exact review head passes CI and the release gate is approved.
-- Storage paths: <branch UUID>/<entity type>/<entity ID>/<filename>.
BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('roshan-lab-reports', 'roshan-lab-reports', false, 10485760, ARRAY['application/pdf', 'image/png', 'image/jpeg']::text[]),
  ('roshan-medical-certificates', 'roshan-medical-certificates', false, 10485760, ARRAY['application/pdf', 'image/png', 'image/jpeg']::text[]),
  ('roshan-clinical-attachments', 'roshan-clinical-attachments', false, 20971520,
    ARRAY['application/pdf', 'image/png', 'image/jpeg']::text[])
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION private.phase33_branch_access_from_path(_path text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_branch_id uuid;
BEGIN
  BEGIN v_branch_id := pg_catalog.split_part(_path, '/', 1)::uuid;
  EXCEPTION WHEN invalid_text_representation THEN RETURN false;
  END;
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.users AS u
    WHERE u.auth_user_id = auth.uid() AND COALESCE(u.active, true) = true AND u.deleted_at IS NULL
  ) THEN RETURN false; END IF;
  RETURN COALESCE(private.app_has_branch_access(v_branch_id), false);
END;
$function$;

CREATE OR REPLACE FUNCTION private.phase34_storage_path_valid(_bucket_id text, _path text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path TO ''
AS $function$
DECLARE v_parts text[]; v_expected_type text;
BEGIN
  v_parts := pg_catalog.string_to_array(COALESCE(_path, ''), '/');
  IF pg_catalog.array_length(v_parts, 1) IS DISTINCT FROM 4
    OR pg_catalog.btrim(v_parts[1]) = '' OR pg_catalog.btrim(v_parts[2]) = ''
    OR pg_catalog.btrim(v_parts[3]) = '' OR pg_catalog.btrim(v_parts[4]) = '' THEN RETURN false; END IF;
  v_expected_type := CASE _bucket_id
    WHEN 'roshan-lab-reports' THEN 'lab-reports'
    WHEN 'roshan-medical-certificates' THEN 'medical-certificates'
    WHEN 'roshan-clinical-attachments' THEN 'clinical-attachments' ELSE NULL END;
  IF v_expected_type IS NULL OR v_parts[2] <> v_expected_type THEN RETURN false; END IF;
  IF v_parts[3] !~ '^[A-Za-z0-9_-]{1,128}$'
    OR v_parts[4] !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$'
    OR v_parts[4] LIKE '..%' THEN RETURN false; END IF;
  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION private.phase33_storage_access(_bucket_id text, _path text, _action text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  allowed boolean := false;
BEGIN
  IF _bucket_id NOT IN ('roshan-lab-reports', 'roshan-medical-certificates', 'roshan-clinical-attachments') THEN
    RETURN true;
  END IF;
  IF NOT private.phase33_branch_access_from_path(_path) THEN
    RETURN false;
  END IF;
  IF NOT private.phase34_storage_path_valid(_bucket_id, _path) THEN RETURN false; END IF;

  CASE _bucket_id
    WHEN 'roshan-lab-reports' THEN
      allowed := CASE _action
        WHEN 'select' THEN private.app_has_perm('lab.read')
        WHEN 'insert' THEN private.app_has_perm('lab.update')
        WHEN 'update' THEN private.app_has_perm('lab.update')
        WHEN 'delete' THEN private.app_has_perm('lab.delete')
        ELSE false
      END;
    WHEN 'roshan-medical-certificates' THEN
      allowed := CASE _action
        WHEN 'select' THEN private.app_has_perm('certificates.read')
        WHEN 'insert' THEN private.app_has_perm('certificates.create')
        WHEN 'update' THEN private.app_has_perm('certificates.update')
        WHEN 'delete' THEN private.app_has_perm('certificates.delete')
        ELSE false
      END;
    WHEN 'roshan-clinical-attachments' THEN
      allowed := CASE _action
        WHEN 'select' THEN private.app_has_perm('emr.read')
        WHEN 'insert' THEN private.app_has_perm('emr.create') OR private.app_has_perm('emr.update')
        WHEN 'update' THEN private.app_has_perm('emr.update')
        WHEN 'delete' THEN private.app_has_perm('emr.delete')
        ELSE false
      END;
  END CASE;
  RETURN COALESCE(allowed, false);
END;
$function$;

CREATE OR REPLACE FUNCTION private.phase33_realtime_topic_access(_topic text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE channel_name text; branch_path text;
BEGIN
  IF pg_catalog.split_part(_topic, ':', 1) <> 'branch'
    OR pg_catalog.split_part(_topic, ':', 4) <> '' THEN RETURN false; END IF;
  channel_name := pg_catalog.split_part(_topic, ':', 3);
  branch_path := pg_catalog.split_part(_topic, ':', 2);
  IF NOT private.phase33_branch_access_from_path(branch_path) THEN RETURN false; END IF;
  IF channel_name = 'queue' THEN RETURN public.app_has_perm('queue.read');
  ELSIF channel_name = 'lab' THEN RETURN public.app_has_perm('lab.read');
  ELSIF channel_name = 'visits' THEN RETURN public.app_has_perm('visits.read');
  END IF;
  RETURN false;
END;
$function$;

REVOKE ALL ON FUNCTION private.phase33_branch_access_from_path(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.phase33_storage_access(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.phase34_storage_path_valid(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.phase33_realtime_topic_access(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.phase33_branch_access_from_path(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.phase33_storage_access(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.phase34_storage_path_valid(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.phase33_realtime_topic_access(text) TO authenticated, service_role;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DO $storage_policies$
DECLARE
  cfg record;
  act text;
  perm text;
  policy_name text;
  policy_expr text;
  policy_sql text;
BEGIN
  FOR cfg IN
    SELECT *
    FROM (VALUES
      ('roshan-lab-reports', 'phase33_lab_reports', 'lab.read', 'lab.update', 'lab.update', 'lab.delete'),
      ('roshan-medical-certificates', 'phase33_certificates', 'certificates.read', 'certificates.create', 'certificates.update', 'certificates.delete'),
      ('roshan-clinical-attachments', 'phase33_attachments', 'emr.read', 'emr.create', 'emr.update', 'emr.delete')
    ) AS buckets(bucket_id, prefix, read_perm, insert_perm, update_perm, delete_perm)
  LOOP
    FOREACH act IN ARRAY ARRAY['select', 'insert', 'update', 'delete']
    LOOP
      perm := CASE act
        WHEN 'select' THEN cfg.read_perm
        WHEN 'insert' THEN cfg.insert_perm
        WHEN 'update' THEN cfg.update_perm
        ELSE cfg.delete_perm
      END;
      policy_name := cfg.prefix || '_' || act;
      policy_expr := format(
        'bucket_id = %L AND public.app_has_perm(%L) AND private.phase33_branch_access_from_path(storage.objects.name)',
        cfg.bucket_id,
        perm
      );
      IF cfg.bucket_id = 'roshan-clinical-attachments' AND act = 'insert' THEN
        policy_expr := format(
          'bucket_id = %L AND (public.app_has_perm(''emr.create'') OR public.app_has_perm(''emr.update'')) AND private.phase33_branch_access_from_path(storage.objects.name)',
          cfg.bucket_id
        );
      END IF;

      EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', policy_name);
      IF act IN ('select', 'delete') THEN
        policy_sql := format(
          'CREATE POLICY %I ON storage.objects FOR %s TO authenticated USING (%s)',
          policy_name,
          upper(act),
          policy_expr
        );
      ELSIF act = 'insert' THEN
        policy_sql := format(
          'CREATE POLICY %I ON storage.objects FOR INSERT TO authenticated WITH CHECK (%s)',
          policy_name,
          policy_expr
        );
      ELSE
        policy_sql := format(
          'CREATE POLICY %I ON storage.objects FOR UPDATE TO authenticated USING (%s) WITH CHECK (%s)',
          policy_name,
          policy_expr,
          policy_expr
        );
      END IF;
      EXECUTE policy_sql;
    END LOOP;
  END LOOP;
END
$storage_policies$;

-- Restrictive policies AND with any pre-existing permissive Storage policy,
-- preventing a broad policy for another bucket from bypassing this boundary.
DROP POLICY IF EXISTS phase33_storage_select_boundary ON storage.objects;
CREATE POLICY phase33_storage_select_boundary ON storage.objects AS RESTRICTIVE
FOR SELECT TO authenticated
USING (
  bucket_id NOT IN ('roshan-lab-reports', 'roshan-medical-certificates', 'roshan-clinical-attachments')
  OR private.phase33_storage_access(bucket_id, name, 'select')
);
DROP POLICY IF EXISTS phase33_storage_insert_boundary ON storage.objects;
CREATE POLICY phase33_storage_insert_boundary ON storage.objects AS RESTRICTIVE
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id NOT IN ('roshan-lab-reports', 'roshan-medical-certificates', 'roshan-clinical-attachments')
  OR private.phase33_storage_access(bucket_id, name, 'insert')
);
DROP POLICY IF EXISTS phase33_storage_update_boundary ON storage.objects;
CREATE POLICY phase33_storage_update_boundary ON storage.objects AS RESTRICTIVE
FOR UPDATE TO authenticated
USING (
  bucket_id NOT IN ('roshan-lab-reports', 'roshan-medical-certificates', 'roshan-clinical-attachments')
  OR private.phase33_storage_access(bucket_id, name, 'update')
)
WITH CHECK (
  bucket_id NOT IN ('roshan-lab-reports', 'roshan-medical-certificates', 'roshan-clinical-attachments')
  OR private.phase33_storage_access(bucket_id, name, 'update')
);
DROP POLICY IF EXISTS phase33_storage_delete_boundary ON storage.objects;
CREATE POLICY phase33_storage_delete_boundary ON storage.objects AS RESTRICTIVE
FOR DELETE TO authenticated
USING (
  bucket_id NOT IN ('roshan-lab-reports', 'roshan-medical-certificates', 'roshan-clinical-attachments')
  OR private.phase33_storage_access(bucket_id, name, 'delete')
);

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS phase33_clinical_realtime_select ON realtime.messages;
CREATE POLICY phase33_clinical_realtime_select ON realtime.messages
FOR SELECT TO authenticated
USING (private.phase33_realtime_topic_access(realtime.topic()));
DROP POLICY IF EXISTS phase33_clinical_realtime_boundary ON realtime.messages;
CREATE POLICY phase33_clinical_realtime_boundary ON realtime.messages AS RESTRICTIVE
FOR SELECT TO authenticated
USING (private.phase33_realtime_topic_access(realtime.topic()));

-- Existing source-table RLS remains the row boundary for Postgres Changes.
DO $publication$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'queue_tickets'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.queue_tickets';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'lab_orders'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.lab_orders';
    END IF;
    IF to_regclass('public.visits') IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='visits'
    ) THEN EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.visits'; END IF;
  END IF;
END
$publication$;



-- Atomic final lab verification contract.
ALTER TABLE public.lab_orders ADD COLUMN IF NOT EXISTS verified_by uuid, ADD COLUMN IF NOT EXISTS verified_at timestamptz;
ALTER TABLE public.lab_order_items ADD COLUMN IF NOT EXISTS verified_by uuid, ADD COLUMN IF NOT EXISTS verified_at timestamptz;

CREATE OR REPLACE FUNCTION private.phase34_lab_result_mutable(_order_item_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.lab_order_items loi JOIN public.lab_orders lo ON lo.id=loi.order_id
    WHERE loi.id=_order_item_id AND loi.deleted_at IS NULL AND lo.deleted_at IS NULL
      AND loi.status IS DISTINCT FROM 'verified' AND lo.status IS DISTINCT FROM 'verified'
  )
$function$;
REVOKE ALL ON FUNCTION private.phase34_lab_result_mutable(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.phase34_lab_result_mutable(uuid) TO authenticated, service_role;

ALTER TABLE public.lab_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS phase34_lab_orders_no_direct_verify ON public.lab_orders;
CREATE POLICY phase34_lab_orders_no_direct_verify ON public.lab_orders AS RESTRICTIVE
FOR INSERT TO authenticated WITH CHECK (status IS DISTINCT FROM 'verified');
DROP POLICY IF EXISTS phase34_lab_orders_no_verified_update ON public.lab_orders;
CREATE POLICY phase34_lab_orders_no_verified_update ON public.lab_orders AS RESTRICTIVE
FOR UPDATE TO authenticated USING (status IS DISTINCT FROM 'verified') WITH CHECK (status IS DISTINCT FROM 'verified');

DROP POLICY IF EXISTS phase34_lab_items_no_direct_verify ON public.lab_order_items;
CREATE POLICY phase34_lab_items_no_direct_verify ON public.lab_order_items AS RESTRICTIVE
FOR INSERT TO authenticated WITH CHECK (status IS DISTINCT FROM 'verified');
DROP POLICY IF EXISTS phase34_lab_items_no_verified_update ON public.lab_order_items;
CREATE POLICY phase34_lab_items_no_verified_update ON public.lab_order_items AS RESTRICTIVE
FOR UPDATE TO authenticated USING (status IS DISTINCT FROM 'verified') WITH CHECK (status IS DISTINCT FROM 'verified');

DROP POLICY IF EXISTS phase34_lab_results_no_mutation_after_verify_insert ON public.lab_results;
CREATE POLICY phase34_lab_results_no_mutation_after_verify_insert ON public.lab_results AS RESTRICTIVE
FOR INSERT TO authenticated WITH CHECK (private.phase34_lab_result_mutable(order_item_id));
DROP POLICY IF EXISTS phase34_lab_results_no_mutation_after_verify_update ON public.lab_results;
CREATE POLICY phase34_lab_results_no_mutation_after_verify_update ON public.lab_results AS RESTRICTIVE
FOR UPDATE TO authenticated USING (private.phase34_lab_result_mutable(order_item_id)) WITH CHECK (private.phase34_lab_result_mutable(order_item_id));
DROP POLICY IF EXISTS phase34_lab_results_no_mutation_after_verify_delete ON public.lab_results;
CREATE POLICY phase34_lab_results_no_mutation_after_verify_delete ON public.lab_results AS RESTRICTIVE
FOR DELETE TO authenticated USING (private.phase34_lab_result_mutable(order_item_id));

CREATE OR REPLACE FUNCTION public.verify_lab_order(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_user_id uuid; v_status text;
BEGIN
  IF NOT public.app_has_perm('lab.verify') THEN RAISE EXCEPTION 'lab verification permission required' USING ERRCODE='42501'; END IF;
  IF p_order_id IS NULL THEN RAISE EXCEPTION 'lab order is required' USING ERRCODE='22023'; END IF;
  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id=v_user_id AND COALESCE(u.active,true)=true AND u.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE='42501';
  END IF;
  SELECT lo.status INTO v_status FROM public.lab_orders lo
    WHERE lo.id=p_order_id AND lo.deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'lab order not found' USING ERRCODE='P0002'; END IF;
  IF NOT private.app_has_lab_order_item_branch_access(p_order_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE='42501';
  END IF;
  IF v_status='verified' THEN RETURN; END IF;
  IF v_status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'only completed lab orders can be verified' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.lab_order_items loi WHERE loi.order_id=p_order_id AND loi.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'lab order must contain at least one active item' USING ERRCODE='22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.lab_order_items loi WHERE loi.order_id=p_order_id AND loi.deleted_at IS NULL AND loi.status IS DISTINCT FROM 'completed') THEN
    RAISE EXCEPTION 'all active lab items must be completed before verification' USING ERRCODE='22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.lab_order_items loi WHERE loi.order_id=p_order_id AND loi.deleted_at IS NULL
      AND NOT EXISTS (SELECT 1 FROM public.lab_results lr WHERE lr.order_item_id=loi.id AND lr.deleted_at IS NULL
        AND (lr.numeric_value IS NOT NULL OR NULLIF(pg_catalog.btrim(COALESCE(lr.result_value,'')),'') IS NOT NULL))
  ) THEN RAISE EXCEPTION 'every active lab item must contain a result before verification' USING ERRCODE='22023'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.lab_order_items loi
    JOIN public.lab_parameters lp ON lp.test_id=loi.test_id
      AND COALESCE(lp.active,true)=true AND COALESCE(lp.is_active,true)=true AND lp.deleted_at IS NULL
    LEFT JOIN public.lab_results lr ON lr.order_item_id=loi.id AND lr.parameter_id=lp.id AND lr.deleted_at IS NULL
    WHERE loi.order_id=p_order_id AND loi.deleted_at IS NULL
      AND (lr.id IS NULL OR (lr.numeric_value IS NULL AND NULLIF(pg_catalog.btrim(COALESCE(lr.result_value,'')),'') IS NULL))
  ) THEN RAISE EXCEPTION 'every active lab parameter must have a result before verification' USING ERRCODE='22023'; END IF;

  UPDATE public.lab_results lr SET verified_by=v_user_id, verified_at=pg_catalog.now(), updated_by=v_user_id
  FROM public.lab_order_items loi
  WHERE loi.order_id=p_order_id AND loi.deleted_at IS NULL AND lr.order_item_id=loi.id AND lr.deleted_at IS NULL;
  UPDATE public.lab_order_items loi SET status='verified', verified_by=v_user_id,
    verified_at=pg_catalog.now(), updated_by=v_user_id
  WHERE loi.order_id=p_order_id AND loi.deleted_at IS NULL AND loi.status='completed';
  UPDATE public.lab_orders SET status='verified', verified_by=v_user_id,
    verified_at=pg_catalog.now(), updated_by=v_user_id
  WHERE id=p_order_id AND deleted_at IS NULL AND status='completed';
  IF NOT FOUND THEN RAISE EXCEPTION 'lab order verification lost a concurrent state transition' USING ERRCODE='40001'; END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.verify_lab_order(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_lab_order(uuid) TO authenticated, service_role;

-- Append-only audit log enforcement.
CREATE OR REPLACE FUNCTION private.phase34_reject_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'audit_logs is append-only; UPDATE, DELETE and TRUNCATE are prohibited' USING ERRCODE='42501';
END;
$function$;
REVOKE ALL ON FUNCTION private.phase34_reject_audit_mutation() FROM PUBLIC;
DROP TRIGGER IF EXISTS phase34_audit_logs_no_row_mutation ON public.audit_logs;
CREATE TRIGGER phase34_audit_logs_no_row_mutation BEFORE UPDATE OR DELETE ON public.audit_logs
FOR EACH ROW EXECUTE FUNCTION private.phase34_reject_audit_mutation();
DROP TRIGGER IF EXISTS phase34_audit_logs_no_truncate ON public.audit_logs;
CREATE TRIGGER phase34_audit_logs_no_truncate BEFORE TRUNCATE ON public.audit_logs
FOR EACH STATEMENT EXECUTE FUNCTION private.phase34_reject_audit_mutation();
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.audit_logs FROM anon, authenticated;

COMMIT;
