import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(new URL("../db/roshan_phase61_prescription_correction_workflow.sql", import.meta.url), "utf8");
const integration = readFileSync(new URL("../db/tests/prescription_correction_integration.sql", import.meta.url), "utf8");
const workflow = readFileSync(new URL("../.github/workflows/ci-phase61-prescription-correction.yml", import.meta.url), "utf8");

test("correction request schema is branch-scoped, snapshot-based and idempotent", () => {
  assert.match(migration, /CREATE TABLE public\.prescription_correction_requests/);
  assert.match(migration, /CREATE TABLE public\.prescription_correction_events/);
  assert.match(migration, /item_snapshot jsonb NOT NULL/);
  assert.match(migration, /request_key uuid NOT NULL/);
  assert.match(migration, /CREATE UNIQUE INDEX[\s\S]*prescription_item_id[\s\S]*status\s*=\s*'open'/i);
  assert.match(migration, /ENABLE ROW LEVEL SECURITY/);
});

test("RPCs enforce empty search_path, permissions, strict branch and original prescriber", () => {
  for (const name of ["create_prescription_correction_request", "resolve_prescription_correction_request", "reject_prescription_correction_request"]) {
    assert.match(migration, new RegExp("FUNCTION public\\." + name));
  }
  assert.match(migration, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
  assert.match(migration, /pharmacy\.update/);
  assert.match(migration, /emr\.update/);
  assert.match(migration, /prescribed_by IS DISTINCT FROM v_uid/);
  assert.match(migration, /current_user_assigned_branch_access/);
  assert.match(migration, /FOR UPDATE/);
});

test("replacement derives catalogue identity and preserves the clinical regimen", () => {
  assert.match(migration, /medicine_id\s*=\s*p_medicine_id/);
  assert.match(migration, /medication_name\s*=\s*v_name/);
  assert.match(migration, /unit_price\s*=\s*v_price/);
  assert.match(migration, /item_replaced/);
  assert.match(migration, /before_snapshot/);
  assert.match(migration, /after_snapshot/);
});

test("cancel and reissue is atomic and uses the existing prescription RPC", () => {
  assert.match(migration, /create_prescription_atomic/);
  assert.match(migration, /cancel_and_reissue/);
  assert.match(migration, /status\s*=\s*'cancelled'/);
  assert.match(integration, /cancel.and.reissue/i);
});

test("correction workflow has no stock or financial write path", () => {
  assert.doesNotMatch(migration, /INSERT\s+INTO\s+public\.(pharmacy_inventory|stock_movements|invoices|invoice_items|payments|cashbox_transactions)/i);
  assert.doesNotMatch(migration, /UPDATE\s+public\.(pharmacy_inventory|stock_movements|invoices|invoice_items|payments|cashbox_transactions)/i);
  assert.match(integration, /no_side_effects/);
});

test("PostgreSQL 17 workflow runs the focused and integration contracts", () => {
  assert.match(workflow, /postgres:17/);
  assert.match(workflow, /prescription_correction_fixture\.sql/);
  assert.match(workflow, /roshan_phase61_prescription_correction_workflow\.sql/);
  assert.match(workflow, /prescription_correction_integration\.sql/);
  assert.match(workflow, /prescription-correction-workflow\.test\.ts/);
});
