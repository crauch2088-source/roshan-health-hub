import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync("db/roshan_phase58_single_sdg_currency_provenance.sql", "utf8");
const integration = readFileSync(
  "db/tests/phase58_sdg_currency_provenance_integration.sql",
  "utf8",
);

const financialTables = [
  "invoices",
  "payments",
  "cashbox_transactions",
  "expenses",
  "supplier_bills",
  "supplier_payments",
  "pharmacy_inventory",
];

test("Phase 58 covers every approved financial source and ledger table", () => {
  for (const table of financialTables) {
    assert.match(migration, new RegExp("'" + table + "'"));
  }
  assert.match(migration, /trg_%s_sdg_currency/);
  assert.match(migration, /ALTER COLUMN currency_code SET DEFAULT %L/);
  assert.match(migration, /currency_code IS NULL OR currency_code = %L/);
  assert.match(migration, /v_table, 'SDG'/);
});

test("Phase 58 preserves unknown legacy rows without a settings-derived backfill", () => {
  assert.match(migration, /Existing rows intentionally remain NULL/);
  assert.doesNotMatch(
    migration,
    /UPDATE\s+public\.(invoices|payments|cashbox_transactions|expenses|supplier_bills|supplier_payments|pharmacy_inventory)\s+SET\s+currency_code/i,
  );
  assert.match(integration, /legacy.*unexpectedly backfilled/i);
});

test("Phase 58 rejects NULL, non-SDG and post-posting currency mutation", () => {
  assert.match(migration, /currency_code is required for new financial records/);
  assert.match(migration, /Roshan supports SDG only/);
  assert.match(migration, /posted financial currency_code is immutable/);
  assert.match(migration, /NEW\.currency_code IS DISTINCT FROM OLD\.currency_code/);
  assert.match(integration, /legacy currency assignment on/);
  assert.match(integration, /explicit NULL insert/);
  assert.match(integration, /non-SDG insert/);
  assert.match(integration, /currency clear/);
  assert.match(integration, /currency change/);
  assert.match(integration, /test_writer unexpectedly has direct EXECUTE/);
  assert.match(integration, /restricted writer/);
});

test("Phase 58 binds payment and supplier-payment currency to known SDG parents", () => {
  assert.match(migration, /TG_TABLE_NAME = 'payments'/);
  assert.match(migration, /TG_TABLE_NAME = 'supplier_payments'/);
  assert.match(migration, /invoice currency provenance is missing or inconsistent/);
  assert.match(migration, /supplier bill currency provenance is missing or inconsistent/);
  assert.match(integration, /payment against legacy unknown-currency invoice/);
  assert.match(integration, /payment against legacy unknown-currency supplier bill/);
});

test("Phase 58 binds source-ledger and reversal currency to their original records", () => {
  assert.match(migration, /TG_TABLE_NAME = 'cashbox_transactions'/);
  assert.match(migration, /source payment currency provenance is missing or inconsistent/);
  assert.match(migration, /source expense currency provenance is missing or inconsistent/);
  assert.match(migration, /source supplier payment currency provenance is missing or inconsistent/);
  assert.match(migration, /reversal currency provenance is missing or inconsistent/);
  assert.match(integration, /cashbox ledger accepted a payment with unknown currency provenance/);
  assert.match(integration, /cashbox ledger accepted an expense with unknown currency provenance/);
  assert.match(integration, /cashbox ledger accepted a supplier payment with unknown currency provenance/);
  assert.match(integration, /cashbox reversal accepted an original row with unknown currency provenance/);
});
