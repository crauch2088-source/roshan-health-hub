import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const billing = read("../src/routes/_authenticated/billing.tsx");
const visits = read("../src/routes/_authenticated/visits.tsx");
const consultation = read("../src/features/clinic/consultation/ConsultationPage.tsx");
const lab = read("../src/features/clinic/consultation/components/LaboratoryTab.tsx");
const migration = read("../db/roshan_phase19_invoice_rpc_only_writes.sql");
const integration = read("../db/tests/invoice_rpc_only_writes_integration.sql");
const pkg = JSON.parse(read("../package.json")) as {
  scripts?: Record<string, string>;
};

test("billing, visit, consultation, and lab workflows do not write invoice tables directly", () => {
  const directInvoiceWrite =
    /\.from\(["'](?:invoices|invoice_items)["']\)\s*\.(?:insert|update|delete)\s*\(/;

  for (const [name, source] of [
    ["billing", billing],
    ["visits", visits],
    ["consultation", consultation],
    ["laboratory", lab],
  ] as const) {
    assert.doesNotMatch(
      source,
      directInvoiceWrite,
      `${name} must use the atomic invoice RPCs`,
    );
  }

  assert.match(billing, /rpc\(["']create_billing_invoice_atomic["']/);
  assert.match(visits, /rpc\(["']create_visit_consultation_invoice_atomic["']/);
  assert.match(lab, /rpc\(["']create_lab_order_with_invoice_atomic["']/);
});

test("invoice grant migration preserves wrapper RPC access while removing direct table DML", () => {
  assert.match(
    migration,
    /REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER[\s\S]*public\.invoices, public\.invoice_items[\s\S]*FROM PUBLIC, anon, authenticated/,
  );
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.create_billing_invoice_atomic/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.create_visit_consultation_invoice_atomic/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.create_lab_order_with_invoice_atomic/);
  assert.match(integration, /direct INSERT unexpectedly succeeded/);
  assert.match(integration, /invoice read privileges were unexpectedly revoked/);
  assert.match(migration, /private\.app_has_branch_access\(i\.branch_id\)/);
  assert.match(integration, /invoice item SELECT policy did not enforce parent-branch access/);
});

test("invoice RPC-only write guard runs in the standard test suite", () => {
  assert.match(pkg.scripts?.["test:guard"] ?? "", /invoice-rpc-only-writes\.test\.ts/);
});
