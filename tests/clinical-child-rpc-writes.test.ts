import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const lab = read("../src/routes/_authenticated/lab_.$orderId.tsx");
const certificates = read("../src/routes/_authenticated/certificates.tsx");
const phase28 = read("../db/roshan_phase28_clinical_child_write_rpcs.sql");
const phase29 = read("../db/roshan_phase29_clinical_child_rpc_only_writes.sql");
const phase30 = read("../db/roshan_phase30_clinical_child_rpc_only_writes.sql");
const fixture = read("../db/tests/clinical_child_rpc_writes_fixture.sql");
const integration = read("../db/tests/clinical_child_rpc_writes_integration.sql");
const pkg = JSON.parse(read("../package.json")) as { scripts?: Record<string, string> };

test("lab item completion uses the branch-checked RPC and surfaces failures", () => {
  assert.match(lab, /supabase\.rpc\(["']complete_lab_order_item["']/);
  assert.doesNotMatch(lab, /\.from\(["']lab_order_items["']\)\s*\.update\s*\(/);
  assert.match(lab, /if \(completion\.error\)/);
  assert.match(lab, /if \(orderCompletion\.error\)/);
});

test("medical certificate creation derives the author on the server", () => {
  assert.match(certificates, /supabase\.rpc\(["']create_medical_certificate["']/);
  assert.doesNotMatch(certificates, /\.from\(["']medical_certificates["']\)\s*\.insert\s*\(/);
  assert.doesNotMatch(certificates, /doctor_id:\s*user\?\.id/);
  assert.match(certificates, /p_patient_id:\s*form\.patient_id/);
  assert.match(certificates, /p_start_date:\s*form\.start_date/);
  assert.match(certificates, /p_end_date:\s*endDate/);
});

test("clinical RPC migration enforces permission, branch, fixed search path, and least privilege", () => {
  assert.match(
    phase28,
    /FUNCTION public\.complete_lab_order_item[\s\S]*?SECURITY DEFINER\s+SET search_path TO ''/,
  );
  assert.match(
    phase28,
    /FUNCTION public\.create_medical_certificate[\s\S]*?SECURITY DEFINER\s+SET search_path TO ''/,
  );
  assert.match(phase28, /private\.app_has_lab_order_item_branch_access/);
  assert.match(phase28, /private\.app_has_patient_branch/);
  assert.match(phase28, /public\.app_has_perm\('lab\.update'\)/);
  assert.match(phase28, /public\.app_has_perm\('certificates\.create'\)/);
  assert.match(phase28, /FROM PUBLIC, anon/);
  assert.match(
    phase29,
    /public\.prescriptions[\s\S]*public\.insurance_prior_authorizations[\s\S]*FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    phase30,
    /public\.lab_order_items[\s\S]*public\.medical_certificates[\s\S]*FROM PUBLIC, anon, authenticated/,
  );
  assert.match(phase30, /REVOKE ALL ON SEQUENCE public\.medical_certificates_id_seq/);
});

test("PostgreSQL integration covers cross-branch denial and retains RLS/SELECT", () => {
  assert.match(fixture, /ENABLE ROW LEVEL SECURITY/);
  assert.match(integration, /cross-branch lab completion unexpectedly succeeded/);
  assert.match(integration, /cross-branch certificate creation unexpectedly succeeded/);
  assert.match(integration, /authenticated lost SELECT/);
  assert.match(integration, /RLS was disabled/);
});

test("clinical child RPC guard runs in the standard test suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /clinical-child-rpc-writes\.test\.ts/);
});
