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

-- Validate the branch path before casting; this avoids malformed paths raising
-- UUID errors and avoids depending on caller-visible rows from public.branches.
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

REVOKE ALL ON FUNCTION private.phase33_branch_access_from_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.phase33_branch_access_from_path(text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.phase33_branch_access_from_path(text) TO service_role;

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

-- Private Broadcast/Presence subscriptions. Browser clients can receive queue/lab
-- notifications only for their own branch and permission; no browser INSERT policy
-- is created, so clients cannot publish arbitrary clinical events.
ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS phase33_clinical_realtime_select ON realtime.messages;
CREATE POLICY phase33_clinical_realtime_select
ON realtime.messages
FOR SELECT
TO authenticated
USING (
  (
    split_part(realtime.topic(), ':', 1) = 'branch'
    AND split_part(realtime.topic(), ':', 3) = 'queue'
    AND public.app_has_perm('queue.read')
    AND private.phase33_branch_access_from_path(split_part(realtime.topic(), ':', 2))
  )
  OR
  (
    split_part(realtime.topic(), ':', 1) = 'branch'
    AND split_part(realtime.topic(), ':', 3) = 'lab'
    AND public.app_has_perm('lab.read')
    AND private.phase33_branch_access_from_path(split_part(realtime.topic(), ':', 2))
  )
);

-- Existing source-table RLS remains the row boundary for Postgres Changes.
-- Add tables to the standard publication only if it exists and the table is absent.
DO $publication$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'queue_tickets'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.queue_tickets';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'lab_orders'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.lab_orders';
    END IF;
  END IF;
END
$publication$;

COMMIT;
