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

  IF NOT has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'SELECT')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'INSERT')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'DELETE')
     OR has_table_privilege('authenticated', 'public.medicine_pack_verifications', 'TRUNCATE')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'INSERT')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'UPDATE')
     OR has_table_privilege('service_role', 'public.medicine_pack_verifications', 'DELETE') THEN
    RAISE EXCEPTION 'authenticated table privileges must be SELECT-only for pack attestations';
  END IF;

  IF NOT (SELECT relrowsecurity AND relforcerowsecurity
          FROM pg_class WHERE oid = 'public.medicine_pack_verifications'::regclass) THEN
    RAISE EXCEPTION 'pack attestation table must enable and force RLS';
  END IF;

  SELECT prosecconfig INTO v_config
  FROM pg_proc
  WHERE oid = 'public.verify_medicine_physical_pack(uuid)'::regprocedure;
  IF v_config IS NULL OR NOT ('search_path=""' = ANY(v_config)) THEN
    RAISE EXCEPTION 'verification RPC must use an empty search_path';
  END IF;

  IF has_function_privilege('anon', 'public.verify_medicine_physical_pack(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.verify_medicine_physical_pack(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'verification RPC EXECUTE grants are incorrect';
  END IF;

  SELECT prosecconfig INTO v_config
  FROM pg_proc
  WHERE oid = 'private.audit_medicine_pack_verification_insert()'::regprocedure;
  IF v_config IS NULL OR NOT ('search_path=""' = ANY(v_config)) THEN
    RAISE EXCEPTION 'pack attestation audit trigger must use an empty search_path';
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

SELECT 'PASS: Phase 60 role separation, RLS, append-only audit evidence and RPC ACLs' AS result;
