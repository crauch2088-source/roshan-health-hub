import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const migration = readFileSync("db/roshan_phase55b_private_helper_acl_reconciliation.sql", "utf8");
const workflow = readFileSync(".github/workflows/ci-phase55-clinical-parent-guard.yml", "utf8");

test("Phase 55B replaces the exact live insurance policy identifiers", () => {
  for (const policy of [
    "insurance_claim_items_sel",
    "insurance_claim_items_ins",
    "insurance_claim_payments_sel",
    "insurance_claim_payments_ins",
  ]) {
    assert.match(migration, new RegExp(`DROP POLICY IF EXISTS ${policy} ON public\\.`));
    assert.match(migration, new RegExp(`CREATE POLICY ${policy} ON public\\.`));
  }
});

test("Phase 55B preserves insurance read/create permission gates", () => {
  assert.equal((migration.match(/app_has_perm\\('insurance\\.read'\\)/g) ?? []).length, 2);
  assert.equal((migration.match(/app_has_perm\\('insurance\\.create'\\)/g) ?? []).length, 2);
  assert.doesNotMatch(migration, /CREATE POLICY insurance_claim_(?:items|payments)_(?:sel|ins)[\\s\\S]*?USING \\(\\(SELECT public\\.app_has_claim_branch/);
});

test("Phase 55B grants only authenticated execution to the public branch wrapper", () => {
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\\.app_has_claim_branch\\(uuid\\)\\s+FROM PUBLIC, anon, authenticated, service_role, authenticator/,
  );
  assert.match(
    migration,
    /GRANT EXECUTE ON FUNCTION public\\.app_has_claim_branch\\(uuid\\) TO authenticated/,
  );
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION private\\.app_has_claim_branch\\(uuid\\)\\s+FROM PUBLIC, anon, authenticated, service_role, authenticator/,
  );
});

test("the PostgreSQL 17 workflow applies Phase 55B before assertions", () => {
  assert.ok(workflow.indexOf("db/roshan_phase55b_private_helper_acl_reconciliation.sql") <
    workflow.indexOf("db/tests/phase55_clinical_parent_guard_assertions.sql"));
  assert.match(workflow, /node --test tests\\/phase55b-insurance-rls-contract\\.test\\.mjs/);
});
