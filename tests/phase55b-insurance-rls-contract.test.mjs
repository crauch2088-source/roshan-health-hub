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
    assert.ok(migration.includes(`DROP POLICY IF EXISTS ${policy} ON public.`));
    assert.ok(migration.includes(`CREATE POLICY ${policy} ON public.`));
  }
  assert.ok(!migration.includes("CREATE POLICY insurance_claim_items_select"));
  assert.ok(!migration.includes("CREATE POLICY insurance_claim_payments_insert"));
});

test("Phase 55B preserves insurance read/create permission gates", () => {
  assert.equal(migration.split("app_has_perm('insurance.read')").length - 1, 2);
  assert.equal(migration.split("app_has_perm('insurance.create')").length - 1, 2);
});

test("Phase 55B grants only authenticated execution to the public branch wrapper", () => {
  assert.ok(migration.includes(
    "REVOKE ALL ON FUNCTION public.app_has_claim_branch(uuid)\n  FROM PUBLIC, anon, authenticated, service_role, authenticator;",
  ));
  assert.ok(migration.includes(
    "GRANT EXECUTE ON FUNCTION public.app_has_claim_branch(uuid) TO authenticated;",
  ));
  assert.ok(migration.includes(
    "REVOKE ALL ON FUNCTION private.app_has_claim_branch(uuid)\n  FROM PUBLIC, anon, authenticated, service_role, authenticator;",
  ));
});

test("the PostgreSQL 17 workflow applies and replays Phase 55B before assertions", () => {
  const migrationStep = workflow.indexOf("-f db/roshan_phase55b_private_helper_acl_reconciliation.sql");
  const assertionsStep = workflow.indexOf("-f db/tests/phase55_clinical_parent_guard_assertions.sql");
  assert.ok(migrationStep >= 0 && migrationStep < assertionsStep);
  assert.ok(workflow.includes("node --test tests/phase55b-insurance-rls-contract.test.mjs"));
  assert.ok(workflow.includes("Reapply Phase 55B"));
});

test("the public branch wrapper also enforces insurance permission before revealing branch membership", () => {
  assert.ok(
    migration.includes(
      "SELECT (public.app_has_perm('insurance.read') OR public.app_has_perm('insurance.create'))",
    ),
  );
});
