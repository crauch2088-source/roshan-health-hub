import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync("db/roshan_phase59_receipt_currency_provenance.sql", "utf8");
const integration = readFileSync("db/tests/phase59_receipt_currency_integration.sql", "utf8");

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

test("Phase 59 treats unknown or inconsistent provenance as a negative match", () => {
  assert.match(migration, /COALESCE\([\s\S]*false\s*\)/);
  assert.match(migration, /payment_currency_code text/);
  assert.match(migration, /reversal_currency_code text/);
});
