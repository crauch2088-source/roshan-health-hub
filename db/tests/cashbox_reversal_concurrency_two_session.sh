#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:=localhost}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGDATABASE:=postgres}"
export PGHOST PGPORT PGUSER PGDATABASE

psql -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.users(id, branch_id)
VALUES ('10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001');

INSERT INTO public.cashbox_transactions(
  id, branch_id, transaction_type, amount, payment_method, category,
  description, source_type, created_by
) VALUES (
  '30000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'deposit', 125.00, 'cash', 'concurrency-test',
  'two-session reversal test', 'manual',
  '10000000-0000-0000-0000-000000000001'
);
SQL

# Launch two independent database sessions against the same original transaction.
set +e
PGAPPNAME=cashbox-reversal-a psql -v ON_ERROR_STOP=1 -c "SELECT public.reverse_cashbox_entry('30000000-0000-0000-0000-000000000001','race A');" >/tmp/cashbox-reversal-a.log 2>&1 &
pid_a=$!

# Wait until session A is visibly inside the fixture-only pg_sleep trigger;
# this proves it already holds the original-row lock before session B starts.
started=0
for _ in $(seq 1 50); do
  waiting=$(psql -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM pg_stat_activity WHERE application_name='cashbox-reversal-a' AND state='active' AND wait_event='PgSleep';")
  if [ "$waiting" -ge 1 ]; then
    started=1
    break
  fi
  sleep 0.05
done
if [ "$started" -ne 1 ]; then
  echo "FAIL: session A never entered the controlled insert delay"
  cat /tmp/cashbox-reversal-a.log
  exit 1
fi

PGAPPNAME=cashbox-reversal-b psql -v ON_ERROR_STOP=1 -c "SELECT public.reverse_cashbox_entry('30000000-0000-0000-0000-000000000001','race B');" >/tmp/cashbox-reversal-b.log 2>&1 &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e

if { [ "$status_a" -eq 0 ] && [ "$status_b" -eq 0 ]; } || { [ "$status_a" -ne 0 ] && [ "$status_b" -ne 0 ]; }; then
  echo "FAIL: expected exactly one successful reversal call (A=$status_a, B=$status_b)"
  cat /tmp/cashbox-reversal-a.log
  cat /tmp/cashbox-reversal-b.log
  exit 1
fi

psql -v ON_ERROR_STOP=1 <<'SQL'
DO $$
DECLARE
  reversal_count integer;
  original_is_reversed boolean;
  original_amount numeric;
  reversal_amount numeric;
BEGIN
  SELECT count(*) INTO reversal_count
    FROM public.cashbox_transactions
   WHERE reversal_of = '30000000-0000-0000-0000-000000000001';
  IF reversal_count <> 1 THEN
    RAISE EXCEPTION 'FAIL: expected exactly one reversal row, got %', reversal_count;
  END IF;

  SELECT is_reversed, amount INTO original_is_reversed, original_amount
    FROM public.cashbox_transactions
   WHERE id = '30000000-0000-0000-0000-000000000001';
  IF original_is_reversed IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: original transaction is not marked reversed';
  END IF;

  SELECT amount INTO reversal_amount
    FROM public.cashbox_transactions
   WHERE reversal_of = '30000000-0000-0000-0000-000000000001';
  IF original_amount + reversal_amount <> 0 THEN
    RAISE EXCEPTION 'FAIL: original plus reversal does not net to zero (% + %)', original_amount, reversal_amount;
  END IF;

  RAISE NOTICE 'PASS: exactly one reversal row exists after two concurrent attempts';
  RAISE NOTICE 'PASS: original transaction is marked reversed';
  RAISE NOTICE 'PASS: original and reversal amounts net to zero';
END;
$$;
SQL

echo "PASS: one concurrent reversal call succeeded and the competing call was rejected."
