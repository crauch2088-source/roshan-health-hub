-- Apply only after the new pharmacy UI is deployed and authenticated smoke tests pass.
-- Keep this as a separate post-deployment migration so the currently deployed UI
-- can continue calling fn_dispense_prescription(uuid) during the compatibility window.
REVOKE ALL ON FUNCTION public.fn_dispense_prescription(uuid) FROM PUBLIC, anon, authenticated;
