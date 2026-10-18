-- Phase 29: revoke direct DML on clinical child tables with no direct frontend write call sites.
-- This safe subset can be applied before the lab/certificate RPC frontend is deployed.
-- SELECT privileges and existing branch-aware RLS policies are preserved.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.prescriptions,
           public.prescription_items,
           public.patient_discounts,
           public.insurance_prior_authorizations
  FROM PUBLIC, anon, authenticated;
