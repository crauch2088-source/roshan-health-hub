-- Phase 29: retire direct client writes after the RPC-based frontend is deployed.
-- SELECT privileges and existing branch-aware RLS policies are deliberately preserved.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.prescriptions,
           public.prescription_items,
           public.lab_order_items,
           public.medical_certificates,
           public.patient_discounts,
           public.insurance_prior_authorizations
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON SEQUENCE public.medical_certificates_id_seq
  FROM PUBLIC, anon, authenticated;
