-- Phase 61C: enforce pharmacist role at the active idempotent dispense RPC entry point.
-- The legacy_pharmacist role is intentionally excluded: it has no current assignments
-- and lacks the dedicated pharmacy.update and billing.create permission pair. Retire it
-- from this clinical transaction boundary rather than broadening its historical grants.
-- Phase 61B already guards the nested invoice-linked dispense RPC. This migration
-- prevents Admin/Super Admin from entering the atomic workflow via broad permissions.
BEGIN;

DO $phase61c_prerequisites$
BEGIN
  IF to_regprocedure('private.app_has_role_permission(text[],text)') IS NULL THEN
    RAISE EXCEPTION 'Phase 61B role permission helper is missing; apply Phase 61B before Phase 61C';
  END IF;
  IF to_regprocedure('private.fn_dispense_prescription_with_invoice_unchecked(uuid,boolean)') IS NULL THEN
    RAISE EXCEPTION 'Phase 61B unchecked invoice-linked dispense implementation is missing; refusing an incomplete role-boundary upgrade';
  END IF;
END;
$phase61c_prerequisites$;

DO $phase61c_move$
BEGIN
  IF to_regprocedure('private.atomic_pharmacy_dispense_unchecked(uuid,boolean,uuid)') IS NULL THEN
    IF to_regprocedure('public.atomic_pharmacy_dispense(uuid,boolean,uuid)') IS NULL THEN
      RAISE EXCEPTION 'Atomic pharmacy dispense RPC is missing; refusing an incomplete role-boundary upgrade';
    END IF;
    EXECUTE 'ALTER FUNCTION public.atomic_pharmacy_dispense(uuid, boolean, uuid) SET SCHEMA private';
    EXECUTE 'ALTER FUNCTION private.atomic_pharmacy_dispense(uuid, boolean, uuid) RENAME TO atomic_pharmacy_dispense_unchecked';
  END IF;
END;
$phase61c_move$;

REVOKE ALL ON FUNCTION private.atomic_pharmacy_dispense_unchecked(uuid, boolean, uuid)
  FROM PUBLIC, anon, authenticated, service_role, authenticator;

CREATE OR REPLACE FUNCTION public.atomic_pharmacy_dispense(
  p_prescription_id uuid,
  p_separate_invoice boolean,
  p_request_id uuid
)
RETURNS TABLE (
  item_id uuid,
  medicine_id uuid,
  medicine_name text,
  batch_id uuid,
  batch_number text,
  expiry_date date,
  quantity_dispensed numeric,
  batch_quantity_remaining numeric,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.app_has_role_permission(
    ARRAY['pharmacist'],
    'pharmacy.update'
  ) OR NOT private.app_has_role_permission(
    ARRAY['pharmacist'],
    'billing.create'
  ) THEN
    RAISE EXCEPTION 'pharmacy_dispense_permission_denied'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT *
  FROM private.atomic_pharmacy_dispense_unchecked(
    p_prescription_id,
    p_separate_invoice,
    p_request_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.atomic_pharmacy_dispense(uuid, boolean, uuid)
  FROM PUBLIC, anon, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.atomic_pharmacy_dispense(uuid, boolean, uuid)
  TO authenticated;

-- Close the legacy direct entry point as well as the idempotent wrapper.
-- Otherwise a legacy_pharmacist assigned broad permission bits could bypass
-- the canonical-role check by calling the invoice-linked RPC directly.
CREATE OR REPLACE FUNCTION public.fn_dispense_prescription_with_invoice(
  p_prescription_id uuid,
  p_separate_invoice boolean
)
RETURNS TABLE (
  item_id uuid,
  medicine_id uuid,
  medicine_name text,
  batch_id uuid,
  batch_number text,
  expiry_date date,
  quantity_dispensed numeric,
  batch_quantity_remaining numeric,
  source text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.app_has_role_permission(
    ARRAY['pharmacist'],
    'pharmacy.update'
  ) OR NOT private.app_has_role_permission(
    ARRAY['pharmacist'],
    'billing.create'
  ) THEN
    RAISE EXCEPTION 'pharmacy_dispense_permission_denied'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT *
  FROM private.fn_dispense_prescription_with_invoice_unchecked(
    p_prescription_id,
    p_separate_invoice
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_dispense_prescription_with_invoice(uuid, boolean)
  FROM PUBLIC, anon, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.fn_dispense_prescription_with_invoice(uuid, boolean)
  TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
