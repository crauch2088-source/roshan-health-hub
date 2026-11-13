#!/usr/bin/env bash
set -euo pipefail

PSQL=(psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -X -q -A -t)

count_snapshot() {
  "${PSQL[@]}" -c "SELECT concat_ws('|',
    (SELECT count(*) FROM public.pharmacy_inventory),
    (SELECT count(*) FROM public.stock_movements),
    (SELECT count(*) FROM public.invoices),
    (SELECT count(*) FROM public.invoice_items),
    (SELECT count(*) FROM public.payments),
    (SELECT count(*) FROM public.cashbox_transactions)
  );"
}

before="$(count_snapshot)"

request_id="$("${PSQL[@]}" -c "
  SET ROLE authenticated;
  SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false);
  SELECT set_config('request.jwt.claim.role','authenticated',false);
  SELECT public.request_prescription_item_correction(
    '61800000-0000-0000-0000-000000000010',
    'Concurrent correction regression: confirm the intended catalogue medicine.'
  );
" | tail -n 1 | tr -d '\r')"

if [[ ! "$request_id" =~ ^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$ ]]; then
  printf 'Could not create the concurrent correction fixture request: %s\n' "$request_id" >&2
  exit 1
fi

# Hold the request row briefly during the first resolution so the second session
# must wait on the same parent/item/request lock sequence.
"${PSQL[@]}" <<'SQL'
CREATE OR REPLACE FUNCTION public.phase61_test_delay_correction_resolution()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF OLD.status = 'pending' AND NEW.status IN ('resolved', 'rejected') THEN
    PERFORM pg_sleep(1.5);
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS phase61_test_delay_correction_resolution
  ON public.prescription_item_correction_requests;
CREATE TRIGGER phase61_test_delay_correction_resolution
BEFORE UPDATE OF status ON public.prescription_item_correction_requests
FOR EACH ROW
EXECUTE FUNCTION public.phase61_test_delay_correction_resolution();
SQL

out_a="$(mktemp)"
out_b="$(mktemp)"
trap 'rm -f "$out_a" "$out_b"' EXIT

resolve_command() {
  local note="$1"
  printf "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000002',false); SELECT set_config('request.jwt.claim.role','authenticated',false); SELECT * FROM public.resolve_prescription_item_correction('%s','reject',NULL,'%s');" "$request_id" "$note"
}

"${PSQL[@]}" -c "$(resolve_command 'Concurrent resolver A records the clinical clarification decision.')" >"$out_a" 2>&1 &
pid_a=$!
sleep 0.15
"${PSQL[@]}" -c "$(resolve_command 'Concurrent resolver B must lose the terminal-state race.')" >"$out_b" 2>&1 &
pid_b=$!

set +e
wait "$pid_a"
status_a=$?
wait "$pid_b"
status_b=$?
set -e

if [[ "$status_a" -eq "$status_b" ]]; then
  cat "$out_a" "$out_b" >&2
  printf 'Expected exactly one concurrent resolution to succeed.\n' >&2
  exit 1
fi

if [[ "$status_a" -eq 0 ]]; then
  success_output="$out_a"
  failure_output="$out_b"
else
  success_output="$out_b"
  failure_output="$out_a"
fi

if ! grep -q 'rejected' "$success_output"; then
  cat "$success_output" >&2
  printf 'The winning concurrent resolution did not return rejected.\n' >&2
  exit 1
fi
if ! grep -q 'prescription_correction_request_already_resolved' "$failure_output"; then
  cat "$failure_output" >&2
  printf 'The losing concurrent resolution did not fail on the terminal-state guard.\n' >&2
  exit 1
fi

state="$("${PSQL[@]}" -c "SELECT CASE
  WHEN r.status = 'rejected'
   AND (SELECT count(*) FROM public.prescription_item_correction_events e
        WHERE e.request_id = r.id) = 2
  THEN 'PASS' ELSE 'FAIL' END
FROM public.prescription_item_correction_requests r
WHERE r.id = '$request_id';")"
if [[ "$state" != "PASS" ]]; then
  printf 'Concurrent request/event state was not exactly one terminal transition: %s\n' "$state" >&2
  exit 1
fi

after="$(count_snapshot)"
if [[ "$before" != "$after" ]]; then
  printf 'Concurrent request/rejection changed stock or financial tables. Before: %s After: %s\n' "$before" "$after" >&2
  exit 1
fi

"${PSQL[@]}" -c "
  DROP TRIGGER IF EXISTS phase61_test_delay_correction_resolution
    ON public.prescription_item_correction_requests;
  DROP FUNCTION IF EXISTS public.phase61_test_delay_correction_resolution();
"
printf 'PASS: concurrent correction resolution serialized to one terminal transition with no stock/financial side effects.\n'
