-- Phase 60 catalog/ACL assertions. Run only in the disposable PostgreSQL 17 CI database after the candidate migration.
DO $phase60$
DECLARE
  v_count integer;
  v_policy text;
  v_config text[];
BEGIN
  SELECT count(*) INTO v_count
  FROM public.role_permissions rp
  JOIN public.roles r ON r.id = rp.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE p.code = 'pharmacy.catalogue_identity.update'
    AND r.code IN ('admin', 'pharmacist');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'identity edit permission must be assigned to Admin and Pharmacist only (got %)', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.role_permissions rp
  JOIN public.roles r ON r.id = rp.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE p.code = 'pharmacy.pack.verify';
  IF v_count <> 1 OR NOT EXISTS (
    SELECT 1 FROM public.role_permissions rp
    JOIN public.roles r ON r.id = rp.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE p.code = 'pharmacy.pack.verify' AND r.code = 'pharmacist'
  ) THEN
    RAISE EXCEPTION 'pack verification permission must belong to Pharmacist only (excluding Super Admin implicit bypass)';
  END IF;

  SELECT pg_get_expr(polqual, polrelid) INTO v_policy
  FROM pg_policy
  WHERE polrelid = 'public.medicines'::regclass AND polname = 'medicines_update';
  IF v_policy IS NULL OR position('pharmacy.catalogue_identity.update' IN v_policy) = 0 THEN
    RAISE EXCEPTION 'medicines UPDATE RLS policy does not enforce the dedicated identity permission';
  END IF;

  IF has_table_privilege('authenticated', 'public.medicines', 'UPDATE') THEN
    RAISE EXCEPTION 'authenticated must not retain table-level UPDATE on medicines';
  END IF;

  IF NOT (
    has_column_privilege('authenticated', 'public.medicines', 'name', 'UPDATE')
    AND has_column_privilege('authenticated', 'public.medicines', 'generic_name', 'UPDATE')
    AND has_column_privilege('authenticated', 'public.medicines', 'brand_name', 'UPDATE')
    AND has_column_privilege('authenticated', 'public.medicines', 'strength', 'UPDATE')
    AND has_column_privilege('authenticated', 'public.medicines', 'dosage_form', 'UPDATE')
  ) THEN
    RAISE EXCEPTION 'authenticated must retain UPDATE only on the five medicine identity columns';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns AS c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'medicines'
      AND c.column_name NOT IN (
        'name', 'generic_name', 'brand_name', 'strength', 'dosage_form'
      )
      AND has_column_privilege(
        'authenticated', 'public.medicines', c.column_name, 'UPDATE'
      )
  ) THEN
    RAISE EXCEPTION 'authenticated retains UPDATE on a non-identity medicine column';
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_policy
  WHERE polrelid = 'public.medicines'::regclass AND polcmd = 'w';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'medicine identity UPDATE must have exactly one dedicated RLS policy (got %)', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.medicines'::regclass
      AND tgname = 'trg_audit_medicines'
      AND tgfoid = 'public.audit_row_change()'::regprocedure
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'medicine identity updates must retain their row-audit trigger';
  END IF;

  IF NOT has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'SELECT')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'INSERT')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'DELETE')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'TRUNCATE')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'INSERT')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'UPDATE')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'DELETE')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'TRUNCATE')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'REFERENCES')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'TRIGGER') THEN
    RAISE EXCEPTION 'authenticated/service_role must not have direct write privileges on pack attestations';
  END IF;

  IF NOT (SELECT relrowsecurity AND relforcerowsecurity
          FROM pg_class WHERE oid = 'public.medicine_pack_verifications'::regclass) THEN
    RAISE EXCEPTION 'pack attestation table must enable and force RLS';
  END IF;

  SELECT proconfig INTO v_config
  FROM pg_proc
  WHERE oid = 'public.verify_medicine_physical_pack(uuid)'::regprocedure;
  IF v_config IS NULL OR NOT ('search_path=""' = ANY(v_config)) THEN
    RAISE EXCEPTION 'verification RPC must use an empty search_path';
  END IF;

  IF has_function_privilege('anon', 'public.verify_medicine_physical_pack(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.verify_medicine_physical_pack(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.verify_medicine_physical_pack(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'verification RPC EXECUTE grants are incorrect';
  END IF;

  SELECT proconfig INTO v_config
  FROM pg_proc
  WHERE oid = 'private.audit_medicine_pack_verification_insert()'::regprocedure;
  IF v_config IS NULL OR NOT ('search_path=""' = ANY(v_config)) THEN
    RAISE EXCEPTION 'pack attestation audit trigger must use an empty search_path';
  END IF;

  IF has_function_privilege('anon', 'private.reject_medicine_pack_verification_mutation()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.reject_medicine_pack_verification_mutation()', 'EXECUTE')
     OR has_function_privilege('service_role', 'private.reject_medicine_pack_verification_mutation()', 'EXECUTE') THEN
    RAISE EXCEPTION 'trigger-only append-only guard must not be directly executable by application/service roles';
  END IF;

  IF NOT EXISTS (
       SELECT 1 FROM pg_trigger
       WHERE tgrelid = 'public.medicine_pack_verifications'::regclass
         AND tgname = 'medicine_pack_verifications_no_update_delete' AND NOT tgisinternal
     )
     OR NOT EXISTS (
       SELECT 1 FROM pg_trigger
       WHERE tgrelid = 'public.medicine_pack_verifications'::regclass
         AND tgname = 'medicine_pack_verifications_no_truncate' AND NOT tgisinternal
     )
     OR NOT EXISTS (
       SELECT 1 FROM pg_trigger
       WHERE tgrelid = 'public.medicine_pack_verifications'::regclass
         AND tgname = 'trg_audit_medicine_pack_verifications' AND NOT tgisinternal
     ) THEN
    RAISE EXCEPTION 'append-only and audit triggers must all exist';
  END IF;
END;
$phase60$;


-- Runtime role tests use only synthetic accounts and a synthetic medicine.
INSERT INTO public.permissions (code, name, module, action)
VALUES
  ('pharmacy.read', 'Read pharmacy catalogue', 'pharmacy', 'read'),
  ('pharmacy.update', 'Legacy broad pharmacy update', 'pharmacy', 'update')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.code IN ('admin', 'pharmacist', 'legacy_admin')
  AND p.code IN ('pharmacy.read', 'pharmacy.update')
ON CONFLICT DO NOTHING;

INSERT INTO auth.users (id)
VALUES
  ('62000000-0000-0000-0000-000000000001'),
  ('62000000-0000-0000-0000-000000000002'),
  ('62000000-0000-0000-0000-000000000003'),
  ('62000000-0000-0000-0000-000000000004')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.users (id, auth_user_id, role_id, full_name, active)
SELECT x.user_id, x.auth_uid, r.id, x.full_name, true
FROM (VALUES
  ('61000000-0000-0000-0000-000000000001'::uuid, '62000000-0000-0000-0000-000000000001'::uuid, 'Admin test user', 'admin'),
  ('61000000-0000-0000-0000-000000000002'::uuid, '62000000-0000-0000-0000-000000000002'::uuid, 'Pharmacist test user', 'pharmacist'),
  ('61000000-0000-0000-0000-000000000003'::uuid, '62000000-0000-0000-0000-000000000003'::uuid, 'Super Admin test user', 'super_admin'),
  ('61000000-0000-0000-0000-000000000004'::uuid, '62000000-0000-0000-0000-000000000004'::uuid, 'Legacy Admin test user', 'legacy_admin')
) AS x(user_id, auth_uid, full_name, role_code)
JOIN public.roles r ON r.code = x.role_code
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.medicines (id, generic_name, brand_name, strength, dosage_form, name)
VALUES (
  '63000000-0000-0000-0000-000000000001',
  'Synthetic test generic',
  'Synthetic test brand',
  '500 mg',
  'tablet',
  'Synthetic test medicine'
)
ON CONFLICT (id) DO NOTHING;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '62000000-0000-0000-0000-000000000001', false);

DO $admin_role$
DECLARE
  v_rows integer;
  v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.catalogue_identity.update')
     OR public.app_has_perm('pharmacy.pack.verify') THEN
    RAISE EXCEPTION 'Admin identity-edit/pack-verification permissions are incorrect';
  END IF;

  UPDATE public.medicines
     SET name = 'Admin identity edit'
   WHERE id = '63000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN RAISE EXCEPTION 'Admin must be able to edit shared medicine identity'; END IF;

  v_denied := false;
  BEGIN
    UPDATE public.medicines
       SET selling_price = 999, stock_quantity = 999
     WHERE id = '63000000-0000-0000-0000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'Admin identity permission must not allow direct price or stock mutation';
  END IF;

  BEGIN
    PERFORM public.verify_medicine_physical_pack('63000000-0000-0000-0000-000000000001');
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Admin must not be able to attest physical-pack verification'; END IF;
END;
$admin_role$;

SELECT set_config('request.jwt.claim.sub', '62000000-0000-0000-0000-000000000002', false);
DO $pharmacist_role$
BEGIN
  IF NOT public.app_has_perm('pharmacy.catalogue_identity.update')
     OR NOT public.app_has_perm('pharmacy.pack.verify') THEN
    RAISE EXCEPTION 'Pharmacist must have both catalogue-edit and pack-verification permissions';
  END IF;
  PERFORM public.verify_medicine_physical_pack('63000000-0000-0000-0000-000000000001');
END;
$pharmacist_role$;

SELECT set_config('request.jwt.claim.sub', '62000000-0000-0000-0000-000000000004', false);
DO $legacy_admin_role$
DECLARE
  v_rows integer;
  v_denied boolean := false;
BEGIN
  IF NOT public.app_has_perm('pharmacy.update')
     OR public.app_has_perm('pharmacy.catalogue_identity.update')
     OR public.app_has_perm('pharmacy.pack.verify') THEN
    RAISE EXCEPTION 'Legacy Admin broad pharmacy.update must not imply catalogue identity or pack verification';
  END IF;

  UPDATE public.medicines
     SET name = 'Legacy admin must not edit'
   WHERE id = '63000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 0 THEN RAISE EXCEPTION 'Legacy Admin unexpectedly updated shared medicine identity'; END IF;

  BEGIN
    PERFORM public.verify_medicine_physical_pack('63000000-0000-0000-0000-000000000001');
  EXCEPTION WHEN insufficient_privilege THEN
    v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'Legacy Admin must not be able to attest physical-pack verification'; END IF;
END;
$legacy_admin_role$;

SELECT set_config('request.jwt.claim.sub', '62000000-0000-0000-0000-000000000003', false);
DO $super_admin_role$
BEGIN
  IF NOT public.app_has_perm('pharmacy.catalogue_identity.update')
     OR NOT public.app_has_perm('pharmacy.pack.verify') THEN
    RAISE EXCEPTION 'Super Admin explicit permission bypass is not effective';
  END IF;
  UPDATE public.medicines
     SET name = 'Super Admin identity edit'
   WHERE id = '63000000-0000-0000-0000-000000000001';
  PERFORM public.verify_medicine_physical_pack('63000000-0000-0000-0000-000000000001');
END;
$super_admin_role$;

RESET ROLE;

DO $phase60_evidence$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.medicine_pack_verifications
  WHERE medicine_id = '63000000-0000-0000-0000-000000000001';
  IF v_count <> 2 THEN RAISE EXCEPTION 'exactly Pharmacist and Super Admin should have created attestations (got %)', v_count; END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.medicine_pack_verifications v
    WHERE v.medicine_id = '63000000-0000-0000-0000-000000000001'
      AND v.verified_by = '61000000-0000-0000-0000-000000000002'
      AND v.identity_snapshot->>'name' = 'Admin identity edit'
      AND v.identity_sha256 = encode(extensions.digest(convert_to(v.identity_snapshot::text, 'UTF8'), 'sha256'), 'hex')
  ) THEN RAISE EXCEPTION 'Pharmacist attestation is not actor-bound or fingerprinted'; END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.medicine_pack_verifications v
    WHERE v.medicine_id = '63000000-0000-0000-0000-000000000001'
      AND v.verified_by = '61000000-0000-0000-0000-000000000003'
      AND v.identity_snapshot->>'name' = 'Super Admin identity edit'
      AND v.identity_sha256 = encode(extensions.digest(convert_to(v.identity_snapshot::text, 'UTF8'), 'sha256'), 'hex')
  ) THEN RAISE EXCEPTION 'Super Admin attestation must snapshot the later saved identity'; END IF;

  IF (SELECT count(*) FROM public.audit_logs
      WHERE table_name = 'medicine_pack_verifications'
        AND action = 'INSERT'
        AND user_id IN (
          '61000000-0000-0000-0000-000000000002',
          '61000000-0000-0000-0000-000000000003'
        )) <> 2 THEN
    RAISE EXCEPTION 'each attestation must produce a correctly attributed audit log';
  END IF;
END;
$phase60_evidence$;

DO $phase60_immutability$
DECLARE
  v_denied boolean;
BEGIN
  v_denied := false;
  BEGIN
    UPDATE public.medicine_pack_verifications SET identity_snapshot = '{}'::jsonb;
  EXCEPTION WHEN SQLSTATE '55000' THEN v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'attestation UPDATE unexpectedly succeeded'; END IF;

  v_denied := false;
  BEGIN
    DELETE FROM public.medicine_pack_verifications;
  EXCEPTION WHEN SQLSTATE '55000' THEN v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'attestation DELETE unexpectedly succeeded'; END IF;

  v_denied := false;
  BEGIN
    TRUNCATE TABLE public.medicine_pack_verifications;
  EXCEPTION WHEN SQLSTATE '55000' THEN v_denied := true;
  END;
  IF NOT v_denied THEN RAISE EXCEPTION 'attestation TRUNCATE unexpectedly succeeded'; END IF;

  IF (SELECT count(*) FROM public.medicine_pack_verifications) <> 2 THEN
    RAISE EXCEPTION 'immutability attempts changed historical attestations';
  END IF;
END;
$phase60_immutability$;

SELECT 'PASS: Phase 60 role separation, RLS, append-only audit evidence and RPC ACLs' AS result;
