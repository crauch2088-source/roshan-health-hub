import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const migration = read("../db/roshan_phase20_clinical_child_branch_isolation.sql");
const integration = read("../db/tests/clinical_child_branch_isolation_integration.sql");
test("clinical child policies use parent branch helpers", () => {
  assert.ok(migration.includes("app_has_attachment_branch_access"));
  assert.ok(migration.includes("app_has_prescription_branch_access"));
  assert.ok(migration.includes("app_has_lab_order_branch_access"));
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION private\.app_has_branch_access\(uuid\) FROM PUBLIC, anon/,
  );
  assert.match(
    migration,
    /GRANT EXECUTE ON FUNCTION private\.app_has_branch_access\(uuid\) TO authenticated/,
  );
  assert.ok(integration.includes("anonymous role must not execute private branch helper"));
  assert.ok(integration.includes("cross-branch prescription UPDATE was allowed"));
});
