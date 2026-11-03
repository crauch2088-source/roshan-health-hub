import assert from "node:assert/strict";
import test from "node:test";
import { buildPrescriptionPrintModel } from "../src/lib/print/prescription.ts";

const completePrescription = () => ({
  id: "rx-1",
  created_at: "2026-11-03T10:00:00Z",
  status: "pending",
  is_external: false,
  patients: { full_name: "Synthetic Patient", mrn: "MRN-001" },
  users: { full_name: "Dr Synthetic" },
  prescription_items: [
    {
      id: "item-1",
      medication_name: "Amoxicillin",
      dose: "500 mg",
      route: "oral",
      frequency: "TID",
      duration: "5 days",
      quantity: 15,
      dosage_form: "Capsule",
      instructions: "After meals",
      deleted_at: null,
    },
  ],
});

test("prescription print model preserves saved patient, author, and medication values", () => {
  const model = buildPrescriptionPrintModel(completePrescription());
  assert.ok(model);
  assert.equal(model.complete, true);
  assert.equal(model.patientName, "Synthetic Patient");
  assert.equal(model.patientMrn, "MRN-001");
  assert.equal(model.prescriberName, "Dr Synthetic");
  assert.equal(model.items[0].dose, "500 mg");
  assert.equal(model.items[0].route, "oral");
  assert.equal(model.items[0].quantity, 15);
  assert.equal(model.items[0].instructions, "After meals");
});

test("incomplete prescription instructions block official printing without inferred values", () => {
  const record = completePrescription();
  record.prescription_items[0].dose = "";
  record.prescription_items[0].route = "";
  record.prescription_items[0].dosage_form = "";
  record.prescription_items[0].quantity = 0;
  const model = buildPrescriptionPrintModel(record);
  assert.ok(model);
  assert.equal(model.complete, false);
  assert.equal(model.items[0].dose, "");
  assert.equal(model.items[0].route, "");
  assert.equal(model.items[0].dosageForm, "");
  assert.equal(model.items[0].quantity, 0);
  assert.ok(model.missingFields.includes("item 1: dose"));
  assert.ok(model.missingFields.includes("item 1: route"));
  assert.ok(model.missingFields.includes("item 1: dosage form"));
  assert.ok(model.missingFields.includes("item 1: quantity"));
});

test("soft-deleted prescription items are excluded from the printable copy", () => {
  const record = completePrescription();
  record.prescription_items[0].deleted_at = "2026-11-03T11:00:00Z";
  const model = buildPrescriptionPrintModel(record);
  assert.ok(model);
  assert.equal(model.items.length, 0);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("items"));
});

test("missing patient or prescriber identity blocks official prescription printing", () => {
  const record = completePrescription();
  record.patients = null;
  record.users = null;
  const model = buildPrescriptionPrintModel(record);
  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("patient"));
  assert.ok(model.missingFields.includes("prescriber"));
});
