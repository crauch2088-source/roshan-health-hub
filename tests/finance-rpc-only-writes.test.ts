import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");

const accounting = read("../src/routes/_authenticated/accounting.tsx");
const finance = read("../src/routes/_authenticated/finance.tsx");
const expenses = read("../src/routes/_authenticated/expenses.tsx");
const insurance = read("../src/lib/insurance.ts");
const migration = read("../db/roshan_phase27_finance_rpc_only_writes.sql");
const integration = read("../db/tests/finance_only_rpc_writes_integration.sql");

test("finance UI routes financial writes through RPCs rather than direct table DML", () => {
  const directFinancialWrite =
    /\.from\(["'](?:cashbox_transactions|payments|expenses|supplier_bills|supplier_payments|insurance_claims|insurance_claim_items|insurance_claim_payments)["']\)\s*\.(?:insert|update|delete|upsert)\s*\(/;

  for (const [name, source] of [
    ["accounting", accounting],
    ["finance", finance],
    ["expenses", expenses],
    ["insurance library", insurance],
  ] as const) {
    assert.doesNotMatch(
      source,
      directFinancialWrite,
      name + " must not mutate financial tables directly",
    );
  }

  assert.match(accounting, /rpc\(["']post_cashbox_entry["']/);
  assert.match(accounting, /rpc\(["']post_invoice_payment["']/);
  assert.match(accounting, /rpc\(["']post_supplier_bill["']/);
  assert.match(accounting, /rpc\(["']post_supplier_payment["']/);
  assert.match(expenses, /rpc\(["']post_expense["']/);
  assert.match(insurance, /rpc(?:<[^>]+>)?\(["']create_insurance_claim["']/);
  assert.match(insurance, /rpc(?:<[^>]+>)?\(["']post_insurance_claim_payment["']/);
  assert.match(insurance, /rpc(?:<[^>]+>)?\(["']update_insurance_claim_status["']/);
});

test("finance migration preserves precision and RPC-only access", () => {
  assert.match(
    migration,
    /REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER[\s\S]*FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migration,
    /public\.post_cashbox_entry[\s\S]*public\.app_has_perm\('accounting\.create'\)/,
  );
  assert.match(migration, /private\.app_has_perm\('accounting\.create'\)/);
  const invoicePaymentFunction = migration.slice(
    migration.indexOf("CREATE OR REPLACE FUNCTION public.post_invoice_payment("),
    migration.indexOf("CREATE OR REPLACE FUNCTION public.post_supplier_bill("),
  );
  assert.ok(invoicePaymentFunction.includes("public.app_has_perm('accounting.create')"));
  assert.match(invoicePaymentFunction, /round\(_amount,\s*2\)/i);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.post_expense[\s\S]*TO authenticated/);
  assert.match(integration, /direct INSERT allowed on/);
  assert.match(integration, /direct UPDATE allowed on/);
  assert.match(integration, /direct DELETE allowed on/);
  assert.match(integration, /overpayment was not rejected/);
  assert.match(integration, /idempotent retry returned different ID/);
  assert.match(integration, /idempotency key accepted a different payload/);
  assert.match(integration, /fractional minor-unit payment amount was accepted/);
  for (const table of ["insurance_claims", "insurance_claim_items", "insurance_claim_payments"]) {
    assert.match(migration, new RegExp(table));
  }
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.create_insurance_claim/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.post_insurance_claim_payment/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.update_insurance_claim_status/);
});

test("finance RPC-only guard is part of the standard guard suite", () => {
  const pkg = JSON.parse(read("../package.json")) as { scripts?: Record<string, string> };
  assert.match(pkg.scripts?.["test:guard"] ?? "", /finance-rpc-only-writes\.test\.ts/);
});
