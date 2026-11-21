-- Phase 55B (Issue #218): Forward-only private-helper EXECUTE ACL reconciliation
-- Keeps private.app_has_claim_branch(uuid) and private.sync_user_role_text() strictly owner-only
-- while preserving authenticated RLS policies on insurance_claim_items and insurance_claim_payments
-- through a least-privilege SECURITY DEFINER wrapper public.app_has_claim_branch(uuid).

REVOKE ALL ON FUNCTION private.app_has_claim_branch(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.sync_user_role_text() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.app_has_claim_branch(_claim_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.app_has_claim_branch(_claim_id)
$function$;

REVOKE ALL ON FUNCTION public.app_has_claim_branch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_has_claim_branch(uuid) TO authenticated;

DO $rebind_insurance_rls$
BEGIN
  IF to_regclass('public.insurance_claim_items') IS NOT NULL THEN
    DROP POLICY IF EXISTS insurance_claim_items_select ON public.insurance_claim_items;
    CREATE POLICY insurance_claim_items_select ON public.insurance_claim_items
      FOR SELECT TO authenticated
      USING ((SELECT public.app_has_claim_branch(claim_id)));

    DROP POLICY IF EXISTS insurance_claim_items_insert ON public.insurance_claim_items;
    CREATE POLICY insurance_claim_items_insert ON public.insurance_claim_items
      FOR INSERT TO authenticated
      WITH CHECK ((SELECT public.app_has_claim_branch(claim_id)));
  END IF;

  IF to_regclass('public.insurance_claim_payments') IS NOT NULL THEN
    DROP POLICY IF EXISTS insurance_claim_payments_select ON public.insurance_claim_payments;
    CREATE POLICY insurance_claim_payments_select ON public.insurance_claim_payments
      FOR SELECT TO authenticated
      USING ((SELECT public.app_has_claim_branch(claim_id)));

    DROP POLICY IF EXISTS insurance_claim_payments_insert ON public.insurance_claim_payments;
    CREATE POLICY insurance_claim_payments_insert ON public.insurance_claim_payments
      FOR INSERT TO authenticated
      WITH CHECK ((SELECT public.app_has_claim_branch(claim_id)));
  END IF;
END
$rebind_insurance_rls$;
