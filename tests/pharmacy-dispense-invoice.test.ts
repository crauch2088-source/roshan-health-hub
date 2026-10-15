import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL("../db/roshan_phase14_dispense_invoice_atomic.sql", import.meta.url),
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

test("pharmacy dispense and billing are one server-side transaction", () => {
  assert.match(
    migration,
    /CREATE OR REPLACE FUNCTION public\.fn_dispense_prescription_with_invoice/,
  );
  assert.match(migration, /private\.create_or_append_visit_invoice_atomic/);
  assert.match(migration, /public\.create_invoice_atomic/);
  assert.match(migration, /m\.selling_price/);
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.fn_dispense_prescription\(uuid\) FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migration,
    /GRANT EXECUTE ON FUNCTION public\.fn_dispense_prescription_with_invoice\(uuid, boolean\) TO authenticated/,
  );
});

test("pharmacy UI exposes a deliberate separate-invoice option only to billing-authorized users", () => {
  assert.match(pharmacyRoute, /can\("billing\.create"\)/);
  assert.match(pharmacyRoute, /separateInvoice/);
  assert.match(pharmacyLib, /fn_dispense_prescription_with_invoice/);
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
});
