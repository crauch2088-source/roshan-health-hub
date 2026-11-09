import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync("db/roshan_phase59_receipt_currency_provenance.sql", "utf8");
const integration = readFileSync("db/tests/phase59_receipt_currency_integration.sql", "utf8");
const receipt = readFileSync("src/lib/print/receipt.ts", "utf8");
const billing = readFileSync("src/routes/_authenticated/billing_.$invoiceId.tsx", "utf8");

test("Phase 59 exposes persisted currency provenance for every receipt ledger leg", () => {
  for (const field of [
    "payment_currency_code",
    "invoice_currency_code",
    "ledger_currency_code",
    "reversal_currency_code",
    "currency_matches",
  ]) {
    assert.match(migration, new RegExp(field));
  }
  assert.match(migration, /get_invoice_payment_receipt_status_v2/);
  assert.match(migration, /private\.app_has_branch_access/);
  assert.match(migration, /payments\.read/);
  assert.match(migration, /billing\.read/);
  assert.match(migration, /FROM PUBLIC, anon/);
  assert.match(migration, /TO authenticated/);
});

test("Phase 59 integration covers legacy NULL, normal, reversed, missing and duplicate ledger states", () => {
  assert.match(integration, /legacy NULL currency provenance/);
  assert.match(integration, /valid SDG payment provenance/);
  assert.match(integration, /valid SDG reversal provenance/);
  assert.match(integration, /payment without a cashbox ledger/);
  assert.match(integration, /duplicate cashbox source rows/);
  assert.match(integration, /branch access boundary/);
  assert.match(integration, /missing permissions/);
});

test("receipt model accepts only matching persisted SDG provenance", () => {
  assert.match(receipt, /payment_currency_code/);
  assert.match(receipt, /invoice_currency_code/);
  assert.match(receipt, /ledger_currency_code/);
  assert.match(receipt, /reversal_currency_code/);
  assert.match(receipt, /currency_matches/);
  assert.match(receipt, /SDG/);
  assert.match(billing, /get_invoice_payment_receipt_status_v2/);
  assert.doesNotMatch(billing, /get_invoice_payment_receipt_status"/);
});
