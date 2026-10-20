import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const migration = read("../db/roshan_phase34_consolidated_storage_realtime_and_lab_verify.sql");
const fixture = read("../db/tests/phase33_storage_realtime_fixture.sql");
const integration = read("../db/tests/phase33_storage_realtime_assertions.sql");
const ci = read("../.github/workflows/ci.yml");
const consultation = read("../src/features/clinic/consultation/ConsultationPage.tsx");
const history = read("../src/features/clinic/consultation/components/HistoryTab.tsx");
const lab = read("../src/routes/_authenticated/lab_.$orderId.tsx");
const mapper = read("../src/lib/lab-workflow.ts");

test("consultation query failures are visible and retryable and visit state resets", () => {
  assert.match(consultation, /visitQ\.error/);
  assert.match(consultation, /visitQ\.refetch\(\)/);
  assert.match(consultation, /invoiceQ\.refetch\(\)/);
  assert.match(
    consultation,
    /setReviewChecks\(\{ identity: false, history: false, vitals: false, plan: false \}\)/,
  );
  assert.match(consultation, /<section\s+key=\{visitId\}/);
  assert.match(consultation, /<HistoryTab visitId=\{visitId\}/);
  assert.match(history, /visits\.error/);
  assert.match(history, /visits\.refetch\(\)/);
  assert.match(
    read("../src/features/clinic/consultation/components/ClinicalNoteTab.tsx"),
    /noteQ\.refetch\(\)/,
  );
  assert.match(
    read("../src/features/clinic/consultation/components/PrescriptionTab.tsx"),
    /medsQ\.refetch\(\)/,
  );
  assert.match(
    read("../src/features/clinic/consultation/components/LaboratoryTab.tsx"),
    /testsQ\.refetch\(\)/,
  );
  assert.match(lab, /setValues\(v\)/);
  assert.match(lab, /setComments\(c\)/);
});

test("typed mapper and server verification contract stay aligned", () => {
  assert.match(mapper, /kind: "empty"/);
  assert.match(mapper, /kind: "numeric"/);
  assert.match(mapper, /kind: "coded"/);
  assert.match(mapper, /kind: "text"/);
  assert.match(mapper, /critical-high/);
  assert.match(mapper, /verifyLabOrder/);
  assert.match(lab, /supabase\.rpc\("verify_lab_order"/);
  assert.doesNotMatch(
    lab,
    /\.from\("lab_orders"\)\s*\.update\(\{\s*status:\s*"verified"/,
  );
});

test("Phase 34 consolidates Storage, Realtime, verification and audit boundaries", () => {
  assert.match(migration, /public\s*=\s*false/i);
  assert.match(migration, /private\.app_has_branch_access/);
  assert.match(migration, /public\.app_has_perm/);
  assert.match(migration, /storage\.objects/);
  assert.match(migration, /realtime\.messages/);
  assert.match(migration, /public\.visits/);
  assert.match(migration, /supabase_realtime/);
  assert.match(migration, /public\.verify_lab_order/);
  assert.match(migration, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
  assert.match(migration, /audit_logs is append-only/);
  assert.match(migration, /phase34_lab_results_no_mutation_after_verify_update/);
  assert.doesNotMatch(migration, /jewzonxplxhogqrnhosl|service_role_key|SUPABASE_URL/i);
  assert.match(fixture, /CREATE SCHEMA IF NOT EXISTS storage/i);
  assert.match(fixture, /CREATE SCHEMA IF NOT EXISTS realtime/i);
  assert.match(integration, /cross-branch storage object leaked/i);
  assert.match(integration, /verify_lab_order/);
  assert.match(integration, /audit log UPDATE was not blocked/);
  assert.match(ci, /phase33-storage-realtime/);
  assert.match(ci, /roshan_phase34_consolidated_storage_realtime_and_lab_verify\.sql/);
});
