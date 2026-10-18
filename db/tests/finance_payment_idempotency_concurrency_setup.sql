-- Deterministic lock-hold trigger for the two-session race.
-- The current finance fixture already declares idempotency_key UNIQUE.
-- The shared finance fixture already seeds the user and invoice IDs used by the race test.

CREATE FUNCTION public.test_pause_payment_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF current_setting('test.pause_payment', true) = 'true' THEN
    PERFORM pg_sleep(3);
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_test_pause_payment_insert
BEFORE INSERT ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.test_pause_payment_insert();
