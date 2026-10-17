-- Retire direct client access to the global invoice-number allocator.
-- create_invoice_atomic calls this as SECURITY DEFINER; the owner retains internal execution.
REVOKE EXECUTE ON FUNCTION public.next_invoice_number() FROM PUBLIC, anon, authenticated;
