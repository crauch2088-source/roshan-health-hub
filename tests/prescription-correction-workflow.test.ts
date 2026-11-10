import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { test } from "node:test";

const migrationPath = new URL("../db/roshan_phase61_prescription_correction_workflow.sql", import.meta.url);
const integrationPath = new URL("../db/tests/prescription_correction_integration.sql", import.meta.url);
const migration = existsSync(migrationPath) ? readFileSync(migrationPath, "utf8") : "";
const integration = existsSync(integrationPath) ? readFileSync(integrationPath, "utf8") : "";
const workflow = readFileSync(new URL("../.github/workflows/ci.yml", import.meta.url), "utf8");

test("correction request and event tables preserve parent/item identity and immutable evidence", () => {
  assert.match(migration, /CREATE TABLE(?: IF NOT EXISTS)? public\.prescription_item_correction_requests/i);
  assert.match(migration, /CREATE TABLE(?: IF NOT EXISTS)? public\.prescription_item_correction_events/i);
  for (const field of ["prescription_id", "prescription_item_id", "patient_id", "visit_id", "branch_id", "prescriber_id", "visit_doctor_id", "item_snapshot", "requested_by", "requested_at", "status"]) {
    assert.match(migration, new RegExp("\\b" + field + "\\b", "i"));
  }
  assert.match(migration, /UNIQUE INDEX[\s\S]*prescription_item_id[\s\S]*WHERE status = 'pending'/i);
  assert.match(migration, /reject_prescription_item_correction_event_mutation/i);
  assert.match(migration, /BEFORE UPDATE OR DELETE/i);
  assert.match(migration, /BEFORE TRUNCATE/i);
});

test("dedicated correction permissions are assigned only to current pharmacist and doctor roles", () => {
  assert.match(migration, /pharmacy\.correction\.request/);
  assert.match(migration, /prescriptions\.correction\.resolve/);
  assert.match(migration, /r\.code\s*=\s*'pharmacist'/i);
  assert.match(migration, /r\.code\s*=\s*'doctor'/i);
  assert.doesNotMatch(migration, /r\.code\s*=\s*'admin'[\s\S]{0,180}correction\.(?:request|resolve)/i);
});

test("correction tables are forced-RLS and expose SELECT only to authenticated", () => {
  assert.match(migration, /ALTER TABLE public\.prescription_item_correction_requests ENABLE ROW LEVEL SECURITY/i);
  assert.match(migration, /ALTER TABLE public\.prescription_item_correction_requests FORCE ROW LEVEL SECURITY/i);
  assert.match(migration, /ALTER TABLE public\.prescription_item_correction_events ENABLE ROW LEVEL SECURITY/i);
  assert.match(migration, /ALTER TABLE public\.prescription_item_correction_events FORCE ROW LEVEL SECURITY/i);
  assert.match(migration, /REVOKE ALL ON TABLE public\.prescription_item_correction_requests[\s\S]*FROM PUBLIC, anon, authenticated, service_role/i);
  assert.match(migration, /REVOKE ALL ON TABLE public\.prescription_item_correction_events[\s\S]*FROM PUBLIC, anon, authenticated, service_role/i);
  assert.match(migration, /GRANT SELECT ON TABLE public\.prescription_item_correction_requests, public\.prescription_item_correction_events TO authenticated/i);
});

test("request RPC is pharmacist-only, branch-bound, pending/internal, exact-item and idempotent", () => {
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.request_prescription_item_correction\(p_prescription_item_id uuid, p_reason text\)/i);
  assert.match(migration, /SECURITY DEFINER[\s\S]*SET search_path TO ''/i);
  assert.match(migration, /app_has_perm\('pharmacy\.correction\.request'\)/i);
  assert.match(migration, /medicine_id IS NULL/i);
  assert.match(migration, /status\s+IS DISTINCT FROM\s+'pending'/i);
  assert.match(migration, /is_external\s+IS TRUE/i);
  assert.match(migration, /prescription_type\s+IS DISTINCT FROM\s+'internal'/i);
  assert.match(migration, /ON CONFLICT[\s\S]*DO NOTHING/i);
  assert.match(migration, /existing pending correction request/i);
});

test("resolver authorizes the responsible doctor and serializes prescription-item-request locks", () => {
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.resolve_prescription_item_correction\(p_request_id uuid, p_action text, p_replacement jsonb, p_reason text\)/i);
  assert.match(migration, /app_has_perm\('prescriptions\.correction\.resolve'\)/i);
  assert.match(migration, /prescribed_by[\s\S]*doctor_id[\s\S]*visit_doctor_id/i);
  const resolverStart = migration.indexOf("CREATE OR REPLACE FUNCTION public.resolve_prescription_item_correction");
  const resolver = migration.slice(resolverStart);
  const prescriptionLock = resolver.indexOf("FROM public.prescriptions p");
  const itemLock = resolver.indexOf("FROM public.prescription_items pi", prescriptionLock + 1);
  const requestLock = resolver.indexOf("FROM public.prescription_item_correction_requests r", itemLock + 1);
  assert.ok(resolverStart >= 0 && prescriptionLock >= 0 && itemLock > prescriptionLock && requestLock > itemLock);
  assert.match(migration, /FOR UPDATE/i);
  assert.match(migration, /stale correction request/i);
});

test("replacement requires an explicit active catalogue item and a complete clinician-entered regimen", () => {
  assert.match(migration, /medicine_id[\s\S]*active IS TRUE[\s\S]*is_active IS TRUE[\s\S]*deleted_at IS NULL/i);
  for (const field of ["dose", "frequency", "duration", "quantity", "dosage_form", "route"]) {
    assert.match(migration, new RegExp("\\b" + field + "\\b", "i"));
  }
  assert.doesNotMatch(migration, /ILIKE|similarity\s*\(/i);
  assert.doesNotMatch(migration, /COALESCE\([^)]*quantity[^)]*,\s*1\s*\)/i);
});

test("correction resolver reissues through the existing atomic prescription RPC and never dispenses or bills", () => {
  assert.match(migration, /cancel_and_reissue/i);
  assert.match(migration, /public\.create_prescription_atomic\(/i);
  assert.doesNotMatch(migration, /fn_dispense_prescription_with_invoice|complete_clinical_visit_and_bill|post_invoice_payment|reverse_invoice_payment/i);
});

test("correction mutations have least-privilege RPC grants and no direct browser writes", () => {
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.request_prescription_item_correction\(uuid, text\) FROM PUBLIC, anon/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.request_prescription_item_correction\(uuid, text\) TO authenticated/i);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.resolve_prescription_item_correction\(uuid, text, jsonb, text\) FROM PUBLIC, anon/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.resolve_prescription_item_correction\(uuid, text, jsonb, text\) TO authenticated/i);
});

test("PostgreSQL 17 integration covers authorization, no-side-effects and all dispositions", () => {
  for (const term of ["request_prescription_item_correction", "resolve_prescription_item_correction", "wrong branch", "unrelated doctor", "duplicate", "external", "cancelled", "dispensed", "stock_movements", "invoice_items", "cashbox_transactions", "replace_item", "reject", "cancel_and_reissue", "stale"]) {
    assert.ok(integration.toLowerCase().includes(term.toLowerCase()), `missing integration assertion: ${term}`);
  }
  assert.match(workflow, /prescription-correction-postgres17/);
  assert.match(workflow, /prescription_correction_integration\.sql/);
});
