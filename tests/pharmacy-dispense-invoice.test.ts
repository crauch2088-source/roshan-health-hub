import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { parseDispenseQuantity } from "../src/lib/pharmacy-quantity.ts";

const migration = readFileSync(
  new URL("../db/roshan_phase14_dispense_invoice_atomic.sql", import.meta.url),
  "utf8",
);
const revocationMigration = readFileSync(
  new URL("../db/roshan_phase17_revoke_legacy_dispense_rpc.sql", import.meta.url),
  "utf8",
);
const pharmacyRoute = readFileSync(
  new URL("../src/routes/_authenticated/pharmacy.tsx", import.meta.url),
  "utf8",
);
const pharmacyLib = readFileSync(new URL("../src/lib/pharmacy.ts", import.meta.url), "utf8");
const integration = readFileSync(
  new URL("../db/tests/pharmacy_dispense_invoice_integration.sql", import.meta.url),
  "utf8",
);
const fixture = readFileSync(
  new URL("../db/tests/pharmacy_dispense_invoice_fixture.sql", import.meta.url),
  "utf8",
);
const quantityGuardMigration = readFileSync(
  new URL("../db/roshan_phase57_pharmacy_quantity_required_guard.sql", import.meta.url),
  "utf8",
);
const pharmacyQuantity = readFileSync(
  new URL("../src/lib/pharmacy-quantity.ts", import.meta.url),
  "utf8",
);

test("pharmacy dispense and billing are one server-side transaction", () => {
  assert.match(
    migration,
    /CREATE OR REPLACE FUNCTION public\.fn_dispense_prescription_with_invoice/,
  );
  assert.match(migration, /private\.create_or_append_visit_invoice_atomic/);
  assert.match(migration, /public\.create_invoice_atomic/);
  assert.match(migration, /m\.selling_price/);
  assert.match(migration, /insufficient_branch_batch_stock/);
  assert.doesNotMatch(migration, /source := 'legacy'/);
  assert.match(migration, /stock_quantity has no branch owner/);
  assert.doesNotMatch(
    migration,
    /REVOKE ALL ON FUNCTION public\.fn_dispense_prescription\(uuid\) FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    revocationMigration,
    /REVOKE ALL ON FUNCTION public\.fn_dispense_prescription\(uuid\) FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migration,
    /GRANT EXECUTE ON FUNCTION public\.fn_dispense_prescription_with_invoice\(uuid, boolean\) TO authenticated/,
  );
});

test("dispensing rejects NULL quantities before and after the locked prescription-item read", () => {
  assert.match(quantityGuardMigration, /pi\.quantity IS NULL/);
  assert.match(quantityGuardMigration, /prescription quantity is required/);
  assert.doesNotMatch(quantityGuardMigration, /COALESCE\(pi\.quantity\s*,\s*1\)/i);
  assert.match(quantityGuardMigration, /v_item\.qty <= 0/);
  const lockedRead = quantityGuardMigration.indexOf("FOR UPDATE OF pi, m");
  const lockedNullGuard = quantityGuardMigration.indexOf("IF v_item.qty IS NULL");
  assert.ok(lockedRead >= 0 && lockedNullGuard > lockedRead);
  assert.match(fixture, /quantity numeric,/);
  assert.doesNotMatch(fixture, /quantity numeric DEFAULT 1/);
  assert.match(integration, /null quantity unexpectedly dispensed/);
  assert.match(integration, /null quantity rejection changed pharmacy stock/);
  assert.match(integration, /null quantity rejection created invoice lines/);
  assert.match(integration, /legacy non-idempotent dispense RPC remains executable/);
});

test("pharmacy UI exposes a deliberate separate-invoice option only to billing-authorized users", () => {
  assert.match(pharmacyRoute, /can\("billing\.create"\)/);
  assert.match(pharmacyRoute, /separateInvoice/);
  assert.match(pharmacyLib, /atomic_pharmacy_dispense/);
  assert.match(pharmacyLib, /p_request_id: requestId/);
  assert.match(pharmacyRoute, /\["invoices"\]/);
});

test("integration contract covers itemized medicine charges, rollback, retry, and explicit secondary invoice", () => {
  assert.match(
    integration,
    /consultation and each dispensed medicine must be separate invoice lines/,
  );
  assert.match(integration, /failed invoice append did not roll back stock/);
  assert.match(integration, /duplicate dispense created duplicate charges/);
  assert.match(integration, /explicit separate pharmacy invoice was not created/);
  assert.match(integration, /cross-branch denial changed stock/);
  assert.match(integration, /aggregate stock guard did not rollback stock/);
  assert.match(integration, /unbatched legacy stock unexpectedly dispensed/);
  assert.match(integration, /legacy-stock denial changed medicine stock/);
  assert.match(integration, /legacy-stock denial created stock movements/);
});

test("pharmacy queue fails closed for missing or invalid prescription quantities", () => {
  assert.match(pharmacyRoute, /parseDispenseQuantity/);
  assert.match(pharmacyRoute, /hasInvalidQuantity/);
  assert.match(pharmacyRoute, /disabled=\{dispense\.isPending \|\| hasInvalidQuantity\}/);
  assert.doesNotMatch(pharmacyRoute, /n\(i, "quantity"\)\s*\|\|\s*1/);
  assert.match(pharmacyRoute, /A prescribed quantity is missing or invalid/);
});

test("dispense quantity parser accepts only finite positive whole units", () => {
  for (const invalid of [
    null,
    undefined,
    "",
    " ",
    0,
    -1,
    1.5,
    Number.NaN,
    Number.POSITIVE_INFINITY,
    Number.NEGATIVE_INFINITY,
    "NaN",
    "Infinity",
    2_147_483_648,
    true,
  ]) {
    assert.equal(parseDispenseQuantity(invalid), null);
  }

  assert.equal(parseDispenseQuantity(1), 1);
  assert.equal(parseDispenseQuantity("2"), 2);
});
