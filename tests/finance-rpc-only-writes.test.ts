import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) =>
  readFileSync(new URL(path, import.meta.url), "utf8");

const accounting = read("../src/routes/_authenticated/accounting.tsx");
const finance = read("../src/routes/_authenticated/finance.tsx");
const expenses = read("../src/routes/_authenticated/expenses.tsx");
const migration = read("../db/roshan_phase17_finance_rpc_only_writes.sql");
const integration = read("../db/tests/finance_rpc_only_writes_integration.sql");
const pkg = JSON.parse(read("../package.json")) as {
  scripts?: Record<string, string>;
};

test("finance UI routes financial writes through RPCs rather than direct table DML", () => {
  const directFinancialWrite =
    /\.from\(["'](?:cashbox_transactions|payments|expenses|supplier_bills|supplier_payments)["']\)\s*\.(?:insert|update|delete)\s*\(/;

  for (const [name, source] of [
    ["accounting", accounting],
    ["finance", finance],
    ["expenses", expenses],
  ] as const) {
    assert.doesNotMatch(source, directFinancialWrite, `${name} must not mutate financial tables directly`);
  }

  assert.match(accounting, /rpc\(["']post_cashbox_entry["']/);
  assert.match(accounting, /rpc\(["']post_invoice_payment["']/);
  assert.match(accounting, /rpc\(["']post_supplier_bill["']/);
  assert.match(accounting, /rpc\(["']post_supplier_payment["']/);
  assert.match(expenses, /rpc\(["']post_expense["']/);
});

test("migration revokes direct write privileges but retains authenticated RPC access", () => {
  assert.match(
    migration,
    /REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER[\s\S]*FROM PUBLIC, anon, authenticated/,
  );
  assert.match(migration, /public\.post_cashbox_entry[\s\S]*public\.app_has_perm\('accounting\.create'\)/);
  assert.match(migration, /private\.app_has_perm\('accounting\.create'\)/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.post_expense[\s\S]*TO authenticated/);
  assert.match(integration, /direct INSERT unexpectedly succeeded/);
  assert.match(integration, /direct UPDATE unexpectedly succeeded/);
  assert.match(integration, /direct DELETE unexpectedly succeeded/);
  assert.match(integration, /accounting\.create/);
});

test("RPC-only finance guard is part of the standard guard suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /finance-rpc-only-writes\.test\.ts/);
});
