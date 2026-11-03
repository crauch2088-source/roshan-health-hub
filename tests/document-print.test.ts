import assert from "node:assert/strict";
import test from "node:test";

import {
  getClinicIdentity,
  getReceiptPrintState,
  isPrescriptionPrintReady,
} from "../src/lib/document-print.ts";

test("receipt print state requires matching ledger and payment reversal flags", () => {
  assert.equal(
    getReceiptPrintState({ deleted_at: null }, {
      ledger_found: true,
      ledger_matches: true,
      ledger_is_reversed: false,
    }),
    "active",
  );
  assert.equal(
    getReceiptPrintState({ deleted_at: "2026-11-03T10:00:00Z" }, {
      ledger_found: true,
      ledger_matches: true,
      ledger_is_reversed: true,
    }),
    "void",
  );
  assert.equal(
    getReceiptPrintState({ deleted_at: null }, {
      ledger_found: true,
      ledger_matches: false,
      ledger_is_reversed: false,
    }),
    "inconsistent",
  );
  assert.equal(getReceiptPrintState({ deleted_at: null }, null), "inconsistent");
  assert.equal(
    getReceiptPrintState({ deleted_at: "2026-11-03T10:00:00Z" }, {
      ledger_found: true,
      ledger_matches: true,
      ledger_is_reversed: false,
    }),
    "inconsistent",
  );
});

test("only complete internal prescriptions are printable", () => {
  const complete = {
    prescription_type: "internal",
    is_external: false,
    prescription_items: [{
      medication_name: "Amoxicillin",
      dose: "500 mg",
      frequency: "Every 8 hours",
      duration: "5 days",
      quantity: 15,
    }],
  };
  assert.equal(isPrescriptionPrintReady(complete), true);
  assert.equal(isPrescriptionPrintReady({ ...complete, prescription_type: "external" }), false);
  assert.equal(isPrescriptionPrintReady({ ...complete, is_external: true }), false);
  assert.equal(
    isPrescriptionPrintReady({
      ...complete,
      prescription_items: [{ ...complete.prescription_items[0], frequency: "" }],
    }),
    false,
  );
  assert.equal(
    isPrescriptionPrintReady({
      ...complete,
      prescription_items: [{ ...complete.prescription_items[0], quantity: 0 }],
    }),
    false,
  );
  assert.equal(isPrescriptionPrintReady({ ...complete, prescription_items: [] }), false);
});

test("clinic identity uses localized center name and branch-specific contact details", () => {
  assert.deepEqual(
    getClinicIdentity(
      { center_name: "Roshan Health Hub", center_name_ar: "مركز روشان الطبي", address: "Main", phone: "111" },
      { branch_name: "Al-Sadaqa", address: "Branch address", phone: "222" },
      "ar",
    ),
    {
      name: "مركز روشان الطبي",
      branchName: "Al-Sadaqa",
      address: "Branch address",
      phone: "222",
    },
  );
  assert.deepEqual(
    getClinicIdentity({}, null, "en"),
    { name: "ROSHAN Medical Center", branchName: "", address: "", phone: "" },
  );
});
