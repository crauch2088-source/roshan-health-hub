import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const read = (path) => readFileSync(join(root, path), "utf8");

test("receipt UI reads persisted payment and invoice fields only", () => {
  const source = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  assert.match(source, /received_at/);
  assert.match(source, /received_by/);
  assert.match(
    source,
    /branch_id, deleted_at, patients\(id, full_name, mrn, phone, branch_id, deleted_at\)/,
  );
  assert.match(source, /received_user:users!payments_received_by_fkey/);
  assert.match(source, /get_invoice_payment_receipt_status_v2/);
  assert.match(source, /payment_method, method/);
  assert.match(source, /net_amount, paid_amount/);
  assert.match(source, /index \+= 200/);
  assert.doesNotMatch(source, /created_by.*cashier/i);
  assert.doesNotMatch(source, /payment_date.*receivedAt/i);
});

test("invoice and payment reads do not require Phase58-only currency columns before migration rollout", () => {
  const source = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  const invoiceSelect = source.match(/from\("invoices"\)\s*\.select\(\s*"([^"]+)"/);
  const paymentSelect = source.match(/from\("payments"\)\s*\.select\(\s*"([^"]+)"/);

  assert.ok(invoiceSelect, "invoice select must remain present");
  assert.ok(paymentSelect, "payment select must remain present");
  assert.doesNotMatch(invoiceSelect[1], /\bcurrency_code\b/);
  assert.doesNotMatch(paymentSelect[1], /\bcurrency_code\b/);
  assert.match(source, /get_invoice_payment_receipt_status_v2/);
});

test("receipt UI does not disclose another cashier without users.read", () => {
  const source = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  assert.match(source, /receivedBy === user\?\.id/);
  assert.match(source, /can\("users\.read"\)/);
  assert.match(source, /s\(receivedUser, "active"\) === "true"/);
  assert.match(source, /!s\(receivedUser, "deleted_at"\)/);
});

test("receipt printing is bound to one selected persisted payment", () => {
  const source = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  assert.match(source, /printingPaymentId/);
  assert.match(source, /paymentRows\.find\([\s\S]*printingPaymentId/);
  assert.match(source, /flushSync\(\(\) => setPrintingPaymentId\(paymentId\)\)/);
  assert.match(source, /document\.body\.classList\.add\("print-scope-active"\)/);
  assert.match(source, /id="payment-receipt-print-document"/);
  assert.match(source, /printRoot\.classList\.add\("print-target-active"\)/);
  assert.match(
    source,
    /if \(!printRoot\) \{[\s\S]*document\.body\.classList\.remove\("print-scope-active"\)[\s\S]*setPrintingPaymentId\(null\)/,
  );
  assert.match(source, /selectedReceipt\?\.complete/);
  assert.match(source, /selectedReceipt\.isReversed/);
  assert.match(source, /Current invoice balance|الرصيد الحالي للفاتورة/);
});

test("receipt UI is not enabled by the unsaved payment form and fails closed when ledger RPC is unavailable", () => {
  const source = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  assert.match(source, /can\("payments\.read"\) && paymentIds\.length > 0/);
  assert.match(source, /receiptStatusQ\.error/);
  assert.match(
    source,
    /Receipt printing is unavailable until payment-ledger and persisted-currency verification are deployed/,
  );
  assert.match(source, /receipt\?\.complete \?/);
  assert.doesNotMatch(source, /onClick=\{\(\) => handlePrintPayment\(amount\)\}/);
});

test("historical payment receipts use Roshan's fixed SDG currency, not mutable display settings", () => {
  const source = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  const db = read("src/lib/db.ts");
  assert.match(db, /export const ROSHAN_CURRENCY = "SDG" as const/);
  assert.match(source, /buildInvoicePaymentReceiptModel\(payment, invoice, ledger, cashierName\)/);
  assert.match(source, /get_invoice_payment_receipt_status_v2/);
  assert.doesNotMatch(source, /buildInvoicePaymentReceiptModel.*ROSHAN_CURRENCY/);
  assert.doesNotMatch(source, /buildInvoicePaymentReceiptModel.*cashierName, currency/);
});
