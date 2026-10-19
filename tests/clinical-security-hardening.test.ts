import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { hasLabItemResultInput } from "../src/lib/lab-workflow.ts";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const consultation = read("../src/features/clinic/consultation/ConsultationPage.tsx");
const certificates = read("../src/routes/_authenticated/certificates.tsx");
const pharmacy = read("../src/lib/pharmacy.ts");
const migration = read("../db/roshan_phase31_clinical_financial_security_hardening.sql");
const contractMigration = read("../db/roshan_phase31_contract_security_cutover.sql");
const visitIndexMigration = read("../db/roshan_phase32_medical_certificate_visit_index.sql");
const visitIndexAssertion = read("../db/tests/medical_certificate_visit_index_assertions.sql");
const sqlAssertions = read("../db/tests/clinical_security_hardening_assertions.sql");
const labOrderPage = read("../src/routes/_authenticated/lab_.$orderId.tsx");
const labWorkflow = read("../src/lib/lab-workflow.ts");
const preflightDoc = read("../docs/CLINICAL_SECURITY_HARDENING_PREFLIGHT_2026-10-18.md");
const reconciliationDoc = read("../docs/DB_MIGRATION_RECONCILIATION.md");
const pkg = JSON.parse(read("../package.json")) as { scripts?: Record<string, string> };

test("visit completion calls one atomic RPC instead of browser table writes", () => {
  assert.match(consultation, /supabase\.rpc\(["']complete_visit_atomic["']/);
  assert.doesNotMatch(consultation, /\.from\(["']visits["']\)\s*\.update\s*\(/);
  assert.doesNotMatch(consultation, /\.from\(["']queue_tickets["']\)\s*\.update\s*\(/);
});

test("pharmacy UI invokes only the invoice-backed dispense RPC", () => {
  assert.match(pharmacy, /fn_dispense_prescription_with_invoice/);
  assert.doesNotMatch(pharmacy, /\.rpc\s*\(["']fn_dispense_prescription["']/);
});

test("certificate issuance requires doctor role and linked visit", () => {
  assert.match(certificates, /user\?\.role_code === ["']doctor["']/);
  assert.match(certificates, /p_visit_id:\s*form\.visit_id/);
  assert.match(certificates, /form\.visit_id/);
  assert.match(
    certificates,
    /disabled=\{create\.isPending \|\| !form\.patient_id \|\| !form\.visit_id\}/,
  );
  assert.match(certificates, /s\(c, ["']certificate_number["']\)/);
  assert.doesNotMatch(
    certificates,
    /\.from\(["']medical_certificates["']\)\s*\.(insert|update|upsert|delete)\s*\(/,
  );
});

test("Phase 31 migration includes the critical database guardrails", () => {
  assert.match(migration, /private\.current_app_user_id[\s\S]*deleted_at IS NULL/);
  assert.match(migration, /private\.app_has_perm[\s\S]*deleted_at IS NULL/);
  assert.match(migration, /post_cashbox_entry[\s\S]*round\(_amount, 2\)/);
  assert.match(migration, /post_supplier_payment[\s\S]*round\(_amount, 2\)/);
  assert.match(migration, /patients_active_national_id_normalized_uq/);
  assert.match(migration, /insurance_claims_one_active_nonrejected_per_invoice_uq/);
  assert.match(
    migration,
    /complete_visit_atomic[\s\S]*private\.app_has_visit_branch_access[\s\S]*queue_tickets/,
  );
  assert.match(migration, /complete_lab_order_item[\s\S]*numeric_value[\s\S]*result_value/);
  assert.match(migration, /invalid lab status transition/);
  assert.match(migration, /r\.code='doctor'[\s\S]*p_visit_id/);
  assert.match(migration, /active patient not found/);
  assert.match(migration, /visit does not belong to the selected patient/);
  assert.match(migration, /medical_certificate_number_seq/);
  assert.match(migration, /certificate_number bigint/);
  assert.match(
    contractMigration,
    /fn_dispense_prescription\(uuid\)[\s\S]*FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    contractMigration,
    /REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public\.lab_order_items/,
  );
  assert.match(migration, /REVOKE INSERT, UPDATE, DELETE ON TABLE public\.medical_certificates/);
  assert.match(contractMigration, /ALTER COLUMN visit_id SET NOT NULL/);
  assert.match(migration, /certificate issuance requires a linked visit/);
});

test("lab completion is retry-safe and partial saves skip empty items", () => {
  assert.match(migration, /IF v_status = 'completed' THEN\s+RETURN;\s+END IF;/);
  assert.match(migration, /IF v_status = 'verified' THEN[\s\S]*?USING ERRCODE = '22023'/);
  assert.match(labOrderPage, /hasLabItemResultInput/);
  assert.match(labOrderPage, /allItemsCompleted/);
  assert.match(labWorkflow, /export function hasLabItemResultInput/);
  assert.equal(hasLabItemResultInput("item-a", ["p1", "p2"], {}), false);
  assert.equal(hasLabItemResultInput("item-a", ["p1", "p2"], { "item-a:p2": "  4.2 " }), true);
  assert.equal(hasLabItemResultInput("item-a", ["p1"], { "item-a:p1": "8" }), true);
});

test("visit completion is idempotent and certificate issuance rejects cancelled visits", () => {
  assert.match(migration, /IF v_status = 'completed' THEN\s+RETURN;\s+END IF;/);
  assert.match(migration, /cancelled visit cannot be used for a medical certificate/);
  assert.match(migration, /v_visit_branch_id IS DISTINCT FROM v_patient_branch_id/);
  assert.match(certificates, /\.neq\(["']status["'], ["']cancelled["']\)/);
  assert.match(sqlAssertions, /completed visit retry changed updated_at/);
  assert.match(sqlAssertions, /visit without queue ticket did not complete/);
  assert.match(sqlAssertions, /certificate accepted a cancelled visit/);
});

test("deleted super-admin identity cannot bypass branch helpers", () => {
  assert.match(
    migration,
    /CREATE OR REPLACE FUNCTION private\.current_role_code\(\)[\s\S]*deleted_at IS NULL/,
  );
  for (const helper of [
    "app_has_branch_access",
    "app_has_claim_branch",
    "app_has_invoice_branch",
    "app_has_patient_branch",
  ]) {
    const start = migration.indexOf("CREATE OR REPLACE FUNCTION private." + helper);
    assert.notEqual(start, -1, helper + " replacement missing");
    const end = migration.indexOf("$function$;", start);
    assert.notEqual(end, -1, helper + " body missing");
    assert.match(migration.slice(start, end), /deleted_at IS NULL/);
  }
  assert.match(sqlAssertions, /soft-deleted super-admin retained role code/);
  assert.match(sqlAssertions, /soft-deleted super-admin retained branch access/);
});

test("contract migration revokes all direct clinical privileges and ledger docs record both phases", () => {
  assert.match(
    contractMigration,
    /REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public\.lab_order_items/,
  );
  assert.match(
    contractMigration,
    /REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public\.medical_certificates/,
  );
  assert.match(preflightDoc, /schema_migrations/);
  assert.match(reconciliationDoc, /20261018195500/);
});

test("catalog assertions are included in the repository and standard test command", () => {
  assert.match(sqlAssertions, /current_app_user_id ignores deleted_at/);
  assert.match(sqlAssertions, /insurance claim unique index missing/);
  assert.match(pkg.scripts?.["test:guard"] ?? "", /clinical-security-hardening\.test\.ts/);
});


test("medical certificate visit foreign key has a valid supporting index", () => {
  assert.match(visitIndexMigration, /CREATE INDEX IF NOT EXISTS medical_certificates_visit_id_idx/);
  assert.match(visitIndexMigration, /ON public\\.medical_certificates/);
  assert.match(visitIndexMigration, /\\(visit_id\\)/);
  assert.match(visitIndexAssertion, /medical_certificates_visit_id_idx/);
  assert.match(visitIndexAssertion, /indisvalid/);
  assert.match(visitIndexAssertion, /indisready/);
});
