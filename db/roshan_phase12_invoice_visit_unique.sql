-- Phase 12 — enforce "one active invoice per visit" at the database level,
-- not just in the UI. Verified before applying live: zero existing
-- violations (query run first, migration applied only after confirming).
-- Partial (deleted_at is null) so a soft-deleted/voided invoice never blocks
-- a legitimate replacement invoice for the same visit.
-- Already applied live to jewzonxplxhogqrnhosl this session.
create unique index if not exists uq_invoices_visit_id
  on public.invoices (visit_id)
  where visit_id is not null and deleted_at is null;
