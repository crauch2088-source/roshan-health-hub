-- Phase 31 contract cutover.
-- Apply ONLY after Phase 31 expand, matching frontend deployment, and authenticated smoke tests.
-- This is the breaking privilege/NOT NULL step; keep it separate from additive schema/function work.
BEGIN;

-- The legacy RPC was made fail-closed in the expand phase, and direct certificate writes are revoked there.
-- This NOT NULL constraint detects any unexpected privileged/unlinked certificate inserted during cutover.
ALTER TABLE public.medical_certificates
  ALTER COLUMN visit_id SET NOT NULL;

REVOKE ALL ON FUNCTION public.create_medical_certificate(uuid,text,date,date)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_dispense_prescription(uuid)
  FROM PUBLIC, anon, authenticated;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.lab_order_items
  FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.medical_certificates
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.medical_certificates_id_seq
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.medical_certificate_number_seq
  FROM PUBLIC, anon, authenticated;

COMMIT;
