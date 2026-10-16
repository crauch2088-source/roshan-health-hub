#!/usr/bin/env bash
set -euo pipefail

psql -h localhost -U postgres -d postgres -X -q -v ON_ERROR_STOP=1 \
  -f db/tests/finance_rpc_only_writes_fixture.sql \
  -f db/roshan_phase17_finance_rpc_only_writes.sql \
  -f db/tests/finance_payment_idempotency_concurrency_setup.sql

a_out="$(mktemp)"
b_out="$(mktemp)"
trap 'rm -f "$a_out" "$b_out"' EXIT

psql -h localhost -U postgres -d postgres -X -qAt -v ON_ERROR_STOP=1 \
  -c "SET test.user_id='10000000-0000-0000-0000-000000000001';
      SET test.permissions='accounting.create';
      SET test.super_admin='false';
      SET test.pause_payment='true';
      SET ROLE authenticated;
      SELECT public.post_invoice_payment(
        '40000000-0000-0000-0000-000000000001', 5, 'cash', 'race', 'concurrent-key'
      );" >"$a_out" 2>&1 &
a_pid=$!

# Wait until session A is inside pg_sleep from the BEFORE INSERT trigger, after
# it has already passed the idempotency lookup and acquired the invoice row lock.
detected=false
for _ in $(seq 1 100); do
  sleeping="$(psql -h localhost -U postgres -d postgres -X -qAt -c "
    SELECT count(*)
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
      AND datname = current_database()
      AND wait_event = 'PgSleep'
      AND query LIKE '%post_invoice_payment%'
  ")"
  if [[ "$sleeping" == "1" ]]; then
    detected=true
    break
  fi
  sleep 0.1
done

if [[ "$detected" != "true" ]]; then
  echo "Could not observe session A inside the controlled payment-insert delay"
  cat "$a_out"
  kill "$a_pid" 2>/dev/null || true
  exit 1
fi

psql -h localhost -U postgres -d postgres -X -qAt -v ON_ERROR_STOP=1 \
  -c "SET test.user_id='10000000-0000-0000-0000-000000000001';
      SET test.permissions='accounting.create';
      SET test.super_admin='false';
      SET ROLE authenticated;
      SELECT public.post_invoice_payment(
        '40000000-0000-0000-0000-000000000001', 5, 'cash', 'race', 'concurrent-key'
      );" >"$b_out" 2>&1 &
b_pid=$!

set +e
wait "$a_pid"
a_status=$?
wait "$b_pid"
b_status=$?
set -e

if [[ "$a_status" -ne 0 || "$b_status" -ne 0 ]]; then
  echo "Both identical idempotent requests must succeed; session A=$a_status, B=$b_status"
  cat "$a_out"
  cat "$b_out"
  exit 1
fi

a_id="$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$a_out" | tail -n 1)"
b_id="$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$b_out" | tail -n 1)"
if [[ -z "$a_id" || "$a_id" != "$b_id" ]]; then
  echo "Concurrent identical requests did not return the same payment ID: A=$a_id B=$b_id"
  cat "$a_out"
  cat "$b_out"
  exit 1
fi

count="$(psql -h localhost -U postgres -d postgres -X -qAt -c \
  "SELECT count(*) FROM public.payments WHERE idempotency_key='concurrent-key'")"
if [[ "$count" != "1" ]]; then
  echo "Expected one payment row for concurrent-key, found $count"
  exit 1
fi

echo "PASS: concurrent identical invoice-payment requests returned the same ID ($a_id) and created one row."
