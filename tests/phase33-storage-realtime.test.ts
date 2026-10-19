import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) =>
  readFileSync(new URL(path, import.meta.url), "utf8");

const migration = read("../db/roshan_phase33_storage_and_realtime.sql");
const fixture = read("../db/tests/phase33_storage_realtime_fixture.sql");
const integration = read("../db/tests/phase33_storage_realtime_assertions.sql");
const ci = read("../.github/workflows/ci.yml");
const consultation = read(
  "../src/features/clinic/consultation/ConsultationPage.tsx",
);
const history = read(
  "../src/features/clinic/consultation/components/HistoryTab.tsx",
);
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
  assert.match(consultation, /<HistoryTab key=\{visitId\}/);
  assert.match(history, /visits\.error/);
  assert.match(history, /visits\.refetch\(\)/);
  assert.match(lab, /setValues\(\{\}\)/);
});

test("typed mapper separates empty, numeric, text/coded and critical", () => {
  assert.match(mapper, /kind: "empty"/);
  assert.match(mapper, /kind: "numeric"/);
  assert.match(mapper, /kind: coded \? "coded" : "text"/);
  assert.match(mapper, /critical_high/);
  assert.match(lab, /mapLabResult\(value, s\(p, "data_type"\), range\)/);
  assert.doesNotMatch(lab, /isAbnormalLabResult/);
});

test("Storage and Realtime policies use branch/permission checks and isolated PG17 CI", () => {
  assert.match(migration, /public\s*=\s*false/i);
  assert.match(migration, /private\.app_has_branch_access/);
  assert.match(migration, /public\.app_has_perm/);
  assert.match(migration, /storage\.objects/);
  assert.match(migration, /realtime\.messages/);
  assert.match(migration, /supabase_realtime/);
  assert.doesNotMatch(migration, /jewzonxplxhogqrnhosl|service_role_key|SUPABASE_URL/i);
  assert.match(fixture, /CREATE SCHEMA IF NOT EXISTS storage/i);
  assert.match(fixture, /CREATE SCHEMA IF NOT EXISTS realtime/i);
  assert.match(integration, /cross-branch storage object leaked/i);
  assert.match(integration, /phase33_clinical_realtime_select/);
  assert.match(ci, /phase33-storage-realtime/);
});
