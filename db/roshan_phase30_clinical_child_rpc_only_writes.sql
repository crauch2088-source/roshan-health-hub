-- Phase 30: revoke direct client writes after the RPC-based lab/certificate frontend is deployed.
-- Do not apply until the production deployment calls both Phase 28 RPCs successfully.
-- SELECT privileges and existing branch-aware RLS policies are preserved.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.lab_order_items,
           public.medical_certificates
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON SEQUENCE public.medical_certificates_id_seq
  FROM PUBLIC, anon, authenticated;
