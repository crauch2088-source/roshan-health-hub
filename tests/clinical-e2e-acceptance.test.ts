import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const workflow = read("../db/tests/clinical_e2e_acceptance_workflow.sql");
const fixture = read("../db/tests/clinical_security_hardening_fixture.sql");
const expand = read("../db/roshan_phase31_clinical_financial_security_hardening.sql");
const contract = read("../db/roshan_phase31_contract_security_cutover.sql");
const ci = read("../.github/workflows/ci.yml");

test("clinical acceptance SQL is explicitly isolated and uses synthetic authenticated JWT subjects", () => {
  assert.match(workflow, /disposable PostgreSQL 17 CI database/i);
  assert.match(workflow, /ROLLBACK;/);
  assert.match(workflow, /request\.jwt\.claim\.sub/);
  assert.match(fixture, /request\.jwt\.claim\.sub/);
  assert.match(workflow, /'receptionist'/);
  assert.match(workflow, /'doctor'/);
  assert.match(workflow, /'lab_technician'/);
  assert.match(workflow, /'pharmacist'/);
  assert.doesNotMatch(workflow, /jewzonxplxhogqrnhosl|supabase\.co|roshan-health-hub\.vercel\.app/i);
});

test("clinical acceptance covers partial lab save, idempotent resave, atomic visit completion, and certificate guards", () => {
  assert.match(workflow, /partial save did not complete item 1/);
  assert.match(workflow, /partial save closed the parent lab order/);
  assert.match(workflow, /complete_lab_order_item\('00000000-0000-0000-0000-000000001901'\)[\s\S]*complete_lab_order_item\('00000000-0000-0000-0000-000000001901'\)/);
  assert.match(workflow, /public\.complete_visit_atomic/);
  assert.match(workflow, /queue ticket was not completed atomically/);
  assert.match(workflow, /certificate serial was not generated/);
  assert.match(workflow, /pharmacist certificate issuance unexpectedly succeeded/);
  assert.match(workflow, /certificate for cancelled visit unexpectedly succeeded/);
  assert.match(expand, /complete_lab_order_item[\s\S]*v_status = 'completed'[\s\S]*RETURN;/);
  assert.match(expand, /complete_visit_atomic[\s\S]*UPDATE public\.queue_tickets/);
  assert.match(contract, /ALTER COLUMN visit_id SET NOT NULL/);
});

test("the clinical acceptance job runs against PostgreSQL 17 and never uses production credentials", () => {
  assert.match(ci, /clinical-e2e-acceptance:/);
  assert.match(ci, /image: postgres:17/);
  assert.match(ci, /db\/baseline\/0000_roshan_pg17_baseline_v112\.sql/);
  assert.match(ci, /db\/tests\/clinical_e2e_acceptance_workflow\.sql/);
  assert.doesNotMatch(ci, /SUPABASE_SERVICE_ROLE_KEY|DATABASE_URL.*jewzonxplxhogqrnhosl/i);
});
