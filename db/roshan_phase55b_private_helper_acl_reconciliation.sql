-- Phase 55B (Issue #218): preserve insurance RLS while closing private-helper EXECUTE ACLs.
-- The public wrapper is intentionally authenticated-callable only; it returns only
-- whether the current JWT actor may access the supplied claim's branch.
-- Preserve the original insurance.read / insurance.create policy gates.
BEGIN;

REVOKE ALL ON FUNCTION private.app_has_claim_branch(uuid)
  FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.sync_user_role_text()
  FROM PUBLIC, anon, authenticated, service_role, authenticator;

CREATE OR REPLACE FUNCTION public.app_has_claim_branch(_claim_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.app_has_claim_branch(_claim_id)
$function$;

REVOKE ALL ON FUNCTION public.app_has_claim_branch(uuid)
  FROM PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.app_has_claim_branch(uuid) TO authenticated;

DO $rebind_insurance_rls$
BEGIN
  IF to_regclass('public.insurance_claim_items') IS NOT NULL THEN
    -- Live QA and Production use *_sel / *_ins, not *_select / *_insert.
    -- Drop both spellings so a previously staged candidate cannot leave a
    -- second permissive policy behind.
    DROP POLICY IF EXISTS insurance_claim_items_select ON public.insurance_claim_items;
    DROP POLICY IF EXISTS insurance_claim_items_insert ON public.insurance_claim_items;
    DROP POLICY IF EXISTS insurance_claim_items_sel ON public.insurance_claim_items;
    DROP POLICY IF EXISTS insurance_claim_items_ins ON public.insurance_claim_items;

    CREATE POLICY insurance_claim_items_sel ON public.insurance_claim_items
      FOR SELECT TO authenticated
      USING (
        app_has_perm('insurance.read')
        AND (SELECT public.app_has_claim_branch(claim_id))
      );

    CREATE POLICY insurance_claim_items_ins ON public.insurance_claim_items
      FOR INSERT TO authenticated
      WITH CHECK (
        app_has_perm('insurance.create')
        AND (SELECT public.app_has_claim_branch(claim_id))
      );
  END IF;

  IF to_regclass('public.insurance_claim_payments') IS NOT NULL THEN
    DROP POLICY IF EXISTS insurance_claim_payments_select ON public.insurance_claim_payments;
    DROP POLICY IF EXISTS insurance_claim_payments_insert ON public.insurance_claim_payments;
    DROP POLICY IF EXISTS insurance_claim_payments_sel ON public.insurance_claim_payments;
    DROP POLICY IF EXISTS insurance_claim_payments_ins ON public.insurance_claim_payments;

    CREATE POLICY insurance_claim_payments_sel ON public.insurance_claim_payments
      FOR SELECT TO authenticated
      USING (
        app_has_perm('insurance.read')
        AND (SELECT public.app_has_claim_branch(claim_id))
      );

    CREATE POLICY insurance_claim_payments_ins ON public.insurance_claim_payments
      FOR INSERT TO authenticated
      WITH CHECK (
        app_has_perm('insurance.create')
        AND (SELECT public.app_has_claim_branch(claim_id))
      );
  END IF;
END
$rebind_insurance_rls$;

COMMIT;
