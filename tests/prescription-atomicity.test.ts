import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const sql = readFileSync(
  new URL("../db/roshan_phase7_atomic_prescription.sql", import.meta.url),
  "utf8",
);
const ui = readFileSync(
  new URL("../src/features/clinic/consultation/components/PrescriptionTab.tsx", import.meta.url),
  "utf8",
);
const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as {
  scripts?: Record<string, string>;
};

test("prescription RPC contains permission, branch, and least-privilege guards", () => {
  assert.match(sql, /app_has_perm\('pharmacy\.create'\)[\s\S]*app_has_perm\('emr\.create'\)/);
  assert.match(sql, /cross-branch prescription access denied/);
  assert.match(sql, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
  assert.match(sql, /REVOKE ALL ON FUNCTION[\s\S]*FROM anon/);
  assert.match(sql, /GRANT EXECUTE ON FUNCTION[\s\S]*TO authenticated/);
});

test("prescription save uses a single atomic RPC", () => {
  const start = ui.indexOf("const save = useSave(");
  const end = ui.indexOf("\n\n  return (", start);
  assert.ok(start >= 0 && end > start);
  const handler = ui.slice(start, end);
  assert.match(handler, /rpc\("create_prescription_atomic"/);
  assert.doesNotMatch(handler, /\.from\("prescriptions"\)\.insert/);
  assert.doesNotMatch(handler, /\.from\("prescription_items"\)\.insert/);
});

test("prescription regression test is included in the guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /prescription-atomicity\.test\.ts/);
});
