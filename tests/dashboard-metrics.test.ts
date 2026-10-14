import assert from "node:assert/strict";
import { test } from "node:test";

import { PENDING_LAB_STATUSES, sumAmounts } from "../src/lib/dashboard-metrics.ts";

test("pending lab statuses use the vocabulary stored in lab_orders", () => {
  for (const status of ["ordered", "sample_collected", "in_progress"]) {
    assert.ok(PENDING_LAB_STATUSES.includes(status), status);
  }
  for (const status of ["completed", "verified", "cancelled"]) {
    assert.ok(!PENDING_LAB_STATUSES.includes(status), status);
  }
});

test("sumAmounts adds numeric and numeric-string amounts and ignores junk", () => {
  const rows = [{ amount: 10.5 }, { amount: "4.5" }, { amount: null }, { amount: "x" }, {}];
  assert.equal(sumAmounts(rows), 15);
});

test("sumAmounts supports a row filter and rounds to cents", () => {
  const rows = [
    { amount: 0.1, d: "2026-10-14" },
    { amount: 0.2, d: "2026-10-14" },
    { amount: 5, d: "2026-10-01" },
  ];
  assert.equal(
    sumAmounts(rows, (r) => String(r["d"]).startsWith("2026-10-14")),
    0.3,
  );
});
