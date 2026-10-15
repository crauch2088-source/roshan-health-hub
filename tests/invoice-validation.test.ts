import assert from "node:assert/strict";
import { test } from "node:test";

import { validateInvoiceDraft } from "../src/lib/invoice-validation.ts";

const validLines = [
  { description: "Consultation", quantity: "2", unit_price: "15", item_type: "consultation" },
  { description: "CBC", quantity: "1", unit_price: "20", item_type: "lab" },
];

test("calculates a valid invoice draft from line items", () => {
  assert.deepEqual(validateInvoiceDraft(validLines, "5"), {
    subtotal: 50,
    discount: 5,
    net: 45,
    lines: [
      { description: "Consultation", quantity: 2, unit_price: 15, item_type: "consultation" },
      { description: "CBC", quantity: 1, unit_price: 20, item_type: "lab" },
    ],
  });
});

test("rejects empty invoices and blank descriptions", () => {
  assert.throws(() => validateInvoiceDraft([], "0"), /at least one item/i);
  assert.throws(
    () =>
      validateInvoiceDraft(
        [{ description: "   ", quantity: "1", unit_price: "10", item_type: "other" }],
        "0",
      ),
    /description/i,
  );
});

test("rejects invalid quantities and prices", () => {
  for (const quantity of ["1.5", "0", "-1", "Infinity", "not-a-number"]) {
    assert.throws(
      () =>
        validateInvoiceDraft(
          [{ description: "Service", quantity, unit_price: "10", item_type: "other" }],
          "0",
        ),
      /quantity/i,
    );
  }
  for (const unit_price of ["-1", "Infinity", "not-money", "1.234"]) {
    assert.throws(
      () =>
        validateInvoiceDraft(
          [{ description: "Service", quantity: "1", unit_price, item_type: "other" }],
          "0",
        ),
      /price/i,
    );
  }
});

test("rejects invalid discounts", () => {
  assert.throws(() => validateInvoiceDraft(validLines, "-1"), /discount/i);
  assert.throws(() => validateInvoiceDraft(validLines, "Infinity"), /discount/i);
  assert.throws(() => validateInvoiceDraft(validLines, "100"), /discount/i);
  assert.throws(() => validateInvoiceDraft(validLines, "0.001"), /decimal places/i);
});
