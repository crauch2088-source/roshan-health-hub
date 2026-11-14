import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildMedicineCatalogueIdentityUpdate,
  buildMedicineCatalogueInsert,
  buildMedicineCatalogueSearchFilter,
  isMedicineIdentityEditorRole,
  isMedicinePackVerifierRole,
  type MedicineCatalogueDraft,
} from "../src/lib/medicine-catalogue.ts";

const draft: MedicineCatalogueDraft = {
  name: "",
  generic_name: "  amoxicillin  ",
  brand_name: "  Amoxil ",
  strength: " 500 mg ",
  dosage_form: " capsule ",
  custom_dosage_form: "",
  unit: " pack ",
  cost_price: "10.5",
  selling_price: "15",
  reorder_level: "5",
};

test("catalogue insert requires a generic name, strength and dosage form", () => {
  assert.deepEqual(buildMedicineCatalogueInsert({ ...draft, generic_name: " " }), {
    error: "missing-generic-name",
  });
  assert.deepEqual(buildMedicineCatalogueInsert({ ...draft, strength: "" }), {
    error: "missing-strength",
  });
  assert.deepEqual(buildMedicineCatalogueInsert({ ...draft, dosage_form: "" }), {
    error: "missing-dosage-form",
  });
  assert.deepEqual(
    buildMedicineCatalogueInsert({ ...draft, dosage_form: "other", custom_dosage_form: " " }),
    { error: "missing-custom-dosage-form" },
  );
});

test("catalogue insert normalizes identity and never creates stock or batch data", () => {
  const result = buildMedicineCatalogueInsert(draft);
  assert.equal("data" in result, true);
  if (!("data" in result)) return;
  assert.deepEqual(result.data, {
    name: "Amoxil 500 mg capsule",
    generic_name: "amoxicillin",
    brand_name: "Amoxil",
    strength: "500 mg",
    dosage_form: "capsule",
    unit: "pack",
    cost_price: 10.5,
    selling_price: 15,
    stock_quantity: 0,
    reorder_level: 5,
    expiry_date: null,
    batch_number: null,
  });
});

test("catalogue insert rejects negative, non-finite and fractional reorder values", () => {
  for (const cost_price of ["-1", "Infinity", "NaN"]) {
    assert.deepEqual(buildMedicineCatalogueInsert({ ...draft, cost_price }), {
      error: "invalid-cost-price",
    });
  }
  assert.deepEqual(buildMedicineCatalogueInsert({ ...draft, selling_price: "-0.01" }), {
    error: "invalid-selling-price",
  });
  assert.deepEqual(buildMedicineCatalogueInsert({ ...draft, reorder_level: "1.5" }), {
    error: "invalid-reorder-level",
  });
});

test("identity-only update cannot carry stock, unit, price, expiry or reorder fields", () => {
  const result = buildMedicineCatalogueIdentityUpdate(draft);
  assert.equal("data" in result, true);
  if (!("data" in result)) return;
  assert.deepEqual(result.data, {
    name: "Amoxil 500 mg capsule",
    generic_name: "amoxicillin",
    brand_name: "Amoxil",
    strength: "500 mg",
    dosage_form: "capsule",
  });
  for (const forbidden of [
    "unit",
    "cost_price",
    "selling_price",
    "stock_quantity",
    "expiry_date",
    "reorder_level",
  ]) {
    assert.equal(forbidden in result.data, false);
  }
});

test("custom dosage form is mandatory only when Other is selected", () => {
  assert.deepEqual(
    buildMedicineCatalogueIdentityUpdate({
      ...draft,
      dosage_form: "other",
      custom_dosage_form: "",
    }),
    { error: "missing-custom-dosage-form" },
  );
  const result = buildMedicineCatalogueIdentityUpdate({
    ...draft,
    dosage_form: "other",
    custom_dosage_form: " oral suspension ",
  });
  assert.equal("data" in result, true);
  if ("data" in result) assert.equal(result.data.dosage_form, "oral suspension");
});

test("identity editor and pack verifier roles remain distinct and case-sensitive", () => {
  assert.equal(isMedicineIdentityEditorRole("admin"), true);
  assert.equal(isMedicineIdentityEditorRole("pharmacist"), true);
  assert.equal(isMedicineIdentityEditorRole("super_admin"), true);
  assert.equal(isMedicineIdentityEditorRole("doctor"), false);
  assert.equal(isMedicineIdentityEditorRole("Admin"), false);
  assert.equal(isMedicinePackVerifierRole("pharmacist"), true);
  assert.equal(isMedicinePackVerifierRole("super_admin"), true);
  assert.equal(isMedicinePackVerifierRole("admin"), false);
});

test("catalogue search returns null for too-short input and searches identity fields", () => {
  assert.equal(buildMedicineCatalogueSearchFilter(" a "), null);
  assert.equal(
    buildMedicineCatalogueSearchFilter("amoxicillin"),
    "name.ilike.%amoxicillin%,generic_name.ilike.%amoxicillin%,brand_name.ilike.%amoxicillin%,strength.ilike.%amoxicillin%,dosage_form.ilike.%amoxicillin%",
  );
});

test("catalogue search neutralizes PostgREST filter delimiters and wildcard injection", () => {
  const result = buildMedicineCatalogueSearchFilter("amox,brand).ilike.*%_\\\\'\"");
  assert.equal(
    result,
    "name.ilike.%amox brand .ilike.%,generic_name.ilike.%amox brand .ilike.%,brand_name.ilike.%amox brand .ilike.%,strength.ilike.%amox brand .ilike.%,dosage_form.ilike.%amox brand .ilike.%",
  );
});
