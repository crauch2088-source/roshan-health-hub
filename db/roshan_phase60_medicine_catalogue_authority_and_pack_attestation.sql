-- Phase 60: separate shared medicine identity authority from physical-pack verification.
-- Candidate only. Do not apply to hosted QA or Production before migration-ledger reconciliation and approval.
-- The catalogue is global across branches. Verification is a separate append-only event.
BEGIN;

INSERT INTO public.permissions (code, name, module, action)
VALUES
  ('pharmacy.catalogue_identity.update', 'Edit shared medicine identity', 'pharmacy', 'catalogue_identity_update'),
  ('pharmacy.pack.verify', 'Verify physical medicine pack', 'pharmacy', 'pack_verify')
ON CONFLICT (code) DO NOTHING;

-- Identity edits are granted only to current Admin and Pharmacist roles.
-- Super Admin continues to receive the explicit app_has_perm() bypass.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r
JOIN public.permissions p ON p.code = 'pharmacy.catalogue_identity.update'
WHERE r.code IN ('admin', 'pharmacist')
ON CONFLICT DO NOTHING;

-- Physical pack verification is a pharmacist duty; Super Admin retains the explicit bypass.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r
JOIN public.permissions p ON p.code = 'pharmacy.pack.verify'
WHERE r.code = 'pharmacist'
ON CONFLICT DO NOTHING;

-- Direct medicine UPDATE is no longer granted by broad pharmacy.update.
-- SECURITY DEFINER stock/dispense RPCs retain their own pharmacy.update checks.
DROP POLICY IF EXISTS medicines_update ON public.medicines;
CREATE POLICY medicines_update ON public.medicines
FOR UPDATE TO authenticated
USING ((SELECT public.app_has_perm('pharmacy.catalogue_identity.update')))
WITH CHECK ((SELECT public.app_has_perm('pharmacy.catalogue_identity.update')));

CREATE TABLE IF NOT EXISTS public.medicine_pack_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id uuid NOT NULL REFERENCES public.medicines(id) ON DELETE RESTRICT,
  verified_by uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  verified_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  identity_snapshot jsonb NOT NULL CHECK (jsonb_typeof(identity_snapshot) = 'object'),
  identity_sha256 text NOT NULL CHECK (identity_sha256 ~ '^[0-9a-f]{64}$')
);

COMMENT ON TABLE public.medicine_pack_verifications IS
  'Append-only physical-pack verification events for the shared medicine catalogue. Each event is bound to the saved medicine identity snapshot and application-user actor.';
COMMENT ON COLUMN public.medicine_pack_verifications.identity_snapshot IS
  'Canonical saved medicine identity at verification time; historical evidence, not a mutable current-state flag.';
COMMENT ON COLUMN public.medicine_pack_verifications.identity_sha256 IS
  'SHA-256 fingerprint of identity_snapshot::text, computed server-side. A later medicine identity edit does not rewrite historical verification.';

CREATE INDEX IF NOT EXISTS idx_medicine_pack_verifications_medicine_verified
ON public.medicine_pack_verifications (medicine_id, verified_at DESC, id DESC);

ALTER TABLE public.medicine_pack_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_pack_verifications FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS medicine_pack_verifications_select ON public.medicine_pack_verifications;
CREATE POLICY medicine_pack_verifications_select ON public.medicine_pack_verifications
FOR SELECT TO authenticated
USING ((SELECT public.app_has_perm('pharmacy.read')));

REVOKE ALL ON TABLE public.medicine_pack_verifications FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.medicine_pack_verifications TO authenticated;

CREATE OR REPLACE FUNCTION private.reject_medicine_pack_verification_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'medicine pack verification history is append-only'
    USING ERRCODE = '55000';
END;
$function$;
REVOKE ALL ON FUNCTION private.reject_medicine_pack_verification_mutation() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS medicine_pack_verifications_no_update_delete ON public.medicine_pack_verifications;
CREATE TRIGGER medicine_pack_verifications_no_update_delete
BEFORE UPDATE OR DELETE ON public.medicine_pack_verifications
FOR EACH ROW EXECUTE FUNCTION private.reject_medicine_pack_verification_mutation();

DROP TRIGGER IF EXISTS medicine_pack_verifications_no_truncate ON public.medicine_pack_verifications;
CREATE TRIGGER medicine_pack_verifications_no_truncate
BEFORE TRUNCATE ON public.medicine_pack_verifications
FOR EACH STATEMENT EXECUTE FUNCTION private.reject_medicine_pack_verification_mutation();

CREATE OR REPLACE FUNCTION private.audit_medicine_pack_verification_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := public.current_app_user_id();
BEGIN
  INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_data, new_data)
  VALUES (v_actor, 'INSERT', 'medicine_pack_verifications', NEW.id, NULL, to_jsonb(NEW));
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.audit_medicine_pack_verification_insert() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_audit_medicine_pack_verifications ON public.medicine_pack_verifications;
CREATE TRIGGER trg_audit_medicine_pack_verifications
AFTER INSERT ON public.medicine_pack_verifications
FOR EACH ROW EXECUTE FUNCTION private.audit_medicine_pack_verification_insert();

CREATE OR REPLACE FUNCTION public.verify_medicine_physical_pack(p_medicine_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_snapshot jsonb;
  v_sha256 text;
  v_verification_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('pharmacy.pack.verify') THEN
    RAISE EXCEPTION 'physical_pack_verification_permission_denied'
      USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'name', m.name,
    'generic_name', m.generic_name,
    'brand_name', m.brand_name,
    'strength', m.strength,
    'dosage_form', m.dosage_form
  ) INTO v_snapshot
  FROM public.medicines AS m
  WHERE m.id = p_medicine_id AND m.deleted_at IS NULL
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'medicine_not_found' USING ERRCODE = 'P0002';
  END IF;

  v_sha256 := encode(extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'), 'hex');

  INSERT INTO public.medicine_pack_verifications
    (medicine_id, verified_by, identity_snapshot, identity_sha256)
  VALUES (p_medicine_id, v_uid, v_snapshot, v_sha256)
  RETURNING id INTO v_verification_id;

  RETURN v_verification_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.verify_medicine_physical_pack(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.verify_medicine_physical_pack(uuid) TO authenticated;

COMMIT;
