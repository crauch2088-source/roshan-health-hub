-- Keep both audit foreign keys, but remove PostgREST's ambiguous users embedding by making the created-by relationship explicit at the application query level. No schema change is required for the error itself.
-- Add a convenient view exposing the creator as a uniquely named relationship for clients that want to embed it.
create or replace view public.followups_with_creator as
select
  f.*,
  u.full_name as creator_full_name
from public.followups f
left join public.users u on u.id = f.created_by;
