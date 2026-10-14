import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../db/roshan_phase6_atomic_pharmacy_stock_receipt.sql", import.meta.url),
  "utf8",
);
const inventory = readFileSync(
  new URL("../src/routes/_authenticated/inventory.tsx", import.meta.url),
  "utf8",
);
const packageJson = JSON.parse(
  readFileSync(new URL("../package.json", import.meta.url), "utf8"),
) as { scripts?: Record<string, string> };

test("atomic stock receipt RPC validates quantity, permission, and branch", () => {
  assert.match(migration, /app_has_perm\('pharmacy\.create'\)/);
  assert.match(migration, /p_quantity <> trunc\(p_quantity\)/);
  assert.match(migration, /FOR UPDATE/);
  assert.match(migration, /user branch is not configured/);
  assert.match(migration, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION[\s\S]*TO authenticated/);
  assert.match(migration, /REVOKE ALL ON FUNCTION[\s\S]*FROM anon/);
});

test("batch receiving uses one RPC instead of separate client-side writes", () => {
  const start = inventory.indexOf("const receive = useSave(", inventory.indexOf("function PharmacyBatchesTab"));
  const end = inventory.indexOf("\n\n  return (\n    <div>", start);
  assert.ok(start >= 0 && end > start, "batch receive handler must exist");
  const handler = inventory.slice(start, end);
  assert.match(handler, /rpc\("receive_pharmacy_stock"/);
  assert.doesNotMatch(handler, /\.from\("pharmacy_inventory"\)/);
  assert.doesNotMatch(handler, /\.from\("medicines"\)/);
  assert.doesNotMatch(handler, /\.from\("stock_movements"\)/);
});

test("the stock receipt regression test is included in the guard suite", () => {
  assert.match(packageJson.scripts?.["test:guard"] ?? "", /atomic-stock-receipt\.test\.ts/);
});
