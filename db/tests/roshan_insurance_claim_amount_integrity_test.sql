-- Contract regression test for db/roshan_phase5_insurance_claim_amount_integrity.sql
-- Run only against a disposable/staging database after applying the migration.
-- This test verifies the deployed RPC definition and security posture; behavioral
-- input tests should additionally be exercised in staging with authenticated fixtures.
DO $$
DECLARE
  v_definition text;
  v_config text[];
  v_anon_exec boolean;
BEGIN
  SELECT pg_get_functiondef(p.oid), p.proconfig,
         has_function_privilege('anon', p.oid, 'EXECUTE')
    INTO v_definition, v_config, v_anon_exec
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'create_insurance_claim'
     AND pg_get_function_identity_arguments(p.oid) =
         '_patient_insurance_id uuid, _invoice_id uuid, _items jsonb, _notes text';

  IF v_definition IS NULL THEN
    RAISE EXCEPTION 'FAIL: create_insurance_claim(uuid, uuid, jsonb, text) not found';
  END IF;
  IF position('claim item covered and patient amounts must equal gross amount' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'FAIL: amount-split invariant missing';
  END IF;
  IF position('claim covered and patient amounts cannot exceed gross amount' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'FAIL: per-component upper bound missing';
  END IF;
  IF position('cross-branch insurance claim access denied' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'FAIL: branch-isolation guard missing';
  END IF;
  IF NOT coalesce(v_config, ARRAY[]::text[]) @> ARRAY['search_path=""'] THEN
    RAISE EXCEPTION 'FAIL: empty search_path is required';
  END IF;
  IF v_anon_exec THEN
    RAISE EXCEPTION 'FAIL: anon must not execute create_insurance_claim';
  END IF;

  RAISE NOTICE 'PASS: claim amount invariants, branch guard, empty search_path, and anon execute restriction verified';
END $$;
