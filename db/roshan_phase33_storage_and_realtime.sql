-- Phase 33 candidate: private clinical Storage buckets and branch-scoped Realtime.
-- Staged for review only; do not apply to production from this branch.
-- Storage object paths must start with <branch UUID>/<resource>/<filename>.
BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('roshan-lab-reports', 'roshan-lab-reports', false, 10485760, ARRAY['application/pdf']::text[]),
  ('roshan-medical-certificates', 'roshan-medical-certificates', false, 10485760, ARRAY['application/pdf']::text[]),
  ('roshan-clinical-attachments', 'roshan-clinical-attachments', false, 20971520,
    ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp']::text[])
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION private.phase33_branch_access_from_path(_path text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  branch_id uuid;
BEGIN
  BEGIN
    branch_id := split_part(_path, '/', 1)::uuid;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RETURN false;
  END;
  RETURN private.app_has_branch_access(branch_id);
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
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  channel_name text;
  branch_path text;
BEGIN
  IF split_part(_topic, ':', 1) <> 'branch'
    OR split_part(_topic, ':', 4) <> '' THEN
    RETURN false;
  END IF;
  channel_name := split_part(_topic, ':', 3);
  branch_path := split_part(_topic, ':', 2);
  IF channel_name = 'queue' THEN
    RETURN public.app_has_perm('queue.read')
      AND private.phase33_branch_access_from_path(branch_path);
  ELSIF channel_name = 'lab' THEN
    RETURN public.app_has_perm('lab.read')
      AND private.phase33_branch_access_from_path(branch_path);
  END IF;
  RETURN false;
END;
$function$;

REVOKE ALL ON FUNCTION private.phase33_branch_access_from_path(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.phase33_storage_access(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.phase33_realtime_topic_access(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.phase33_branch_access_from_path(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.phase33_storage_access(text, text, text) TO authenticated, service_role;
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
  END IF;
END
$publication$;

COMMIT;
