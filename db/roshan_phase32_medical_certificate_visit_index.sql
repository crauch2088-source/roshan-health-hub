-- Phase 32: cover the medical-certificate visit foreign key for lookups and FK checks.
-- This is an additive performance-only change; it does not alter clinical data or privileges.
BEGIN;

CREATE INDEX IF NOT EXISTS medical_certificates_visit_id_idx
  ON public.medical_certificates (visit_id);

COMMIT;
