import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../db/roshan_phase4_deduplicate_finance_audit_triggers.sql", import.meta.url),
  "utf8",
);
const integration = readFileSync(
  new URL("../db/tests/roshan_finance_audit_triggers_integration.sql", import.meta.url),
  "utf8",
);

test("finance audit cleanup removes only the redundant trigger from all four affected tables", () => {
  for (const table of ["payments", "expenses", "supplier_payments", "supplier_bills", "cashbox_transactions"]) {
    assert.match(
      migration,
      new RegExp("DROP TRIGGER IF EXISTS trg_finance_audit ON public\\." + table, "i"),
    );
    assert.match(integration, /trg_audit_/);
  }
  assert.doesNotMatch(migration, /DROP TRIGGER[^;]*trg_audit_/i);
  assert.doesNotMatch(migration, /DROP TABLE|TRUNCATE|DELETE FROM/i);
  assert.match(integration, /actual_count <> 1/);
  assert.match(integration, /generic audit trigger missing/);
});
