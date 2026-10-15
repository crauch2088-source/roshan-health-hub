import assert from "node:assert/strict";
import { test } from "node:test";

import { calculateOutstandingBalance } from "../src/lib/patient-snapshot.ts";

test("calculates balance across all fetched invoice pages and falls back to total amount", () => {
  assert.equal(
    calculateOutstandingBalance([
      { net_amount: 100, total_amount: 100, paid_amount: 40 },
      { net_amount: null, total_amount: 50, paid_amount: 10 },
      { net_amount: 75, total_amount: 75, paid_amount: 75 },
    ]),
    100,
  );
});

test("does not count an overpayment as a negative outstanding debt", () => {
  assert.equal(
    calculateOutstandingBalance([
      { net_amount: 100, total_amount: 100, paid_amount: 120 },
      { net_amount: 20, total_amount: 20, paid_amount: 5 },
    ]),
    15,
  );
});

test("treats missing or invalid money fields as zero rather than producing NaN", () => {
  assert.equal(
    calculateOutstandingBalance([
      { net_amount: null, total_amount: null, paid_amount: null },
      { net_amount: "not-money", total_amount: 25, paid_amount: "invalid" },
    ]),
    25,
  );
});
