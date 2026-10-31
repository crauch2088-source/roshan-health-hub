-- Disposable PostgreSQL 17 assertions for Phase 47 Storage entity/branch binding.
-- Every synthetic row and temporary privilege grant is rolled back.
BEGIN;

GRANT INSERT, UPDATE, DELETE ON storage.objects TO authenticated;

SET LOCAL ROLE service_role;

INSERT INTO public.branches(id, branch_code, branch_name)
VALUES
  ('00000000-0000-0000-0000-000000003301', 'CI-P47-A', 'Phase 47 A'),
  ('00000000-0000-0000-0000-000000003302', 'CI-P47-B', 'Phase 47 B');

INSERT INTO public.roles(id, name, code)
VALUES
  ('00000000-0000-0000-0000-000000003311', 'Phase 47 Storage writer', 'phase47_storage_writer'),
  ('00000000-0000-0000-0000-000000003312', 'Phase 47 no Storage access', 'phase47_storage_no_access')
ON CONFLICT DO NOTHING;

INSERT INTO public.permissions(id, code, name)
VALUES
  ('00000000-0000-0000-0000-000000003321', 'lab.read', 'Lab read'),
  ('00000000-0000-0000-0000-000000003322', 'lab.update', 'Lab update'),
  ('00000000-0000-0000-0000-000000003323', 'lab.delete', 'Lab delete'),
  ('00000000-0000-0000-0000-000000003324', 'certificates.read', 'Certificates read'),
  ('00000000-0000-0000-0000-000000003325', 'certificates.create', 'Certificates create'),
  ('00000000-0000-0000-0000-000000003326', 'certificates.update', 'Certificates update'),
  ('00000000-0000-0000-0000-000000003327', 'certificates.delete', 'Certificates delete'),
  ('00000000-0000-0000-0000-000000003328', 'emr.read', 'EMR read'),
  ('00000000-0000-0000-0000-000000003329', 'emr.create', 'EMR create'),
  ('00000000-0000-0000-0000-000000003330', 'emr.update', 'EMR update'),
  ('00000000-0000-0000-0000-000000003331', 'emr.delete', 'EMR delete')
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions(role_id, permission_id)
SELECT '00000000-0000-0000-0000-000000003311'::uuid, p.id
FROM public.permissions AS p
WHERE p.code IN (
  'lab.read', 'lab.update', 'lab.delete',
  'certificates.read', 'certificates.create', 'certificates.update', 'certificates.delete',
  'emr.read', 'emr.create', 'emr.update', 'emr.delete'
)
ON CONFLICT DO NOTHING;

INSERT INTO auth.users(id)
VALUES
  ('00000000-0000-0000-0000-000000003341'),
  ('00000000-0000-0000-0000-000000003342')
ON CONFLICT DO NOTHING;

INSERT INTO public.users(id, auth_user_id, active, deleted_at, branch_id, role_id, full_name)
VALUES
  ('00000000-0000-0000-0000-000000003331', '00000000-0000-0000-0000-000000003341', true, NULL,
   '00000000-0000-0000-0000-000000003301', '00000000-0000-0000-0000-000000003311', 'Phase 47 User A'),
  ('00000000-0000-0000-0000-000000003332', '00000000-0000-0000-0000-000000003342', true, NULL,
   '00000000-0000-0000-0000-000000003302', '00000000-0000-0000-0000-000000003312', 'Phase 47 User B');

INSERT INTO public.patients(id, branch_id, mrn, full_name, gender)
VALUES
  ('00000000-0000-0000-0000-000000003365', '00000000-0000-0000-0000-000000003301', 'CI-P47-A', 'Synthetic Patient A', 'unknown'),
  ('00000000-0000-0000-0000-000000003375', '00000000-0000-0000-0000-000000003302', 'CI-P47-B', 'Synthetic Patient B', 'unknown');

INSERT INTO public.visits(id, branch_id, patient_id, status)
VALUES
  ('00000000-0000-0000-0000-000000003381', '00000000-0000-0000-0000-000000003301', '00000000-0000-0000-0000-000000003365', 'waiting'),
  ('00000000-0000-0000-0000-000000003382', '00000000-0000-0000-0000-000000003302', '00000000-0000-0000-0000-000000003375', 'waiting');

INSERT INTO public.lab_orders(id, patient_id, visit_id, ordered_by, status, branch_id)
VALUES
  ('00000000-0000-0000-0000-000000003361', '00000000-0000-0000-0000-000000003365', '00000000-0000-0000-0000-000000003381', '00000000-0000-0000-0000-000000003331', 'completed', '00000000-0000-0000-0000-000000003301'),
  ('00000000-0000-0000-0000-000000003362', '00000000-0000-0000-0000-000000003375', '00000000-0000-0000-0000-000000003382', '00000000-0000-0000-0000-000000003332', 'completed', '00000000-0000-0000-0000-000000003302'),
  ('00000000-0000-0000-0000-000000003378', '00000000-0000-0000-0000-000000003365', '00000000-0000-0000-0000-000000003382', '00000000-0000-0000-0000-000000003331', 'completed', '00000000-0000-0000-0000-000000003301');

INSERT INTO public.medical_certificates(id, certificate_number, patient_id, doctor_id, diagnosis, start_date, end_date, visit_id)
VALUES
  (3363, 90001, '00000000-0000-0000-0000-000000003365', '00000000-0000-0000-0000-000000003331', 'Synthetic certificate A', DATE '2026-10-31', DATE '2026-10-31', '00000000-0000-0000-0000-000000003381'),
  (3364, 90002, '00000000-0000-0000-0000-000000003375', '00000000-0000-0000-0000-000000003332', 'Synthetic certificate B', DATE '2026-10-31', DATE '2026-10-31', '00000000-0000-0000-0000-000000003382'),
  (3365, 90003, '00000000-0000-0000-0000-000000003365', '00000000-0000-0000-0000-000000003331', 'Wrong-parent certificate', DATE '2026-10-31', DATE '2026-10-31', '00000000-0000-0000-0000-000000003382');

INSERT INTO public.attachments(id, patient_id, visit_id, file_name, storage_path, uploaded_by)
VALUES
  ('00000000-0000-0000-0000-000000003364', '00000000-0000-0000-0000-000000003365', '00000000-0000-0000-0000-000000003381', 'attachment-a.pdf', NULL, '00000000-0000-0000-0000-000000003331'),
  ('00000000-0000-0000-0000-000000003376', '00000000-0000-0000-0000-000000003375', '00000000-0000-0000-0000-000000003382', 'attachment-b.pdf', NULL, '00000000-0000-0000-0000-000000003332'),
  ('00000000-0000-0000-0000-000000003377', '00000000-0000-0000-0000-000000003365', '00000000-0000-0000-0000-000000003382', 'wrong-parent.pdf', NULL, '00000000-0000-0000-0000-000000003331');

-- Seed one pre-existing object per bucket for each branch. Explicit IDs keep
-- the UPDATE regression deterministic; every object and row is synthetic and rolled back.
INSERT INTO storage.objects(id, bucket_id, name)
VALUES
  ('00000000-0000-0000-0000-000000003351', 'roshan-lab-reports',
   '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003361/original.pdf'),
  ('00000000-0000-0000-0000-000000003352', 'roshan-lab-reports',
   '00000000-0000-0000-0000-000000003302/lab-reports/00000000-0000-0000-0000-000000003362/original.pdf'),
  ('00000000-0000-0000-0000-000000003353', 'roshan-medical-certificates',
   '00000000-0000-0000-0000-000000003301/medical-certificates/3363/original.pdf'),
  ('00000000-0000-0000-0000-000000003354', 'roshan-clinical-attachments',
   '00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003364/original.pdf'),
  ('00000000-0000-0000-0000-000000003355', 'roshan-medical-certificates',
   '00000000-0000-0000-0000-000000003302/medical-certificates/3364/other.pdf'),
  ('00000000-0000-0000-0000-000000003356', 'roshan-clinical-attachments',
   '00000000-0000-0000-0000-000000003302/clinical-attachments/00000000-0000-0000-0000-000000003376/other.pdf');


-- Seed privileged objects with forged/missing entity references under a branch-A prefix.
-- SELECT must reject these even though the branch prefix itself belongs to the reader.
INSERT INTO storage.objects(bucket_id, name)
VALUES
  ('roshan-lab-reports', '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003362/forged-existing.pdf'),
  ('roshan-lab-reports', '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003399/orphan-existing.pdf'),
  ('roshan-medical-certificates', '00000000-0000-0000-0000-000000003301/medical-certificates/3364/forged-existing.pdf'),
  ('roshan-medical-certificates', '00000000-0000-0000-0000-000000003301/medical-certificates/3399/orphan-existing.pdf'),
  ('roshan-clinical-attachments', '00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003376/forged-existing.pdf'),
  ('roshan-clinical-attachments', '00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003398/orphan-existing.pdf');

RESET ROLE;

DO $phase47_catalog$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = 'phase47_storage_entity_branch_matches'
      AND p.prosecdef
      AND COALESCE(p.proconfig, ARRAY[]::text[]) @> ARRAY['search_path=""']
  ) THEN
    RAISE EXCEPTION 'Storage entity helper must be SECURITY DEFINER with empty search_path';
  END IF;

  IF has_function_privilege('anon', 'private.phase47_storage_entity_branch_matches(text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.phase47_storage_entity_branch_matches(text,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'private.phase47_storage_entity_branch_matches(text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Storage entity helper must not be directly executable by browser or service roles';
  END IF;
END
$phase47_catalog$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000003341', true);

-- Matching-branch entities are allowed for all three bucket path contracts.
DO $phase47_valid_uploads$
BEGIN
  INSERT INTO storage.objects(bucket_id, name)
  VALUES ('roshan-lab-reports',
    '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003361/upload.pdf');

  INSERT INTO storage.objects(bucket_id, name)
  VALUES ('roshan-medical-certificates',
    '00000000-0000-0000-0000-000000003301/medical-certificates/3363/upload.pdf');

  INSERT INTO storage.objects(bucket_id, name)
  VALUES ('roshan-clinical-attachments',
    '00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003364/upload.pdf');
END
$phase47_valid_uploads$;

-- A branch-A writer cannot place a branch-B entity under a branch-A prefix.
DO $phase47_reject_forged$
DECLARE
  v_blocked boolean;
BEGIN
  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-lab-reports',
      '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003362/forged.pdf');
    RAISE EXCEPTION 'branch-A writer uploaded a branch-B lab order';
  EXCEPTION WHEN insufficient_privilege THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'branch-B lab entity was not rejected'; END IF;

  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-medical-certificates',
      '00000000-0000-0000-0000-000000003301/medical-certificates/3364/forged.pdf');
    RAISE EXCEPTION 'branch-A writer uploaded a branch-B certificate';
  EXCEPTION WHEN insufficient_privilege THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'branch-B certificate was not rejected'; END IF;

  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-clinical-attachments',
      '00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003376/forged.pdf');
    RAISE EXCEPTION 'branch-A writer uploaded a branch-B attachment';
  EXCEPTION WHEN insufficient_privilege THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'branch-B attachment was not rejected'; END IF;
END
$phase47_reject_forged$;

-- Well-formed paths that reference missing rows fail closed.
DO $phase47_reject_missing$
DECLARE
  v_blocked boolean;
BEGIN
  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-lab-reports',
      '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003399/missing.pdf');
    RAISE EXCEPTION 'missing lab order was accepted';
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'missing lab order was not rejected'; END IF;

  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-medical-certificates',
      '00000000-0000-0000-0000-000000003301/medical-certificates/3399/missing.pdf');
    RAISE EXCEPTION 'missing certificate was accepted';
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'missing certificate was not rejected'; END IF;

  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-clinical-attachments',
      '00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003398/missing.pdf');
    RAISE EXCEPTION 'missing attachment was accepted';
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'missing attachment was not rejected'; END IF;
END
$phase47_reject_missing$;

-- Existing entity rows with mismatched patient/visit parents are rejected even when
-- the entity's own branch column (lab_orders) or patient branch (certificate/attachment) matches.
DO $phase47_reject_parent_mismatch$
DECLARE
  v_blocked boolean;
BEGIN
  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-lab-reports',
      '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003378/wrong-parent.pdf');
    RAISE EXCEPTION 'lab order with a cross-patient visit was accepted';
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'cross-patient lab order was not rejected'; END IF;

  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-medical-certificates',
      '00000000-0000-0000-0000-000000003301/medical-certificates/3365/wrong-parent.pdf');
    RAISE EXCEPTION 'certificate with a cross-patient visit was accepted';
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'cross-patient certificate was not rejected'; END IF;

  v_blocked := false;
  BEGIN
    INSERT INTO storage.objects(bucket_id, name)
    VALUES ('roshan-clinical-attachments',
      '00000000-0000-0000-0000-000000003301/clinical-attachments/00000000-0000-0000-0000-000000003377/wrong-parent.pdf');
    RAISE EXCEPTION 'attachment with a cross-patient visit was accepted';
  EXCEPTION WHEN insufficient_privilege THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'cross-patient attachment was not rejected'; END IF;
END
$phase47_reject_parent_mismatch$;

-- The existing same-branch read behavior is retained; branch-B objects remain hidden.
DO $phase47_read_visibility$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM storage.objects WHERE bucket_id = 'roshan-lab-reports';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'branch-A reader should see its two lab objects, got %', v_count;
  END IF;
  SELECT count(*) INTO v_count FROM storage.objects WHERE bucket_id = 'roshan-medical-certificates';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'branch-A reader should see its two certificate objects, got %', v_count;
  END IF;
  SELECT count(*) INTO v_count FROM storage.objects WHERE bucket_id = 'roshan-clinical-attachments';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'branch-A reader should see its two attachment objects, got %', v_count;
  END IF;
  IF EXISTS (
    SELECT 1 FROM storage.objects
    WHERE name LIKE '00000000-0000-0000-0000-000000003302/%'
  ) THEN
    RAISE EXCEPTION 'branch-B object became visible to branch-A reader';
  END IF;
END
$phase47_read_visibility$;

-- UPDATE cannot rebind an existing branch-A object to a branch-B entity.
DO $phase47_update_guard$
DECLARE
  v_blocked boolean;
BEGIN
  v_blocked := false;
  BEGIN
    UPDATE storage.objects
    SET name = '00000000-0000-0000-0000-000000003301/lab-reports/00000000-0000-0000-0000-000000003362/renamed.pdf'
    WHERE id = '00000000-0000-0000-0000-000000003351';
    RAISE EXCEPTION 'Storage UPDATE rebound a branch-A object to a branch-B entity';
  EXCEPTION WHEN insufficient_privilege THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'Storage UPDATE accepted a forged entity path'; END IF;
END
$phase47_update_guard$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000003342', true);

DO $phase47_branch_b$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM storage.objects
  WHERE bucket_id IN (
    'roshan-lab-reports',
    'roshan-medical-certificates',
    'roshan-clinical-attachments'
  );
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'branch-B user without clinical Storage permissions saw % objects', v_count;
  END IF;
END
$phase47_branch_b$;

ROLLBACK;
