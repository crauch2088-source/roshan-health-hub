CREATE OR REPLACE FUNCTION public.fn_ledger_from_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  perform public.fn_ledger_post(
    'customer_payment', abs(new.amount), coalesce(new.payment_method, new.method, 'cash'),
    'patient_payment', 'Invoice payment', 'payment', new.id,
    coalesce(new.payment_date::timestamptz, new.received_at, now()), new.branch_id
  );
  return new;
end
$function$;
