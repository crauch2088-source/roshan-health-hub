import assert from "node:assert/strict";
import test from "node:test";
import { buildInvoicePaymentReceiptModel } from "../src/lib/print/receipt.ts";

const source = () => ({
  payment: {
    id: "payment-1",
    invoice_id: "invoice-1",
    amount: "125.50",
    payment_method: "bankak",
    method: "bankak",
    reference_no: "BANKAK-REF-1",
    received_at: "2026-11-03T10:15:00.000Z",
    received_by: "cashier-1",
    branch_id: "branch-1",
    deleted_at: null,
  },
  invoice: {
    id: "invoice-1",
    invoice_number: "INV-0001",
    branch_id: "branch-1",
    deleted_at: null,
    net_amount: "500.00",
    paid_amount: "250.00",
    patients: {
      id: "patient-1",
      full_name: "Synthetic Patient",
      mrn: "MRN-0001",
      branch_id: "branch-1",
      deleted_at: null,
    },
  },
  ledger: {
    payment_id: "payment-1",
    ledger_found: true,
    ledger_matches: true,
    ledger_is_reversed: false,
    reversal_reason: null,
    reversal_at: null,
  },
});

test("receipt model preserves posted payment values and authoritative current invoice balance", () => {
  const data = source();
  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, true);
  assert.equal(model.paymentId, "payment-1");
  assert.equal(model.invoiceNumber, "INV-0001");
  assert.equal(model.amount, 125.5);
  assert.equal(model.paymentMethod, "bankak");
  assert.equal(model.reference, "BANKAK-REF-1");
  assert.equal(model.receivedAt, "2026-11-03T10:15:00.000Z");
  assert.equal(model.cashierName, "Recorded Cashier");
  assert.equal(model.currentBalance, 250);
  assert.equal(model.currency, "SDG");
  assert.equal(model.isReversed, false);
});

test("receipt model refuses payments without a matching posted cashbox ledger row", () => {
  const data = source();
  data.ledger.ledger_found = false;
  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("ledger"));
});

test("receipt model refuses ledger amount or branch mismatches", () => {
  const data = source();
  data.ledger.ledger_matches = false;
  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("ledger integrity"));
});

test("receipt model refuses branchless or cross-branch source rows even when caller supplies a positive status", () => {
  const data = source();
  data.payment.branch_id = null;
  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("branch binding"));
});

test("receipt model can rely on the ledger and authorized parent read when a legacy patient row has no branch_id", () => {
  const data = source();
  data.invoice.patients.branch_id = null;

  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, true);
});

test("receipt model permits a soft-deleted payment only when the authoritative ledger says reversed", () => {
  const data = source();
  data.payment.deleted_at = "2026-11-03T11:00:00.000Z";
  data.ledger.ledger_is_reversed = true;
  data.ledger.reversal_reason = "Duplicate payment";
  data.ledger.reversal_at = "2026-11-03T11:00:00.000Z";

  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, true);
  assert.equal(model.isReversed, true);
  assert.equal(model.reversalReason, "Duplicate payment");
  assert.equal(model.reversalAt, "2026-11-03T11:00:00.000Z");
});

test("receipt model blocks a deleted payment whose ledger is not reversed", () => {
  const data = source();
  data.payment.deleted_at = "2026-11-03T11:00:00.000Z";

  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("payment state"));
});

test("receipt model blocks an active payment whose ledger is reversed", () => {
  const data = source();
  data.ledger.ledger_is_reversed = true;
  data.ledger.reversal_at = "2026-11-03T11:00:00.000Z";

  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("payment state"));
});

test("receipt model never invents missing cashier, received timestamp, method, or invoice number", () => {
  const data = source();
  data.payment.received_at = null;
  data.payment.payment_method = null;
  data.payment.method = null;
  data.invoice.invoice_number = null;

  const model = buildInvoicePaymentReceiptModel(data.payment, data.invoice, data.ledger, "", "SDG");

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("cashier"));
  assert.ok(model.missingFields.includes("received timestamp"));
  assert.ok(model.missingFields.includes("payment method"));
  assert.ok(model.missingFields.includes("invoice number"));
});

test("receipt model rejects a payment linked to a different invoice", () => {
  const data = source();
  data.payment.invoice_id = "other-invoice";

  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("invoice linkage"));
});

test("receipt model rejects zero, negative, and non-finite payment amounts", () => {
  for (const amount of [0, -1, "NaN", "Infinity"]) {
    const data = source();
    data.payment.amount = amount;
    const model = buildInvoicePaymentReceiptModel(
      data.payment,
      data.invoice,
      data.ledger,
      "Recorded Cashier",
      "SDG",
    );

    assert.ok(model);
    assert.equal(model.complete, false);
    assert.ok(model.missingFields.includes("payment amount"));
  }
});

test("receipt model rejects conflicting legacy and canonical payment method fields", () => {
  const data = source();
  data.payment.method = "cash";

  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("payment method consistency"));
});

test("receipt model rejects missing or negative invoice balance inputs", () => {
  const data = source();
  data.invoice.net_amount = null;
  data.invoice.paid_amount = "600.00";

  const model = buildInvoicePaymentReceiptModel(
    data.payment,
    data.invoice,
    data.ledger,
    "Recorded Cashier",
    "SDG",
  );

  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("invoice balance"));
});
