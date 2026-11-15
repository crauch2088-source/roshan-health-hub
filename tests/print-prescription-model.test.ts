import assert from "node:assert/strict";
import test from "node:test";
import { buildPrescriptionPrintModel } from "../src/lib/print/prescription.ts";

const completePrescription = () => ({
  id: "rx-1",
  created_at: "2026-11-03T10:00:00Z",
  status: "pending",
  is_external: false,
  branch_id: "branch-1",
  patients: { full_name: "Synthetic Patient", mrn: "MRN-001", branch_id: "branch-1" },
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
  const model = buildPrescriptionPrintModel(completePrescription(), "branch-1");
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

test("incomplete saved medication fields block official printing without inferred values", () => {
  const record = completePrescription();
  record.prescription_items[0].dose = "";
  record.prescription_items[0].route = "";
  record.prescription_items[0].dosage_form = "";
  record.prescription_items[0].quantity = 0;
  const model = buildPrescriptionPrintModel(record, "branch-1");
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
  const model = buildPrescriptionPrintModel(record, "branch-1");
  assert.ok(model);
  assert.equal(model.items.length, 0);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("items"));
});

test("missing patient or prescriber identity blocks official printing", () => {
  const record = completePrescription();
  record.patients = null;
  record.users = null;
  const model = buildPrescriptionPrintModel(record, "branch-1");
  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("patient"));
  assert.ok(model.missingFields.includes("prescriber"));
});

test("prescription print model blocks missing or cross-branch source context", () => {
  const record = completePrescription();
  record.branch_id = "branch-2";
  const model = buildPrescriptionPrintModel(record, "branch-1");
  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("branch binding"));

  const missingContext = buildPrescriptionPrintModel(completePrescription());
  assert.ok(missingContext);
  assert.equal(missingContext.complete, false);
  assert.ok(missingContext.missingFields.includes("branch binding"));
});

test("soft-deleted patient identity blocks official prescription printing", () => {
  const record = completePrescription();
  Object.assign(record.patients, { deleted_at: "2026-11-03T11:00:00Z" });
  const model = buildPrescriptionPrintModel(record, "branch-1");
  assert.ok(model);
  assert.equal(model.complete, false);
  assert.ok(model.missingFields.includes("patient record"));
});

test("only pending and dispensed saved prescription statuses are printable", () => {
  for (const status of ["pending", "dispensed"]) {
    const record = completePrescription();
    record.status = status;
    const model = buildPrescriptionPrintModel(record, "branch-1");
    assert.ok(model);
    assert.equal(model.complete, true);
    assert.equal(model.status, status);
  }
});

test("cancelled, draft, correction-requested, missing and unknown statuses block printing", () => {
  const invalidStatuses: Array<string | null> = [
    "cancelled",
    "draft",
    "correction_requested",
    null,
    "future_status",
  ];

  for (const status of invalidStatuses) {
    const record = completePrescription();
    if (status === null) {
      delete (record as { status?: string }).status;
    } else {
      record.status = status;
    }

    const model = buildPrescriptionPrintModel(record, "branch-1");
    assert.ok(model);
    assert.equal(model.complete, false, `status ${String(status)} must not be printable`);
    assert.ok(model.missingFields.includes("prescription status"));
  }
});

test("external prescriptions remain printable copies when their saved status is pending", () => {
  const record = completePrescription();
  record.is_external = true;
  const model = buildPrescriptionPrintModel(record, "branch-1");
  assert.ok(model);
  assert.equal(model.complete, true);
  assert.equal(model.isExternal, true);
});
