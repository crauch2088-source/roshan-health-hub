#!/usr/bin/env bash
set -euo pipefail
: "${PGHOST:=localhost}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGDATABASE:=postgres}"
export PGHOST PGPORT PGUSER PGDATABASE

psql -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.users(id,branch_id,active)
VALUES ('10000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',true)
ON CONFLICT (id) DO UPDATE SET branch_id=EXCLUDED.branch_id,active=true,deleted_at=NULL;

CREATE OR REPLACE FUNCTION public.test_patient_insert_delay()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.full_name IN ('Concurrency Patient A','Concurrency Patient B') THEN
    PERFORM pg_sleep(1.0);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER test_patient_insert_delay
BEFORE INSERT ON public.patients
FOR EACH ROW EXECUTE FUNCTION public.test_patient_insert_delay();
SQL

set +e
PGAPPNAME=patient-registration-a psql -v ON_ERROR_STOP=1 <<'SQL' >/tmp/patient-registration-a.log 2>&1 &
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.allow_create','true',false);
SELECT public.create_patient_atomic('Concurrency Patient A','male',NULL,NULL,NULL);
SQL
pid_a=$!

started=0
for _ in $(seq 1 50); do
  waiting=$(psql -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM pg_stat_activity WHERE application_name='patient-registration-a' AND state='active' AND wait_event='PgSleep';")
  if [ "$waiting" -ge 1 ]; then started=1; break; fi
  sleep 0.05
done
if [ "$started" -ne 1 ]; then
  echo "FAIL: first registration did not enter the controlled insert delay"
  cat /tmp/patient-registration-a.log
  exit 1
fi

PGAPPNAME=patient-registration-b psql -v ON_ERROR_STOP=1 <<'SQL' >/tmp/patient-registration-b.log 2>&1 &
SELECT set_config('test.user_id','10000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.allow_create','true',false);
SELECT public.create_patient_atomic('Concurrency Patient B','female',NULL,NULL,NULL);
SQL
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e
if [ "$status_a" -ne 0 ] || [ "$status_b" -ne 0 ]; then
  echo "FAIL: both concurrent patient registrations should succeed (A=$status_a, B=$status_b)"
  cat /tmp/patient-registration-a.log
  cat /tmp/patient-registration-b.log
  exit 1
fi

psql -v ON_ERROR_STOP=1 <<'SQL'
DO $test$
DECLARE
  total_count integer;
  distinct_mrn_count integer;
BEGIN
  SELECT count(*), count(DISTINCT mrn)
    INTO total_count, distinct_mrn_count
    FROM public.patients
   WHERE full_name IN ('Concurrency Patient A','Concurrency Patient B');
  IF total_count <> 2 OR distinct_mrn_count <> 2 THEN
    RAISE EXCEPTION 'expected two concurrent patient rows with unique MRNs; rows %, unique MRNs %', total_count, distinct_mrn_count;
  END IF;
END
$test$;
DROP TRIGGER test_patient_insert_delay ON public.patients;
DROP FUNCTION public.test_patient_insert_delay();
SQL
