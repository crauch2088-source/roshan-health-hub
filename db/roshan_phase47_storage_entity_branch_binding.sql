-- Phase 47: bind private clinical Storage paths to authoritative entity rows and parent branches.
-- Candidate only. Replay on disposable PostgreSQL 17 and review before any live application.
-- No Storage configuration, bucket visibility, or live object data is changed by this source file.
BEGIN;

CREATE OR REPLACE FUNCTION private.phase47_storage_entity_branch_matches(_bucket_id text, _path text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_parts text[];
  v_branch_id uuid;
  v_entity_id uuid;
  v_certificate_id integer;
BEGIN
  IF NOT private.phase34_storage_path_valid(_bucket_id, _path) THEN
    RETURN false;
  END IF;

  v_parts := pg_catalog.string_to_array(_path, '/');
  BEGIN
    v_branch_id := v_parts[1]::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN false;
  END;

  CASE _bucket_id
    WHEN 'roshan-lab-reports' THEN
      BEGIN
        v_entity_id := v_parts[3]::uuid;
      EXCEPTION WHEN invalid_text_representation THEN
        RETURN false;
      END;

      RETURN EXISTS (
        SELECT 1
        FROM public.lab_orders AS lo
        JOIN public.patients AS p ON p.id = lo.patient_id
        LEFT JOIN public.visits AS v ON v.id = lo.visit_id
        WHERE lo.id = v_entity_id
          AND lo.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND lo.branch_id = v_branch_id
          AND p.branch_id = v_branch_id
          AND (
            lo.visit_id IS NULL
            OR (
              v.id IS NOT NULL
              AND v.deleted_at IS NULL
              AND v.patient_id = lo.patient_id
              AND COALESCE(v.branch_id, p.branch_id) = v_branch_id
            )
          )
      );

    WHEN 'roshan-medical-certificates' THEN
      IF v_parts[3] !~ '^[1-9][0-9]{0,9}$' THEN
        RETURN false;
      END IF;
      BEGIN
        v_certificate_id := v_parts[3]::integer;
      EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
        RETURN false;
      END;

      -- medical_certificates has no branch_id column: its authoritative branch is
      -- the same-patient visit, with the patient's branch as the visit fallback.
      RETURN EXISTS (
        SELECT 1
        FROM public.medical_certificates AS c
        JOIN public.patients AS p ON p.id = c.patient_id
        JOIN public.visits AS v ON v.id = c.visit_id
        WHERE c.id = v_certificate_id
          AND c.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND v.deleted_at IS NULL
          AND v.patient_id = c.patient_id
          AND p.branch_id = v_branch_id
          AND COALESCE(v.branch_id, p.branch_id) = v_branch_id
      );

    WHEN 'roshan-clinical-attachments' THEN
      BEGIN
        v_entity_id := v_parts[3]::uuid;
      EXCEPTION WHEN invalid_text_representation THEN
        RETURN false;
      END;

      -- Attachments may be patient-linked, visit-linked, or linked to both.
      -- At least one parent must exist; when both are present they must identify
      -- the same patient and resolve to the path's branch.
      RETURN EXISTS (
        SELECT 1
        FROM public.attachments AS a
        WHERE a.id = v_entity_id
          AND a.deleted_at IS NULL
          AND (a.patient_id IS NOT NULL OR a.visit_id IS NOT NULL)
          AND (
            a.patient_id IS NULL
            OR EXISTS (
              SELECT 1
              FROM public.patients AS p
              WHERE p.id = a.patient_id
                AND p.deleted_at IS NULL
                AND p.branch_id = v_branch_id
            )
          )
          AND (
            a.visit_id IS NULL
            OR EXISTS (
              SELECT 1
              FROM public.visits AS v
              JOIN public.patients AS p ON p.id = v.patient_id
              WHERE v.id = a.visit_id
                AND v.deleted_at IS NULL
                AND p.deleted_at IS NULL
                AND (a.patient_id IS NULL OR v.patient_id = a.patient_id)
                AND p.branch_id = v_branch_id
                AND COALESCE(v.branch_id, p.branch_id) = v_branch_id
            )
          )
      );
    ELSE
      RETURN false;
  END CASE;
END;
$function$;

REVOKE ALL ON FUNCTION private.phase47_storage_entity_branch_matches(text, text)
  FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION private.phase47_storage_entity_branch_matches(text, text) IS
  'Fails closed unless a private clinical Storage path resolves to an existing lab order, medical certificate, or attachment whose authoritative patient/visit branch matches the path prefix.';

-- Keep the existing bucket permission contract, but add entity-to-branch binding
-- to the restrictive Storage boundary for SELECT, INSERT, UPDATE, and DELETE.
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
  IF _bucket_id NOT IN (
    'roshan-lab-reports',
    'roshan-medical-certificates',
    'roshan-clinical-attachments'
  ) THEN
    RETURN true;
  END IF;

  IF NOT private.phase33_branch_access_from_path(_path) THEN
    RETURN false;
  END IF;
  IF NOT private.phase34_storage_path_valid(_bucket_id, _path) THEN
    RETURN false;
  END IF;
  IF NOT private.phase47_storage_entity_branch_matches(_bucket_id, _path) THEN
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

REVOKE ALL ON FUNCTION private.phase33_storage_access(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.phase33_storage_access(text, text, text) TO authenticated, service_role;

COMMIT;
