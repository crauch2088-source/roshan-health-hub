-- Deterministic lock-hold trigger for the two-session race.
-- The current finance fixture already declares idempotency_key UNIQUE.
INSERT INTO public.users(id, branch_id, active)
VALUES ('10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001', true);
INSERT INTO public.invoices(id, branch_id, net_amount, total_amount, paid_amount)
VALUES ('40000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001', 10, 10, 0);

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
