-- QA-only forward reconciliation for the isolated Roshan acceptance project.
-- Intended target: Supabase project ref hopfohcnrtbiqjkgeukz (roshan-health-hub-qa).
-- NEVER include this file in the production migration chain or apply it to production.
-- The operator must independently verify the target project ref before execution.
--
-- This script changes view security metadata only. It does not read or mutate
-- patient, visit, invoice, payment, inventory, or other business records.
-- Re-running it is safe: ALTER VIEW SET is idempotent for these options.

BEGIN;

DO $roshan_qa_view_precondition$
DECLARE
  missing_views text[];
BEGIN
  SELECT array_agg(required.view_name ORDER BY required.view_name)
    INTO missing_views
  FROM (VALUES
    ('cashbox_balance'),
    ('follow_ups'),
    ('v_patient_receivables'),
    ('v_supplier_outstanding')
  ) AS required(view_name)
  LEFT JOIN pg_class AS view_catalog
    ON view_catalog.relname = required.view_name
   AND view_catalog.relnamespace = 'public'::regnamespace
   AND view_catalog.relkind = 'v'
  WHERE view_catalog.oid IS NULL;

  IF missing_views IS NOT NULL THEN
    RAISE EXCEPTION
      'Refusing QA reconciliation; expected public views are missing: %',
      array_to_string(missing_views, ', ');
  END IF;
END
$roshan_qa_view_precondition$;

ALTER VIEW public.cashbox_balance SET (security_invoker = true);
ALTER VIEW public.follow_ups SET (security_invoker = true);
ALTER VIEW public.v_patient_receivables SET (security_invoker = true);
ALTER VIEW public.v_supplier_outstanding SET (security_invoker = true);

DO $roshan_qa_view_postcondition$
DECLARE
  missing_views text[];
BEGIN
  SELECT array_agg(required.view_name ORDER BY required.view_name)
    INTO missing_views
  FROM (VALUES
    ('cashbox_balance'),
    ('follow_ups'),
    ('v_patient_receivables'),
    ('v_supplier_outstanding')
  ) AS required(view_name)
  LEFT JOIN pg_class AS view_catalog
    ON view_catalog.relname = required.view_name
   AND view_catalog.relnamespace = 'public'::regnamespace
   AND view_catalog.relkind = 'v'
  WHERE NOT COALESCE(
    'security_invoker=true' = ANY(view_catalog.reloptions),
    false
  );

  IF missing_views IS NOT NULL THEN
    RAISE EXCEPTION
      'QA reconciliation did not restore security_invoker=true on views: %',
      array_to_string(missing_views, ', ');
  END IF;
END
$roshan_qa_view_postcondition$;

COMMIT;
