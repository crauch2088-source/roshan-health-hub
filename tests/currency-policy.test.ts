import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("Roshan exposes one immutable SDG currency across all app formatting", () => {
  const db = read("src/lib/db.ts");
  assert.match(db, /export const ROSHAN_CURRENCY = "SDG" as const/);
  assert.match(db, /currency: ROSHAN_CURRENCY/);
  assert.doesNotMatch(db, /currency: settings\["currency"\]/);
});

test("system settings cannot edit or overwrite the fixed currency", () => {
  const settings = read("src/routes/_authenticated/settings.tsx");
  const keys = settings.match(/const KEYS = \[([\s\S]*?)\] as const/);
  assert.ok(keys);
  assert.doesNotMatch(keys[1], /"currency"/);
  assert.match(settings, /ROSHAN_CURRENCY/);
  assert.doesNotMatch(settings, /Input[^>]*value=\{form\["currency"\]/);
});

test("all receipt and invoice views use the same fixed currency source", () => {
  const receipt = read("src/routes/_authenticated/billing_.$invoiceId.tsx");
  assert.match(receipt, /ROSHAN_CURRENCY/);
  assert.match(
    receipt,
    /buildInvoicePaymentReceiptModel\\(payment, invoice, ledger, cashierName, ROSHAN_CURRENCY\\)/,
  );
});
