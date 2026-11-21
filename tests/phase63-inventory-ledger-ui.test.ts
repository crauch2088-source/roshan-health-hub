import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  WRITEOFF_TYPES,
  assertNonEmptyReason,
  assertValidWriteoffType,
} from "../src/lib/inventory-ledger.ts";

test("Phase 63 writeoff types match SQL check constraint", () => {
  assert.deepEqual([...WRITEOFF_TYPES], ["expired", "damaged", "lost", "supplier_return"]);
  assert.equal(assertValidWriteoffType("expired"), "expired");
  assert.throws(() => assertValidWriteoffType("other"), /Invalid write-off type/);
});

test("Phase 63 reason validation rejects blank strings", () => {
  assert.equal(assertNonEmptyReason("  cycle count  "), "cycle count");
  assert.throws(() => assertNonEmptyReason("   "), /Reason is required/);
});

test("inventory.tsx wires all five Phase 63 RPC wrappers", () => {
  const src = fs.readFileSync(
    path.resolve("src/routes/_authenticated/inventory.tsx"),
    "utf8",
  );
  for (const fn of [
    "adjustInventoryBatchAtomic",
    "quarantineExpiredBatchAtomic",
    "recordInventoryWriteoffAtomic",
    "updateMedicineSellingPriceAtomic",
    "reconcileMedicineStockLedger",
  ]) {
    assert.ok(src.includes(fn), `Expected inventory.tsx to reference ${fn}`);
  }
});
