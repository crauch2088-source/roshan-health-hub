#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:=localhost}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGDATABASE:=postgres}"
export PGHOST PGPORT PGUSER PGDATABASE

BR_ID="62c00000-0000-4000-8000-000000000001"
PHARM_ID="62c00000-0000-4000-8000-000000000011"
PAT_ID="62c00000-0000-4000-8000-000000000021"
MED_ID="62c00000-0000-4000-8000-000000000031"
BATCH_ID="62c00000-0000-4000-8000-000000000041"

VISIT_A="62c00000-0000-4000-8000-000000000101"
INV_A="62c00000-0000-4000-8000-000000000201"
RX_A="62c00000-0000-4000-8000-000000000301"
RXI_A="62c00000-0000-4000-8000-000000000401"
IDEM_A="62c00000-0000-4000-8000-00000000a001"

VISIT_B="62c00000-0000-4000-8000-000000000102"
INV_B="62c00000-0000-4000-8000-000000000202"
RX_B="62c00000-0000-4000-8000-000000000302"
RXI_B="62c00000-0000-4000-8000-000000000402"
IDEM_B="62c00000-0000-4000-8000-00000000b001"

VISIT_C="62c00000-0000-4000-8000-000000000103"
INV_C="62c00000-0000-4000-8000-000000000203"
RX_C="62c00000-0000-4000-8000-000000000303"
RXI_C="62c00000-0000-4000-8000-000000000403"
IDEM_C="62c00000-0000-4000-8000-00000000c001"

psql -v ON_ERROR_STOP=1 -q <<SQL
BEGIN;
INSERT INTO public.branches (id, name, code, is_active)
VALUES ('${BR_ID}', 'Phase62 Concurrency Branch', 'P62C', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.patients (id, branch_id)
VALUES ('${PAT_ID}', '${BR_ID}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.medicines (id, name, selling_price, stock_quantity)
VALUES ('${MED_ID}', 'Phase62 Concurrency Med', 50, 100)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pharmacy_inventory (id, medicine_id, batch_number, expiry_date, quantity, quantity_remaining, quantity_received, branch_id)
VALUES ('${BATCH_ID}', '${MED_ID}', 'BATCH-P62C', CURRENT_DATE + 180, 100, 100, 100, '${BR_ID}')
ON CONFLICT (id) DO UPDATE SET quantity_remaining = 100;

INSERT INTO public.visits (id, patient_id, branch_id) VALUES
  ('${VISIT_A}', '${PAT_ID}', '${BR_ID}'),
  ('${VISIT_B}', '${PAT_ID}', '${BR_ID}'),
  ('${VISIT_C}', '${PAT_ID}', '${BR_ID}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.invoices (id, invoice_number, patient_id, visit_id, total_amount, net_amount, paid_amount, payment_status, branch_id) VALUES
  ('${INV_A}', 'INV-P62C-A', '${PAT_ID}', '${VISIT_A}', 100, 100, 0, 'unpaid', '${BR_ID}'),
  ('${INV_B}', 'INV-P62C-B', '${PAT_ID}', '${VISIT_B}', 100, 100, 100, 'paid', '${BR_ID}'),
  ('${INV_C}', 'INV-P62C-C', '${PAT_ID}', '${VISIT_C}', 100, 100, 100, 'paid', '${BR_ID}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.prescriptions (id, patient_id, visit_id, status, dispensed_by, dispensed_at) VALUES
  ('${RX_A}', '${PAT_ID}', '${VISIT_A}', 'dispensed', '${PHARM_ID}', now()),
  ('${RX_B}', '${PAT_ID}', '${VISIT_B}', 'dispensed', '${PHARM_ID}', now()),
  ('${RX_C}', '${PAT_ID}', '${VISIT_C}', 'dispensed', '${PHARM_ID}', now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.prescription_items (id, prescription_id, medicine_id, medication_name, quantity, dispensed_quantity, unit_price, is_dispensed) VALUES
  ('${RXI_A}', '${RX_A}', '${MED_ID}', 'Phase62 Concurrency Med', 2, 2, 50, true),
  ('${RXI_B}', '${RX_B}', '${MED_ID}', 'Phase62 Concurrency Med', 2, 2, 50, true),
  ('${RXI_C}', '${RX_C}', '${MED_ID}', 'Phase62 Concurrency Med', 2, 2, 50, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.stock_movements (medicine_id, batch_id, movement_type, quantity, reference_id, reference_table, branch_id, created_by) VALUES
  ('${MED_ID}', '${BATCH_ID}', 'dispense', -2, '${RX_A}', 'prescriptions', '${BR_ID}', '${PHARM_ID}'),
  ('${MED_ID}', '${BATCH_ID}', 'dispense', -2, '${RX_B}', 'prescriptions', '${BR_ID}', '${PHARM_ID}'),
  ('${MED_ID}', '${BATCH_ID}', 'dispense', -2, '${RX_C}', 'prescriptions', '${BR_ID}', '${PHARM_ID}');

SELECT set_config('test.user_id', '${PHARM_ID}', true);
SELECT set_config('test.perms', 'pharmacy.read,pharmacy.update', true);
SELECT set_config('test.super_admin', 'false', true);
PERFORM public.confirm_pharmacy_handover('${RX_C}');
COMMIT;
SQL

run_sess() {
  local app="$1"
  local sql="$2"
  PGAPPNAME="$app" psql -v ON_ERROR_STOP=1 -q -c "BEGIN; SELECT set_config('test.user_id','${PHARM_ID}',true); SELECT set_config('test.perms','pharmacy.read,pharmacy.update',true); SELECT set_config('test.super_admin','false',true); ${sql} COMMIT;"
}

# (a) Concurrent cancel_dispense_before_handover vs confirm_pharmacy_handover
set +e
run_sess "p62_a1" "SELECT public.cancel_dispense_before_handover('${RX_A}', 'Concurrent cancel', '${IDEM_A}');" &
p1=$!
run_sess "p62_a2" "SELECT public.confirm_pharmacy_handover('${RX_A}');" &
p2=$!
wait "$p1"; s1=$?
wait "$p2"; s2=$?
set -e
echo "Test (a) statuses: cancel=$s1, handover=$s2"
if [ $(( (s1 == 0) + (s2 == 0) )) -ne 1 ]; then
  echo "FAIL (a): expected exactly one winner between cancel and handover"
  exit 1
fi

# (b) Concurrent duplicate cancel_dispense_before_handover with same UUID idempotency key
set +e
run_sess "p62_b1" "SELECT public.cancel_dispense_before_handover('${RX_B}', 'Duplicate cancel', '${IDEM_B}');" &
p1=$!
run_sess "p62_b2" "SELECT public.cancel_dispense_before_handover('${RX_B}', 'Duplicate cancel', '${IDEM_B}');" &
p2=$!
wait "$p1"; s1=$?
wait "$p2"; s2=$?
set -e
echo "Test (b) statuses: s1=$s1, s2=$s2"
if [ "$s1" -ne 0 ] && [ "$s2" -ne 0 ]; then
  echo "FAIL (b): expected at least one cancel_dispense_before_handover to succeed"
  exit 1
fi

# (c) Concurrent duplicate record_post_handover_return with same UUID idempotency key
set +e
run_sess "p62_c1" "SELECT public.record_post_handover_return('${RX_C}', '${MED_ID}', '${BATCH_ID}', 2, 'unopened_intact', 'Duplicate return', '${IDEM_C}');" &
p1=$!
run_sess "p62_c2" "SELECT public.record_post_handover_return('${RX_C}', '${MED_ID}', '${BATCH_ID}', 2, 'unopened_intact', 'Duplicate return', '${IDEM_C}');" &
p2=$!
wait "$p1"; s1=$?
wait "$p2"; s2=$?
set -e
echo "Test (c) statuses: s1=$s1, s2=$s2"
if [ "$s1" -ne 0 ] && [ "$s2" -ne 0 ]; then
  echo "FAIL (c): expected at least one record_post_handover_return to succeed"
  exit 1
fi

psql -v ON_ERROR_STOP=1 -q <<SQL
DO \$\$
DECLARE
  v_a_cancels int;
  v_a_handover timestamptz;
  v_b_cancels int;
  v_b_comp int;
  v_b_inv_net numeric;
  v_c_returns int;
  v_c_quar int;
  v_c_inv_net numeric;
  v_qty_rem numeric;
BEGIN
  SELECT count(*) INTO v_a_cancels FROM public.pharmacy_dispense_cancellations WHERE prescription_id = '${RX_A}';
  SELECT handover_confirmed_at INTO v_a_handover FROM public.prescriptions WHERE id = '${RX_A}';
  IF NOT ((v_a_cancels = 1 AND v_a_handover IS NULL) OR (v_a_cancels = 0 AND v_a_handover IS NOT NULL)) THEN
    RAISE EXCEPTION 'FAIL (a) split-brain: cancels=%, handover=%', v_a_cancels, v_a_handover;
  END IF;

  SELECT count(*) INTO v_b_cancels FROM public.pharmacy_dispense_cancellations WHERE prescription_id = '${RX_B}';
  SELECT count(*) INTO v_b_comp FROM public.financial_compensations WHERE reference_id = '${RX_B}';
  SELECT net_amount INTO v_b_inv_net FROM public.invoices WHERE id = '${INV_B}';
  IF v_b_cancels <> 1 OR v_b_comp <> 1 OR v_b_inv_net <> 100 THEN
    RAISE EXCEPTION 'FAIL (b): cancels=%, comp=%, inv_net=%', v_b_cancels, v_b_comp, v_b_inv_net;
  END IF;

  SELECT count(*) INTO v_c_returns FROM public.pharmacy_returns WHERE prescription_id = '${RX_C}';
  SELECT count(*) INTO v_c_quar FROM public.pharmacy_return_quarantine q JOIN public.pharmacy_returns r ON r.id = q.return_id WHERE r.prescription_id = '${RX_C}';
  SELECT net_amount INTO v_c_inv_net FROM public.invoices WHERE id = '${INV_C}';
  SELECT quantity_remaining INTO v_qty_rem FROM public.pharmacy_inventory WHERE id = '${BATCH_ID}';
  IF v_c_returns <> 1 OR v_c_quar <> 1 OR v_c_inv_net <> 100 THEN
    RAISE EXCEPTION 'FAIL (c): returns=%, quar=%, inv_net=%', v_c_returns, v_c_quar, v_c_inv_net;
  END IF;
  IF v_qty_rem <> (100 + v_a_cancels * 2 + 2) THEN
    RAISE EXCEPTION 'FAIL inventory restock mismatch: expected %, got %', (100 + v_a_cancels * 2 + 2), v_qty_rem;
  END IF;
END
\$\$;
SQL

echo "ALL PHASE 62 CONCURRENCY CHECKS PASSED"
