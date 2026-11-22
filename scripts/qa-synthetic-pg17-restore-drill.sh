#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

# Synthetic QA PostgreSQL 17 Backup & Restore Drill (isolated temp DBs only)
# Never targets Production or shared QA hosted Supabase instances.

: "${PGHOST:=127.0.0.1}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGPASSWORD:?PGPASSWORD must be set for isolated PG17 drill container}"
export PGHOST PGPORT PGUSER PGPASSWORD

readonly SOURCE_DB="roshan_qa_drill_source"
readonly RESTORE_DB="roshan_qa_drill_restore"
WORK_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/roshan-qa-pg17-drill.XXXXXX")"
readonly WORK_DIR
readonly PLAIN_DIR="${WORK_DIR}/plaintext"
readonly ARTIFACT_DIR="${WORK_DIR}/artifact"
readonly KEY_FILE="${WORK_DIR}/ephemeral-drill.key"
readonly ARTIFACT_NAME="roshan-qa-synthetic-drill.tar.gz.age"

cleanup() {
  psql -X -d postgres -v ON_ERROR_STOP=0 -c "DROP DATABASE IF EXISTS ${RESTORE_DB} WITH (FORCE);" >/dev/null 2>&1 || true
  psql -X -d postgres -v ON_ERROR_STOP=0 -c "DROP DATABASE IF EXISTS ${SOURCE_DB} WITH (FORCE);" >/dev/null 2>&1 || true
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

mkdir -p "${PLAIN_DIR}" "${ARTIFACT_DIR}"

echo "=== 1. PostgreSQL 17 Client/Server Compatibility Check ==="
CLIENT_PG_DUMP="$(pg_dump --version)"
CLIENT_PG_RESTORE="$(pg_restore --version)"
SERVER_VERSION="$(psql -X -d postgres -Atqc "SELECT current_setting('server_version');")"
SERVER_VERSION_NUM="$(psql -X -d postgres -Atqc "SELECT current_setting('server_version_num')::int;")"
AGE_VERSION="$(age --version)"
echo "pg_dump_version=${CLIENT_PG_DUMP}"
echo "pg_restore_version=${CLIENT_PG_RESTORE}"
echo "server_version=${SERVER_VERSION}"
echo "server_version_num=${SERVER_VERSION_NUM}"
echo "age_version=${AGE_VERSION}"

if (( SERVER_VERSION_NUM < 170000 || SERVER_VERSION_NUM >= 180000 )); then
  echo "::error::Isolated drill requires PostgreSQL 17 (found ${SERVER_VERSION})."
  exit 1
fi

echo "=== 2. Provision Synthetic QA Source Database ==="
psql -X -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${SOURCE_DB} WITH (FORCE);" >/dev/null
psql -X -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${SOURCE_DB} TEMPLATE template0;" >/dev/null

psql -X -d "${SOURCE_DB}" -v ON_ERROR_STOP=1 <<'SQL'
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE public.branches (
  id uuid PRIMARY KEY,
  branch_code text NOT NULL UNIQUE,
  branch_name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE public.patients (
  id uuid PRIMARY KEY,
  mrn text NOT NULL UNIQUE,
  full_name text NOT NULL,
  branch_id uuid NOT NULL REFERENCES public.branches(id)
);

CREATE TABLE public.visits (
  id uuid PRIMARY KEY,
  patient_id uuid NOT NULL REFERENCES public.patients(id),
  branch_id uuid NOT NULL REFERENCES public.branches(id),
  status text NOT NULL CHECK (status IN ('waiting', 'in_progress', 'completed'))
);

CREATE TABLE public.medicines (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  stock_quantity integer NOT NULL CHECK (stock_quantity >= 0),
  selling_price numeric(12,2) NOT NULL CHECK (selling_price >= 0)
);

CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY,
  visit_id uuid NOT NULL REFERENCES public.visits(id),
  patient_id uuid NOT NULL REFERENCES public.patients(id),
  branch_id uuid NOT NULL REFERENCES public.branches(id),
  status text NOT NULL CHECK (status IN ('pending', 'dispensed', 'cancelled'))
);

CREATE TABLE public.invoices (
  id uuid PRIMARY KEY,
  invoice_number text NOT NULL UNIQUE,
  visit_id uuid NOT NULL REFERENCES public.visits(id),
  patient_id uuid NOT NULL REFERENCES public.patients(id),
  branch_id uuid NOT NULL REFERENCES public.branches(id),
  total_amount numeric(12,2) NOT NULL CHECK (total_amount >= 0),
  status text NOT NULL CHECK (status IN ('unpaid', 'partial', 'paid'))
);

CREATE TABLE public.invoice_items (
  id uuid PRIMARY KEY,
  invoice_id uuid NOT NULL REFERENCES public.invoices(id),
  item_type text NOT NULL CHECK (item_type IN ('lab', 'pharmacy', 'consultation')),
  item_name text NOT NULL,
  quantity numeric(10,2) NOT NULL CHECK (quantity > 0),
  unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
  total_price numeric(12,2) NOT NULL CHECK (total_price >= 0)
);

CREATE TABLE public.stock_movements (
  id uuid PRIMARY KEY,
  medicine_id uuid NOT NULL REFERENCES public.medicines(id),
  movement_type text NOT NULL CHECK (movement_type IN ('purchase', 'dispense', 'adjustment')),
  quantity numeric(10,2) NOT NULL,
  reference_id uuid NOT NULL
);

CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY,
  table_name text NOT NULL,
  action text NOT NULL,
  record_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_invoices_visit_id ON public.invoices(visit_id);
CREATE INDEX idx_stock_movements_medicine_id ON public.stock_movements(medicine_id);

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.qa_drill_invoice_sum(_visit_id uuid)
RETURNS numeric
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(SUM(ii.total_price), 0)
  FROM public.invoices i
  JOIN public.invoice_items ii ON ii.invoice_id = i.id
  WHERE i.visit_id = _visit_id;
$$;

-- Seed synthetic QA fixtures (zero real/Production data)
INSERT INTO public.branches VALUES
  ('274db95c-12f4-4d7b-a772-8228c572a692', 'ROS-MAIN', 'ROSHAN Main Branch (QA Synthetic)', true);
INSERT INTO public.patients VALUES
  ('3a6b645c-f75d-400e-82b2-6eb8b269e881', 'RMC000001', 'QA Synthetic Patient 20261121', '274db95c-12f4-4d7b-a772-8228c572a692');
INSERT INTO public.visits VALUES
  ('ab7cc71b-4e25-4342-aafa-96b223802225', '3a6b645c-f75d-400e-82b2-6eb8b269e881', '274db95c-12f4-4d7b-a772-8228c572a692', 'in_progress');
INSERT INTO public.medicines VALUES
  ('e9fdbdb8-3539-4809-9dea-0842bb9818a2', 'QA Test Paracetamol 500mg', 8, 150.00);
INSERT INTO public.prescriptions VALUES
  ('7239fedf-b480-4970-bc65-f0a0cde15ce1', 'ab7cc71b-4e25-4342-aafa-96b223802225', '3a6b645c-f75d-400e-82b2-6eb8b269e881', '274db95c-12f4-4d7b-a772-8228c572a692', 'dispensed');
INSERT INTO public.invoices VALUES
  ('53a21820-80f8-4437-8796-43f4bcd56b7e', 'INV-202611-00001', 'ab7cc71b-4e25-4342-aafa-96b223802225', '3a6b645c-f75d-400e-82b2-6eb8b269e881', '274db95c-12f4-4d7b-a772-8228c572a692', 800.00, 'unpaid');
INSERT INTO public.invoice_items VALUES
  ('b6e2d6cb-79b4-48ed-becf-c756c10c2fbe', '53a21820-80f8-4437-8796-43f4bcd56b7e', 'lab', 'QA Synthetic CBC', 1.00, 500.00, 500.00),
  ('c4f4f3b5-4fa7-4f93-86a6-a336faa38a1d', '53a21820-80f8-4437-8796-43f4bcd56b7e', 'pharmacy', 'QA Test Paracetamol 500mg', 2.00, 150.00, 300.00);
INSERT INTO public.stock_movements VALUES
  ('4ec5103f-5576-45f0-bdae-a8f07750cf62', 'e9fdbdb8-3539-4809-9dea-0842bb9818a2', 'purchase', 10.00, '7fbb386d-1746-4465-abe5-d3476081a640'),
  ('9d180652-8e71-4747-8b34-117ed1b2154e', 'e9fdbdb8-3539-4809-9dea-0842bb9818a2', 'dispense', -2.00, '7239fedf-b480-4970-bc65-f0a0cde15ce1');
INSERT INTO public.audit_logs VALUES
  ('a3902ffe-2ff1-4c08-8f11-6ef9f6e76321', 'prescriptions', 'UPDATE', '7239fedf-b480-4970-bc65-f0a0cde15ce1', now()),
  ('877378d7-6e2d-4841-8b8a-5ce4120ee08d', 'invoices', 'UPDATE', '53a21820-80f8-4437-8796-43f4bcd56b7e', now());
SQL

BACKUP_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "backup_recovery_point_utc=${BACKUP_TS}"

COUNT_SQL="SELECT jsonb_build_object(
  'branches',(SELECT count(*) FROM public.branches),
  'patients',(SELECT count(*) FROM public.patients),
  'visits',(SELECT count(*) FROM public.visits),
  'medicines',(SELECT count(*) FROM public.medicines),
  'prescriptions',(SELECT count(*) FROM public.prescriptions),
  'invoices',(SELECT count(*) FROM public.invoices),
  'invoice_items',(SELECT count(*) FROM public.invoice_items),
  'stock_movements',(SELECT count(*) FROM public.stock_movements),
  'audit_logs',(SELECT count(*) FROM public.audit_logs),
  'rls_tables',(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity),
  'secdef_empty_sp',(SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef AND p.proconfig @> ARRAY['search_path='])
)::text;"

SOURCE_COUNTS="$(psql -X -d "${SOURCE_DB}" -v ON_ERROR_STOP=1 -Atqc "${COUNT_SQL}")"
printf '%s
' "${SOURCE_COUNTS}" > "${PLAIN_DIR}/source-counts.json"
echo "source_counts=${SOURCE_COUNTS}"

echo "=== 3. Create Custom Dump, Package, and Atomically Encrypt with Ephemeral Drill Key ==="
pg_dump -d "${SOURCE_DB}" --format=custom --no-owner --file="${PLAIN_DIR}/full.dump"
pg_restore --list "${PLAIN_DIR}/full.dump" > "${PLAIN_DIR}/archive-contents.txt"
tar -C "${PLAIN_DIR}" -czf "${WORK_DIR}/bundle.tar.gz" full.dump archive-contents.txt source-counts.json

age-keygen -o "${KEY_FILE}" >/dev/null 2>&1
EPHEMERAL_RECIPIENT="$(age-keygen -y "${KEY_FILE}")"
age -r "${EPHEMERAL_RECIPIENT}" -o "${ARTIFACT_DIR}/${ARTIFACT_NAME}.tmp" "${WORK_DIR}/bundle.tar.gz"
mv "${ARTIFACT_DIR}/${ARTIFACT_NAME}.tmp" "${ARTIFACT_DIR}/${ARTIFACT_NAME}"
(cd "${ARTIFACT_DIR}" && sha256sum "${ARTIFACT_NAME}" > SHA256SUMS)
ARTIFACT_SHA256="$(awk '{print $1}' "${ARTIFACT_DIR}/SHA256SUMS")"
ARTIFACT_BYTES="$(stat -c %s "${ARTIFACT_DIR}/${ARTIFACT_NAME}")"
echo "encrypted_artifact_sha256=${ARTIFACT_SHA256}"
echo "encrypted_artifact_bytes=${ARTIFACT_BYTES}"

echo "=== 4. Verify Checksum, Decrypt, Restore into Isolated PG17 Target, and Measure QA Drill RTO ==="
RTO_START_MS="$(date +%s%3N)"
RTO_START_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

(cd "${ARTIFACT_DIR}" && sha256sum -c SHA256SUMS)
mkdir -p "${WORK_DIR}/restored-bundle"
age -d -i "${KEY_FILE}" "${ARTIFACT_DIR}/${ARTIFACT_NAME}" | tar -xz -C "${WORK_DIR}/restored-bundle"

psql -X -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${RESTORE_DB} WITH (FORCE);" >/dev/null
psql -X -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${RESTORE_DB} TEMPLATE template0;" >/dev/null
pg_restore --dbname="${RESTORE_DB}" --no-owner --exit-on-error --single-transaction "${WORK_DIR}/restored-bundle/full.dump"

RESTORE_COUNTS="$(psql -X -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 -Atqc "${COUNT_SQL}")"
SMOKE_TOTAL="$(psql -X -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 -Atqc "SELECT public.qa_drill_invoice_sum('ab7cc71b-4e25-4342-aafa-96b223802225');")"
SMOKE_STOCK="$(psql -X -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 -Atqc "SELECT stock_quantity FROM public.medicines WHERE id='e9fdbdb8-3539-4809-9dea-0842bb9818a2';")"
RESTORE_DB_SIZE="$(psql -X -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 -Atqc "SELECT pg_size_pretty(pg_database_size('${RESTORE_DB}'));")"

if [[ "${SOURCE_COUNTS}" != "${RESTORE_COUNTS}" ]]; then
  echo "::error::QA drill structural/row-count mismatch."
  exit 1
fi
if [[ "${SMOKE_TOTAL}" != "800.00" || "${SMOKE_STOCK}" != "8" ]]; then
  echo "::error::QA drill smoke assertion failed (total=${SMOKE_TOTAL}, stock=${SMOKE_STOCK})."
  exit 1
fi

RTO_END_MS="$(date +%s%3N)"
RTO_END_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RTO_MS=$(( RTO_END_MS - RTO_START_MS ))

echo "restore_counts=${RESTORE_COUNTS}"
echo "smoke_invoice_total_sdg=${SMOKE_TOTAL}"
echo "smoke_paracetamol_stock=${SMOKE_STOCK}"
echo "restored_db_size=${RESTORE_DB_SIZE}"
echo "rto_start_utc=${RTO_START_UTC}"
echo "rto_end_utc=${RTO_END_UTC}"
echo "qa_drill_rto_ms=${RTO_MS}"

echo "=== 5. Explicit Cleanup & Verification ==="
psql -X -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${RESTORE_DB} WITH (FORCE);" >/dev/null
psql -X -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${SOURCE_DB} WITH (FORCE);" >/dev/null
rm -rf "${WORK_DIR}"

LEFTOVER_DBS="$(psql -X -d postgres -Atqc "SELECT count(*) FROM pg_database WHERE datname IN ('${SOURCE_DB}', '${RESTORE_DB}');")"
if [[ "${LEFTOVER_DBS}" != "0" || -d "${WORK_DIR}" ]]; then
  echo "::error::Cleanup verification failed (leftover_dbs=${LEFTOVER_DBS})."
  exit 1
fi
echo "cleanup_leftover_dbs=${LEFTOVER_DBS}"
echo "cleanup_workdir_exists=false"
echo "QA_SYNTHETIC_PG17_RESTORE_DRILL=PASS"
