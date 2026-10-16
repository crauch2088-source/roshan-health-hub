DO $legacy_dispense_revoke$
BEGIN
  IF has_function_privilege('authenticated','public.fn_dispense_prescription(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'legacy dispense RPC remains executable after post-deployment revoke';
  END IF;
  IF has_function_privilege('anon','public.fn_dispense_prescription(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'anon can execute legacy dispense RPC after revoke';
  END IF;
  IF NOT has_function_privilege('authenticated','public.fn_dispense_prescription_with_invoice(uuid,boolean)','EXECUTE') THEN
    RAISE EXCEPTION 'new dispense-and-invoice RPC is not executable by authenticated';
  END IF;
END
$legacy_dispense_revoke$;
SELECT 'post-deployment legacy dispense revoke test passed' AS result;
