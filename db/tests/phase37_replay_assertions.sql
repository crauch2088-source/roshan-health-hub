-- Disposable PostgreSQL 17 replay contract. This validates the canonical v112 baseline plus
-- the tracked forward migrations corresponding to production ledger entries 113 and 114.
-- Platform-owned storage/realtime shims are supplied by phase33_storage_realtime_fixture.sql.
BEGIN;
DO $phase37_catalog_contract$
DECLARE
  v_public_tables integer;
  v_public_policies integer;
  v_missing text;
BEGIN
  SELECT count(*) INTO v_public_tables
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind IN ('r','p');
  IF v_public_tables <> 56 THEN
    RAISE EXCEPTION 'Expected 56 public application tables after replay, got %',v_public_tables;
  END IF;

  SELECT count(*) INTO v_public_policies FROM pg_policies WHERE schemaname='public';
  IF v_public_policies <> 210 THEN
    RAISE EXCEPTION 'Expected 210 public RLS policies after v112 + migrations 113-114, got %',v_public_policies;
  END IF;

  SELECT string_agg(required, ', ' ORDER BY required) INTO v_missing
  FROM (VALUES
    ('public.lab_orders.verified_by'),
    ('public.lab_orders.verified_at'),
    ('public.lab_order_items.verified_by'),
    ('public.lab_order_items.verified_at')
  ) expected(required)
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema='public'
      AND c.table_name=split_part(required,'.',2)
      AND c.column_name=split_part(required,'.',3)
  );
  IF v_missing IS NOT NULL THEN RAISE EXCEPTION 'Missing Phase 34 columns: %',v_missing; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='private' AND p.proname='phase36_guard_clinical_visit_links'
      AND p.prosecdef AND COALESCE(p.proconfig,ARRAY[]::text[]) @> ARRAY['search_path=""']
  ) THEN
    RAISE EXCEPTION 'Phase 36 clinical visit guard missing SECURITY DEFINER/empty search_path contract';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='verify_lab_order'
      AND pg_get_function_identity_arguments(p.oid)='p_order_id uuid'
      AND p.prosecdef AND COALESCE(p.proconfig,ARRAY[]::text[]) @> ARRAY['search_path=""']
  ) THEN
    RAISE EXCEPTION 'Phase 34 verify_lab_order signature/security contract is missing';
  END IF;

  IF (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND NOT t.tgisinternal AND t.tgname='phase36_visit_link_guard'
        AND c.relname IN ('lab_orders','lab_order_items','prescriptions','prescription_items','medical_certificates')) <> 5 THEN
    RAISE EXCEPTION 'Expected Phase 36 visit-link guard on all five clinical tables';
  END IF;

  IF (SELECT count(*) FROM pg_policies
      WHERE schemaname='public' AND policyname IN (
        'phase34_lab_orders_no_direct_verify','phase34_lab_orders_no_verified_update',
        'phase34_lab_items_no_direct_verify','phase34_lab_items_no_verified_update',
        'phase34_lab_results_no_mutation_after_verify_insert',
        'phase34_lab_results_no_mutation_after_verify_update',
        'phase34_lab_results_no_mutation_after_verify_delete'
      )) <> 7 THEN
    RAISE EXCEPTION 'Expected all seven Phase 34 restrictive lab-verification policies';
  END IF;

  IF NOT (
    has_table_privilege('authenticated','public.lab_orders','SELECT')
    AND has_table_privilege('authenticated','public.lab_order_items','SELECT')
    AND has_table_privilege('authenticated','public.lab_results','SELECT')
    AND has_table_privilege('authenticated','public.medical_certificates','SELECT')
  ) THEN
    RAISE EXCEPTION 'Expected authenticated clinical read grants are missing';
  END IF;
END
$phase37_catalog_contract$;
ROLLBACK;
