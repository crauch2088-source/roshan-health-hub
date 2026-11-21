import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

test("Phase 60B SQL defines physical-pack identity dimensions and exact duplicate guard", () => {
  const sql = fs.readFileSync(
    path.resolve("db/roshan_phase60b_medicine_pack_identity_and_duplicate_guard.sql"),
    "utf8",
  );
  for (const token of [
    "manufacturer_name",
    "pack_size",
    "dispensing_unit",
    "gtin_barcode",
    "route",
    "medicines_pack_size_positive_check",
    "medicines_gtin_barcode_format_check",
    "private.normalize_medicine_identity_key",
    "idx_medicines_active_gtin_unique",
    "idx_medicines_active_exact_identity_unique",
    "Does NOT verify regulatory or manufacturer authenticity",
  ]) {
    assert.ok(sql.includes(token), `Expected Phase 60B SQL to include ${token}`);
  }
});
