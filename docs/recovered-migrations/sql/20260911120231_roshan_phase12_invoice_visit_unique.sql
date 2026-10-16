-- Phase 12 — enforce "one active invoice per visit" at the database level,
-- not just in the UI. Verified before applying: zero existing violations.
-- Partial (deleted_at is null) so a soft-deleted/voided invoice never blocks
-- a legitimate replacement for the same visit.
create unique index if not exists uq_invoices_visit_id
  on public.invoices (visit_id)
  where visit_id is not null and deleted_at is null;
