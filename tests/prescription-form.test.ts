import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildMedicineSearchFilter,
  createEmptyPrescriptionEntry,
  preparePrescriptionEntryForMedicine,
} from "../src/lib/prescription-form.ts";

test("empty prescription entry has no inherited regimen and starts at quantity one", () => {
  assert.deepEqual(createEmptyPrescriptionEntry(), {
    medicine_id: "",
    name: "",
    dose: "",
    frequency: "",
    duration: "",
    quantity: "1",
    instructions: "",
    dosage_form: "",
    route: "",
  });
});

test("choosing a new medicine clears the previous medicine-specific regimen", () => {
  const entry = preparePrescriptionEntryForMedicine(
    {
      medicine_id: "old",
      name: "Old medicine",
      dose: "500 mg",
      frequency: "twice_daily",
      duration: "7_days",
      quantity: "14",
      instructions: "after meals",
      dosage_form: "tablet",
      route: "oral",
    },
    {
      id: "new",
      name: "New medicine",
      generic_name: "New generic",
      dosage_form: "Capsule",
    },
  );

  assert.deepEqual(entry, {
    medicine_id: "new",
    name: "New medicine",
    dose: "",
    frequency: "",
    duration: "",
    quantity: "1",
    instructions: "",
    dosage_form: "capsule",
    route: "oral",
  });
});

test("medicine search is server-side filterable across canonical name fields", () => {
  assert.equal(
    buildMedicineSearchFilter("amoxicillin"),
    "name.ilike.%amoxicillin%,generic_name.ilike.%amoxicillin%,brand_name.ilike.%amoxicillin%,strength.ilike.%amoxicillin%",
  );
});

test("short and empty medicine search terms do not trigger a broad catalog query", () => {
  assert.equal(buildMedicineSearchFilter(""), null);
  assert.equal(buildMedicineSearchFilter("a"), null);
  assert.equal(buildMedicineSearchFilter("  a  "), null);
});

test("medicine search removes PostgREST filter grammar characters", () => {
  assert.equal(
    buildMedicineSearchFilter("amox),status.eq.active,(brand"),
    "name.ilike.%amox status.eq.active brand%,generic_name.ilike.%amox status.eq.active brand%,brand_name.ilike.%amox status.eq.active brand%,strength.ilike.%amox status.eq.active brand%",
  );
});
