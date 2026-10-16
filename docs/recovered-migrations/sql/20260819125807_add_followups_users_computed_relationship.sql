-- follow_ups is a compatibility VIEW over public.followups, so PostgreSQL cannot attach
-- a normal FK to the view. Expose the existing created_by/updated_by relationship
-- to PostgREST as a computed relationship named `users`.
CREATE OR REPLACE FUNCTION public.users(public.follow_ups)
RETURNS SETOF public.users
ROWS 1
STABLE
LANGUAGE sql
AS $$
  SELECT u.*
  FROM public.users AS u
  WHERE u.id = $1.created_by
$$;

NOTIFY pgrst, 'reload schema';
