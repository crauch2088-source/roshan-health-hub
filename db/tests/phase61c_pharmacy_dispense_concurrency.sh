#!/usr/bin/env bash
set -euo pipefail

PSQL=(psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -X -q -A -t)
OUT_A="$(mktemp)"
OUT_B="$(mktemp)"

cleanup() {
  "${PSQL[@]}" -c "
    DROP TRIGGER IF EXISTS phase61c_test_delay_prescription ON public.prescriptions;
    DROP TRIGGER IF EXISTS phase61c_test_delay_medicine ON public.medicines;
    DROP FUNCTION IF EXISTS public.phase61c_test_delay_dispense();
  " >/dev/null 2>&1 || true
  rm -f "$OUT_A" "$OUT_B"
}
trap cleanup EXIT

# Isolated synthetic medicine with five units. The first race consumes one;
# the second race deliberately asks two concurrent prescriptions for six units.
"${PSQL[@]}" <<'SQL'
INSERT INTO public.medicines (
  id,generic_name,brand_name,name,strength,dosage_form,active,is_active,selling_price,stock_quantity
) VALUES (
  '61600000-0000-0000-0000-000000000002',
  'Concurrency test medicine','Roshan CI','Concurrency test medicine','1 unit','tablet',
  true,true,1.00,5
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.pharmacy_inventory (
  id,medicine_id,batch_number,expiry_date,quantity,quantity_received,quantity_remaining,branch_id
) VALUES (
  '61900000-0000-0000-0000-000000000002',
  '61600000-0000-0000-0000-000000000002',
  'PHASE61C-RACE',
  CURRENT_DATE + 90,
  5,5,5,
  '61100000-0000-0000-0000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.prescriptions (
  id,patient_id,visit_id,prescribed_by,doctor_id,prescription_type,is_external,status,created_by,updated_by
) VALUES
  ('61700000-0000-0000-0000-000000000017','61400000-0000-0000-0000-000000000001','61500000-0000-0000-0000-000000000001','61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002','internal',false,'pending','61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002'),
  ('61700000-0000-0000-0000-000000000018','61400000-0000-0000-0000-000000000001','61500000-0000-0000-0000-000000000001','61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002','internal',false,'pending','61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002'),
  ('61700000-0000-0000-0000-000000000019','61400000-0000-0000-0000-000000000001','61500000-0000-0000-0000-000000000001','61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002','internal',false,'pending','61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.prescription_items (
  id,prescription_id,medicine_id,medication_name,dose,dosage,frequency,duration,quantity,
  instructions,dosage_form,route,unit_price,created_by,updated_by,is_dispensed,dispensed_quantity
) VALUES
  ('61800000-0000-0000-0000-000000000017','61700000-0000-0000-0000-000000000017','61600000-0000-0000-0000-000000000002','Concurrency test medicine','1 unit','1 unit','OD','1 day',1,'CI race','tablet','oral',1.00,'61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002',false,0),
  ('61800000-0000-0000-0000-000000000018','61700000-0000-0000-0000-000000000018','61600000-0000-0000-0000-000000000002','Concurrency test medicine','1 unit','1 unit','OD','1 day',3,'CI race','tablet','oral',1.00,'61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002',false,0),
  ('61800000-0000-0000-0000-000000000019','61700000-0000-0000-0000-000000000019','61600000-0000-0000-0000-000000000002','Concurrency test medicine','1 unit','1 unit','OD','1 day',3,'CI race','tablet','oral',1.00,'61300000-0000-0000-0000-000000000002','61300000-0000-0000-0000-000000000002',false,0)
ON CONFLICT (id) DO NOTHING;

UPDATE public.invoices
SET status='paid', payment_status='paid', paid_amount=net_amount
WHERE visit_id='61500000-0000-0000-0000-000000000001'
  AND is_primary IS TRUE
  AND deleted_at IS NULL;

DO $phase61c_concurrency_fixture$
BEGIN
  IF (SELECT stock_quantity FROM public.medicines
      WHERE id='61600000-0000-0000-0000-000000000002') <> 5
     OR (SELECT quantity_remaining FROM public.pharmacy_inventory
      WHERE id='61900000-0000-0000-0000-000000000002') <> 5 THEN
    RAISE EXCEPTION 'concurrency fixture did not start with exactly five stock units';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.invoices
    WHERE visit_id='61500000-0000-0000-0000-000000000001'
      AND is_primary IS TRUE AND status='paid' AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'concurrency fixture requires the finalized primary invoice';
  END IF;
END;
$phase61c_concurrency_fixture$;

CREATE OR REPLACE FUNCTION public.phase61c_test_delay_dispense()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_TABLE_NAME = 'prescriptions'
     AND OLD.id = '61700000-0000-0000-0000-000000000017'
     AND OLD.status = 'pending'
     AND NEW.status = 'dispensed' THEN
    PERFORM pg_sleep(1.5);
  END IF;
  IF TG_TABLE_NAME = 'medicines'
     AND OLD.id = '61600000-0000-0000-0000-000000000002'
     AND NEW.stock_quantity < OLD.stock_quantity THEN
    PERFORM pg_sleep(1.5);
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS phase61c_test_delay_prescription ON public.prescriptions;
CREATE TRIGGER phase61c_test_delay_prescription
BEFORE UPDATE OF status ON public.prescriptions
FOR EACH ROW EXECUTE FUNCTION public.phase61c_test_delay_dispense();

DROP TRIGGER IF EXISTS phase61c_test_delay_medicine ON public.medicines;
CREATE TRIGGER phase61c_test_delay_medicine
BEFORE UPDATE OF stock_quantity ON public.medicines
FOR EACH ROW EXECUTE FUNCTION public.phase61c_test_delay_dispense();
SQL

run_pair() {
  local label="$1"
  local prescription_a="$2"
  local prescription_b="$3"
  local request_a="$4"
  local request_b="$5"
  local expected_error="$6"
  local app_a="phase61c_${label}_a"
  local app_b="phase61c_${label}_b"
  local sql_a="SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false); SELECT set_config('request.jwt.claim.role','authenticated',false); SELECT * FROM public.atomic_pharmacy_dispense('${prescription_a}',true,'${request_a}');"
  local sql_b="SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','61200000-0000-0000-0000-000000000001',false); SELECT set_config('request.jwt.claim.role','authenticated',false); SELECT * FROM public.atomic_pharmacy_dispense('${prescription_b}',true,'${request_b}');"

  PGAPPNAME="$app_a" "${PSQL[@]}" -c "$sql_a" >"$OUT_A" 2>&1 &
  local pid_a=$!
  sleep 0.15
  PGAPPNAME="$app_b" "${PSQL[@]}" -c "$sql_b" >"$OUT_B" 2>&1 &
  local pid_b=$!

  # Observe a real PostgreSQL lock wait while one transaction holds the row.
  local lock_seen=0
  for _ in {1..60}; do
    local blocked
    blocked="$("${PSQL[@]}" -c "SELECT count(*) FROM pg_stat_activity WHERE application_name IN ('$app_a','$app_b') AND wait_event_type='Lock';")"
    if [[ "$blocked" -ge 1 ]]; then
      lock_seen=1
      break
    fi
    sleep 0.05
  done
  if [[ "$lock_seen" -ne 1 ]]; then
    cat "$OUT_A" "$OUT_B" >&2
    printf 'No PostgreSQL row-lock wait was observed in %s race.\n' "$label" >&2
    return 1
  fi

  set +e
  wait "$pid_a"
  local status_a=$?
  wait "$pid_b"
  local status_b=$?
  set -e

  if [[ "$status_a" -eq "$status_b" ]]; then
    cat "$OUT_A" "$OUT_B" >&2
    printf 'Expected exactly one winner in %s race (exit codes %s/%s).\n' "$label" "$status_a" "$status_b" >&2
    return 1
  fi

  local failure_output="$OUT_A"
  if [[ "$status_a" -eq 0 ]]; then failure_output="$OUT_B"; fi
  if ! grep -Fq "$expected_error" "$failure_output"; then
    cat "$OUT_A" "$OUT_B" >&2
    printf 'The losing %s transaction did not fail at the expected guard: %s\n' "$label" "$expected_error" >&2
    return 1
  fi
}

# Same prescription, different request IDs: only one transaction may dispense it.
run_pair "same" \
  "61700000-0000-0000-0000-000000000017" \
  "61700000-0000-0000-0000-000000000017" \
  "ffffffff-ffff-ffff-ffff-ffffffffffe4" \
  "ffffffff-ffff-ffff-ffff-ffffffffffe5" \
  "prescription_not_pending"

# Different prescriptions competing for the final stock: one may consume three,
# the other must fail after waiting and re-reading the locked aggregate/batch balance.
run_pair "stock" \
  "61700000-0000-0000-0000-000000000018" \
  "61700000-0000-0000-0000-000000000019" \
  "ffffffff-ffff-ffff-ffff-ffffffffffe6" \
  "ffffffff-ffff-ffff-ffff-ffffffffffe7" \
  "medicine aggregate stock is insufficient or inconsistent"

state="$("${PSQL[@]}" -c "
SELECT CASE WHEN
  (SELECT count(*) FROM private.pharmacy_dispense_idempotency
   WHERE request_id IN (
     'ffffffff-ffff-ffff-ffff-ffffffffffe4',
     'ffffffff-ffff-ffff-ffff-ffffffffffe5'
   )) = 1
  AND
  (SELECT count(*) FROM private.pharmacy_dispense_idempotency
   WHERE request_id IN (
     'ffffffff-ffff-ffff-ffff-ffffffffffe6',
     'ffffffff-ffff-ffff-ffff-ffffffffffe7'
   )) = 1
  AND
  (SELECT count(*) FROM public.stock_movements
   WHERE reference_id='61700000-0000-0000-0000-000000000017'
     AND reference_table='prescriptions' AND movement_type='dispense') = 1
  AND
  (SELECT count(*) FROM public.stock_movements
   WHERE reference_id IN (
     '61700000-0000-0000-0000-000000000018',
     '61700000-0000-0000-0000-000000000019'
   )
     AND reference_table='prescriptions' AND movement_type='dispense') = 1
  AND
  (SELECT count(*) FROM public.prescriptions
   WHERE id='61700000-0000-0000-0000-000000000017' AND status='dispensed') = 1
  AND
  (SELECT count(*) FROM public.prescriptions
   WHERE id IN (
     '61700000-0000-0000-0000-000000000018',
     '61700000-0000-0000-0000-000000000019'
   ) AND status='dispensed') = 1
  AND
  (SELECT count(*) FROM public.prescriptions
   WHERE id IN (
     '61700000-0000-0000-0000-000000000018',
     '61700000-0000-0000-0000-000000000019'
   ) AND status='pending') = 1
  AND
  (SELECT stock_quantity FROM public.medicines
   WHERE id='61600000-0000-0000-0000-000000000002') = 1
  AND
  (SELECT quantity_remaining FROM public.pharmacy_inventory
   WHERE id='61900000-0000-0000-0000-000000000002') = 1
  AND
  (SELECT count(*) FROM public.invoice_items
   WHERE item_type='pharmacy'
     AND item_id='61600000-0000-0000-0000-000000000002'
     AND deleted_at IS NULL) = 2
THEN 'PASS' ELSE 'FAIL' END;
")"

if [[ "$state" != "PASS" ]]; then
  printf 'Atomic dispense concurrency assertions failed: %s\n' "$state" >&2
  exit 1
fi

printf 'PASS: same-prescription/different-key and final-stock pharmacy dispense races serialized with exactly one successful write each.\n'
