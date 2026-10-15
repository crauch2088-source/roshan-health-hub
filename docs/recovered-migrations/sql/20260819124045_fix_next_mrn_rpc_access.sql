-- Ensure the authenticated API role can invoke the MRN RPC.
GRANT EXECUTE ON FUNCTION public.next_mrn() TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_mrn() TO service_role;

-- Keep the function safely isolated from caller privileges and search_path manipulation.
ALTER FUNCTION public.next_mrn()
  SECURITY DEFINER
  SET search_path = public, pg_temp;

-- Refresh PostgREST's schema cache so the RPC grant/function metadata is visible immediately.
NOTIFY pgrst, 'reload schema';
