import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const sql = readFileSync(
  new URL("../db/roshan_phase8_atomic_invoice.sql", import.meta.url),
  "utf8",
);
const ui = readFileSync(
  new URL("../src/routes/_authenticated/billing.tsx", import.meta.url),
  "utf8",
);
const pkg = JSON.parse(
  readFileSync(new URL("../package.json", import.meta.url), "utf8"),
) as {
  scripts?: Record<string, string>;
};

test("invoice RPC enforces permission, branch scope, atomicity, and least privilege", () => {
  assert.match(sql, /app_has_perm\('billing\.create'\)/);
  assert.match(sql, /cross-branch invoice access denied/);
  assert.match(sql, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
  assert.match(sql, /REVOKE ALL ON FUNCTION[\s\S]*FROM anon/);
  assert.match(sql, /GRANT EXECUTE ON FUNCTION[\s\S]*TO authenticated/);
});
test("billing UI uses the atomic invoice RPC", () => {
  assert.match(ui, /rpc\("create_invoice_atomic"/);
  assert.doesNotMatch(ui, /\.from\("invoices"\)\s*\n\s*\.insert/);
  assert.doesNotMatch(ui, /\.from\("invoice_items"\)\.insert/);
});
test("invoice RPC test is included in guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /invoice-atomicity\.test\.ts/);
});
