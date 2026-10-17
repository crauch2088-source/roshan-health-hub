import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import testRunner from "node:test";

const source = readFileSync(
  new URL("../src/routes/_authenticated/inventory.tsx", import.meta.url),
  "utf8",
);

testRunner("inventory receiving uses the atomic guarded pharmacy RPC", () => {
  assert.match(
    source,
    /\.rpc\(["']fn_receive_pharmacy_batch["']/,
    "batch receipt must call the server-side atomic RPC",
  );
  assert.doesNotMatch(
    source,
    /supabase\s*\.from\(["']pharmacy_inventory["']\)\s*\.insert\s*\(/,
    "batch receipt must not insert inventory rows directly from the client",
  );
  assert.doesNotMatch(
    source,
    /supabase\s*\.from\(["']stock_movements["']\)\s*\.insert\s*\(/,
    "batch receipt must not write stock movements separately from the inventory transaction",
  );
  assert.doesNotMatch(
    source,
    /supabase\s*\.from\(["']medicines["']\)\s*\.update\s*\(\s*\{\s*stock_quantity/,
    "batch receipt must not update stock totals separately from the inventory transaction",
  );
});
