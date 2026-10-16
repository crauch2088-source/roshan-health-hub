import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const migration = read("../db/roshan_phase18_dedupe_finance_audit_triggers.sql");
const fixture = read("../db/tests/finance_audit_trigger_dedup_fixture.sql");
const integration = read("../db/tests/finance_audit_trigger_dedup_integration.sql");
const pkg = JSON.parse(read("../package.json")) as {
  scripts?: Record<string, string>;
};

test("finance audit migration removes only the redundant generic triggers", () => {
  for (const table of [
    "cashbox_transactions",
    "expenses",
    "payments",
    "supplier_bills",
    "supplier_payments",
  ]) {
    assert.match(
      migration,
      new RegExp(`DROP TRIGGER IF EXISTS trg_audit_${table} ON public\\.${table};`),
    );
  }

  assert.doesNotMatch(migration, /DROP TRIGGER IF EXISTS trg_finance_audit/);
  assert.match(integration, /expected exactly one audit row/);
  assert.match(integration, /canonical finance audit trigger missing/);
});

test("generic audit remains installed on non-finance tables", () => {
  assert.match(fixture, /CREATE TRIGGER trg_audit_patients/);
  assert.match(integration, /generic audit trigger was unexpectedly removed from patients/);
});

test("finance audit trigger regression is part of the standard guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /finance-audit-trigger-dedup\.test\.ts/);
});
