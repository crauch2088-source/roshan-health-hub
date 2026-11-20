#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:=localhost}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGDATABASE:=postgres}"
export PGHOST PGPORT PGUSER PGDATABASE

BRANCH_1="63c00000-0000-4000-8000-000000000001"
USER_1="63c00000-0000-4000-8000-000000000011"
MED_ID="63c00000-0000-4000-8000-000000000101"
BATCH_A="63c00000-0000-4000-8000-000000000201"
BATCH_B="63c00000-0000-4000-8000-000000000202"
BATCH_C="63c00000-0000-4000-8000-000000000203"
BATCH_D="63c00000-0000-4000-8000-000000000204"

# 1. Seed deterministic synthetic fixture rows matching Phase 63 schema
psql -v ON_ERROR_STOP=1 <<SQL
INSERT INTO public.users (id, branch_id, active)
VALUES ('${USER_1}', '${BRANCH_1}', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.medicines (id, name, brand_name, generic_name, selling_price, stock_quantity, active, is_active)
VALUES ('${MED_ID}', 'Phase63 Concurrency Med', 'P63ConcBrand', 'P63ConcGeneric', 10.00, 260, true, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pharmacy_inventory (id, medicine_id, batch_number, expiry_date, quantity, quantity_remaining, quantity_received, branch_id)
VALUES
  ('${BATCH_A}', '${MED_ID}', 'P63C-BATCH-A', CURRENT_DATE + 365, 100, 100, 100, '${BRANCH_1}'),
  ('${BATCH_B}', '${MED_ID}', 'P63C-BATCH-B', CURRENT_DATE + 365, 100, 100, 100, '${BRANCH_1}'),
  ('${BATCH_C}', '${MED_ID}', 'P63C-BATCH-C', CURRENT_DATE - 5,   20,  20,  20,  '${BRANCH_1}'),
  ('${BATCH_D}', '${MED_ID}', 'P63C-BATCH-D', CURRENT_DATE + 365, 40,  40,  40,  '${BRANCH_1}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.stock_movements (medicine_id, batch_id, movement_type, quantity, reference_id, reference_table, notes, branch_id, created_by)
VALUES
  ('${MED_ID}', '${BATCH_A}', 'stock_in', 100, NULL, NULL, 'Initial concurrency seed A', '${BRANCH_1}', '${USER_1}'),
  ('${MED_ID}', '${BATCH_B}', 'stock_in', 100, NULL, NULL, 'Initial concurrency seed B', '${BRANCH_1}', '${USER_1}'),
  ('${MED_ID}', '${BATCH_C}', 'stock_in', 20,  NULL, NULL, 'Initial concurrency seed C', '${BRANCH_1}', '${USER_1}'),
  ('${MED_ID}', '${BATCH_D}', 'stock_in', 40,  NULL, NULL, 'Initial concurrency seed D', '${BRANCH_1}', '${USER_1}');
SQL

run_session() {
  local app_name="$1"
  local sql_call="$2"
  local log_file="$3"
  PGAPPNAME="${app_name}" psql -v ON_ERROR_STOP=1 -c "
    BEGIN;
    SELECT set_config('test.user_id', '${USER_1}', true),
           set_config('test.super_admin', 'false', true),
           set_config('test.perms', 'pharmacy.read,pharmacy.update', true);
    ${sql_call}
    COMMIT;
  " >"${log_file}" 2>&1
}

# (a) Two concurrent adjust_inventory_batch_atomic calls racing -60 each on 100-unit batch
set +e
run_session "p63_a_1" "SELECT public.adjust_inventory_batch_atomic('${BATCH_A}', -60, 'Concurrent deduct A1', 'p63-conc-a-1');" /tmp/p63_a_1.log &
pid_a=$!
run_session "p63_a_2" "SELECT public.adjust_inventory_batch_atomic('${BATCH_A}', -60, 'Concurrent deduct A2', 'p63-conc-a-2');" /tmp/p63_a_2.log &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e

echo "Test (a) statuses: A=${status_a}, B=${status_b}"
if ! { [ "$status_a" -eq 0 ] && [ "$status_b" -ne 0 ]; } && ! { [ "$status_a" -ne 0 ] && [ "$status_b" -eq 0 ]; }; then
  echo "FAIL (a): expected XOR success, got A=${status_a}, B=${status_b}"
  cat /tmp/p63_a_1.log /tmp/p63_a_2.log
  exit 1
fi
if [ "$status_a" -ne 0 ]; then fail_log=/tmp/p63_a_1.log; else fail_log=/tmp/p63_a_2.log; fi
grep -q "negative_stock_not_permitted" "$fail_log" || { echo "FAIL (a): expected negative_stock_not_permitted"; cat "$fail_log"; exit 1; }

rem_a=$(psql -Atc "SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id = '${BATCH_A}';")
[ "$rem_a" -eq 40 ] || { echo "FAIL (a): expected quantity_remaining=40, got ${rem_a}"; exit 1; }

# (b) Two concurrent adjust_inventory_batch_atomic calls with SAME p_idempotency_key (+15)
set +e
run_session "p63_b_1" "SELECT public.adjust_inventory_batch_atomic('${BATCH_B}', 15, 'Idempotent surplus B', 'p63-conc-b-same');" /tmp/p63_b_1.log &
pid_a=$!
run_session "p63_b_2" "SELECT public.adjust_inventory_batch_atomic('${BATCH_B}', 15, 'Idempotent surplus B', 'p63-conc-b-same');" /tmp/p63_b_2.log &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e

echo "Test (b) statuses: A=${status_a}, B=${status_b}"
[ "$status_a" -eq 0 ] && [ "$status_b" -eq 0 ] || { echo "FAIL (b): expected both to succeed"; cat /tmp/p63_b_1.log /tmp/p63_b_2.log; exit 1; }

rem_b=$(psql -Atc "SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id = '${BATCH_B}';")
mov_b=$(psql -Atc "SELECT COUNT(*) FROM public.stock_movements WHERE batch_id = '${BATCH_B}' AND movement_type <> 'stock_in';")
[ "$rem_b" -eq 115 ] || { echo "FAIL (b): expected quantity_remaining=115, got ${rem_b}"; exit 1; }
[ "$mov_b" -eq 1 ] || { echo "FAIL (b): expected 1 movement, got ${mov_b}"; exit 1; }

# (c) Concurrent quarantine_expired_batch_atomic vs adjust_inventory_batch_atomic on expired batch
set +e
run_session "p63_c_1" "SELECT public.quarantine_expired_batch_atomic('${BATCH_C}', 'Expired quarantine race', 'p63-conc-c-quar');" /tmp/p63_c_1.log &
pid_a=$!
run_session "p63_c_2" "SELECT public.adjust_inventory_batch_atomic('${BATCH_C}', -5, 'Concurrent adjust on expired', 'p63-conc-c-adj');" /tmp/p63_c_2.log &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e

echo "Test (c) statuses: quarantine=${status_a}, adjust=${status_b}"
[ "$status_a" -eq 0 ] || { echo "FAIL (c): quarantine failed"; cat /tmp/p63_c_1.log /tmp/p63_c_2.log; exit 1; }
if grep -qi "deadlock detected" /tmp/p63_c_1.log /tmp/p63_c_2.log; then
  echo "FAIL (c): deadlock detected"; cat /tmp/p63_c_1.log /tmp/p63_c_2.log; exit 1
fi
res_c=$(psql -Atc "SELECT quantity_remaining || '|' || is_quarantined FROM public.pharmacy_inventory WHERE id = '${BATCH_C}';")
[ "$res_c" = "0|t" ] || { echo "FAIL (c): expected 0|t, got ${res_c}"; exit 1; }

# (d) Two concurrent record_inventory_writeoff_atomic calls racing 30 each on 40-unit batch
set +e
run_session "p63_d_1" "SELECT public.record_inventory_writeoff_atomic('${BATCH_D}', 30, 'damaged', 'Concurrent writeoff 1', 'p63-conc-d-1');" /tmp/p63_d_1.log &
pid_a=$!
run_session "p63_d_2" "SELECT public.record_inventory_writeoff_atomic('${BATCH_D}', 30, 'damaged', 'Concurrent writeoff 2', 'p63-conc-d-2');" /tmp/p63_d_2.log &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e

echo "Test (d) statuses: A=${status_a}, B=${status_b}"
if ! { [ "$status_a" -eq 0 ] && [ "$status_b" -ne 0 ]; } && ! { [ "$status_a" -ne 0 ] && [ "$status_b" -eq 0 ]; }; then
  echo "FAIL (d): expected XOR success, got A=${status_a}, B=${status_b}"
  cat /tmp/p63_d_1.log /tmp/p63_d_2.log
  exit 1
fi
rem_d=$(psql -Atc "SELECT quantity_remaining FROM public.pharmacy_inventory WHERE id = '${BATCH_D}';")
[ "$rem_d" -eq 10 ] || { echo "FAIL (d): expected quantity_remaining=10, got ${rem_d}"; exit 1; }

neg_cnt=$(psql -Atc "SELECT COUNT(*) FROM public.pharmacy_inventory WHERE medicine_id = '${MED_ID}' AND quantity_remaining < 0;")
[ "$neg_cnt" -eq 0 ] || { echo "FAIL: found negative stock batches: ${neg_cnt}"; exit 1; }

# (e) Two concurrent update_medicine_selling_price_atomic calls with distinct idempotency keys
set +e
run_session "p63_e_1" "SELECT public.update_medicine_selling_price_atomic('${MED_ID}', '${BRANCH_1}', 12.50, 'Price update A', 'p63-conc-e-1');" /tmp/p63_e_1.log &
pid_a=$!
run_session "p63_e_2" "SELECT public.update_medicine_selling_price_atomic('${MED_ID}', '${BRANCH_1}', 14.00, 'Price update B', 'p63-conc-e-2');" /tmp/p63_e_2.log &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e

echo "Test (e) statuses: A=${status_a}, B=${status_b}"
[ "$status_a" -eq 0 ] && [ "$status_b" -eq 0 ] || { echo "FAIL (e): expected both price updates to succeed"; cat /tmp/p63_e_1.log /tmp/p63_e_2.log; exit 1; }

hist_cnt=$(psql -Atc "SELECT COUNT(*) FROM public.medicine_price_history WHERE medicine_id = '${MED_ID}' AND branch_id = '${BRANCH_1}';")
[ "$hist_cnt" -eq 2 ] || { echo "FAIL (e): expected 2 price history rows, got ${hist_cnt}"; exit 1; }

price_match=$(psql -Atc "
  SELECT (m.selling_price = h.new_price)
  FROM public.medicines m
  CROSS JOIN LATERAL (
    SELECT new_price FROM public.medicine_price_history
    WHERE medicine_id = m.id AND branch_id = '${BRANCH_1}'
    ORDER BY created_at DESC, id DESC
    LIMIT 1
  ) h
  WHERE m.id = '${MED_ID}';
")
[ "$price_match" = "t" ] || { echo "FAIL (e): selling_price does not match latest history row"; exit 1; }

# Final reconciliation check
reconcile_res=$(psql -Atc "SELECT is_balanced || '|' || batch_sum || '|' || ledger_net FROM public.reconcile_medicine_stock_ledger('${MED_ID}', '${BRANCH_1}');")
echo "Reconcile result: ${reconcile_res}"
is_bal="${reconcile_res%%|*}"
[ "$is_bal" = "t" ] || { echo "FAIL: reconcile_medicine_stock_ledger is_balanced=${reconcile_res}"; exit 1; }

echo "PASS: phase63_inventory_ledger_concurrency.sh"
