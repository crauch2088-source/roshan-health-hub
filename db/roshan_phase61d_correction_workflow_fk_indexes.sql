-- Phase 61D: cover every unindexed foreign key introduced by the Phase 61 correction workflow.
-- Forward-only and independent of Phase 61C role hardening; requires the Phase 61 tables.
-- Candidate only. Do not apply to hosted QA or Production without the normal review/release gates.
BEGIN;

CREATE INDEX IF NOT EXISTS pirc_requests_replacement_prescription_id_idx
  ON public.prescription_item_correction_requests USING btree (replacement_prescription_id);

CREATE INDEX IF NOT EXISTS pirc_requests_corrected_item_id_idx
  ON public.prescription_item_correction_requests USING btree (corrected_item_id);

CREATE INDEX IF NOT EXISTS pirc_requests_patient_id_idx
  ON public.prescription_item_correction_requests USING btree (patient_id);

CREATE INDEX IF NOT EXISTS pirc_requests_requested_by_idx
  ON public.prescription_item_correction_requests USING btree (requested_by);

CREATE INDEX IF NOT EXISTS pirc_requests_resolved_by_idx
  ON public.prescription_item_correction_requests USING btree (resolved_by);

CREATE INDEX IF NOT EXISTS pirc_requests_visit_id_idx
  ON public.prescription_item_correction_requests USING btree (visit_id);

CREATE INDEX IF NOT EXISTS pirc_events_actor_id_idx
  ON public.prescription_item_correction_events USING btree (actor_id);

COMMIT;
