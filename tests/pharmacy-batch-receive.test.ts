import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const inventory = readFileSync(
  new URL("../src/routes/_authenticated/inventory.tsx", import.meta.url),
  "utf8",
);
const rpcSql = readFileSync(
  new URL("../db/roshan_phase3_pharmacy_batch_receive_validation.sql", import.meta.url),
  "utf8",
);
const pkg = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as {
  scripts?: Record<string, string>;
};

test("medicine and batch receive flows use the atomic batch RPC", () => {
  assert.ok((inventory.match(/supabase\.rpc\("fn_receive_pharmacy_batch"/g) ?? []).length >= 2);
  assert.doesNotMatch(inventory, /\.from\("pharmacy_inventory"\)\s*\.insert/);
  assert.doesNotMatch(inventory, /\.from\("stock_movements"\)\.insert/);
  assert.doesNotMatch(inventory, /\.from\("medicines"\)\s*\.update\(\{\s*stock_quantity/);
  assert.match(inventory, /stock_quantity:\s*0/);
});

test("server RPC validates numeric bounds, supplier, active medicine, branch, and atomic stock updates", () => {
  assert.match(rpcSql, /p_quantity::text IN \('NaN', 'Infinity', '-Infinity'\)/);
  assert.match(rpcSql, /invalid_purchase_price/);
  assert.match(rpcSql, /invalid_selling_price/);
  assert.match(rpcSql, /active_supplier_not_found/);
  assert.match(rpcSql, /m\.active IS TRUE/);
  assert.match(rpcSql, /stock_quantity_overflow/);
  assert.match(
    rpcSql,
    /REVOKE INSERT ON TABLE public\.stock_movements FROM PUBLIC, anon, authenticated/,
  );
  assert.match(rpcSql, /DROP POLICY IF EXISTS stock_movements_insert/);
  assert.match(rpcSql, /SECURITY DEFINER[\s\S]*SET search_path TO ''/);
});

test("batch receiving regression test is included in guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /pharmacy-batch-receive\.test\.ts/);
});
