import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const ui = read("../src/routes/_authenticated/visits.tsx");
const migration = read("../db/roshan_phase24_visit_form_options.sql");
const integration = read("../db/tests/visit_form_options_integration.sql");

test("visit form options use a narrow server-side RPC instead of direct staff-table reads", () => {
  assert.match(ui, /supabase\.rpc\("get_visit_form_options"\)/);
  assert.doesNotMatch(ui, /\.from\("users"\)\s*\.select\("id, full_name, roles\(code\)"\)/);
  assert.match(migration, /public\.app_has_perm\('visits\.create'\)/);
  assert.match(migration, /private\.app_has_branch_access\(u\.branch_id\)/);
  assert.match(migration, /REVOKE ALL ON FUNCTION public\.get_visit_form_options\(\) FROM PUBLIC, anon/);
  assert.match(integration, /cross-branch, inactive, non-clinical, or branchless doctor leaked into receptionist options/);
  assert.match(integration, /anonymous execution must be denied/);
});
