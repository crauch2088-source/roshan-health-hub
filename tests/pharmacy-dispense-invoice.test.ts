import assert from "node:assert/strict";
import { createHash } from "node:crypto";
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
const sourceGuardMigration = readFileSync(
  new URL("../db/roshan_phase57b_free_text_external_prescription_guard.sql", import.meta.url),
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

test("dispensing rejects NULL quantities before invoice construction or stock mutation", () => {
  assert.match(quantityGuardMigration, /pi\.quantity IS NULL/);
  assert.match(quantityGuardMigration, /prescription quantity is required/);
  assert.doesNotMatch(quantityGuardMigration, /COALESCE\(pi\.quantity\s*,\s*1\)/i);
  assert.match(quantityGuardMigration, /v_item\.qty <= 0/);
  assert.match(fixture, /quantity numeric,/);
  assert.doesNotMatch(fixture, /quantity numeric DEFAULT 1/);
  assert.match(integration, /null quantity unexpectedly dispensed/);
  assert.match(integration, /null quantity rejection changed pharmacy stock/);
  assert.match(integration, /null quantity rejection created invoice lines/);
  assert.match(integration, /legacy non-idempotent dispense RPC remains executable/);
});

test("Phase 57 source remains byte-identical to the QA-applied migration", () => {
  assert.equal(
    createHash("md5").update(quantityGuardMigration).digest("hex"),
    "921970d4d86b32dccd430a0ea0ef8745",
  );
  assert.doesNotMatch(quantityGuardMigration, /p\.is_external|free-text item/);
});

test("Phase 57B rejects free-text and external prescriptions before any mutation", () => {
  assert.match(sourceGuardMigration, /pi\.medicine_id IS NULL/);
  assert.match(sourceGuardMigration, /free-text item/);
  assert.match(sourceGuardMigration, /p\.is_external/);
  assert.match(sourceGuardMigration, /external_prescription_not_eligible_for_internal_dispense/);
  assert.match(integration, /mixed prescription rejection changed stock/);
  assert.match(integration, /mixed prescription rejection changed parent status/);
  assert.match(integration, /external prescription rejection changed stock/);
  assert.match(integration, /external prescription rejection changed status/);
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
  assert.match(pharmacyRoute, /hasUnlinkedItem/);
  assert.match(pharmacyRoute, /disabled=\{dispense\.isPending \|\| hasDispenseBlocker\}/);
  assert.match(pharmacyRoute, /medication_name, dosage, frequency/);
  assert.doesNotMatch(pharmacyRoute, /n\(i, "quantity"\)\s*\|\|\s*1/);
  assert.match(pharmacyRoute, /A prescribed quantity is missing or invalid/);
  assert.match(pharmacyRoute, /not linked to the active catalogue/);
  assert.doesNotMatch(pharmacyRoute, /n\(i, "quantity"\)\s*\|\|\s*1/);
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

test("external prescriptions cannot enter the internal stock dispense flow", () => {
  assert.match(sourceGuardMigration, /p\.is_external/);
  assert.match(sourceGuardMigration, /external_prescription_not_eligible_for_internal_dispense/);
  assert.match(pharmacyRoute, /hasExternalPrescription/);
  assert.match(pharmacyRoute, /external_prescription_internal_stock_blocked/);
  assert.match(integration, /external prescription rejection changed stock/);
  assert.match(integration, /external prescription rejection changed status/);
});
